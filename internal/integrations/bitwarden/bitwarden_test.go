package bitwarden

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/credentials"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/integrationstest"
)

// fakeBW answers like the Bitwarden CLI and records each call.
type fakeBW struct {
	mu     sync.Mutex
	calls  []string
	envs   [][]string
	inputs []string
	status string
	fail   map[string]error
}

func (f *fakeBW) run(_ context.Context, _ string, args, env []string, input string, _ time.Duration) (string, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	cmd := strings.Join(args, " ")
	f.calls = append(f.calls, cmd)
	f.envs = append(f.envs, env)
	f.inputs = append(f.inputs, input)
	if err, ok := f.fail[args[0]]; ok {
		return "", err
	}
	switch args[0] {
	case "status":
		return f.status, nil
	case "login", "unlock":
		return "session-key", nil
	case "list":
		return `[{"id":"i1","name":"Bank","login":{"username":"u"}}]`, nil
	}
	return "", nil
}

func envHas(env []string, kv string) bool {
	for _, e := range env {
		if e == kv {
			return true
		}
	}
	return false
}

type sealer struct{}

func (sealer) Seal(s string) (string, error) { return "sealed:" + s, nil }
func (sealer) Open(s string) (string, error) { return strings.TrimPrefix(s, "sealed:"), nil }

func TestCLISignInUnlockAndLock(t *testing.T) {
	bw := &fakeBW{status: `{"status":"unauthenticated"}`}
	dir := t.TempDir()
	c := &CLI{Binary: "bw", DataDir: dir, Sealer: sealer{}, Run: bw.run}
	ctx := context.Background()
	if _, err := c.Unlock(ctx, 1, "a", "", nil, UnlockOptions{Email: "n@example.com"}); err == nil || err.Error() != "Bitwarden master password is required." {
		t.Fatalf("empty password: %v", err)
	}
	if _, err := c.Unlock(ctx, 1, "a", "pw", 3.0, UnlockOptions{Email: "n@example.com", TwoStepMethod: "9"}); err == nil ||
		err.(*CodedError).Code() != "BITWARDEN_TWO_STEP_METHOD_INVALID" {
		t.Fatalf("bad method: %v", err)
	}
	bw.calls, bw.envs, bw.inputs = nil, nil, nil
	st, err := c.Unlock(ctx, 1, "a", "pw", 3.0, UnlockOptions{ServerURL: "https://vault.example/", Email: "n@example.com", TwoStepMethod: "0", TwoStepCode: "123456", Persist: true})
	if err != nil {
		t.Fatal(err)
	}
	if want := "config server https://vault.example|status|login n@example.com --passwordenv NEOAGENT_BITWARDEN_MASTER_PASSWORD --raw --method 0 --code 123456"; strings.Join(bw.calls, "|") != want {
		t.Fatalf("calls %q", bw.calls)
	}
	if !envHas(bw.envs[2], "NEOAGENT_BITWARDEN_MASTER_PASSWORD=pw") || bw.inputs[2] != "123456\n" ||
		!envHas(bw.envs[0], "BITWARDENCLI_APPDATA_DIR="+filepath.Join(dir, "integrations", "bitwarden", "1", "a")) {
		t.Fatalf("env/input: %v %q", bw.envs[2], bw.inputs[2])
	}
	if !st.Unlocked || !st.Persistent || st.IdleMinutes != nil {
		t.Fatalf("status %+v", st)
	}
	saved, err := os.ReadFile(filepath.Join(dir, "integrations", "bitwarden", "1", "a", sessionFile))
	if err != nil || !strings.Contains(string(saved), `"sessionKey":"session-key"`) {
		t.Fatalf("persisted session: %s %v", saved, err)
	}
	if info, _ := os.Stat(filepath.Join(dir, "integrations", "bitwarden", "1", "a", sessionFile)); info.Mode().Perm() != 0o600 {
		t.Fatalf("session file mode %v", info.Mode())
	}

	// A fresh driver picks the persisted session up.
	again := &CLI{Binary: "bw", DataDir: dir, Sealer: sealer{}, Run: bw.run}
	items, err := again.ListItems(ctx, 1, "a")
	if err != nil || len(items) != 1 || items[0]["id"] != "i1" || !envHas(bw.envs[len(bw.envs)-1], "BW_SESSION=session-key") {
		t.Fatalf("items %v %v", items, err)
	}
	again.Lock(ctx, 1, "a")
	if _, err := again.ListItems(ctx, 1, "a"); err == nil || err.(*CodedError).Code() != "BITWARDEN_LOCKED" {
		t.Fatalf("after lock: %v", err)
	}
	if _, err := os.Stat(filepath.Join(dir, "integrations", "bitwarden", "1", "a", sessionFile)); !os.IsNotExist(err) {
		t.Fatalf("persisted session survived lock: %v", err)
	}

	// Without a code, "Code is required." becomes the verification prompt.
	bw.fail = map[string]error{"login": &CodedError{code: "BITWARDEN_CLI_FAILED", message: "Bitwarden: Code is required.", cliMessage: "Code is required."}}
	if _, err := c.Unlock(ctx, 2, "a", "pw", nil, UnlockOptions{Email: "n@example.com"}); err == nil || err.(*CodedError).Code() != "BITWARDEN_VERIFICATION_CODE_REQUIRED" {
		t.Fatalf("verification: %v", err)
	}
}

