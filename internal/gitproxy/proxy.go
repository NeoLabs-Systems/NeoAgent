package gitproxy

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/url"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/ssrf"
)

const (
	capabilityHeader = "X-Neoagent-Git-Capability"
	proxyPath        = "/api/git-proxy/github.com/"
	mountPrefix      = "/api/git-proxy/github.com"
	githubHost       = "https://github.com"
	githubAPI        = "https://api.github.com"
)

var (
	repoPath         = regexp.MustCompile(`^/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+?)(?:\.git)?/(info/refs|git-upload-pack|git-receive-pack)$`)
	forwardedRequest = []string{"Content-Type", "Content-Encoding", "Accept", "Accept-Encoding", "Git-Protocol", "User-Agent"}
	// Content-Length is not a header here: it travels as the request's length.
	forwardedResponse = []string{"Content-Type", "Content-Encoding", "Content-Length", "Cache-Control", "Expires", "Pragma"}
)

// Config wires the proxy.
type Config struct {
	Connections Connections
	// Port is the port of this server, which guests reach the proxy on.
	Port int
	Log  *slog.Logger
	// Client, BaseURL and APIBaseURL point at GitHub; the zero values use
	// github.com through an SSRF-checked client that does not follow redirects.
	Client     *http.Client
	BaseURL    string
	APIBaseURL string
	// Now is the clock; nil is time.Now.
	Now func() time.Time
}

// Proxy serves /api/git-proxy/github.com/ and mints the capabilities guests
// present there.
type Proxy struct {
	conns   Connections
	port    int
	log     *slog.Logger
	client  *http.Client
	base    string
	apiBase string
	caps    *capabilities
}

// New builds the proxy.
func New(cfg Config) *Proxy {
	client := cfg.Client
	if client == nil {
		// A clone or push can run for a long time; the deadline is generous.
		client = ssrf.NewClient(ssrf.Options{Timeout: 2 * time.Hour})
		client.CheckRedirect = func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }
	}
	now := cfg.Now
	if now == nil {
		now = time.Now
	}
	return &Proxy{
		conns:   cfg.Connections,
		port:    cfg.Port,
		log:     cfg.Log,
		client:  client,
		base:    orDefault(cfg.BaseURL, githubHost),
		apiBase: orDefault(cfg.APIBaseURL, githubAPI),
		caps:    newCapabilities(now),
	}
}

func orDefault(v, fallback string) string {
	if v == "" {
		return fallback
	}
	return v
}

// Routes registers the proxy. Git inside a guest calls it, not a signed-in
// client: each request is authorised by the capability header.
func (p *Proxy) Routes(mux *http.ServeMux) {
	mux.HandleFunc(mountPrefix, p.serve)
	mux.HandleFunc(mountPrefix+"/", p.serve)
}

// GuestEnvRequest says which command to prepare git for.
type GuestEnvRequest struct {
	UserID    int64
	AgentID   string
	RunID     string
	GuestHost string
	// TTL is how long the command may run; the capability outlives it by a grace period.
	TTL time.Duration
}

// GuestEnv is the environment for one guest command: GitHub remotes go
// through the proxy and commits carry the agent's own GitHub account. It
// returns nil when the agent has no GitHub connection, so git behaves exactly
// as the guest has it configured.
func (p *Proxy) GuestEnv(ctx context.Context, req GuestEnvRequest) (map[string]string, error) {
	conn, err := p.conns.Github(ctx, req.UserID, req.AgentID)
	if err != nil || conn == nil {
		return nil, err
	}
	token, err := p.caps.mint(Grant{UserID: req.UserID, AgentID: conn.AgentID, RunID: req.RunID}, req.TTL)
	if err != nil {
		return nil, err
	}
	base := "http://" + req.GuestHost + ":" + strconv.Itoa(p.port) + proxyPath
	config := [][2]string{
		{"url." + base + ".insteadOf", "https://github.com/"},
		{"url." + base + ".insteadOf", "git@github.com:"},
		{"url." + base + ".insteadOf", "ssh://git@github.com/"},
		{"http." + base + ".extraHeader", "X-NeoAgent-Git-Capability: " + token},
	}
	env := map[string]string{"GIT_CONFIG_COUNT": strconv.Itoa(len(config)), "GIT_TERMINAL_PROMPT": "0"}
	for i, kv := range config {
		env["GIT_CONFIG_KEY_"+strconv.Itoa(i)] = kv[0]
		env["GIT_CONFIG_VALUE_"+strconv.Itoa(i)] = kv[1]
	}
	if conn.Login != "" && conn.UserID != "" {
		email := conn.UserID + "+" + conn.Login + "@users.noreply.github.com"
		env["GIT_AUTHOR_NAME"] = conn.Login
		env["GIT_AUTHOR_EMAIL"] = email
		env["GIT_COMMITTER_NAME"] = conn.Login
		env["GIT_COMMITTER_EMAIL"] = email
	}
	return env, nil
}

