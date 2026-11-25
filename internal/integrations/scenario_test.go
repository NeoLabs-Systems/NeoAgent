package integrations_test

import (
	"encoding/json"
	"os"
	"reflect"
	"regexp"
	"strconv"
	"strings"
	"testing"

	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/integrationstest"
)

type tstack struct{ *integrationstest.Stack }

// ---- replaying what the Node server answered --------------------------------

type step struct {
	Name     string             `json:"name"`
	Method   string             `json:"method"`
	Path     string             `json:"path"`
	User     int                `json:"user"`
	Provider string             `json:"provider"`
	Headers  map[string]string  `json:"headers"`
	Body     string             `json:"body"`
	SQL      string             `json:"sql"`
	Params   []any              `json:"params"`
	Env      map[string]*string `json:"env"`
	Expect   *struct {
		Status int    `json:"status"`
		Body   any    `json:"body"`
		Text   string `json:"text"`
	} `json:"expect"`
}

type scenario struct {
	Ported   map[string]string `json:"ported"`
	Steps    []step            `json:"steps"`
	Snapshot struct {
		Connections []map[string]any `json:"connections"`
		OAuthApps   []map[string]any `json:"oauthApps"`
		States      []map[string]any `json:"states"`
	} `json:"snapshot"`
}

func loadScenario(t *testing.T) scenario {
	t.Helper()
	raw, err := os.ReadFile("testdata/scenario.json")
	if err != nil {
		t.Fatal(err)
	}
	var sc scenario
	if err := json.Unmarshal(raw, &sc); err != nil {
		t.Fatal(err)
	}
	return sc
}

var (
	statePattern     = regexp.MustCompile(`[a-f0-9]{48}`)
	challengePattern = regexp.MustCompile(`code_challenge=[A-Za-z0-9_-]+`)
)

func (s *tstack) agentLabels(t *testing.T) map[string]string {
	t.Helper()
	rows, err := s.DB.W.Query(`SELECT id, user_id, slug FROM agents`)
	if err != nil {
		t.Fatal(err)
	}
	defer rows.Close()
	labels := map[string]string{}
	for rows.Next() {
		var id, slug string
		var user int64
		if err := rows.Scan(&id, &user, &slug); err != nil {
			t.Fatal(err)
		}
		labels[id] = "<agent:" + strconv.FormatInt(user, 10) + ":" + slug + ">"
	}
	return labels
}

func (s *tstack) normalize(t *testing.T, text string) string {
	text = statePattern.ReplaceAllString(text, "<state>")
	text = challengePattern.ReplaceAllString(text, "code_challenge=<challenge>")
	for id, label := range s.agentLabels(t) {
		text = strings.ReplaceAll(text, id, label)
	}
	return text
}

// ported keeps the answers about the providers this Go build serves: the list
// answer is every provider of the Node server.
func ported(provider string, keys map[string]bool, body any) any {
	list, ok := body.([]any)
	if !ok {
		return body
	}
	var out []any
	for _, item := range list {
		if m, ok := item.(map[string]any); ok && keys[m["id"].(string)] {
			out = append(out, item)
		}
	}
	return out
}

func decode(t *testing.T, text string) any {
	var v any
	if err := json.Unmarshal([]byte(text), &v); err != nil {
		t.Fatalf("not json: %s", text)
	}
	return v
}

// replay runs the recorded steps against a stack and fails on any difference.
func replay(t *testing.T, providers func(*integrations.Services) []integrations.Provider) {
	sc := loadScenario(t)
	s := &tstack{integrationstest.New(t, providers, integrations.Hooks{})}
	keys := map[string]bool{}
	for _, p := range s.Mgr.Providers() {
		keys[p.Info().Key] = true
	}
	for _, st := range sc.Steps {
		if st.Provider != "" && !keys[st.Provider] {
			continue
		}
		switch {
		case st.Env != nil:
			for name, value := range st.Env {
				s.SetEnv(name, value)
			}
		case st.SQL != "":
			if p := providerOfStep(st.Name); p != "" && !keys[p] {
				continue
			}
			s.Exec(t, st.SQL, st.Params...)
		default:
			got := s.Call(t, st.Method, st.Path, st.User, st.Body, st.Headers)
			if got.Status != st.Expect.Status {
				t.Errorf("%s: status %d, Node answered %d (%s)", st.Name, got.Status, st.Expect.Status, got.Raw)
				continue
			}
			var gotParsed any
			_ = json.Unmarshal([]byte(got.Raw), &gotParsed)
			want := st.Expect.Body
			gotBody := gotParsed
			if st.Path == "/api/integrations" || st.Path == "/api/integrations/" || strings.HasPrefix(st.Path, "/api/integrations?") {
				want, gotBody = ported("", keys, want), ported("", keys, gotParsed)
			}
			wantText, _ := json.Marshal(want)
			gotText, _ := json.Marshal(gotBody)
			wantNorm := decode(t, s.normalize(t, string(wantText)))
			gotNorm := decode(t, s.normalize(t, string(gotText)))
			if !reflect.DeepEqual(wantNorm, gotNorm) {
				t.Errorf("%s:\n  go:   %s\n  node: %s", st.Name, s.normalize(t, string(gotText)), s.normalize(t, string(wantText)))
			}
		}
	}

	s.checkSnapshot(t, sc, keys)
}

