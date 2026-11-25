// Package replay plays a conversation recorded from the Node server's real
// routes (see the gen/ scripts next to each package's tests) against the Go
// routes and requires the same answers. It is test support, imported only by
// tests.
package replay

import (
	"crypto/hmac"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"io"
	"math"
	"net/http"
	"os"
	"regexp"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/tasks/jsv"
)

// Webhook describes a signed delivery to a task webhook: the signature covers
// the timestamp and body with the secret a previous step captured.
type Webhook struct {
	SecretVar string `json:"secretVar"`
	RequestID string `json:"requestId"`
	// SkewMs shifts the signed timestamp from now.
	SkewMs int64 `json:"skewMs"`
	// BadSignature signs with the wrong secret.
	BadSignature bool `json:"badSignature"`
}

// Step is one request or SQL statement of a scenario.
type Step struct {
	Name    string            `json:"name"`
	Method  string            `json:"method"`
	Path    string            `json:"path"`
	User    int               `json:"user"`
	Headers map[string]string `json:"headers"`
	Body    string            `json:"body"`
	SQL     string            `json:"sql"`
	Params  []any             `json:"params"`
	Webhook *Webhook          `json:"webhook"`
	// Capture stores response members under variable names, written
	// {"secret": "secret"}; later paths, bodies and headers read them as {{secret}}.
	Capture map[string]string `json:"capture"`
	Expect  *struct {
		Status int    `json:"status"`
		Raw    string `json:"raw"`
	} `json:"expect"`
}

// Scenario is a recorded conversation.
type Scenario struct {
	// Volatile lists the keys whose string values change from run to run
	// (clock readings); they are compared as present or absent only.
	Volatile []string `json:"volatile"`
	// Rounded lists the keys whose numbers drift with clock readings (scores
	// that decay with age); they are compared to a millionth.
	Rounded []string `json:"rounded"`
	Steps   []Step   `json:"steps"`
	// Snapshot is the database state the conversation left behind.
	Snapshot []SnapshotRow `json:"snapshot"`
}

// Load reads a scenario file.
func Load(t *testing.T, path string) Scenario {
	t.Helper()
	raw, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	var sc Scenario
	if err := json.Unmarshal(raw, &sc); err != nil {
		t.Fatal(err)
	}
	return sc
}

var uuidPattern = regexp.MustCompile(`[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}`)

// Canonical rewrites a response so two runs of the same conversation read the
// same: random ids and agent ids become labels and volatile members a marker.
func Canonical(raw string, volatile []string, labels map[string]string) string {
	for id, label := range labels {
		raw = strings.ReplaceAll(raw, id, label)
	}
	raw = uuidPattern.ReplaceAllString(raw, "<uuid>")
	// A volatile member inside a JSON text stored in a string reads \"key\":\"...\".
	for _, k := range volatile {
		embedded := regexp.MustCompile(`\\"` + regexp.QuoteMeta(k) + `\\":\\"[^\\]*\\"`)
		raw = embedded.ReplaceAllLiteralString(raw, `\"`+k+`\":\"<time>\"`)
	}
	v, err := jsv.Decode([]byte(raw))
	if err != nil {
		return raw
	}
	set := map[string]bool{}
	for _, k := range volatile {
		set[k] = true
	}
	return jsv.Stringify(mask(v, set))
}

func mask(v any, volatile map[string]bool) any {
	switch v := v.(type) {
	case *jsv.Object:
		out := jsv.NewObject()
		for _, k := range v.Keys() {
			val := v.Val(k)
			if s, ok := val.(string); ok && volatile[k] && s != "" {
				val = "<time>"
			} else {
				val = mask(val, volatile)
			}
			out.Set(k, val)
		}
		return out
	case []any:
		out := make([]any, len(v))
		for i, e := range v {
			out[i] = mask(e, volatile)
		}
		return out
	}
	return v
}

// splitDrifting replaces the numbers under the given keys with a marker and
// returns them in document order, to be compared with a tolerance.
func splitDrifting(raw string, keys []string) (string, []float64) {
	if len(keys) == 0 {
		return raw, nil
	}
	v, err := jsv.Decode([]byte(raw))
	if err != nil {
		return raw, nil
	}
	set := map[string]bool{}
	for _, k := range keys {
		set[k] = true
	}
	var nums []float64
	var walk func(v any) any
	walk = func(v any) any {
		switch v := v.(type) {
		case *jsv.Object:
			out := jsv.NewObject()
			for _, k := range v.Keys() {
				val := v.Val(k)
				if f, ok := val.(float64); ok && set[k] {
					nums = append(nums, f)
					val = "<num>"
				} else {
					val = walk(val)
				}
				out.Set(k, val)
			}
			return out
		case []any:
			out := make([]any, len(v))
			for i, e := range v {
				out[i] = walk(e)
			}
			return out
		}
		return v
	}
	return jsv.Stringify(walk(v)), nums
}

// near says whether two lists of drifting numbers agree to a millionth.
func near(a, b []float64) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if math.Abs(a[i]-b[i]) > 1e-6*math.Max(1, math.Abs(b[i])) {
			return false
		}
	}
	return true
}

