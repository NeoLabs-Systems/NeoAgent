// Package github is the official GitHub integration: OAuth with a user token
// and the repository, issue, pull request, content and workflow tools over the
// REST API.
package github

import (
	"bytes"
	"context"
	_ "embed"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"net/url"
	"strconv"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neolabs-go/oauthclient"
)

//go:embed provider.json
var specJSON []byte

// scopes asked for on every connection: the account's identity and what the
// tools need.
var scopes = []string{"read:user", "user:email", "repo", "workflow", "read:org"}

type endpoints struct {
	oauth string // https://github.com
	api   string // https://api.github.com
}

type provider struct {
	*integrations.OAuthProviderImpl
	svc *integrations.Services
	ep  endpoints
	app *integrations.OAuthApp
}

// New is the GitHub provider.
func New(svc *integrations.Services) integrations.Provider {
	return newProvider(svc, endpoints{oauth: "https://github.com", api: "https://api.github.com"})
}

func newProvider(svc *integrations.Services, ep endpoints) *provider {
	p := &provider{svc: svc, ep: ep}
	p.app = integrations.NewOAuthApp(svc, integrations.OAuthAppSpec{
		ProviderKey: "github",
		Label:       "GitHub",
		EnvPrefix:   "GITHUB",
		ConsoleURL:  "https://github.com/settings/applications/new",
		Notes:       "Create an OAuth App (not a GitHub App), use the callback URL as the Authorization callback URL, then generate a client secret.",
		Scopes:      scopes,
	})
	spec := integrations.LoadSpec(specJSON)
	spec.DefaultApp = "repos"
	p.OAuthProviderImpl = integrations.NewOAuthProvider(svc, spec, p.app, integrations.OAuthHooks{
		Begin:      p.begin,
		Finish:     p.finish,
		Execute:    p.execute,
		Disconnect: p.revoke,
		Test: func(ctx context.Context, tc *integrations.ToolContext) error {
			_, err := p.request(ctx, tc.Credentials, request{path: "/user"})
			return err
		},
	})
	return p
}

func (p *provider) begin(_ context.Context, in integrations.BeginInput) (integrations.BeginResult, error) {
	u, err := oauthclient.SetParams(p.ep.oauth+"/login/oauth/authorize", oauthclient.Query{
		{"client_id", in.OAuth.ClientID}, {"redirect_uri", in.OAuth.RedirectURI}, {"scope", strings.Join(scopes, " ")},
		{"state", in.State}, {"code_challenge", oauthclient.CodeChallenge(in.CodeVerifier)}, {"code_challenge_method", "S256"},
	})
	return integrations.BeginResult{URL: u, AppID: in.App.ID}, err
}

func (p *provider) finish(ctx context.Context, in integrations.FinishInput) (integrations.FinishResult, error) {
	raw, err := p.svc.Client("GitHub OAuth token exchange").JSON(ctx, oauthclient.Request{
		Method: "POST", URL: p.ep.oauth + "/login/oauth/access_token",
		Form: [][2]string{
			{"client_id", in.OAuth.ClientID}, {"client_secret", in.OAuth.ClientSecret}, {"code", in.Code},
			{"code_verifier", in.CodeVerifier}, {"redirect_uri", in.OAuth.RedirectURI},
		},
	})
	if err != nil {
		return integrations.FinishResult{}, err
	}
	token := integrations.Object(raw)
	if integrations.Truthy(token["error"]) {
		return integrations.FinishResult{}, fmt.Errorf("GitHub OAuth error: %s", integrations.Str(integrations.Or(token["error_description"], token["error"])))
	}
	access := integrations.Str(token["access_token"])
	if !integrations.Truthy(token["access_token"]) {
		return integrations.FinishResult{}, errors.New("GitHub OAuth did not return an access token.")
	}
	userRaw, err := p.svc.Client("GitHub user profile").JSON(ctx, oauthclient.Request{
		URL:    p.ep.api + "/user",
		Header: map[string]string{"Authorization": "Bearer " + access, "Accept": "application/vnd.github.v3+json"},
	})
	if err != nil {
		return integrations.FinishResult{}, err
	}
	user := integrations.Object(userRaw)
	login := strings.TrimSpace(integrations.Str(user["login"]))
	if login == "" {
		return integrations.FinishResult{}, errors.New("GitHub API did not return a user login.")
	}
	creds := oauthclient.Credentials{"access_token": access}
	for _, k := range []string{"token_type", "scope"} {
		if v, ok := token[k]; ok {
			creds[k] = v
		}
	}
	granted := []string{}
	if integrations.Truthy(token["scope"]) {
		granted = strings.Split(integrations.Str(token["scope"]), " ")
	}
	return integrations.FinishResult{
		AppID: in.App.ID, AccountEmail: login, Credentials: creds, Scopes: granted,
		Metadata: map[string]any{"appId": in.App.ID, "userId": user["id"]},
	}, nil
}