func TestCLIIdleSessionsLock(t *testing.T) {
	now := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	bw := &fakeBW{status: `{"status":"locked","userEmail":"n@example.com"}`}
	c := &CLI{Binary: "bw", DataDir: t.TempDir(), Sealer: sealer{}, Run: bw.run, Now: func() time.Time { return now }}
	if _, err := c.Unlock(context.Background(), 1, "a", "pw", 5.0, UnlockOptions{Email: "n@example.com"}); err != nil {
		t.Fatal(err)
	}
	if bw.calls[len(bw.calls)-1] != "unlock --passwordenv NEOAGENT_BITWARDEN_MASTER_PASSWORD --raw" {
		t.Fatalf("signed-in account unlocks only: %v", bw.calls)
	}
	now = now.Add(4 * time.Minute)
	c.LockExpired(context.Background())
	if !c.GetStatus(1, "a").Unlocked {
		t.Fatal("locked too early")
	}
	now = now.Add(2 * time.Minute)
	c.LockExpired(context.Background())
	if c.GetStatus(1, "a").Unlocked {
		t.Fatal("idle session stayed unlocked")
	}
}

type fakeBroker struct{}

func (fakeBroker) ListVaultItems(context.Context, int64, string) ([]credentials.SafeItem, error) {
	return nil, nil
}
func (fakeBroker) ListBindings(context.Context, int64, string) ([]credentials.Binding, error) {
	return nil, nil
}
func (fakeBroker) DeleteBinding(context.Context, int64, string, string) (bool, error) {
	return false, nil
}

