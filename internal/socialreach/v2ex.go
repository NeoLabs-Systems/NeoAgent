package socialreach

import (
	"context"
	"encoding/json"
	"regexp"
	"strings"
)

type v2exChannel struct {
	base
	http fetcher
}

func newV2ex(f fetcher) *v2exChannel { return &v2exChannel{base{platforms["v2ex"]}, f} }

func (c *v2exChannel) check(context.Context, int64) (obj, error) {
	s := c.baseStatus()
	s.set("activeBackend", "v2ex_public_api")
	s.set("message", "Public API supports hot topics, node topics, topic details, and users.")
	return s, nil
}

func shapeTopic(item any) obj {
	id := dig(item, "id")
	var url any
	switch {
	case truthy(dig(item, "url")):
		url = dig(item, "url")
	case truthy(id):
		url = "https://www.v2ex.com/t/" + text(id)
	default:
		url = ""
	}
	return obj{
		{"id", or(id, nil)}, {"title", or(dig(item, "title"), "")}, {"url", url}, {"content", or(dig(item, "content"), "")},
		{"replies", or(dig(item, "replies"), json.Number("0"))},
		{"nodeName", or(dig(item, "node", "name"), "")}, {"nodeTitle", or(dig(item, "node", "title"), "")},
		{"author", or(dig(item, "member", "username"), "")}, {"createdAt", or(dig(item, "created"), nil)},
	}
}

var topicPath = regexp.MustCompile(`^/t/(\d+)`)

func (c *v2exChannel) read(ctx context.Context, a readArgs) (any, error) {
	u, err := assertHTTPURL(a.get("url"))
	if err != nil {
		return nil, err
	}
	m := topicPath.FindStringSubmatch(u.EscapedPath())
	if m == nil {
		q := u.Query().Get("q")
		if q == "" {
			q = "hot"
		}
		return c.search(ctx, readArgs{a.userID, map[string]any{"query": q, "limit": a.get("limit")}})
	}
	topicData, err := c.http.json(ctx, "https://www.v2ex.com/api/topics/show.json?id="+encodeURIComponent(m[1]), nil)
	if err != nil {
		return nil, err
	}
	topic := topicData
	if l, ok := topicData.([]any); ok {
		topic = nil
		if len(l) > 0 {
			topic = l[0]
		}
	}
	replies, err := c.http.json(ctx, "https://www.v2ex.com/api/replies/show.json?topic_id="+encodeURIComponent(m[1])+"&page=1", nil)
	if err != nil {
		if ctx.Err() != nil {
			return nil, ctx.Err()
		}
		replies = nil
	}
	limit := normalizeLimit(a.get("limit"), 50, 100)
	out := append(obj{{"platform", c.ID}}, shapeTopic(topic)...)
	items := []any{}
	for i, reply := range list(replies) {
		if i == limit {
			break
		}
		items = append(items, obj{{"author", or(dig(reply, "member", "username"), "")}, {"content", or(dig(reply, "content"), "")},
			{"createdAt", or(dig(reply, "created"), nil)}})
	}
	return append(out, field{"repliesList", items}, field{"source", "v2ex_public_api"}), nil
}

func (c *v2exChannel) search(ctx context.Context, a readArgs) (any, error) {
	query := strings.ToLower(jsTrim(str(a.get("query"))))
	capped := normalizeLimit(a.get("limit"), 20, 100)
	target, label := "https://www.v2ex.com/api/topics/hot.json", "hot"
	if query != "" && query != "hot" {
		target, label = "https://www.v2ex.com/api/topics/show.json?node_name="+encodeURIComponent(query)+"&page=1", query
	}
	data, err := c.http.json(ctx, target, nil)
	if err != nil {
		return nil, err
	}
	results := []any{}
	for i, item := range list(data) {
		if i == capped {
			break
		}
		results = append(results, shapeTopic(item))
	}
	return obj{{"platform", c.ID}, {"query", label}, {"results", results}, {"source", "v2ex_public_api"}}, nil
}
