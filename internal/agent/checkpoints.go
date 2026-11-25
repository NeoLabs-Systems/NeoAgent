package agent

import (
	"context"
	"path"
	"regexp"
	"strings"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/ai"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/tools"
	"github.com/NeoLabs-Systems/neoagent/internal/runledger"
	"github.com/NeoLabs-Systems/neoagent/internal/workspace/repotools"
)

// Workspace checkpoints (workspace_checkpoint.js): advisory change tracking
// for repo_diff, never proof of ownership. External editors and processes can
// write during any tool, so automatic restore is refused.

const (
	checkpointCommandTimeout = 30 * time.Second
	// Reading a tree this slow around every call would cost more than an undo is worth.
	checkpointSlowRead = 5 * time.Second
	gitlinkMode        = "160000"
)

// CommandRunner runs a script in the user's workspace, where every computer
// maps the guest workspace directory. The record carries exitCode, stdout,
// stderr and truncated.
type CommandRunner interface {
	RunInWorkspace(ctx context.Context, userID int64, runID, deviceTarget, script string, timeout time.Duration) (dyn.Map, error)
}

type checkpointPath struct{ source string }

type checkpointRepo struct {
	paths   map[string]checkpointPath
	order   []string
	tooSlow bool
}

// checkpointState is what a run's checkpoints know.
type checkpointState struct {
	mu              sync.Mutex
	notRepositories map[string]bool
	repositories    map[string]*checkpointRepo
	repoOrder       []string
	directories     map[string]string
	untracked       []map[string]any
}

func newCheckpointState() *checkpointState {
	return &checkpointState{notRepositories: map[string]bool{}, repositories: map[string]*checkpointRepo{}, directories: map[string]string{}}
}

type checkpointStart struct {
	root, tree, file string
	call             ai.Call
}

var (
	cdPrefix = regexp.MustCompile(`^\s*cd\s+("[^"]+"|'[^']+'|[^\s;&|]+)\s*(?:&&|;)`)
	rawDiff  = regexp.MustCompile(`^:(\d+) (\d+) ([0-9a-f]+) ([0-9a-f]+) \S+\t(.+)$`)
	treeID   = regexp.MustCompile(`^[0-9a-f]{40,64}$`)
	notRepo  = regexp.MustCompile(`(?i)not a git repository`)
)

func targetFile(call ai.Call, meta tools.Meta) string {
	if meta.Group == "shell" {
		return ""
	}
	if target := dyn.Str(call.Arguments["path"]); target != "" {
		return repotools.FromGuestWorkspacePath(target)
	}
	return ""
}

// commandDirectory is where a call works. A shell command often moves there
// itself: "cd project && ...".
func commandDirectory(call ai.Call, meta tools.Meta) string {
	if meta.Group == "shell" {
		if cwd := dyn.Str(call.Arguments["cwd"]); cwd != "" {
			return repotools.FromGuestWorkspacePath(cwd)
		}
		if m := cdPrefix.FindStringSubmatch(dyn.Str(call.Arguments["command"])); m != nil {
			return repotools.FromGuestWorkspacePath(strings.Trim(m[1], `"'`))
		}
		return ""
	}
	if file := targetFile(call, meta); file != "" {
		return path.Dir(file)
	}
	return ""
}

// repositoryScript runs a command from the directory a call means, or the
// nearest existing parent of it.
func repositoryScript(directory, command string) string {
	lines := []string{"set -e"}
	if directory != "" {
		lines = append(lines, "d="+repotools.ShellQuote(directory),
			`while [ ! -d "$d" ] && [ "$d" != "." ] && [ "$d" != "/" ]; do d=$(dirname "$d"); done`, `cd "$d"`)
	}
	return strings.Join(append(lines, command), "\n")
}

type rawChange struct {
	path    string
	gitlink bool
}

// parseRawDiff reads ":100644 100644 <old> <new> M\tpath". Quoted names are
// left out: not recording a file only means nothing tracks it.
func parseRawDiff(text string) []rawChange {
	var out []rawChange
	for _, line := range strings.Split(text, "\n") {
		m := rawDiff.FindStringSubmatch(line)
		if m == nil || strings.HasPrefix(m[5], `"`) {
			continue
		}
		out = append(out, rawChange{path: m[5], gitlink: m[1] == gitlinkMode || m[2] == gitlinkMode})
	}
	return out
}

// checkpoints is the ai.Checkpointer of one run.
type checkpoints struct {
	e *Engine
	r *Run
}