// revoke withdraws the token at GitHub with the app's own credentials.
func (p *provider) revoke(ctx context.Context, tc *integrations.ToolContext) error {
	access := strings.TrimSpace(tc.Credentials.String("access_token"))
	if access == "" {
		return nil
	}
	clientID, secret := strings.TrimSpace(tc.OAuth.ClientID), strings.TrimSpace(tc.OAuth.ClientSecret)
	if clientID == "" || secret == "" {
		return errors.New("revoke skipped because OAuth client credentials are missing")
	}
	res, err := p.svc.Client("GitHub token revocation").Do(ctx, oauthclient.Request{
		Method: "DELETE", URL: p.ep.api + "/applications/" + url.PathEscape(clientID) + "/token",
		Header: map[string]string{"Authorization": "Basic " + base64.StdEncoding.EncodeToString([]byte(clientID+":"+secret))},
		JSON:   map[string]any{"access_token": access}, NoRetry: true,
	})
	if err != nil {
		return err
	}
	if res.Status < 200 || res.Status > 299 {
		return fmt.Errorf("revoking the token failed: %d %s", res.Status, res.Body)
	}
	return nil
}

func (p *provider) SummarizeForModel(s integrations.Snapshot) string {
	label := p.Info().Label
	if !s.Env.Configured {
		return integrations.DescribeIncompleteSetup(label, s.Env)
	}
	lines := make([]string, 0, len(s.Apps))
	for _, app := range s.Apps {
		switch {
		case app.Connection.Connected:
			names := strings.Join(p.Toolset().NamesForApp(app.ID), ", ")
			if names != "" {
				lines = append(lines, fmt.Sprintf("- %s: %s. Use built-in tools: %s", app.Label, integrations.FormatAccountSummary(app), names))
			} else {
				lines = append(lines, fmt.Sprintf("- %s: %s.", app.Label, integrations.FormatAccountSummary(app)))
			}
		case app.Connection.Status == "authorizing":
			lines = append(lines, fmt.Sprintf("- %s: connection is still being authorized.", app.Label))
		default:
			lines = append(lines, fmt.Sprintf("- %s: not connected yet.", app.Label))
		}
	}
	var head []string
	if !s.Connection.Connected {
		head = []string{label + ": workspace setup is ready, but no app accounts are connected yet. If the user wants to use it, tell them to connect an account in Official Integrations first."}
	} else {
		head = []string{
			label + ": some app-specific native access is connected on this server in this run. Only the listed connected apps are available through built-in tools.",
			"Connected apps: " + integrations.ConnectedAppSummary(s.Apps),
		}
	}
	return strings.Join(append(head, lines...), "\n")
}

// Snapshot is the generic snapshot without the connect hints.
func (p *provider) Snapshot(rows []integrations.Connection, scope integrations.Scope) integrations.Snapshot {
	snap := p.OAuthProviderImpl.Snapshot(rows, scope)
	snap.Extra = nil
	return snap
}

// ---- API access --------------------------------------------------------------

type request struct {
	method string
	path   string
	query  oauthclient.Query
	body   any
	// base is the API root; empty is the provider's.
	base string
}

