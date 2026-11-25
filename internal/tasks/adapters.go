package tasks

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"math"
	"regexp"
	"slices"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/tasks/jsv"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
)

// Adapter describes one kind of trigger: how its settings are checked and
// shown, and how it fires, by polling an integration or by an event.
type Adapter struct {
	Type        string
	Label       string
	ProviderKey string // the integration it needs, if any
	AppKey      string
	// ConfigHint tells the model how to write the trigger's settings.
	ConfigHint string
	// Validate checks and normalizes a trigger's settings.
	Validate func(vc *validation, config *jsv.Object) (*jsv.Object, error)
	// Summarize is the trigger in a few words.
	Summarize func(config *jsv.Object) string
	// Poll, when set, makes the scheduler look for news every few minutes.
	Poll *Poll
	// Event, when set, fires the task from an event the server raises itself.
	Event *EventSpec
	// ReplyTarget names the chat thread a firing event belongs to.
	ReplyTarget func(event map[string]any) (platform, to string, ok bool)
}

// validation is what a trigger's settings are checked against.
type validation struct {
	ctx             context.Context
	db              *dbx.DB
	userID          int64
	agentID         string
	taskID          int64
	hasIntegrations bool
	timeZone        *time.Location
}

// Row is something a poll found: a fingerprint that identifies it, when it
// happened, what the run is told about it, and whether it only moves the
// checkpoint (Silent).
type Row struct {
	Fingerprint string
	Timestamp   string
	Context     *jsv.Object
	Silent      bool
}

// ToolFunc runs an integration tool for the task's account: the connection
// arguments are added to args.
type ToolFunc func(name string, args *jsv.Object) (any, error)

// Poll describes how an integration trigger looks for news.
type Poll struct {
	// IntervalMinutes is how often to look; nil means every minute.
	IntervalMinutes func(config *jsv.Object) float64
	// Cursor is "list" (rows are the latest items and the checkpoint is the
	// last one fired) or "ordered" (fingerprints sort chronologically, so every
	// row after the checkpoint is new).
	Cursor string
	// Baseline, for an ordered cursor with no checkpoint, is "now" (start from
	// the time the task was first polled) or "latest" (from the newest row).
	Baseline string
	// InitialCheckpoint, when set, is stored as the checkpoint on creation.
	InitialCheckpoint func() string
	// FetchRows returns the rows, oldest first.
	FetchRows func(tool ToolFunc, config *jsv.Object, checkpoint string, now time.Time) ([]Row, error)
}

// Payload is what an event hands a task: a fingerprint (so the same event never
// runs a task twice), when it happened and what the run is told.
type Payload struct {
	Fingerprint string
	Timestamp   string
	Context     *jsv.Object
}

// EventSpec describes how an event trigger fires.
type EventSpec struct {
	// Source and Name identify the event: "runtime" events are raised by this
	// package's PublishEvent, the others come through HandleEvent.
	Source, Name string
	Matches      func(config *jsv.Object, event map[string]any, task taskRow) bool
	ToPayload    func(event map[string]any, config *jsv.Object) Payload
}

// ---- reading loosely typed JSON, as the adapters' JavaScript did ------------

// pick is `config.a || config.b || ...`: the first truthy member, else the last.
func pick(o *jsv.Object, keys ...string) any {
	var v any
	for _, k := range keys {
		if v = o.Val(k); jsv.Truthy(v) {
			return v
		}
	}
	return v
}

// coalesce is `config.a ?? config.b`: the first member that is neither null nor missing.
func coalesce(o *jsv.Object, keys ...string) any {
	for _, k := range keys {
		if v, ok := o.Get(k); ok && v != nil {
			return v
		}
	}
	return nil
}

// dig follows keys through objects; anything missing reads as nil.
func dig(v any, keys ...string) any {
	for _, k := range keys {
		o, ok := v.(*jsv.Object)
		if !ok {
			return nil
		}
		v = o.Val(k)
	}
	return v
}

func str(v any) string {
	if v == nil {
		return ""
	}
	return jsv.String(v)
}

// orNil turns a falsy value into null, as `value || null` does.
func orNil(v any) any {
	if jsv.Truthy(v) {
		return v
	}
	return nil
}