func (c checkpoints) state() *checkpointState {
	c.r.mu.Lock()
	defer c.r.mu.Unlock()
	if c.r.checkpoints == nil {
		c.r.checkpoints = newCheckpointState()
	}
	return c.r.checkpoints
}

func (c checkpoints) run(ctx context.Context, script string) (dyn.Map, error) {
	return c.e.deps.Commands.RunInWorkspace(ctx, c.r.UserID, c.r.ID, c.r.DeviceTarget, script, checkpointCommandTimeout)
}

func exitCode(result dyn.Map) (int, bool) {
	n, ok := dyn.Int(result["exitCode"])
	return n, ok
}

type treeRead struct {
	root, tree    string
	notRepository bool
}

func (c checkpoints) readTree(ctx context.Context, directory string) (treeRead, error) {
	result, err := c.run(ctx, repositoryScript(directory, repotools.SnapshotCommand()))
	if err != nil {
		return treeRead{}, err
	}
	if code, ok := exitCode(result); !ok || code != 0 {
		return treeRead{notRepository: notRepo.MatchString(dyn.Str(result["stderr"]))}, nil
	}
	lines := strings.Split(strings.TrimSpace(dyn.Str(result["stdout"])), "\n")
	if len(lines) < 2 || lines[0] == "" || !treeID.MatchString(lines[1]) {
		return treeRead{}, nil
	}
	return treeRead{root: lines[0], tree: lines[1]}, nil
}

func (c checkpoints) noteUntracked(call ai.Call, reason string) {
	st := c.state()
	st.mu.Lock()
	st.untracked = append(st.untracked, map[string]any{"tool": call.Name, "reason": reason})
	st.mu.Unlock()
	c.e.RecordEvent(c.r.UserID, c.r.ID, c.r.AgentID, runledger.EventWorkspaceChanged, map[string]any{"untracked": true, "tool": call.Name, "reason": reason})
}

// Begin reads the tree a mutating call starts from. A failure never stops the
// work, but it is recorded, so repo_diff and the outcome say what is not covered.
func (c checkpoints) Begin(ctx context.Context, s *ai.Session, call ai.Call, meta tools.Meta) any {
	st := c.state()
	directory := commandDirectory(call, meta)
	key := directory
	if key == "" {
		key = "."
	}
	st.mu.Lock()
	known := st.notRepositories[key]
	knownRoot := st.directories[key]
	anySlow := false
	for _, repo := range st.repositories {
		anySlow = anySlow || repo.tooSlow
	}
	st.mu.Unlock()
	if known {
		c.noteUntracked(call, "not_a_repository")
		return nil
	}
	started := time.Now()
	if knownRoot == "" && anySlow {
		// Resolve identity cheaply before deciding whether a full snapshot is allowed.
		result, err := c.run(ctx, repositoryScript(directory, repotools.GitFunction+"\ng rev-parse --show-toplevel"))
		if err == nil {
			if code, ok := exitCode(result); ok && code == 0 {
				knownRoot = strings.TrimSpace(dyn.Str(result["stdout"]))
				st.mu.Lock()
				st.directories[key] = knownRoot
				st.mu.Unlock()
			}
		}
	}
	st.mu.Lock()
	slow := knownRoot != "" && st.repositories[knownRoot] != nil && st.repositories[knownRoot].tooSlow
	st.mu.Unlock()
	if slow {
		c.noteUntracked(call, "repository_too_slow")
		return nil
	}
	start, err := c.readTree(ctx, directory)
	if err != nil {
		c.e.log.Warn("Could not read the workspace", "error", err)
		c.noteUntracked(call, "read_failed")
		return nil
	}
	if start.notRepository {
		st.mu.Lock()
		st.notRepositories[key] = true
		st.mu.Unlock()
	}
	if start.tree == "" {
		reason := "read_failed"
		if start.notRepository {
			reason = "not_a_repository"
		}
		c.noteUntracked(call, reason)
		return nil
	}
	st.mu.Lock()
	st.directories[key] = start.root
	repo := st.repositories[start.root]
	created := repo == nil
	if created {
		repo = &checkpointRepo{paths: map[string]checkpointPath{}}
		st.repositories[start.root] = repo
		st.repoOrder = append(st.repoOrder, start.root)
	}
	tooSlow := repo.tooSlow
	if !tooSlow && time.Since(started) > checkpointSlowRead {
		repo.tooSlow = true
	}
	st.mu.Unlock()
	if created {
		c.e.RecordEvent(c.r.UserID, c.r.ID, c.r.AgentID, runledger.EventCheckpointCreated, map[string]any{"kind": "workspace", "duration_ms": time.Since(started).Milliseconds()})
	}
	if tooSlow {
		c.noteUntracked(call, "repository_too_slow")
		return nil
	}
	return &checkpointStart{root: start.root, tree: start.tree, file: targetFile(call, meta), call: call}
}

