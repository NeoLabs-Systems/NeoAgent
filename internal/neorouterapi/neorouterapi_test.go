package neorouterapi

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"net/netip"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/cloudsec"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
)

type memEnv struct {
	mu   sync.Mutex
	vals map[string]string
}

func (e *memEnv) Get(k string) string {
	e.mu.Lock()
	defer e.mu.Unlock()
	return e.vals[k]
}

func (e *memEnv) Set(k, v string) error {
	e.mu.Lock()
	defer e.mu.Unlock()
	e.vals[k] = v
	return nil
}

type memSettings struct {
	mu           sync.Mutex
	apiKey       string
	baseURL      string
	roles        any
	liveProvider string
	usableLive   map[string]bool
}

func (m *memSettings) NeoRouter(context.Context, int64, string) (string, string, any, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.apiKey, m.baseURL, m.roles, nil
}

func (m *memSettings) SaveUserNeoRouter(_ context.Context, _ int64, _ string, baseURL, apiKey string, roles []string, _ bool) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.baseURL = baseURL
	m.apiKey = apiKey
	m.roles = roles
	return nil
}

func (m *memSettings) ClearUserNeoRouter(context.Context, int64, string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.baseURL = ""
	m.apiKey = ""
	m.roles = nil
	return nil
}

func (m *memSettings) UpdateUserRoles(_ context.Context, _ int64, _ string, roles []string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.roles = roles
	return nil
}

func (m *memSettings) GetVoiceLiveProvider(context.Context, int64, string) (string, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.liveProvider, nil
}

func (m *memSettings) SetVoiceLiveProvider(_ context.Context, _ int64, _ string, provider string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.liveProvider = provider
	return nil
}

func (m *memSettings) IsLiveProviderUsable(_ context.Context, _ string, _ int64, _ string, provider string) (bool, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.usableLive[provider], nil
}

type memAccounts struct {
	admins map[int64]bool
}

func (a *memAccounts) IsAdmin(_ context.Context, userID int64) bool { return a.admins[userID] }
func (a *memAccounts) ResolveAgentID(_ context.Context, _ int64, raw string) string {
	if raw == "" {
		return "main"
	}
	return raw
}

func newTestSessions(t *testing.T) *sessionx.Manager {
	t.Helper()
	db, err := dbx.Open(context.Background(), t.TempDir()+"/sessions.db", dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = db.Close() })
	store, err := sessionx.NewStore(context.Background(), db.W)
	if err != nil {
		t.Fatal(err)
	}
	mgr, err := sessionx.NewManager(store, sessionx.Options{Name: "neoagent.sid", Secrets: []string{"test-secret"}})
	if err != nil {
		t.Fatal(err)
	}
	return mgr
}

func withSession(t *testing.T, mgr *sessionx.Manager, userID int64, h http.Handler) http.Handler {
	t.Helper()
	return mgr.Middleware(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if userID > 0 {
			sessionx.FromContext(r.Context()).Set("userId", userID)
		}
		h.ServeHTTP(w, r)
	}))
}

func TestAPIBaseForAndNormalizeRoles(t *testing.T) {
	if got := APIBaseFor("router.local:3333"); got != "https://router.local:3333/v1" {
		t.Fatalf("got %q", got)
	}
	if got := APIBaseFor("http://router.example.com:80/app/"); got != "http://router.example.com/v1" {
		t.Fatalf("got %q", got)
	}
	if got := APIBaseFor("https://user:pass@router.example.com"); got != "" {
		t.Fatalf("expected empty for credentials, got %q", got)
	}
	roles := NormalizeRoles([]any{"search", "chat", "unknown"})
	if len(roles) != 2 || roles[0] != "chat" || roles[1] != "search" {
		t.Fatalf("unexpected roles: %v", roles)
	}
}