// gitError answers as text/plain, which git shows as "remote: <message>".
func gitError(w http.ResponseWriter, status int, message string) {
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.WriteHeader(status)
	_, _ = io.WriteString(w, "NeoAgent: "+message+"\n")
}

func (p *Proxy) serve(w http.ResponseWriter, r *http.Request) {
	grant, ok := p.caps.resolve(r.Header.Get(capabilityHeader))
	if !ok {
		gitError(w, 403, "git access for this command has expired. Run the git command again.")
		return
	}
	path := strings.TrimPrefix(r.URL.Path, mountPrefix)
	if path == "" {
		path = "/"
	}
	m := repoPath.FindStringSubmatch(path)
	if m == nil {
		gitError(w, 404, "only GitHub repository clone, fetch, and push requests are proxied.")
		return
	}
	owner, repo, endpoint := m[1], m[2], m[3]
	advert := endpoint == "info/refs"
	service := endpoint
	wantMethod := http.MethodPost
	if advert {
		service = r.URL.Query().Get("service")
		wantMethod = http.MethodGet
	}
	if (service != "git-upload-pack" && service != "git-receive-pack") || r.Method != wantMethod {
		gitError(w, 400, "unsupported git request.")
		return
	}

	conn, err := p.conns.Github(r.Context(), grant.UserID, grant.AgentID)
	if err != nil {
		p.log.Warn("git proxy connection lookup failed", "error", err)
		gitError(w, 502, "Something went wrong. Please try again.")
		return
	}
	if conn == nil || conn.Token == "" {
		gitError(w, 403, "this agent has no connected GitHub account. Connect GitHub for this agent in Integrations.")
		return
	}
	pushing := service == "git-receive-pack"
	if pushing && conn.ReadOnly {
		gitError(w, 403, "this agent's GitHub connection is read-only.")
		return
	}

	upstreamPath := "/" + owner + "/" + repo + ".git/" + endpoint
	if advert {
		upstreamPath += "?service=" + service
	}
	if pushing && !advert {
		err = p.refuseOrForwardPush(w, r, grant, owner, repo, upstreamPath, conn.Token)
	} else {
		err = p.forward(w, r, upstreamPath, conn.Token, nil)
	}
	if err != nil {
		p.log.Warn("git proxy request failed", "service", service, "repo", owner+"/"+repo, "error", err)
		gitError(w, 502, err.Error())
	}
}

func (p *Proxy) refuseOrForwardPush(w http.ResponseWriter, r *http.Request, grant Grant, owner, repo, upstreamPath, token string) error {
	if r.Header.Get("Content-Encoding") != "" {
		gitError(w, 415, "Compressed push requests are not supported.")
		return nil
	}
	head, err := readPushCommands(r.Body)
	if err != nil {
		return err
	}
	refs := make([]string, len(head.commands))
	for i, c := range head.commands {
		refs[i] = c.Ref
	}
	list := strings.Join(refs, ", ")
	refused, err := p.findPushRefusal(r.Context(), head.commands, owner, repo, token)
	if err != nil {
		return err
	}
	if refused != nil {
		p.log.Warn("refused push", "agent", grant.AgentID, "run", grant.RunID, "repo", owner+"/"+repo, "refs", list, "reason", refused.reason)
		// Drain the pack the client is still sending before answering.
		_, _ = io.Copy(io.Discard, r.Body)
		w.Header().Set("Content-Type", "application/x-git-receive-pack-result")
		w.Header().Set("Cache-Control", "no-cache")
		w.WriteHeader(200)
		_, _ = w.Write(buildPushRefusalReport(head.commands, head.clientCapabilities, *refused))
		return nil
	}
	p.log.Info("agent push", "agent", grant.AgentID, "run", grant.RunID, "repo", owner+"/"+repo, "refs", list)
	return p.forward(w, r, upstreamPath, token, head.head)
}

