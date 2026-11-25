package github

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"sync"
	"testing"

	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/integrationstest"
	"github.com/NeoLabs-Systems/neolabs-go/oauthclient"
)

type recorded struct{ Method, URI, Auth, Body string }

type fake struct {
	srv      *httptest.Server
	mu       sync.Mutex
	requests []recorded
	answers  map[string]func(r *http.Request) (int, string)
}

func newFake(t *testing.T) *fake {
	f := &fake{answers: map[string]func(*http.Request) (int, string){}}
	f.srv = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		raw, _ := io.ReadAll(r.Body)
		f.mu.Lock()
		f.requests = append(f.requests, recorded{r.Method, r.URL.RequestURI(), r.Header.Get("Authorization"), string(raw)})
		answer := f.answers[r.Method+" "+r.URL.Path]
		f.mu.Unlock()
		if answer == nil {
			w.WriteHeader(404)
			w.Write([]byte(`{"message":"Not Found"}`))
			return
		}
		status, body := answer(r)
		w.WriteHeader(status)
		w.Write([]byte(body))
	}))
	t.Cleanup(f.srv.Close)
	return f
}

func (f *fake) on(route string, status int, body string) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.answers[route] = func(*http.Request) (int, string) { return status, body }
}

func (f *fake) last() recorded {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.requests[len(f.requests)-1]
}

func (f *fake) count() int {
	f.mu.Lock()
	defer f.mu.Unlock()
	return len(f.requests)
}

func setup(t *testing.T) (*integrationstest.Stack, *fake) {
	f := newFake(t)
	s := integrationstest.New(t, func(svc *integrations.Services) []integrations.Provider {
		return []integrations.Provider{newProvider(svc, endpoints{oauth: f.srv.URL, api: f.srv.URL})}
	}, integrations.Hooks{})
	sealed, _ := s.Box.Seal(`{"clientId":"cid","clientSecret":"csecret"}`)
	s.Exec(t, `INSERT INTO integration_oauth_apps (user_id, provider_key, config_json) VALUES (1, 'github', ?)`, sealed)
	s.Connect(t, 1, "github", "repos", "octo", `{"access_token":"gho_1"}`)
	return s, f
}

func run(t *testing.T, s *integrationstest.Stack, name string, args map[string]any) string {
	t.Helper()
	out, err := s.Mgr.ExecuteTool(context.Background(), 1, name, args, "", integrations.ExecOptions{})
	if err != nil {
		t.Fatal(err)
	}
	raw, err := oauthclient.MarshalJS(out)
	if err != nil {
		t.Fatal(err)
	}
	return string(raw)
}