func TestSetupUnlockAndRoutes(t *testing.T) {
	bw := &fakeBW{status: `{"status":"unauthenticated"}`}
	var p *Provider
	var api *integrations.API
	s := integrationstest.New(t, func(svc *integrations.Services) []integrations.Provider {
		p = New(svc, &CLI{Binary: "bw", DataDir: t.TempDir(), Sealer: sealer{}, Run: bw.run}, nil)
		return []integrations.Provider{p}
	}, integrations.Hooks{})
	api = integrations.New(integrations.Config{Manager: s.Mgr, UserID: func(r *http.Request) (int64, bool) { return 1, r.Header.Get("X-Test-User") == "1" }})
	mux := http.NewServeMux()
	Routes(mux, api, p, fakeBroker{})
	srv := httptest.NewServer(mux)
	defer srv.Close()
	if code, body := call(t, srv, "POST", "/api/integrations/bitwarden/unlock", `{"masterPassword":"pw"}`); code != 400 ||
		body != `{"error":"Save the Bitwarden account email before signing in.","code":null}` {
		t.Fatalf("unlock route: %d %s", code, body)
	}
	if code, body := call(t, srv, "GET", "/api/integrations/bitwarden/items", ""); code != 200 || body != `{"items":[]}` {
		t.Fatalf("items: %d %s", code, body)
	}
	if code, body := call(t, srv, "DELETE", "/api/integrations/bitwarden/bindings/b1", ""); code != 200 || body != `{"deleted":false}` {
		t.Fatalf("delete binding: %d %s", code, body)
	}
	if code, body := call(t, srv, "POST", "/api/integrations/bitwarden/lock", ""); code != 200 || body != `{"locked":true}` {
		t.Fatalf("lock: %d %s", code, body)
	}

	ctx := context.Background()
	scope := integrations.Scope{UserID: 1, AgentID: s.MainAgent(t, 1)}
	if _, err := p.SaveSetup(ctx, scope, map[string]any{"serverUrl": "http://vault.example"}); err == nil ||
		err.Error() != "Bitwarden server must be an HTTPS URL without embedded credentials." {
		t.Fatalf("http server: %v", err)
	}
	if _, err := p.SaveSetup(ctx, scope, map[string]any{}); err == nil || err.Error() != "Bitwarden account email is required." {
		t.Fatalf("no email: %v", err)
	}
	if _, err := p.Unlock(ctx, scope, "pw", true, nil, nil); err == nil || err.Error() != "Save the Bitwarden account email before signing in." {
		t.Fatalf("unlock before setup: %v", err)
	}
	cfg, err := p.SaveSetup(ctx, scope, map[string]any{"email": "n@example.com", "clientSecret": "s", "idleTimeoutMinutes": 500.0})
	if err != nil {
		t.Fatal(err)
	}
	if got := mustJSON(cfg); got != `{"serverUrl":"https://vault.bitwarden.com","email":"n@example.com","authenticationMethod":"master_password","hasClientId":false,"hasClientSecret":true,"configured":true,"accountCount":0,"hasConnectedAccount":false,"connectionId":null,"cliAvailable":true,"unlocked":false,"persistent":false,"lastUsedAt":null}` {
		t.Fatalf("config %s", got)
	}
	if !p.EnvStatus(scope).Configured {
		t.Fatal("env not configured after setup")
	}
	out, err := p.Unlock(ctx, scope, "pw", false, nil, "")
	if err != nil {
		t.Fatal(err)
	}
	if got := mustJSON(out); !strings.Contains(got, `"accountCount":1,"hasConnectedAccount":true`) || !strings.Contains(got, `"unlocked":true,"persistent":false`) {
		t.Fatalf("after unlock %s", got)
	}
	snap := p.Snapshot(mustRows(t, s, scope), scope)
	if !snap.Connection.Connected || snap.AvailableToolCount != 2 || p.SummarizeForModel(snap) != "Bitwarden credential broker: No credential bindings are configured. Secret values are never available to the model." {
		t.Fatalf("snapshot %+v", snap)
	}
	if err := p.ClearSetup(ctx, scope); err != nil {
		t.Fatal(err)
	}
	if rows := mustRows(t, s, scope); len(rows) != 0 || p.cli.GetStatus(1, scope.AgentID).Unlocked {
		t.Fatalf("clear left %v", rows)
	}
}

func mustRows(t *testing.T, s *integrationstest.Stack, scope integrations.Scope) []integrations.Connection {
	t.Helper()
	rows, err := s.Svc.ListConnections(context.Background(), scope.UserID, key, scope.AgentID)
	if err != nil {
		t.Fatal(err)
	}
	return rows
}

func mustJSON(v any) string {
	raw, err := json.Marshal(v)
	if err != nil {
		panic(err)
	}
	return string(raw)
}

func call(t *testing.T, srv *httptest.Server, method, path, body string) (int, string) {
	t.Helper()
	req, _ := http.NewRequest(method, srv.URL+path, strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Test-User", "1")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(resp.Body)
	return resp.StatusCode, string(raw)
}

func (fakeBroker) CreateBinding(context.Context, int64, string, map[string]any) (*credentials.Binding, error) {
	return nil, nil
}

func (fakeBroker) UpdateBinding(context.Context, int64, string, string, map[string]any) (*credentials.Binding, error) {
	return nil, nil
}
