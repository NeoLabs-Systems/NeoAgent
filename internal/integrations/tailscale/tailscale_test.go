package tailscale

import (
	"context"
	"encoding/json"
	"errors"
	"reflect"
	"regexp"
	"strconv"
	"sync"
	"testing"

	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/integrationstest"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/replaytest"
)

type vectors struct {
	Steps []struct {
		replaytest.Step
		Op         string            `json:"op"`
		App        string            `json:"app"`
		Replies    []json.RawMessage `json:"replies"`
		Connection string            `json:"connection"`
		Services   any               `json:"services"`
		Tool       string            `json:"tool"`
		Args       map[string]any    `json:"args"`
	} `json:"steps"`
}

var opPattern = regexp.MustCompile(`[a-f0-9]{48}`)

// fakeComputer answers with the recorded replies and records the requests in
// the shape the Node test recorded.
type fakeComputer struct {
	mu      sync.Mutex
	replies []json.RawMessage
	calls   []any
}

func (f *fakeComputer) Isolated() bool { return true }

func (f *fakeComputer) Request(_ context.Context, userID int64, method, path string, body any, o ComputerRequest) (map[string]any, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	call := map[string]any{"userId": userID, "method": method, "path": opPattern.ReplaceAllString(path, "<op>"), "timeoutMs": o.Timeout.Milliseconds(), "maxResponseBytes": nil}
	if o.MaxResponseBytes > 0 {
		call["maxResponseBytes"] = o.MaxResponseBytes
	}
	if body != nil {
		raw, _ := json.Marshal(body)
		var copy map[string]any
		_ = json.Unmarshal(raw, &copy)
		if _, ok := copy["operationId"]; ok {
			copy["operationId"] = "<op>"
		}
		call["body"] = copy
	}
	f.calls = append(f.calls, call)
	if len(f.replies) == 0 {
		return map[string]any{}, nil
	}
	next := f.replies[0]
	f.replies = f.replies[1:]
	var reply map[string]any
	if err := json.Unmarshal(next, &reply); err != nil {
		return nil, errors.New("bad reply")
	}
	return reply, nil
}

// TestMatchesNode replays the Node provider's recorded sign-in, grants and
// node operations against a fake cloud computer.
func TestMatchesNode(t *testing.T) {
	var v vectors
	replaytest.Load(t, &v)
	fc := &fakeComputer{}
	var p *Provider
	st := integrationstest.New(t, func(svc *integrations.Services) []integrations.Provider {
		p = New(svc)
		p.SetComputer(fc)
		return []integrations.Provider{p}
	}, integrations.Hooks{})
	ctx := context.Background()
	agent, err := st.Svc.ResolveAgent(ctx, 1, "")
	if err != nil {
		t.Fatal(err)
	}
	scope := integrations.Scope{UserID: 1, AgentID: agent}
	current := func() integrations.Connection {
		rows, err := st.Svc.ListConnections(ctx, 1, providerKey, agent)
		if err != nil || len(rows) != 1 {
			t.Fatalf("connections: %v %d", err, len(rows))
		}
		return rows[0]
	}
	sessionID := ""
	for _, step := range v.Steps {
		fc.mu.Lock()
		fc.replies, fc.calls = append([]json.RawMessage(nil), step.Replies...), nil
		fc.mu.Unlock()
		var got any
		var err error
		switch step.Op {
		case "env":
			got = p.EnvStatus(scope)
		case "begin":
			var start integrations.ConnectionStart
			start, err = p.BeginConnection(ctx, scope, step.App)
			if err == nil {
				sessionID = start.SessionID
				start.SessionID = "<session>"
				start.URL = "/api/integrations/tailscale/connect/<session>"
			}
			got = start
		case "session":
			s, ok := p.ConnectionSession(scope, sessionID)
			if !ok {
				t.Fatalf("%s: session missing", step.Name)
			}
			s.ID = "<session>"
			raw, _ := json.Marshal(s)
			var m map[string]any
			_ = json.Unmarshal(raw, &m)
			delete(m, "qr") // the Go session always has the member; the Node one has none
			if id, ok := m["connectionId"].(float64); ok {
				// Row ids differ between the databases; the id must be the stored row.
				if int64(id) != current().ID {
					t.Errorf("%s: connectionId %v is not the stored row", step.Name, id)
				}
				want := replaytest.Decode(t, step.Result).(map[string]any)
				m["connectionId"] = want["connectionId"]
			}
			got = m
		case "stored":
			c := current()
			var meta, scopes any
			_ = json.Unmarshal([]byte(c.MetadataJSON), &meta)
			_ = json.Unmarshal([]byte(c.ScopesJSON), &scopes)
			got = map[string]any{"user_id": c.UserID, "agent_id": "<agent>", "provider_key": c.ProviderKey, "app_key": c.AppKey,
				"status": c.Status, "account_email": c.AccountEmail, "scopes_json": scopes, "credentials_json": st.Svc.Credentials(c), "metadata_json": meta}
			want := replaytest.Decode(t, step.Result).(map[string]any)
			want["agent_id"] = "<agent>"
			var wantMeta, wantScopes any
			_ = json.Unmarshal([]byte(want["metadata_json"].(string)), &wantMeta)
			_ = json.Unmarshal([]byte(want["scopes_json"].(string)), &wantScopes)
			want["metadata_json"], want["scopes_json"] = wantMeta, wantScopes
			if g := replaytest.Normalize(t, got); !reflect.DeepEqual(g, replaytest.Normalize(t, want)) {
				t.Errorf("stored connection\n got %v\nwant %v", g, want)
			}
			continue
		case "services":
			id := "999"
			if step.Connection == "own" {
				id = strconv.FormatInt(current().ID, 10)
			}
			got, err = p.SetServiceAccess(ctx, scope, id, step.Services)
		case "exec":
			var ex *integrations.Execution
			ex, err = p.ExecuteTool(ctx, step.Tool, step.Args, current())
			if ex != nil {
				got = ex.Result
			}
		case "read_write":
			if _, err := st.DB.W.Exec(`UPDATE integration_connections SET metadata_json = json_set(metadata_json, '$.access_mode', 'read_write') WHERE provider_key = 'tailscale'`); err != nil {
				t.Fatal(err)
			}
			continue
		case "credentials":
			got = st.Svc.Credentials(current())
		case "disconnect":
			err = p.Disconnect(ctx, current())
		default:
			t.Fatalf("unknown op %q", step.Op)
		}
		replaytest.Check(t, step.Step, got, err)
		fc.mu.Lock()
		calls := fc.calls
		fc.mu.Unlock()
		if calls == nil {
			calls = []any{}
		}
		if len(step.Calls) > 0 {
			if g, w := replaytest.Normalize(t, calls), replaytest.Decode(t, step.Calls); !reflect.DeepEqual(g, w) {
				t.Errorf("%s: computer calls\n got %s\nwant %s", step.Name, mustJSON(g), step.Calls)
			}
		}
	}
}

func mustJSON(v any) string {
	raw, _ := json.Marshal(v)
	return string(raw)
}

func TestNotConfiguredWithoutAnIsolatedComputer(t *testing.T) {
	p := New(&integrations.Services{})
	if env := p.EnvStatus(integrations.Scope{}); env.Configured || env.Missing[0] != "isolated_computer" {
		t.Fatalf("env %+v", env)
	}
	if !p.Info().Exclusive {
		t.Fatal("tool calls must be exclusive per connection")
	}
}