func objects(v any) []*jsv.Object {
	var out []*jsv.Object
	if list, ok := v.([]any); ok {
		for _, item := range list {
			if o, ok := item.(*jsv.Object); ok {
				out = append(out, o)
			}
		}
	}
	return out
}

// listFrom finds the list in a tool's answer: the answer itself, one of keys,
// the same keys under .result, or .result itself.
func listFrom(result any, keys ...string) []any {
	if list, ok := result.([]any); ok {
		return list
	}
	for _, k := range keys {
		if list, ok := dig(result, k).([]any); ok {
			return list
		}
		if list, ok := dig(result, "result", k).([]any); ok {
			return list
		}
	}
	if list, ok := dig(result, "result").([]any); ok {
		return list
	}
	return []any{}
}

func trimText(v any, max int) string { return jsv.Slice(jsv.Trim(jsv.Text(v)), max) }

func requiredText(v any, max int, message string) (string, error) {
	text := trimText(v, max)
	if text == "" {
		return "", errors.New(message)
	}
	return text, nil
}

func normalizeBoolean(v any, fallback bool) bool {
	switch v := v.(type) {
	case bool:
		return v
	case string:
		switch strings.ToLower(jsv.Trim(v)) {
		case "true", "1", "yes", "on":
			return true
		case "false", "0", "no", "off":
			return false
		}
	}
	return fallback
}

// optionalNumber is null for an empty value and an error for text that is not a number.
func optionalNumber(v any) (any, error) {
	if v == nil || jsv.Trim(jsv.String(v)) == "" {
		return nil, nil
	}
	n := jsv.Number(v)
	if math.IsNaN(n) || math.IsInf(n, 0) {
		return nil, fmt.Errorf("\"%s\" is not a number.", jsv.String(v))
	}
	return n, nil
}

func boundedInteger(v any, fallback, min, max int) int {
	n := math.Floor(jsv.Number(v) + 0.5)
	if math.IsNaN(n) || math.IsInf(n, 0) {
		return fallback
	}
	return int(math.Max(float64(min), math.Min(n, float64(max))))
}

var ownerRepoPattern = regexp.MustCompile(`^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$`)

func ownerRepo(config *jsv.Object) (string, error) {
	repo := trimText(pick(config, "repo", "owner_repo"), 200)
	if !ownerRepoPattern.MatchString(repo) {
		return "", errors.New(`GitHub repository is required in the format "owner/repo".`)
	}
	return repo, nil
}

// timeCursor leads with a timestamp so ordered cursors compare as plain text;
// it is "" when the time cannot be read.
func timeCursor(value any, id any) string {
	var ms float64
	if v, ok := value.(float64); ok {
		ms = v
	} else {
		t, ok := jsv.ParseDate(jsv.Text(value))
		if !ok {
			return ""
		}
		ms = float64(t.UnixMilli())
	}
	if math.IsNaN(ms) || math.IsInf(ms, 0) {
		return ""
	}
	return jsv.ISO(time.UnixMilli(int64(ms))) + "|" + idText(id)
}

// idText is `${id}` in a template string.
func idText(id any) string {
	if id == nil {
		return "undefined"
	}
	return jsv.String(id)
}

var nonDigits = regexp.MustCompile(`\D`)

func sequenceCursor(v any) string {
	digits := nonDigits.ReplaceAllString(jsv.Text(v), "")
	if digits == "" {
		return ""
	}
	return strings.Repeat("0", max(16-len(digits), 0)) + digits
}

// summaryParts joins a label and the parts that are set with " · ".
func summaryParts(label string, parts ...any) string {
	out := []string{label}
	for _, p := range parts {
		switch p := p.(type) {
		case bool, nil:
			// a false flag or a missing value leaves its part out
		case string:
			if p != "" {
				out = append(out, p)
			}
		default:
			if jsv.Truthy(p) {
				out = append(out, jsv.String(p))
			}
		}
	}
	return strings.Join(out, " · ")
}

// when gives text when cond is set, or "" otherwise: the `value && \`text\“
// of the JavaScript.
func when(cond any, text string) string {
	if jsv.Truthy(cond) {
		return text
	}
	return ""
}