// Runner plays steps against a server.
type Runner struct {
	T       *testing.T
	BaseURL string
	// Exec runs a scenario's SQL step.
	Exec func(query string, params []any)
	// MainAgent returns the id of a user's main agent, written $main1 and $main2
	// in SQL steps; nil when the scenario names none.
	MainAgent func(userID int) string
	// Labels maps random agent ids to stable names; nil for none.
	Labels func() map[string]string
	vars   map[string]string
}

func (r *Runner) expand(s string) string {
	for k, v := range r.vars {
		s = strings.ReplaceAll(s, "{{"+k+"}}", v)
	}
	return s
}

// Run plays every step and fails the test on the first difference.
func (r *Runner) Run(sc Scenario) {
	r.vars = map[string]string{}
	for _, step := range sc.Steps {
		if step.SQL != "" {
			query := r.expand(step.SQL)
			if r.MainAgent != nil {
				for _, user := range []int{1, 2} {
					query = strings.ReplaceAll(query, "$main"+strconv.Itoa(user), r.MainAgent(user))
				}
			}
			r.Exec(query, step.Params)
			continue
		}
		status, raw := r.send(step)
		labels := map[string]string{}
		if r.Labels != nil {
			labels = r.Labels()
		}
		for name, member := range step.Capture {
			if v, ok := jsv.ParseObject(raw).Val(member).(string); ok {
				r.vars[name] = v
			}
		}
		if step.Expect == nil {
			continue
		}
		got, gotNums := splitDrifting(Canonical(raw, sc.Volatile, labels), sc.Rounded)
		want, wantNums := splitDrifting(step.Expect.Raw, sc.Rounded)
		if status != step.Expect.Status || got != want || !near(gotNums, wantNums) {
			r.T.Errorf("step %q (%s %s)\n got  %d %s\n want %d %s", step.Name, step.Method, step.Path, status, Canonical(raw, sc.Volatile, labels), step.Expect.Status, step.Expect.Raw)
		}
	}
}

func (r *Runner) send(step Step) (int, string) {
	body := r.expand(step.Body)
	headers := map[string]string{}
	for k, v := range step.Headers {
		headers[k] = r.expand(v)
	}
	if w := step.Webhook; w != nil {
		secret := r.vars[w.SecretVar]
		if w.BadSignature {
			secret += "x"
		}
		ts := strconv.FormatInt(time.Now().UnixMilli()+w.SkewMs, 10)
		mac := hmac.New(sha256.New, []byte(secret))
		mac.Write([]byte(ts + "." + body))
		headers["x-neoagent-timestamp"] = ts
		headers["x-neoagent-request-id"] = w.RequestID
		headers["x-neoagent-signature"] = "sha256=" + hex.EncodeToString(mac.Sum(nil))
	}
	var rdr io.Reader
	if body != "" {
		rdr = strings.NewReader(body)
	}
	req, err := http.NewRequest(step.Method, r.BaseURL+r.expand(step.Path), rdr)
	if err != nil {
		r.T.Fatal(err)
	}
	if body != "" {
		req.Header.Set("Content-Type", "application/json")
	}
	if step.User != 0 {
		req.Header.Set("X-Test-User", strconv.Itoa(step.User))
	}
	for k, v := range headers {
		req.Header.Set(k, v)
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		r.T.Fatal(err)
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(resp.Body)
	return resp.StatusCode, string(raw)
}

// SnapshotRow is one stored row of the final database state, written as
// canonical JSON.
type SnapshotRow struct {
	Table string `json:"table"`
	Row   string `json:"row"`
}

// Snapshot reads the rows of query as canonical JSON objects whose members
// follow the selected columns. transform may replace a column's value (to open
// a sealed one); it receives the column name and the stored value.
func Snapshot(t *testing.T, db *sql.DB, table, query string, volatile []string, labels map[string]string, transform func(col string, v any) any) []SnapshotRow {
	t.Helper()
	rows, err := db.Query(query)
	if err != nil {
		t.Fatal(err)
	}
	defer rows.Close()
	cols, _ := rows.Columns()
	var out []SnapshotRow
	for rows.Next() {
		values := make([]any, len(cols))
		ptrs := make([]any, len(cols))
		for i := range values {
			ptrs[i] = &values[i]
		}
		if err := rows.Scan(ptrs...); err != nil {
			t.Fatal(err)
		}
		obj := jsv.NewObject()
		for i, col := range cols {
			v := values[i]
			switch x := v.(type) {
			case int64:
				v = float64(x)
			case []byte:
				v = string(x)
			}
			if transform != nil {
				v = transform(col, v)
			}
			obj.Set(col, v)
		}
		out = append(out, SnapshotRow{Table: table, Row: Canonical(jsv.Stringify(obj), volatile, labels)})
	}
	return out
}

// Raw reads a scenario file's bytes, for tests that keep members of their own.
func Raw(t *testing.T, path string) []byte {
	t.Helper()
	raw, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	return raw
}

// Unmarshal decodes JSON into v, failing the test on error.
func Unmarshal(t *testing.T, raw []byte, v any) {
	t.Helper()
	if err := json.Unmarshal(raw, v); err != nil {
		t.Fatal(err)
	}
}