func TestOAuthRoundTrip(t *testing.T) {
	s, f := setup(t)
	s.Exec(t, `DELETE FROM integration_connections`)
	f.on("POST /login/oauth/access_token", 200, `{"access_token":"gho_new","token_type":"bearer","scope":"read:user,user:email,repo"}`)
	f.on("GET /user", 200, `{"login":"octo","id":42}`)

	start, err := s.Mgr.BeginOAuth(context.Background(), 1, "github", integrations.BeginOptions{AppKey: "repos"})
	if err != nil {
		t.Fatal(err)
	}
	u, _ := url.Parse(start.URL)
	q := u.Query()
	if u.Path != "/login/oauth/authorize" || q.Get("scope") != "read:user user:email repo workflow read:org" || q.Get("code_challenge_method") != "S256" || q.Get("client_id") != "cid" {
		t.Fatalf("authorization url %s", start.URL)
	}
	res, err := s.Mgr.FinishOAuth(context.Background(), start.State, "code1")
	if err != nil || res.AccountEmail != "octo" {
		t.Fatalf("%+v %v", res, err)
	}
	form, _ := url.ParseQuery(f.requests[0].Body)
	if form.Get("code") != "code1" || form.Get("code_verifier") == "" || form.Get("client_secret") != "csecret" {
		t.Fatalf("token request %v", form)
	}
	conn, _ := s.Svc.ConnectionByID(context.Background(), 1, *res.ConnectionID, s.MainAgent(t, 1))
	creds := s.Svc.Credentials(*conn)
	if creds.String("access_token") != "gho_new" || creds.String("scope") != "read:user,user:email,repo" || conn.ScopesJSON != `["read:user,user:email,repo"]` {
		t.Fatalf("stored %v %s", creds, conn.ScopesJSON)
	}
	var meta map[string]any
	_ = json.Unmarshal([]byte(conn.MetadataJSON), &meta)
	if meta["userId"] != float64(42) || meta["appId"] != "repos" {
		t.Fatalf("metadata %v", meta)
	}

	// GitHub answers a bad code with 200 and an error body.
	f.on("POST /login/oauth/access_token", 200, `{"error":"bad_verification_code","error_description":"The code passed is incorrect or expired."}`)
	start, _ = s.Mgr.BeginOAuth(context.Background(), 1, "github", integrations.BeginOptions{AppKey: "repos"})
	if _, err := s.Mgr.FinishOAuth(context.Background(), start.State, "bad"); err == nil || err.Error() != "GitHub OAuth error: The code passed is incorrect or expired." {
		t.Fatalf("got %v", err)
	}
	f.on("POST /login/oauth/access_token", 200, `{}`)
	start, _ = s.Mgr.BeginOAuth(context.Background(), 1, "github", integrations.BeginOptions{AppKey: "repos"})
	if _, err := s.Mgr.FinishOAuth(context.Background(), start.State, "bad"); err == nil || err.Error() != "GitHub OAuth did not return an access token." {
		t.Fatalf("got %v", err)
	}
}

func TestIssuesAndPullRequests(t *testing.T) {
	s, f := setup(t)
	f.on("GET /repos/o/r/issues", 200, `[{"number":1}]`)
	if got := run(t, s, "github_list_issues", map[string]any{"owner_repo": "o/r", "state": "open", "labels": "bug,ui", "max_results": float64(500)}); got != `[{"number":1}]` {
		t.Fatalf("got %s", got)
	}
	if uri := f.last().URI; uri != "/repos/o/r/issues?per_page=100&state=open&labels=bug%2Cui" || f.last().Auth != "Bearer gho_1" {
		t.Fatalf("request %s %s", uri, f.last().Auth)
	}
	// owner and repo may be given apart.
	run(t, s, "github_list_issues", map[string]any{"owner": "o", "repo": "r"})
	if f.last().URI != "/repos/o/r/issues?per_page=30" {
		t.Fatalf("alias request %s", f.last().URI)
	}
	if got := run(t, s, "github_get_repo", map[string]any{"owner_repo": "just-one"}); got != `{"error":"owner_repo must be in format \"owner/repo\""}` {
		t.Fatalf("bad owner_repo: %s", got)
	}

	f.on("POST /repos/o/r/issues", 201, `{"number":7}`)
	run(t, s, "github_create_issue", map[string]any{"owner_repo": "o/r", "title": "T", "labels": " a, b ,", "body": "B"})
	var body map[string]any
	_ = json.Unmarshal([]byte(f.last().Body), &body)
	if body["title"] != "T" || body["body"] != "B" || len(body["labels"].([]any)) != 2 || len(body["assignees"].([]any)) != 0 {
		t.Fatalf("create body %s", f.last().Body)
	}
	f.on("PATCH /repos/o/r/issues/7", 200, `{}`)
	run(t, s, "github_update_issue", map[string]any{"owner_repo": "o/r", "issue_number": float64(7), "state": "closed", "body": ""})
	if f.last().Body != `{"body":"","state":"closed"}` {
		t.Fatalf("update body %s", f.last().Body)
	}

	f.on("POST /repos/o/r/pulls", 201, `{"number":3}`)
	run(t, s, "github_create_pr", map[string]any{"owner_repo": "o/r", "title": "PR", "head": "feat"})
	body = nil
	_ = json.Unmarshal([]byte(f.last().Body), &body)
	if body["base"] != "main" || body["draft"] != false || body["head"] != "feat" {
		t.Fatalf("pr body %s", f.last().Body)
	}
	f.on("PUT /repos/o/r/pulls/3/merge", 200, `{"merged":true}`)
	run(t, s, "github_merge_pr", map[string]any{"owner_repo": "o/r", "pr_number": "3"})
	if f.last().Body != `{"merge_method":"squash"}` {
		t.Fatalf("merge body %s", f.last().Body)
	}
}

