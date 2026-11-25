package ai

import (
	"crypto/sha256"
	"encoding/hex"
	"regexp"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/textx"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/tools"
)

// StableHash is the sha256 of a value's canonical JSON (object keys sorted), or
// of the text itself when the value is a string.
func StableHash(value any) string {
	text, ok := value.(string)
	if !ok {
		text = dyn.Stringify(value)
	}
	sum := sha256.Sum256([]byte(text))
	return hex.EncodeToString(sum[:])
}

var (
	shellCommentLine = regexp.MustCompile(`(^|\n)` + `[` + textx.SpaceClass + `]*#[^\n\r\x{2028}\x{2029}]*`)
	shellRedirect    = regexp.MustCompile(`2?>[` + textx.SpaceClass + `]*(?:"[^"]+"|'[^']+'|[^` + textx.SpaceClass + `]+)`)
	urlInCommand     = regexp.MustCompile("(?i)https?://[^\\s\"'`|;&)]+")
	pathInCommand    = regexp.MustCompile("(?:^|\\s)(/[A-Za-z0-9._~/%+-][^\\s\"'`|;&)]*)")
	repoSearch       = regexp.MustCompile(`(?i)\brepo:[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+`)
	queryOrFragment  = regexp.MustCompile(`(?s)[?#].*$`)
	outputTrim       = regexp.MustCompile(`\|\s*(cat|head(?:\s+-n?\s+\d+)?|tail(?:\s+-n?\s+\d+)?|wc(?:\s+-[A-Za-z]+)?)\b[^|;&]*`)
)

// NormalizeReadOnlyShellIntent reduces a read-only command to what it asks for:
// the same URLs, paths or repository searches are the same question however the
// command is phrased or piped.
func NormalizeReadOnlyShellIntent(command string) dyn.Map {
	text := shellCommentLine.ReplaceAllString(command, "\n")
	text = shellRedirect.ReplaceAllString(text, "")
	text = textx.Collapse(text)

	urls := []string{}
	for _, m := range urlInCommand.FindAllString(text, -1) {
		urls = append(urls, queryOrFragment.ReplaceAllString(m, ""))
	}
	paths := []string{}
	for _, m := range pathInCommand.FindAllStringSubmatch(text, -1) {
		if p := queryOrFragment.ReplaceAllString(m[1], ""); !strings.HasPrefix(p, "/tmp/") {
			paths = append(paths, p)
		}
	}
	repos := []string{}
	for _, m := range repoSearch.FindAllString(text, -1) {
		repos = append(repos, strings.ToLower(m))
	}
	sort.Strings(urls)
	sort.Strings(paths)
	sort.Strings(repos)
	if len(urls) > 0 || len(paths) > 0 || len(repos) > 0 {
		return dyn.Map{"kind": "read_only_shell_intent", "urls": urls, "paths": paths, "repoSearches": repos}
	}
	return dyn.Map{"kind": "read_only_shell_command", "command": textx.Trim(outputTrim.ReplaceAllString(text, ""))}
}

func canonicalToolArgs(toolName string, args dyn.Map) any {
	if toolName == "execute_command" && tools.IsClearlyReadOnlyShellCommand(dyn.Str(args["command"]), true) {
		return NormalizeReadOnlyShellIntent(dyn.Str(args["command"]))
	}
	if args == nil {
		return dyn.Map{}
	}
	return args
}

const (
	// How long an earlier answer can stand in for a repeated read. Nothing the
	// harness saw changed, but a person or a background process could have.
	duplicateReadWindow = 2 * time.Minute
	// A tool that fails the same way for different arguments is down, not
	// misused: a used-up search quota, an organization that blocks the app, a
	// service that is unreachable. Asking it again with other arguments only
	// burns turns, so after this many such failures in a row it rests, for as
	// long as it said or a minute.
	toolFailureLimit = 3
	toolRest         = time.Minute
)

type repetitionEntry struct {
	At             time.Time
	ResultHash     string
	UnchangedCount int
	Failure        string
}