// providerOfStep reads "<provider>: ..." step names.
func providerOfStep(name string) string {
	if i := strings.Index(name, ": "); i > 0 {
		return name[:i]
	}
	return ""
}

func (s *tstack) checkSnapshot(t *testing.T, sc scenario, keys map[string]bool) {
	t.Helper()
	// Connections: the same rows, with the same metadata, for the providers served.
	rows, err := s.DB.W.Query(`SELECT user_id, agent_id, provider_key, app_key, status, account_email, scopes_json, metadata_json
		FROM integration_connections ORDER BY id`)
	if err != nil {
		t.Fatal(err)
	}
	defer rows.Close()
	var got []map[string]any
	for rows.Next() {
		var user int64
		var agent, provider, app, status, email, scopes, meta string
		if err := rows.Scan(&user, &agent, &provider, &app, &status, &email, &scopes, &meta); err != nil {
			t.Fatal(err)
		}
		got = append(got, map[string]any{
			"user_id": float64(user), "agent_id": agent, "provider_key": provider, "app_key": app,
			"status": status, "account_email": email, "scopes_json": scopes, "metadata_json": canonicalJSON(t, meta),
		})
	}
	var want []map[string]any
	for _, r := range sc.Snapshot.Connections {
		if keys[r["provider_key"].(string)] {
			r["metadata_json"] = canonicalJSON(t, r["metadata_json"].(string))
			want = append(want, r)
		}
	}
	labels := s.agentLabels(t)
	for _, r := range got {
		if l, ok := labels[r["agent_id"].(string)]; ok {
			r["agent_id"] = l
		}
	}
	for _, r := range want {
		if r["agent_id"] == "helper-agent-id" {
			r["agent_id"] = "<agent:1:helper>"
		} else {
			r["agent_id"] = "<agent:1:main>"
		}
	}
	if !reflect.DeepEqual(got, want) {
		gotText, _ := json.MarshalIndent(got, "", " ")
		wantText, _ := json.MarshalIndent(want, "", " ")
		t.Errorf("connection rows differ\n go: %s\nnode: %s", gotText, wantText)
	}

	// OAuth apps are stored sealed with the same fields.
	var apps []map[string]any
	appRows, err := s.DB.W.Query(`SELECT user_id, provider_key, config_json FROM integration_oauth_apps ORDER BY user_id, provider_key`)
	if err != nil {
		t.Fatal(err)
	}
	defer appRows.Close()
	for appRows.Next() {
		var user int64
		var provider, sealed string
		if err := appRows.Scan(&user, &provider, &sealed); err != nil {
			t.Fatal(err)
		}
		plain, err := s.Box.OpenSealed(sealed)
		if err != nil {
			t.Fatal(err)
		}
		apps = append(apps, map[string]any{"user_id": float64(user), "provider_key": provider, "config_json": decode(t, plain)})
	}
	var wantApps []map[string]any
	for _, r := range sc.Snapshot.OAuthApps {
		if keys[r["provider_key"].(string)] {
			wantApps = append(wantApps, r)
		}
	}
	if !reflect.DeepEqual(apps, wantApps) {
		t.Errorf("oauth apps differ\n go: %v\nnode: %v", apps, wantApps)
	}

	// Pending OAuth states: one per started flow, verifier sealed.
	var states []map[string]any
	stRows, err := s.DB.W.Query(`SELECT user_id, agent_id, provider_key, app_key, code_verifier, memory_sweep FROM integration_oauth_states ORDER BY id`)
	if err != nil {
		t.Fatal(err)
	}
	defer stRows.Close()
	for stRows.Next() {
		var user, sweep int64
		var agent, provider, app, verifier string
		if err := stRows.Scan(&user, &agent, &provider, &app, &verifier, &sweep); err != nil {
			t.Fatal(err)
		}
		plain, err := s.Box.OpenSealed(verifier)
		if err != nil {
			t.Fatal(err)
		}
		states = append(states, map[string]any{"user_id": float64(user), "agent_id": labels[agent], "provider_key": provider, "app_key": app, "code_verifier": float64(len(plain)), "memory_sweep": float64(sweep)})
	}
	var wantStates []map[string]any
	for _, r := range sc.Snapshot.States {
		if keys[r["provider_key"].(string)] {
			r["agent_id"] = "<agent:1:main>"
			wantStates = append(wantStates, r)
		}
	}
	if !reflect.DeepEqual(states, wantStates) {
		t.Errorf("oauth states differ\n go: %v\nnode: %v", states, wantStates)
	}
}

func canonicalJSON(t *testing.T, text string) string {
	t.Helper()
	out, _ := json.Marshal(decode(t, text))
	return string(out)
}