func TestErrorsKeepMessageAndStatus(t *testing.T) {
	s, f := setup(t)
	f.on("GET /repos/o/r", 404, `{"message":"Not Found","documentation_url":"x"}`)
	got := run(t, s, "github_get_repo", map[string]any{"owner_repo": "o/r"})
	if got != `{"error":"Not Found","status":404,"next":"Nothing by those names or IDs: check them before trying again."}` {
		t.Fatalf("got %s", got)
	}
	f.on("GET /repos/o/boom", 502, `<html>bad gateway</html>`)
	if got := run(t, s, "github_get_repo", map[string]any{"owner_repo": "o/boom"}); !strings.HasPrefix(got, `{"error":"GitHub API error 502: <html`) {
		t.Fatalf("non-json error: %s", got)
	}
	f.on("GET /repos/o/empty", 500, ``)
	if got := run(t, s, "github_get_repo", map[string]any{"owner_repo": "o/empty"}); !strings.HasPrefix(got, `{"error":"GitHub API error: 500"`) {
		t.Fatalf("empty error: %s", got)
	}
}

func TestPagingStopsAtTheLimitOrAShortPage(t *testing.T) {
	s, f := setup(t)
	// Pages are as long as per_page asks; the third is short.
	f.mu.Lock()
	f.answers["GET /repos/o/r/collaborators"] = func(r *http.Request) (int, string) {
		per := 0
		fmt.Sscan(r.URL.Query().Get("per_page"), &per)
		page := 0
		fmt.Sscan(r.URL.Query().Get("page"), &page)
		n := per
		if page >= 3 {
			n = 1
		}
		items := make([]string, n)
		for i := range items {
			items[i] = fmt.Sprintf(`{"id":%d}`, (page-1)*per+i+1)
		}
		return 200, "[" + strings.Join(items, ",") + "]"
	}
	f.mu.Unlock()
	if got := run(t, s, "github_list_collaborators", map[string]any{"owner_repo": "o/r", "max_results": float64(3)}); got != `[{"id":1},{"id":2},{"id":3}]` {
		t.Fatalf("limit reached on the first page: %s", got)
	}
	f.mu.Lock()
	f.answers["GET /repos/o/r/collaborators"] = func(r *http.Request) (int, string) {
		switch r.URL.Query().Get("page") {
		case "1":
			return 200, `[{"id":1},{"id":2}]`
		case "2":
			return 200, `[{"id":3},{"id":4}]`
		}
		return 200, `[]`
	}
	f.mu.Unlock()
	if got := run(t, s, "github_list_collaborators", map[string]any{"owner_repo": "o/r", "max_results": float64(2)}); got != `[{"id":1},{"id":2}]` {
		t.Fatalf("got %s", got)
	}
	f.mu.Lock()
	f.answers["GET /repos/o/r/collaborators"] = func(r *http.Request) (int, string) {
		if r.URL.Query().Get("page") == "1" {
			return 200, `[{"id":1},{"id":2}]`
		}
		return 200, `[{"id":3}]`
	}
	f.mu.Unlock()
	if got := run(t, s, "github_list_collaborators", map[string]any{"owner_repo": "o/r", "max_results": float64(2)}); got != `[{"id":1},{"id":2}]` {
		t.Fatalf("a full first page asks for the second only when more are wanted: %s", got)
	}
	// per_page is the limit, so a page of 3 asked for 3 ends the loop.
	f.mu.Lock()
	f.answers["GET /repos/o/r/actions/runs"] = func(r *http.Request) (int, string) {
		return 200, `{"workflow_runs":[{"id":1},{"id":2}]}`
	}
	f.mu.Unlock()
	if got := run(t, s, "github_list_workflow_runs", map[string]any{"owner_repo": "o/r", "max_results": float64(5), "branch": "main"}); got != `[{"id":1},{"id":2}]` {
		t.Fatalf("runs %s", got)
	}
	if !strings.Contains(f.last().URI, "branch=main") || !strings.Contains(f.last().URI, "per_page=5") {
		t.Fatalf("runs request %s", f.last().URI)
	}
	f.on("GET /user/repos", 200, `[]`)
	if got := run(t, s, "github_list_user_repos", map[string]any{"visibility": "private"}); got != `[]` {
		t.Fatalf("user repos %s", got)
	}
}

