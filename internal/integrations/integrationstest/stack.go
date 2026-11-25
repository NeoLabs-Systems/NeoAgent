// Package integrationstest builds the integrations routes over a real SQLite
// file with the real schema, for the tests of the package and its providers.
package integrationstest

import (
	"context"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"testing"

	"github.com/NeoLabs-Systems/neoagent/internal/config"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neoagent/internal/schema"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/secretbox"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
)

// Stack is a running server. A request is signed in as the account named by
// the X-Test-User header.
type Stack struct {
	Srv *httptest.Server
	DB  *dbx.DB
	Box *secretbox.Box
	Svc *integrations.Services
	Mgr *integrations.Manager

	mu    sync.Mutex
	env   map[string]string
	bound []string
}

// New serves the providers built by makeProviders. The environment starts with
// PUBLIC_URL=https://neo.example, the sealing key is "x" (the key the Node
// scenarios were recorded with), outbound requests use the plain HTTP client
// so fake provider servers on localhost are reachable, and accounts 1 (alice)
// and 2 (bob) exist.
func New(t *testing.T, makeProviders func(*integrations.Services) []integrations.Provider, hooks integrations.Hooks) *Stack {
	t.Helper()
	ctx := context.Background()
	db, err := dbx.Open(ctx, filepath.Join(t.TempDir(), "neoagent.db"), dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Close() })
	if err := schema.Ensure(ctx, db.W); err != nil {
		t.Fatal(err)
	}
	box, err := secretbox.New(config.SecretPrefix, "x")
	if err != nil {
		t.Fatal(err)
	}
	s := &Stack{DB: db, Box: box, env: map[string]string{"PUBLIC_URL": "https://neo.example"}}
	s.Svc = integrations.NewServices(db, box)
	s.Svc.Getenv = s.Getenv
	s.Svc.HTTP = &http.Client{Transport: localOnly{}}
	s.Mgr, err = integrations.NewManager(s.Svc, makeProviders(s.Svc), hooks, slog.New(slog.NewTextHandler(io.Discard, nil)))
	if err != nil {
		t.Fatal(err)
	}
	api := integrations.New(integrations.Config{
		Manager: s.Mgr,
		UserID: func(r *http.Request) (int64, bool) {
			id, err := strconv.ParseInt(r.Header.Get("X-Test-User"), 10, 64)
			return id, err == nil
		},
		BindState: func(_ *sessionx.Session, state string) {
			s.mu.Lock()
			s.bound = append(s.bound, state)
			s.mu.Unlock()
		},
	})
	mux := http.NewServeMux()
	api.Routes(mux)
	s.Srv = httptest.NewServer(mux)
	t.Cleanup(s.Srv.Close)
	s.Exec(t, `INSERT INTO users (id, username, password) VALUES (1, 'alice', 'x'), (2, 'bob', 'x')`)
	return s
}

// localOnly refuses every request that is not for the machine itself, so a
// test can never reach a real provider.
type localOnly struct{}

func (localOnly) RoundTrip(r *http.Request) (*http.Response, error) {
	host := r.URL.Hostname()
	if host != "127.0.0.1" && host != "localhost" && host != "::1" {
		return nil, fmt.Errorf("integrationstest: network access to %s is disabled", host)
	}
	return http.DefaultTransport.RoundTrip(r)
}

// Getenv is the environment the services read.
func (s *Stack) Getenv(name string) string {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.env[name]
}

// SetEnv sets (or with nil removes) an environment variable.
func (s *Stack) SetEnv(name string, value *string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if value == nil {
		delete(s.env, name)
	} else {
		s.env[name] = *value
	}
}

// Bound are the OAuth states bound to a session so far.
func (s *Stack) Bound() []string {
	s.mu.Lock()
	defer s.mu.Unlock()
	return append([]string(nil), s.bound...)
}

// Exec runs a statement on the database.
func (s *Stack) Exec(t *testing.T, query string, args ...any) {
	t.Helper()
	if _, err := s.DB.W.Exec(query, args...); err != nil {
		t.Fatalf("%s: %v", query, err)
	}
}

// Reply is an answer of the server.
type Reply struct {
	Status int
	Raw    string
}

// Call makes a request as user (0 for nobody).
func (s *Stack) Call(t *testing.T, method, path string, user int, body string, headers map[string]string) Reply {
	t.Helper()
	var rdr io.Reader
	if body != "" {
		rdr = strings.NewReader(body)
	}
	req, _ := http.NewRequest(method, s.Srv.URL+path, rdr)
	if body != "" {
		req.Header.Set("Content-Type", "application/json")
	}
	if user != 0 {
		req.Header.Set("X-Test-User", strconv.Itoa(user))
	}
	for k, v := range headers {
		req.Header.Set(k, v)
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(resp.Body)
	return Reply{Status: resp.StatusCode, Raw: string(raw)}
}

// MainAgent is the id of an account's default agent.
func (s *Stack) MainAgent(t *testing.T, userID int64) string {
	t.Helper()
	id, err := s.Svc.ResolveAgent(context.Background(), userID, "")
	if err != nil {
		t.Fatal(err)
	}
	return id
}

// Connect inserts a connected account with sealed credentials and returns its
// row id.
func (s *Stack) Connect(t *testing.T, userID int64, provider, app, email, credentialsJSON string) int64 {
	t.Helper()
	sealed, err := s.Box.Seal(credentialsJSON)
	if err != nil {
		t.Fatal(err)
	}
	agent := s.MainAgent(t, userID)
	err = s.Svc.UpsertConnection(context.Background(), integrations.ConnectedAccount{
		UserID: userID, AgentID: agent, ProviderKey: provider, AppKey: app, AccountEmail: email, CredentialsJSON: sealed,
	})
	if err != nil {
		t.Fatal(err)
	}
	c, err := s.Svc.FindAppConnection(context.Background(), userID, agent, provider, app, email)
	if err != nil || c == nil {
		t.Fatalf("connection not stored: %v", err)
	}
	return c.ID
}