type answeredRead struct {
	StepIndex int
	At        time.Time
}

type failureStreak struct {
	failure     string
	count       int
	until       time.Time
	serviceWait bool
}

// ToolResting says why a tool cannot be used right now.
type ToolResting struct {
	Failure     string
	Count       int
	RetryIn     time.Duration
	ServiceWait bool
}

// ToolRepetitionGuard tells a useful repeat from a useless one. A call's
// fingerprint includes the version of the state it depends on, so re-reading a
// file after an edit is new work and re-reading it before any edit is not. Two
// rules follow:
//
//   - A deterministic read repeated against unchanged state is suppressed once;
//     the model already has that answer. If it asks again it has a reason, such
//     as a background process writing the file, so the next one runs.
//   - Anything else is stopped only once it has failed the same way repeatedly:
//     a search or a poll can legitimately change, and a failed call changed
//     nothing, so repeating it cannot turn out differently.
type ToolRepetitionGuard struct {
	mu             sync.Mutex
	unchangedLimit int
	now            func() time.Time
	entries        map[string]*repetitionEntry
	answeredReads  map[string]answeredRead
	stateVersions  map[string]int
	toolFailures   map[string]*failureStreak
	// A compaction may have removed the earlier answer from the model's view.
	contextEpoch int
}

// NewToolRepetitionGuard creates a guard; unchangedLimit below 1 means 2 and a
// nil clock means time.Now.
func NewToolRepetitionGuard(unchangedLimit int, now func() time.Time) *ToolRepetitionGuard {
	if unchangedLimit < 1 {
		unchangedLimit = 2
	}
	if now == nil {
		now = time.Now
	}
	return &ToolRepetitionGuard{
		unchangedLimit: unchangedLimit,
		now:            now,
		entries:        map[string]*repetitionEntry{},
		answeredReads:  map[string]answeredRead{},
		stateVersions:  map[string]int{},
		toolFailures:   map[string]*failureStreak{},
	}
}

// Fingerprint identifies a call together with the state it depends on.
func (g *ToolRepetitionGuard) Fingerprint(toolName string, args dyn.Map, stateScope string) string {
	g.mu.Lock()
	defer g.mu.Unlock()
	if stateScope == "" {
		stateScope = "none"
	}
	return StableHash(dyn.Map{
		"tool":  toolName,
		"args":  canonicalToolArgs(toolName, args),
		"state": stateScope + ":" + itoa(g.stateVersions[stateScope]),
		"epoch": g.contextEpoch,
	})
}

func (g *ToolRepetitionGuard) key(toolName string, args dyn.Map, stateScope string) string {
	state := ""
	if stateScope != "" {
		state = ":" + stateScope + ":" + itoa(g.stateVersions[stateScope])
	}
	return toolName + state + ":" + StableHash(canonicalToolArgs(toolName, args))
}

// NoteStateChanged records that something a scope's reads depend on changed.
func (g *ToolRepetitionGuard) NoteStateChanged(scope string) {
	g.mu.Lock()
	defer g.mu.Unlock()
	if scope != "" && scope != "none" {
		g.stateVersions[scope]++
	}
}

// NoteCompaction forgets earlier answers: the model no longer sees them.
func (g *ToolRepetitionGuard) NoteCompaction() {
	g.mu.Lock()
	defer g.mu.Unlock()
	g.contextEpoch++
	clear(g.answeredReads)
	for key, entry := range g.entries {
		if entry.Failure == "" {
			delete(g.entries, key)
		}
	}
}

// ClaimRead claims a read before it runs, so identical reads in one parallel
// batch run once. It returns the earlier answer's record when this read repeats
// one still in the window; the claim is dropped again then, and when the read
// fails, so one repeat is stopped and the one after it is not.
func (g *ToolRepetitionGuard) ClaimRead(fingerprint string, stepIndex int) *answeredRead {
	g.mu.Lock()
	defer g.mu.Unlock()
	if prior, ok := g.answeredReads[fingerprint]; ok && g.now().Sub(prior.At) < duplicateReadWindow {
		delete(g.answeredReads, fingerprint)
		return &prior
	}
	g.answeredReads[fingerprint] = answeredRead{StepIndex: stepIndex, At: g.now()}
	return nil
}

