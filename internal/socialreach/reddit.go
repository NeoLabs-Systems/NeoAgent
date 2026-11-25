package socialreach

import (
	"context"
	"math"
	"regexp"
	"strconv"
	"strings"
	"time"
)

type redditChannel struct {
	base
	http fetcher
}

func newReddit(f fetcher) *redditChannel { return &redditChannel{base{platforms["reddit"]}, f} }

func (c *redditChannel) check(context.Context, int64) (obj, error) {
	s := c.baseStatus()
	s.set("activeBackend", "reddit_public_json")
	s.set("message", "Reads and searches public Reddit posts when Reddit allows anonymous JSON access.")
	return s, nil
}

var commentsPath = regexp.MustCompile(`(?i)/comments/[a-z0-9]+`)

func redditPostJSONURL(input any) (string, error) {
	u, err := assertHTTPURL(input)
	if err != nil {
		return "", err
	}
	host := strings.TrimPrefix(strings.TrimPrefix(strings.ToLower(u.Hostname()), "www."), "old.")
	if host != "reddit.com" {
		return "", badRequest("A Reddit URL is required.")
	}
	path := u.EscapedPath()
	if !commentsPath.MatchString(path) {
		return "", badRequest("A Reddit post URL is required.")
	}
	return "https://www.reddit.com" + strings.TrimRight(path, "/") + ".json?raw_json=1", nil
}

func isoFromUnix(v any) any {
	if !truthy(v) {
		return nil
	}
	n := number(v) * 1000
	if math.IsNaN(n) || math.IsInf(n, 0) {
		return nil
	}
	return time.UnixMilli(int64(math.Trunc(n))).UTC().Format("2006-01-02T15:04:05.000Z")
}

func nullish(v any) any { return v }

func shapePost(raw any) obj {
	data := or(dig(raw, "data"), raw)
	permalink := dig(data, "permalink")
	var url any
	if truthy(permalink) {
		url = "https://www.reddit.com" + text(permalink)
	} else {
		url = or(dig(data, "url"), "")
	}
	return obj{
		{"id", or(dig(data, "id"), nil)}, {"title", or(dig(data, "title"), "")}, {"subreddit", or(dig(data, "subreddit"), "")},
		{"author", or(dig(data, "author"), "")},
		{"text", compactText(or(dig(data, "selftext"), dig(data, "selftext_html"), ""), 4000)},
		{"url", url}, {"outboundUrl", or(dig(data, "url_overridden_by_dest"), nil)},
		{"score", nullish(dig(data, "score"))}, {"comments", nullish(dig(data, "num_comments"))},
		{"createdAt", isoFromUnix(dig(data, "created_utc"))},
	}
}

func shapeComment(raw any) obj {
	data := or(dig(raw, "data"), raw)
	return obj{
		{"id", or(dig(data, "id"), nil)}, {"author", or(dig(data, "author"), "")},
		{"text", compactText(or(dig(data, "body"), dig(data, "body_html"), ""), 2000)},
		{"score", nullish(dig(data, "score"))}, {"createdAt", isoFromUnix(dig(data, "created_utc"))},
	}
}

func (c *redditChannel) read(ctx context.Context, a readArgs) (any, error) {
	target, err := redditPostJSONURL(a.get("url"))
	if err != nil {
		return nil, err
	}
	data, err := c.http.json(ctx, target, nil)
	if err != nil {
		return nil, err
	}
	limit := normalizeLimit(a.get("limit"), 20, 100)
	comments := []any{}
	for _, item := range list(dig(data, 1, "data", "children")) {
		if len(comments) == limit {
			break
		}
		if dig(item, "kind") == "t1" {
			comments = append(comments, shapeComment(item))
		}
	}
	return obj{{"platform", c.ID}, {"post", shapePost(dig(data, 0, "data", "children", 0))}, {"comments", comments}, {"source", "reddit_public_json"}}, nil
}

func (c *redditChannel) search(ctx context.Context, a readArgs) (any, error) {
	q, err := requireQuery(a)
	if err != nil {
		return nil, err
	}
	data, err := c.http.json(ctx, "https://www.reddit.com/search.json?q="+encodeURIComponent(q)+
		"&limit="+strconv.Itoa(normalizeLimit(a.get("limit"), 10, 50))+"&raw_json=1", nil)
	if err != nil {
		return nil, err
	}
	results := []any{}
	for _, item := range list(dig(data, "data", "children")) {
		results = append(results, shapePost(item))
	}
	return obj{{"platform", c.ID}, {"query", q}, {"results", results}, {"source", "reddit_public_json"}}, nil
}