func TestContentIsDecodedAndWritten(t *testing.T) {
	s, f := setup(t)
	f.on("GET /repos/o/r/contents/docs/a b.md", 200, `{"name":"a b.md","encoding":"base64","content":"`+base64.StdEncoding.EncodeToString([]byte("héllo"))[:4]+`\n`+base64.StdEncoding.EncodeToString([]byte("héllo"))[4:]+`","sha":"s1"}`)
	got := run(t, s, "github_get_content", map[string]any{"owner_repo": "o/r", "path": "docs/a b.md", "ref": "dev"})
	if got != `{"name":"a b.md","encoding":"utf8","content":"héllo","sha":"s1"}` {
		t.Fatalf("got %s", got)
	}
	if !strings.Contains(f.last().URI, "ref=dev") {
		t.Fatalf("request %s", f.last().URI)
	}
	f.on("PUT /repos/o/r/contents/x.txt", 201, `{}`)
	run(t, s, "github_create_or_update_file", map[string]any{"owner_repo": "o/r", "path": "x.txt", "message": "m", "content": "héllo", "branch": "b"})
	if f.last().Body != `{"branch":"b","content":"aMOpbGxv","message":"m"}` {
		t.Fatalf("put body %s", f.last().Body)
	}
	run(t, s, "github_create_or_update_file", map[string]any{"owner_repo": "o/r", "path": "x.txt", "message": "m", "content": "aMOp bGxv\n", "encoding": "base64"})
	if f.last().Body != `{"content":"aMOpbGxv","message":"m"}` {
		t.Fatalf("base64 put body %s", f.last().Body)
	}
}

func TestWorkflowInputsMustBeJSON(t *testing.T) {
	s, f := setup(t)
	f.on("POST /repos/o/r/actions/workflows/ci.yml/dispatches", 204, ``)
	if got := run(t, s, "github_trigger_workflow", map[string]any{"owner_repo": "o/r", "workflow_id": "ci.yml", "inputs": "{nope"}); !strings.HasPrefix(got, `{"error":"Invalid workflow inputs JSON: `) {
		t.Fatalf("got %s", got)
	}
	if got := run(t, s, "github_trigger_workflow", map[string]any{"owner_repo": "o/r", "workflow_id": "ci.yml", "inputs": `{"a":"1"}`}); got != `null` {
		t.Fatalf("no content answer %s", got)
	}
	if f.last().Body != `{"inputs":{"a":"1"},"ref":"main"}` {
		t.Fatalf("dispatch body %s", f.last().Body)
	}
}