func TestClientAndOffer(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "Bearer nrt_test" {
			w.WriteHeader(http.StatusUnauthorized)
			return
		}
		switch {
		case r.URL.Path == "/v1/models" && r.URL.Query().Get("type") == "chat":
			w.Write([]byte(`{"data":[{"id":"auto"},{"id":"gpt-4o"}],"neorouter":{"not_allowed_for_key":{"free":1,"plan":2}}}`))
		case r.URL.Path == "/v1/models" && r.URL.Query().Get("type") == "moderation":
			w.Write([]byte(`{"data":[{"id":"dec-1","neorouter":{"decision":true}},{"id":"safe-1","neorouter":{"decision":false}}],"neorouter":{"not_allowed_for_key":{"decision_models":{"paid":3}}}}`))
		case r.URL.Path == "/v1/models" && r.URL.Query().Get("type") == "live":
			w.Write([]byte(`{"data":[{"id":"gem-live","neorouter":{"protocols":["gemini_live"]}}]}`))
		case r.URL.Path == "/v1/models":
			w.Write([]byte(`{"data":[]}`))
		case r.URL.Path == "/v1/embeddings":
			w.Header().Set("x-neorouter-embedding-pin", "e5-small:384")
			w.Write([]byte(`{"model":"host/e5","data":[{"embedding":[0.1,0.2]}]}`))
		case r.URL.Path == "/v1/search":
			w.Write([]byte(`{"results":[{"title":"Go","url":"https://go.dev","content":"Go lang"}]}`))
		default:
			w.WriteHeader(http.StatusNotFound)
		}
	}))
	defer srv.Close()

	svc := New(Config{HTTPClient: srv.Client()})
	defer svc.Stop()
	conn := &Connection{APIBase: srv.URL + "/v1", APIKey: "nrt_test", Roles: Roles}

	offer, err := svc.DescribeOffer(context.Background(), conn, true)
	if err != nil {
		t.Fatalf("DescribeOffer: %v", err)
	}
	if offer.Roles["chat"] != 1 || offer.Roles["system_one"] != 1 || offer.Roles["live"] != 1 {
		t.Fatalf("unexpected roles counts: %+v", offer.Roles)
	}
	if offer.NotAllowed["chat"] != 3 || offer.NotAllowed["system_one"] != 3 {
		t.Fatalf("unexpected notAllowed: %+v", offer.NotAllowed)
	}
	if len(offer.LiveProtocols) != 1 || offer.LiveProtocols[0] != "gemini_live" {
		t.Fatalf("unexpected liveProtocols: %+v", offer.LiveProtocols)
	}

	emb, err := svc.Embed(context.Background(), conn, "hello", "query")
	if err != nil || emb == nil || emb.Model != "e5-small:384" || len(emb.Vector) != 2 {
		t.Fatalf("Embed: %+v, err=%v", emb, err)
	}
	sr, err := svc.SearchWeb(context.Background(), conn, "golang", 5, "pw")
	if err != nil || len(sr) != 1 || sr[0].Rank != 1 || sr[0].Title != "Go" {
		t.Fatalf("SearchWeb: %+v, err=%v", sr, err)
	}
}