// ReleaseRead drops a read's claim.
func (g *ToolRepetitionGuard) ReleaseRead(fingerprint string) {
	g.mu.Lock()
	defer g.mu.Unlock()
	delete(g.answeredReads, fingerprint)
}

// ShouldBlock reports whether the call has failed the same way often enough to
// stop. Successful reads use the timed claim cache; repeated failures are
// blocked, but reads may retry after expiry because external state can change.
func (g *ToolRepetitionGuard) ShouldBlock(toolName string, args dyn.Map, readOnly bool, stateScope string) bool {
	g.mu.Lock()
	defer g.mu.Unlock()
	entry := g.entries[g.key(toolName, args, stateScope)]
	if entry == nil || entry.UnchangedCount < g.unchangedLimit {
		return false
	}
	if readOnly && g.now().Sub(entry.At) >= duplicateReadWindow {
		return false
	}
	return entry.Failure != ""
}

// LastFailure is the failure the call last ended in.
func (g *ToolRepetitionGuard) LastFailure(toolName string, args dyn.Map, stateScope string) string {
	g.mu.Lock()
	defer g.mu.Unlock()
	if entry := g.entries[g.key(toolName, args, stateScope)]; entry != nil {
		return entry.Failure
	}
	return ""
}

// ToolResting says why a tool cannot be used right now, or nil.
func (g *ToolRepetitionGuard) ToolResting(toolName string) *ToolResting {
	g.mu.Lock()
	defer g.mu.Unlock()
	streak := g.toolFailures[toolName]
	if streak == nil || streak.count < toolFailureLimit || !g.now().Before(streak.until) {
		return nil
	}
	return &ToolResting{Failure: streak.failure, Count: streak.count, RetryIn: streak.until.Sub(g.now()), ServiceWait: streak.serviceWait}
}

func (g *ToolRepetitionGuard) noteToolOutcome(toolName, failure string, result any) {
	if failure == "" {
		delete(g.toolFailures, toolName)
		return
	}
	count := 1
	if previous := g.toolFailures[toolName]; previous != nil && previous.failure == failure {
		count = previous.count + 1
	}
	retryAfter := toolRest
	wait, _ := dyn.Float(dyn.Get(result, "retryAfterSeconds"))
	serviceWait := wait > 0
	if serviceWait {
		retryAfter = time.Duration(wait * float64(time.Second))
	}
	g.toolFailures[toolName] = &failureStreak{failure: failure, count: count, until: g.now().Add(retryAfter), serviceWait: serviceWait}
}

// Observe records what a call returned and says how often that has now
// happened in a row.
func (g *ToolRepetitionGuard) Observe(toolName string, args dyn.Map, result any, failure, stateScope string) UnchangedObservation {
	g.mu.Lock()
	defer g.mu.Unlock()
	g.noteToolOutcome(toolName, failure, result)
	key := g.key(toolName, args, stateScope)
	var resultHash string
	if failure != "" {
		resultHash = StableHash(dyn.Map{"failure": failure})
	} else {
		resultHash = StableHash(result)
	}
	unchanged := 1
	if previous := g.entries[key]; previous != nil && previous.ResultHash == resultHash {
		unchanged = previous.UnchangedCount + 1
	}
	g.entries[key] = &repetitionEntry{At: g.now(), ResultHash: resultHash, UnchangedCount: unchanged, Failure: failure}
	return UnchangedObservation{UnchangedCount: unchanged, Failure: failure}
}

// UnchangedObservation is what Observe reports.
type UnchangedObservation struct {
	UnchangedCount int
	Failure        string
}

func itoa(n int) string { return dyn.Number(float64(n)) }