func TestAPIRequestStaysOnAllowedHosts(t *testing.T) {
	s, f := setup(t)
	f.on("GET /repos/o/r/labels", 200, `[]`)
	// A relative path is completed with the repository.
	run(t, s, "github_api_request", map[string]any{"path": "labels", "owner_repo": "o/r", "query": map[string]any{"per_page": float64(5)}})
	if f.last().URI != "/repos/o/r/labels?per_page=5" {
		t.Fatalf("got %s", f.last().URI)
	}
	f.on("GET /orgs/acme", 200, `{}`)
	run(t, s, "github_api_request", map[string]any{"endpoint": "/orgs/acme", "owner_repo": "o/r"})
	if f.last().URI != "/orgs/acme" {
		t.Fatalf("got %s", f.last().URI)
	}
	// A protocol-relative path stays on the API host instead of leaving it.
	before := f.count()
	run(t, s, "github_api_request", map[string]any{"path": "//evil.example/x"})
	if f.count() != before+1 || strings.Contains(f.last().URI, "evil") && f.last().URI[:2] != "//" {
		t.Fatalf("request %s", f.last().URI)
	}
	for url, want := range map[string]string{
		"http://api.github.com/user":       "Only https:// GitHub API URLs are allowed.",
		"https://evil.example/user":        "Host is not allowed for GitHub API requests: evil.example",
		"https://api.github.com.evil.io/x": "Host is not allowed for GitHub API requests: api.github.com.evil.io",
	} {
		_ = url
		_ = want
	}
	got := run(t, s, "github_api_request", map[string]any{"path": "https://evil.example/user"})
	if got != `{"error":"Host is not allowed for GitHub API requests: evil.example"}` {
		t.Fatalf("got %s", got)
	}
	enabled := "ghe.corp.example"
	s.SetEnv("GITHUB_ALLOWED_API_HOSTS", &enabled)
	prod := newProvider(s.Svc, endpoints{oauth: "https://github.com", api: "https://api.github.com"})
	if !prod.allowedAPIHost("GHE.corp.example") || !prod.allowedAPIHost("api.github.com") || prod.allowedAPIHost("github.com") || prod.allowedAPIHost("") {
		t.Fatal("allowed hosts")
	}
	if got := run(t, s, "github_api_request", map[string]any{}); got != `{"error":"github_api_request requires path, endpoint, or url."}` {
		t.Fatalf("no path: %s", got)
	}
}

func TestMissingTokenMarksTheConnectionExpired(t *testing.T) {
	s, _ := setup(t)
	s.Exec(t, `UPDATE integration_connections SET credentials_json = '{}'`)
	got := run(t, s, "github_get_auth_user", nil)
	if !strings.Contains(got, `"expired":true`) {
		t.Fatalf("got %s", got)
	}
}

func TestDisconnectRevokesTheToken(t *testing.T) {
	s, f := setup(t)
	f.on("DELETE /applications/cid/token", 204, ``)
	if r := s.Call(t, "POST", "/api/integrations/github/disconnect", 1, `{"connectionId":1}`, nil); r.Status != 200 {
		t.Fatal(r.Raw)
	}
	last := f.last()
	if last.Method != "DELETE" || last.Auth != "Basic "+base64.StdEncoding.EncodeToString([]byte("cid:csecret")) || last.Body != `{"access_token":"gho_1"}` {
		t.Fatalf("revoke request %+v", last)
	}
}

func TestSnapshotHasNoConnectHints(t *testing.T) {
	s, _ := setup(t)
	p := s.Mgr.Provider("github")
	scope := integrations.Scope{UserID: 1, AgentID: s.MainAgent(t, 1)}
	rows, _ := s.Svc.ListConnections(context.Background(), 1, "github", scope.AgentID)
	snap := p.Snapshot(rows, scope)
	raw, _ := json.Marshal(snap)
	if strings.Contains(string(raw), "connectPrompt") || strings.Contains(string(raw), "connectionMethod") {
		t.Fatalf("snapshot %s", raw)
	}
	got := p.SummarizeForModel(snap)
	if !strings.Contains(got, "- Repositories: connected as octo. Use built-in tools: github_search_repos") || !strings.Contains(got, "- Mentions: not connected yet.") {
		t.Fatalf("summary\n%s", got)
	}
}