// Record notes the paths a call changed. The first snapshot is the baseline,
// not an ownership claim or leave to restore the path.
func (c checkpoints) Record(ctx context.Context, s *ai.Session, started any) {
	m, ok := started.(*checkpointStart)
	if !ok || m == nil {
		return
	}
	end, err := c.readTree(ctx, m.root)
	if err != nil || end.tree == "" {
		c.noteUntracked(m.call, "read_failed")
		return
	}
	if end.tree == m.tree {
		return
	}
	diff, err := c.run(ctx, repotools.GitFunction+"\ncd "+repotools.ShellQuote(m.root)+" && g -c core.quotepath=off diff-tree -r --no-renames --raw "+
		repotools.ShellQuote(m.tree)+" "+repotools.ShellQuote(end.tree))
	code, codeOK := exitCode(diff)
	if err != nil || !codeOK || code != 0 || dyn.Truthy(diff["truncated"]) {
		reason := "read_failed"
		if err == nil && dyn.Truthy(diff["truncated"]) {
			reason = "too_many_changes"
		}
		c.noteUntracked(m.call, reason)
		return
	}
	listed := parseRawDiff(dyn.Str(diff["stdout"]))
	var changes []string
	submodule := false
	for _, change := range listed {
		if change.gitlink {
			submodule = true
			continue
		}
		// A file tool changes the one file it names; anything else that moved in
		// that moment is someone else's.
		if m.file != "" && m.file != change.path && !strings.HasSuffix(m.file, "/"+change.path) {
			continue
		}
		changes = append(changes, change.path)
	}
	if submodule {
		c.noteUntracked(m.call, "submodule")
	}
	st := c.state()
	st.mu.Lock()
	repo := st.repositories[m.root]
	for _, p := range changes {
		known, seen := repo.paths[p]
		source := m.tree
		if seen {
			source = known.source
		} else {
			repo.order = append(repo.order, p)
		}
		repo.paths[p] = checkpointPath{source: source}
	}
	st.mu.Unlock()
	if len(changes) > 0 {
		shown := changes
		if len(shown) > 50 {
			shown = shown[:50]
		}
		c.e.RecordEvent(c.r.UserID, c.r.ID, c.r.AgentID, runledger.EventWorkspaceChanged, map[string]any{"count": len(changes), "paths": shown})
	}
}

// RunRepositories is what a run's checkpoints recorded it changed, for repo_diff.
func (e *Engine) RunRepositories(runID string) []dyn.Map {
	r, ok := e.RunInfo(runID)
	if !ok || r == nil {
		return nil
	}
	r.mu.Lock()
	st := r.checkpoints
	r.mu.Unlock()
	if st == nil {
		return nil
	}
	st.mu.Lock()
	defer st.mu.Unlock()
	var out []dyn.Map
	for _, root := range st.repoOrder {
		repo := st.repositories[root]
		paths := []any{}
		for _, p := range repo.order {
			paths = append(paths, dyn.Map{"path": p, "source": repo.paths[p].source})
		}
		out = append(out, dyn.Map{"root": root, "paths": paths})
	}
	return out
}

// checkpointChangedPaths are the paths a run's checkpoints saw it change.
func (r *Run) checkpointChangedPaths() []string {
	r.mu.Lock()
	st := r.checkpoints
	r.mu.Unlock()
	if st == nil {
		return nil
	}
	st.mu.Lock()
	defer st.mu.Unlock()
	var out []string
	for _, root := range st.repoOrder {
		out = append(out, st.repositories[root].order...)
	}
	return out
}

// RollbackWorkspace: a before/after tree cannot tell the run's writes from an
// external editor's, and a check followed by restore cannot exclude an external
// write in between, so no destructive Git command is ever guessed.
func (e *Engine) RollbackWorkspace(ctx context.Context, runID string) any {
	return dyn.Ordered{{Key: "success", Value: false},
		{Key: "error", Value: "Automatic workspace rollback is disabled: this shared workspace cannot prove exclusive ownership of changes. Inspect repo_diff and correct specific edits forward."}}
}

// FileDiagnosticsHistory is the diagnostics a run has seen per file.
func (e *Engine) FileDiagnosticsHistory(runID string) map[string]string {
	r, ok := e.RunInfo(runID)
	if !ok || r == nil {
		return nil
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.fileDiagnostics == nil {
		r.fileDiagnostics = map[string]string{}
	}
	return r.fileDiagnostics
}