// localeCompare orders strings like String.prototype.localeCompare does in
// ICU's root collation for the characters ids and times use: punctuation, then
// digits, then letters ignoring case, lower case first among equals.
func localeCompare(a, b string) int {
	ra, rb := []rune(a), []rune(b)
	for i := 0; i < len(ra) && i < len(rb); i++ {
		if ka, kb := collationKey(ra[i]), collationKey(rb[i]); ka != kb {
			return cmpInt(ka, kb)
		}
	}
	if len(ra) != len(rb) {
		return cmpInt(len(ra), len(rb))
	}
	for i := range ra {
		if ra[i] != rb[i] {
			if ra[i] > rb[i] { // lower case sorts first
				return -1
			}
			return 1
		}
	}
	return 0
}

const punctuationOrder = "_-,;:!?.'\"()[]{}@*/\\&#%`^+<=>|~$"

func collationKey(r rune) int {
	switch {
	case r >= '0' && r <= '9':
		return 1000 + int(r-'0')
	case r >= 'a' && r <= 'z':
		return 2000 + int(r-'a')*2
	case r >= 'A' && r <= 'Z':
		return 2000 + int(r-'A')*2
	}
	if i := strings.IndexRune(punctuationOrder, r); i >= 0 {
		return 100 + i
	}
	return 3000 + int(r)
}

func cmpInt(a, b int) int {
	if a < b {
		return -1
	}
	return 1
}

func sortRows(rows []Row, compare func(a, b Row) int) []Row {
	slices.SortStableFunc(rows, compare)
	return rows
}

func byFingerprint(a, b Row) int { return localeCompare(a.Fingerprint, b.Fingerprint) }
func byTimestamp(a, b Row) int   { return localeCompare(a.Timestamp, b.Timestamp) }

func keepFingerprinted(rows []Row) []Row {
	return slices.DeleteFunc(rows, func(r Row) bool { return r.Fingerprint == "" })
}

// ---- integration connections -----------------------------------------------

type connection struct {
	ID       int64
	Provider string
	App      string
	Status   string
	Email    sql.NullString
}

// ownedConnection finds the connection a trigger names, which must be the
// agent's own, connected, and of the provider (and app) the trigger needs.
func (vc *validation) ownedConnection(config *jsv.Object, providerKey, appKey string) (*connection, error) {
	id := jsv.Number(pick(config, "connectionId", "connection_id"))
	if !jsv.IsInteger(id) || id <= 0 {
		return nil, errors.New("A valid integration connection is required.")
	}
	if !vc.hasIntegrations {
		return nil, errors.New("Official integration manager is not available.")
	}
	var c connection
	err := vc.db.W.QueryRowContext(vc.ctx, `SELECT id, provider_key, app_key, status, account_email FROM integration_connections WHERE user_id = ? AND agent_id = ? AND id = ?`,
		vc.userID, vc.agentID, int64(id)).Scan(&c.ID, &c.Provider, &c.App, &c.Status, &c.Email)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, errors.New("Integration connection not found for this agent.")
	}
	if err != nil {
		return nil, err
	}
	switch {
	case jsv.Trim(c.Provider) != jsv.Trim(providerKey):
		return nil, errors.New("Integration connection does not match the selected provider.")
	case appKey != "" && jsv.Trim(c.App) != jsv.Trim(appKey):
		return nil, errors.New("Integration connection does not match the selected app.")
	case jsv.Trim(c.Status) != "connected":
		return nil, errors.New("Integration connection is not connected.")
	}
	return &c, nil
}

func (c *connection) email() any {
	if c.Email.Valid && c.Email.String != "" {
		return c.Email.String
	}
	return nil
}

// connectionConfig is the connection fields every integration trigger stores.
func (vc *validation) connectionConfig(config *jsv.Object, providerKey, appKey string) (*jsv.Object, error) {
	c, err := vc.ownedConnection(config, providerKey, appKey)
	if err != nil {
		return nil, err
	}
	return jsv.NewObject().Set("connectionId", float64(c.ID)).Set("accountEmail", c.email()), nil
}

// withConnection runs build on the settings of a trigger that needs an
// integration account, putting the connection fields first.
func (vc *validation) withConnection(config *jsv.Object, providerKey, appKey string, build func(out *jsv.Object) error) (*jsv.Object, error) {
	out, err := vc.connectionConfig(config, providerKey, appKey)
	if err != nil {
		return nil, err
	}
	return out, build(out)
}
