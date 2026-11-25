package socialreach

import (
	"context"
	"regexp"
	"strconv"
	"strings"
)

type xueqiuChannel struct {
	base
	http    fetcher
	cookies *cookieStore
}

func newXueqiu(f fetcher, c *cookieStore) *xueqiuChannel {
	return &xueqiuChannel{base{platforms["xueqiu"]}, f, c}
}

var htmlTag = regexp.MustCompile(`<[^>]+>`)

func stripHTML(v any) string {
	return jsTrim(spaceRun.ReplaceAllString(htmlTag.ReplaceAllString(str(v), ""), " "))
}

func (c *xueqiuChannel) check(ctx context.Context, userID int64) (obj, error) {
	summary := c.cookies.summary(ctx, userID, c.ID)
	s := c.baseStatus()
	s.set("ready", summary.Configured)
	if summary.Configured {
		s.set("status", "ok")
		s.set("activeBackend", "xueqiu_http_cookies")
		s.set("cookie", summary)
		s.set("message", "Cookie-backed Xueqiu APIs are configured.")
	} else {
		s.set("status", "warn")
		s.set("activeBackend", nil)
		s.set("cookie", summary)
		s.set("message", "Import Xueqiu cookies from the cloud computer browser before using stock and community APIs.")
	}
	return s, nil
}

func (c *xueqiuChannel) headers(ctx context.Context, userID int64) map[string]string {
	h := map[string]string{"User-Agent": defaultUA, "Referer": "https://xueqiu.com/"}
	if cookie := c.cookies.header(ctx, userID, c.ID); cookie != "" {
		h["Cookie"] = cookie
	}
	return h
}

func (c *xueqiuChannel) search(ctx context.Context, a readArgs) (any, error) {
	q, err := requireQuery(a)
	if err != nil {
		return nil, err
	}
	data, err := c.http.json(ctx, "https://xueqiu.com/stock/search.json?code="+encodeURIComponent(q)+
		"&size="+strconv.Itoa(normalizeLimit(a.get("limit"), 10, 50)), c.headers(ctx, a.userID))
	if err != nil {
		return nil, err
	}
	results := []any{}
	for _, item := range list(or(dig(data, "stocks"), []any{})) {
		results = append(results, obj{{"symbol", or(dig(item, "code"), "")}, {"name", or(dig(item, "name"), "")}, {"exchange", or(dig(item, "exchange"), "")}})
	}
	return obj{{"platform", c.ID}, {"query", q}, {"results", results}, {"source", "xueqiu_http_cookies"}}, nil
}

// jsUpper is String.prototype.toUpperCase for the symbols people type.
func jsUpper(s string) string { return strings.ToUpper(s) }

func (c *xueqiuChannel) read(ctx context.Context, a readArgs) (any, error) {
	raw := jsUpper(jsTrim(str(a.get("symbol"))))
	if raw != "" {
		data, err := c.http.json(ctx, "https://stock.xueqiu.com/v5/stock/batch/quote.json?symbol="+encodeURIComponent(raw), c.headers(ctx, a.userID))
		if err != nil {
			return nil, err
		}
		quote := or(dig(data, "data", "items", 0, "quote"), map[string]any{})
		return obj{{"platform", c.ID}, {"symbol", or(dig(quote, "symbol"), raw)}, {"name", or(dig(quote, "name"), "")},
			{"quote", quote}, {"source", "xueqiu_http_cookies"}}, nil
	}
	data, err := c.http.json(ctx, "https://xueqiu.com/v4/statuses/public_timeline_by_category.json?since_id=-1&max_id=-1&count=20&category=-1", c.headers(ctx, a.userID))
	if err != nil {
		return nil, err
	}
	limit := normalizeLimit(a.get("limit"), 20, 50)
	results := []any{}
	for i, item := range list(or(dig(data, "list"), []any{})) {
		if i == limit {
			break
		}
		post := parseMaybeJSON(dig(item, "data"))
		var url any = ""
		if truthy(dig(post, "target")) {
			url = "https://xueqiu.com" + text(dig(post, "target"))
		}
		results = append(results, obj{
			{"id", or(dig(post, "id"), dig(item, "id"), nil)}, {"title", or(dig(post, "title"), "")},
			{"text", stripHTML(or(dig(post, "text"), dig(post, "description"), ""))},
			{"author", or(dig(post, "user", "screen_name"), "")}, {"likes", or(dig(post, "like_count"), nil)}, {"url", url},
		})
	}
	return obj{{"platform", c.ID}, {"results", results}, {"source", "xueqiu_http_cookies"}}, nil
}

// parseMaybeJSON reads a JSON string (or passes an object through); anything
// else is an empty object.
func parseMaybeJSON(v any) any {
	switch v := v.(type) {
	case string:
		if parsed, err := decode([]byte(v)); err == nil && truthy(parsed) {
			return parsed
		}
	case map[string]any:
		return v
	}
	return map[string]any{}
}