func TestRoutesAndDeviceSignIn(t *testing.T) {
	var tokenCalls int
	routerSrv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/oauth/device/code":
			w.Write([]byte(`{"device_code":"dc1","user_code":"ABCD-1234","verification_uri":"https://router.example/approve","interval":1,"expires_in":60}`))
		case "/oauth/token":
			tokenCalls++
			if tokenCalls == 1 {
				w.WriteHeader(http.StatusBadRequest)
				w.Write([]byte(`{"error":"authorization_pending"}`))
				return
			}
			w.Write([]byte(`{"access_token":"nrt_new_key"}`))
		case "/v1/models":
			w.Write([]byte(`{"data":[]}`))
		default:
			w.WriteHeader(http.StatusNotFound)
		}
	}))
	defer routerSrv.Close()

	env := &memEnv{vals: map[string]string{}}
	settings := &memSettings{usableLive: map[string]bool{}}
	svc := New(Config{
		Env:        env,
		Settings:   settings,
		Accounts:   &memAccounts{admins: map[int64]bool{1: true}},
		HTTPClient: routerSrv.Client(),
		Checker: &cloudsec.Checker{
			Lookup: func(context.Context, string) ([]netip.Addr, error) {
				return []netip.Addr{netip.MustParseAddr("93.184.216.34")}, nil
			},
		},
	})
	defer svc.Stop()

	mux := http.NewServeMux()
	svc.Routes(mux)
	mgr := newTestSessions(t)

	// Unauthenticated -> 401
	rec := httptest.NewRecorder()
	withSession(t, mgr, 0, mux).ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/api/neorouter", nil))
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", rec.Code)
	}

	// Non-admin trying server scope -> 403
	rec = httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodDelete, "/api/neorouter/server", nil)
	withSession(t, mgr, 2, mux).ServeHTTP(rec, req)
	if rec.Code != http.StatusForbidden {
		t.Fatalf("expected 403, got %d", rec.Code)
	}

	// Admin connects server scope via device flow
	rec = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodPost, "/api/neorouter/connect", strings.NewReader(`{"scope":"server","address":"`+routerSrv.URL+`"}`))
	withSession(t, mgr, 1, mux).ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("connect status %d: %s", rec.Code, rec.Body.String())
	}
	var started BeginSignInResult
	if err := json.Unmarshal(rec.Body.Bytes(), &started); err != nil || started.ID == "" || started.UserCode != "ABCD-1234" {
		t.Fatalf("unexpected start response: %s", rec.Body.String())
	}

	// Poll until completed
	deadline := time.Now().Add(5 * time.Second)
	for time.Now().Before(deadline) {
		rec = httptest.NewRecorder()
		withSession(t, mgr, 1, mux).ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/api/neorouter/connect/"+started.ID, nil))
		if rec.Code == http.StatusOK {
			var st SignInStatus
			_ = json.Unmarshal(rec.Body.Bytes(), &st)
			if st.Status == "completed" {
				break
			}
		}
		time.Sleep(100 * time.Millisecond)
	}
	if env.Get(envAPIKey) != "nrt_new_key" {
		t.Fatalf("expected server key saved, got %q", env.Get(envAPIKey))
	}

	// Update roles & disconnect
	rec = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodPut, "/api/neorouter/server/roles", strings.NewReader(`{"roles":["chat","search"]}`))
	withSession(t, mgr, 1, mux).ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("update roles status %d: %s", rec.Code, rec.Body.String())
	}
	if env.Get(envRoles) != "chat,search" {
		t.Fatalf("expected roles chat,search, got %q", env.Get(envRoles))
	}
}

func TestOperatorRouterMayBePrivateButUserRouterMayNot(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { _, _ = w.Write([]byte(`{"data":[]}`)) }))
	defer srv.Close()
	other := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { t.Error("private user endpoint was contacted") }))
	defer other.Close()
	env := &memEnv{vals: map[string]string{"NEOROUTER_BASE_URL": srv.URL, "NEOROUTER_API_KEY": "key"}}
	svc := New(Config{Env: env})
	defer svc.Stop()
	server := svc.ServerConnection()
	if _, err := svc.ListModels(context.Background(), server, "moderation"); err != nil {
		t.Fatalf("operator router: %v", err)
	}
	same := &Connection{Scope: "user", APIBase: server.APIBase, APIKey: "user-key"}
	if _, err := svc.ListModels(context.Background(), same, "moderation"); err != nil {
		t.Fatalf("user key on operator router: %v", err)
	}
	user := &Connection{Scope: "user", APIBase: other.URL + "/v1", APIKey: "key"}
	if _, err := svc.ListModels(context.Background(), user, "moderation"); err == nil {
		t.Fatal("user supplied private router accepted")
	}
}

func TestServerDeviceSignInAllowsOperatorLocalRouter(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/oauth/device/code" {
			t.Errorf("unexpected path %s", r.URL.Path)
		}
		_, _ = w.Write([]byte(`{"device_code":"device","user_code":"ABCD","verification_uri":"https://router.example/verify","interval":30,"expires_in":600}`))
	}))
	defer srv.Close()
	svc := New(Config{})
	defer svc.Stop()
	if _, err := svc.BeginSignIn(context.Background(), BeginSignInInput{Scope: "server", UserID: 1, Address: srv.URL}); err != nil {
		t.Fatal(err)
	}
	if _, err := svc.BeginSignIn(context.Background(), BeginSignInInput{Scope: "user", UserID: 1, Address: srv.URL}); err == nil {
		t.Fatal("user supplied private router accepted")
	}
}
