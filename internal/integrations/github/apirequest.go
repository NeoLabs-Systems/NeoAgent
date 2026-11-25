package github

import (
	"encoding/base64"
	"errors"
	"fmt"
	"net/url"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neolabs-go/oauthclient"
)

func decodeBase64Lenient(s string) (string, error) {
	out, err := base64.StdEncoding.DecodeString(s)
	if err != nil {
		out, err = base64.RawStdEncoding.DecodeString(strings.TrimRight(s, "="))
	}
	return string(out), err
}

// allowedAPIHosts are the hosts github_api_request may reach: GitHub itself
// and the GitHub Enterprise hosts an administrator names.
func (p *provider) allowedAPIHost(host string) bool {
	host = strings.ToLower(strings.TrimSpace(host))
	if host == "" {
		return false
	}
	if base, err := url.Parse(p.ep.api); err == nil && host == strings.ToLower(base.Hostname()) {
		return true
	}
	for _, h := range strings.Split(p.svc.Env("GITHUB_ALLOWED_API_HOSTS"), ",") {
		if strings.ToLower(strings.TrimSpace(h)) == host {
			return true
		}
	}
	return false
}

func apiRequestPath(args map[string]any) string {
	for _, key := range []string{"path", "endpoint", "url"} {
		if s, ok := args[key].(string); ok && strings.TrimSpace(s) != "" {
			return strings.TrimSpace(s)
		}
	}
	return ""
}

func (t *toolRun) apiRequest() (any, error) {
	args := t.args
	path := apiRequestPath(args)
	if path == "" {
		return nil, errNoPath
	}
	var query oauthclient.Query
	base := ""
	if q, ok := args["query"].(map[string]any); ok {
		for _, k := range integrations.SortedKeys(q) {
			if q[k] != nil {
				query = append(query, [2]string{k, integrations.Str(q[k])})
			}
		}
	}
	switch {
	case strings.HasPrefix(path, "http"):
		u, err := url.Parse(path)
		if err != nil {
			return nil, err
		}
		if u.Scheme != "https" && !t.p.insecureAPI() {
			return nil, errors.New("Only https:// GitHub API URLs are allowed.")
		}
		if !t.p.allowedAPIHost(u.Hostname()) {
			return nil, fmt.Errorf("Host is not allowed for GitHub API requests: %s", u.Hostname())
		}
		base, path = u.Scheme+"://"+u.Host, u.Path
		var merged oauthclient.Query
		for _, part := range strings.Split(u.RawQuery, "&") {
			if part == "" {
				continue
			}
			k, v, _ := strings.Cut(part, "=")
			k, _ = url.QueryUnescape(k)
			v, _ = url.QueryUnescape(v)
			merged.Set(k, v)
		}
		for _, kv := range query {
			merged.Set(kv[0], kv[1])
		}
		query = merged
	case hasOwnerRepo(args) && !strings.HasPrefix(path, "/repos/") && !strings.HasPrefix(path, "/user") &&
		!strings.HasPrefix(path, "/orgs/") && !strings.HasPrefix(path, "/search/"):
		// Convenience: prepend /repos/{owner}/{repo} for relative paths.
		or, err := parseOwnerRepoArg(args)
		if err != nil {
			return nil, err
		}
		if !strings.HasPrefix(path, "/") {
			path = "/" + path
		}
		path = "/repos/" + or.owner + "/" + or.repo + path
	}
	var body any
	for _, key := range []string{"body", "payload"} {
		if m, ok := args[key].(map[string]any); ok {
			body = m
			break
		}
	}
	return t.p.request(t.ctx, t.creds, request{method: textOf(args["method"]), path: path, query: query, body: body, base: base})
}

// insecureAPI is true only for a plain-http API root, which exists in tests.
func (p *provider) insecureAPI() bool { return strings.HasPrefix(p.ep.api, "http://") }