// request calls the GitHub REST API. The answer is the decoded body: the
// object or list, the text of a non-JSON success, nil for no content.
func (p *provider) request(ctx context.Context, creds oauthclient.Credentials, r request) (any, error) {
	token := strings.TrimSpace(creds.String("access_token"))
	if token == "" {
		return nil, errors.New("GitHub authentication token is required for GitHub API requests.")
	}
	base := orDefault(r.base, p.ep.api)
	path := r.path
	if !strings.HasPrefix(path, "/") {
		path = "/" + path
	}
	target, err := oauthclient.SetParams(strings.TrimSuffix(base, "/")+path, r.query)
	if err != nil {
		return nil, err
	}
	method := strings.ToUpper(orDefault(r.method, "GET"))
	req := oauthclient.Request{
		Method: method, URL: target, NoRetry: true,
		Header: map[string]string{
			"Accept": "application/vnd.github.v3+json", "Authorization": "Bearer " + token, "X-GitHub-Api-Version": "2022-11-28",
		},
	}
	if r.body != nil {
		req.JSON = r.body
	}
	res, err := p.svc.Client("GitHub API").Do(ctx, req)
	if err != nil {
		return nil, err
	}
	var data any
	hasData := false
	if res.Status != 204 && res.Status != 205 && len(bytes.TrimSpace(res.Body)) > 0 {
		var raw json.RawMessage
		if json.Unmarshal(res.Body, &raw) == nil {
			data, hasData = raw, true
		} else {
			if res.Status < 200 || res.Status > 299 {
				return nil, &oauthclient.Error{Status: res.Status, Message: fmt.Sprintf("GitHub API error %d: %s", res.Status, res.Body), Header: res.Header}
			}
			data, hasData = string(res.Body), true
		}
	}
	if res.Status < 200 || res.Status > 299 {
		msg := fmt.Sprintf("GitHub API error: %d", res.Status)
		obj := integrations.Object(res.Body)
		if m := obj["message"]; integrations.Truthy(m) && hasData {
			msg = integrations.Str(m)
		}
		return nil, &oauthclient.Error{Status: res.Status, Message: msg, Data: obj, Header: res.Header}
	}
	if !hasData {
		return nil, nil
	}
	return data, nil
}

func orDefault(s, fallback string) string {
	if s == "" {
		return fallback
	}
	return s
}

func (p *provider) execute(ctx context.Context, name string, args map[string]any, tc *integrations.ToolContext) (any, error) {
	if strings.TrimSpace(tc.Credentials.String("access_token")) == "" {
		return nil, errors.New("GitHub access token is missing or expired. Please reconnect your GitHub account.")
	}
	t := &toolRun{p: p, ctx: ctx, creds: tc.Credentials, args: args}
	return t.run(name)
}

// ---- argument helpers --------------------------------------------------------

func parsePositiveInt(v any, fallback int) int {
	n, ok := integrations.JSNumber(v)
	if !ok || n <= 0 || math.IsInf(n, 0) {
		return fallback
	}
	return int(math.Floor(n))
}

func numberText(n float64) string { return strconv.FormatFloat(n, 'f', -1, 64) }

// number is Number(value) as text; NaN reads "NaN" like it does in a URL.
func number(v any) string {
	n, ok := integrations.JSNumber(v)
	if !ok || math.IsNaN(n) {
		return "NaN"
	}
	return numberText(n)
}

// perPage is Math.min(Number(v) || def, 100).
func perPage(v any, def float64) string {
	n, ok := integrations.JSNumber(v)
	if !ok || n == 0 {
		n = def
	}
	return numberText(math.Min(n, 100))
}

func textOf(v any) string {
	if !integrations.Truthy(v) {
		return ""
	}
	return integrations.Str(v)
}

func commaList(v any) []string {
	out := []string{}
	if !integrations.Truthy(v) {
		return out
	}
	for _, s := range strings.Split(integrations.Str(v), ",") {
		if s = strings.TrimSpace(s); s != "" {
			out = append(out, s)
		}
	}
	return out
}

type ownerRepo struct{ owner, repo string }

func parseOwnerRepo(v any) (ownerRepo, error) {
	parts := strings.Split(textOf(v), "/")
	if len(parts) != 2 {
		return ownerRepo{}, errors.New(`owner_repo must be in format "owner/repo"`)
	}
	return ownerRepo{parts[0], parts[1]}, nil
}

func hasOwnerRepo(args map[string]any) bool {
	if s, ok := args["owner_repo"].(string); ok && strings.TrimSpace(s) != "" {
		return true
	}
	return strings.TrimSpace(textOf(args["owner"])) != "" && strings.TrimSpace(textOf(args["repo"])) != ""
}

func parseOwnerRepoArg(args map[string]any) (ownerRepo, error) {
	if s, ok := args["owner_repo"].(string); ok && strings.TrimSpace(s) != "" {
		return parseOwnerRepo(s)
	}
	owner, repo := strings.TrimSpace(textOf(args["owner"])), strings.TrimSpace(textOf(args["repo"]))
	if owner != "" && repo != "" {
		return parseOwnerRepo(owner + "/" + repo)
	}
	return parseOwnerRepo(args["owner_repo"])
}

func encodeFileContent(args map[string]any) string {
	content := ""
	if args["content"] != nil {
		content = integrations.Str(args["content"])
	}
	encoding := strings.ToLower(orDefault(textOf(integrations.Or(args["encoding"], args["content_encoding"], "utf-8")), "utf-8"))
	if encoding == "base64" {
		return strings.Join(strings.Fields(content), "")
	}
	return base64.StdEncoding.EncodeToString([]byte(content))
}
