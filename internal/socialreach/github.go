package socialreach

import (
	"context"
	"encoding/json"
	"strconv"
	"strings"
)

type githubChannel struct {
	base
	http fetcher
}

func newGithub(f fetcher) *githubChannel { return &githubChannel{base{platforms["github"]}, f} }

func (c *githubChannel) check(context.Context, int64) (obj, error) {
	s := c.baseStatus()
	s.set("activeBackend", "github_rest_public")
	s.set("message", "Public GitHub repository read/search is available through the GitHub REST API.")
	return s, nil
}

func parseRepoURL(raw any) (owner, repo string, err error) {
	u, err := assertHTTPURL(raw)
	if err != nil {
		return "", "", err
	}
	var parts []string
	for _, p := range strings.Split(u.EscapedPath(), "/") {
		if p != "" {
			parts = append(parts, p)
		}
	}
	if strings.TrimPrefix(u.Hostname(), "www.") != "github.com" || len(parts) < 2 {
		return "", "", badRequest("A GitHub repository URL is required.")
	}
	return parts[0], strings.TrimSuffix(parts[1], ".git"), nil
}

func (c *githubChannel) read(ctx context.Context, a readArgs) (any, error) {
	owner, repo, err := parseRepoURL(a.get("url"))
	if err != nil {
		return nil, err
	}
	data, err := c.http.json(ctx, "https://api.github.com/repos/"+encodeURIComponent(owner)+"/"+encodeURIComponent(repo), nil)
	if err != nil {
		return nil, err
	}
	zero := json.Number("0")
	count := func(key string) any { return or(dig(data, key), zero) }
	return obj{
		{"platform", c.ID}, {"owner", owner}, {"repo", repo},
		{"title", or(dig(data, "full_name"), owner+"/"+repo)},
		{"description", or(dig(data, "description"), "")},
		{"url", or(dig(data, "html_url"), "https://github.com/"+owner+"/"+repo)},
		{"stars", count("stargazers_count")}, {"forks", count("forks_count")}, {"openIssues", count("open_issues_count")},
		{"language", or(dig(data, "language"), nil)}, {"defaultBranch", or(dig(data, "default_branch"), nil)},
		{"source", "github_rest_public"},
	}, nil
}

func (c *githubChannel) search(ctx context.Context, a readArgs) (any, error) {
	q, err := requireQuery(a)
	if err != nil {
		return nil, err
	}
	data, err := c.http.json(ctx, "https://api.github.com/search/repositories?q="+encodeURIComponent(q)+
		"&per_page="+strconv.Itoa(normalizeLimit(a.get("limit"), 10, 30)), nil)
	if err != nil {
		return nil, err
	}
	results := []any{}
	for _, item := range list(dig(data, "items")) {
		r := obj{}
		if has(item, "full_name") {
			r = append(r, field{"name", dig(item, "full_name")})
		}
		r = append(r, field{"description", or(dig(item, "description"), "")})
		if has(item, "html_url") {
			r = append(r, field{"url", dig(item, "html_url")})
		}
		r = append(r, field{"stars", or(dig(item, "stargazers_count"), json.Number("0"))}, field{"language", or(dig(item, "language"), nil)})
		results = append(results, r)
	}
	return obj{{"platform", c.ID}, {"query", q}, {"results", results}, {"source", "github_rest_public"}}, nil
}