// findPushRefusal decides before any pack data reaches GitHub. Creating the
// default branch (the first push to an empty repository) cannot overwrite
// anything; only updates to an existing default branch are refused.
func (p *Proxy) findPushRefusal(ctx context.Context, commands []PushCommand, owner, repo, token string) (*refusal, error) {
	for _, c := range commands {
		if isNullID(c.NewID) {
			return &refusal{ref: c.Ref, reason: "agents may not delete remote branches or tags"}, nil
		}
	}
	var updates []PushCommand
	for _, c := range commands {
		if !isNullID(c.OldID) {
			updates = append(updates, c)
		}
	}
	if len(updates) == 0 {
		return nil, nil
	}
	branch, err := p.defaultBranch(ctx, token, owner, repo)
	if err != nil {
		return nil, err
	}
	for _, c := range updates {
		if c.Ref == "refs/heads/"+branch {
			return &refusal{ref: c.Ref, reason: "pushes to the default branch " + branch + " are blocked; push a feature branch and open a pull request"}, nil
		}
	}
	return nil, nil
}

// defaultBranch asks the GitHub API for the repository's default branch. A
// repository without one reads as "undefined", the text Node built from the
// missing field.
func (p *Proxy) defaultBranch(ctx context.Context, token, owner, repo string) (string, error) {
	u, err := url.JoinPath(p.apiBase, "repos", owner, repo)
	if err != nil {
		return "", err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, u, nil)
	if err != nil {
		return "", err
	}
	req.Header.Set("Accept", "application/vnd.github.v3+json")
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("X-GitHub-Api-Version", "2022-11-28")
	resp, err := p.client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	raw, err := io.ReadAll(io.LimitReader(resp.Body, 10<<20))
	if err != nil {
		return "", err
	}
	var data struct {
		Message       string `json:"message"`
		DefaultBranch any    `json:"default_branch"`
	}
	text := string(bytes.TrimSpace(raw))
	parsed := text != "" && json.Unmarshal(raw, &data) == nil
	if resp.StatusCode < 200 || resp.StatusCode > 299 {
		switch {
		case text != "" && !parsed:
			return "", fmt.Errorf("GitHub API error %d: %s", resp.StatusCode, raw)
		case data.Message != "":
			return "", errors.New(data.Message)
		}
		return "", fmt.Errorf("GitHub API error: %d", resp.StatusCode)
	}
	if s, ok := data.DefaultBranch.(string); ok && s != "" {
		return s, nil
	}
	return "undefined", nil
}

// forward sends the request to GitHub with the agent's token and streams the
// answer back. head is the part of a push body already read.
func (p *Proxy) forward(w http.ResponseWriter, r *http.Request, upstreamPath, token string, head []byte) error {
	var body io.Reader
	length := int64(0)
	if r.Method == http.MethodPost {
		body = r.Body
		length = r.ContentLength
		if head != nil {
			body = io.MultiReader(bytes.NewReader(head), r.Body)
		}
	}
	req, err := http.NewRequestWithContext(r.Context(), r.Method, p.base+upstreamPath, body)
	if err != nil {
		return err
	}
	if body != nil {
		req.ContentLength = length
	}
	req.Header.Set("Authorization", "Basic "+base64.StdEncoding.EncodeToString([]byte("x-access-token:"+token)))
	for _, name := range forwardedRequest {
		if v := r.Header.Get(name); v != "" {
			req.Header.Set(name, v)
		}
	}
	resp, err := p.client.Do(req)
	if err != nil {
		p.log.Warn("GitHub request failed", "error", err)
		gitError(w, 502, "GitHub request failed.")
		return nil
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusUnauthorized {
		_, _ = io.Copy(io.Discard, resp.Body)
		gitError(w, 403, "GitHub rejected this agent's token. Reconnect GitHub for this agent in Integrations.")
		return nil
	}
	for _, name := range forwardedResponse {
		if v := resp.Header.Get(name); v != "" {
			w.Header().Set(name, v)
		}
	}
	w.WriteHeader(resp.StatusCode)
	flusher := http.NewResponseController(w)
	buf := make([]byte, 32*1024)
	for {
		n, rerr := resp.Body.Read(buf)
		if n > 0 {
			if _, werr := w.Write(buf[:n]); werr != nil {
				return nil
			}
			_ = flusher.Flush()
		}
		if rerr == io.EOF {
			return nil
		}
		if rerr != nil {
			// Headers are out; cut the connection so git sees the failure.
			panic(http.ErrAbortHandler)
		}
	}
}
