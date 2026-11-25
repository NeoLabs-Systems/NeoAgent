package socialreach

import (
	"context"
	"regexp"
	"strings"
)

type xChannel struct {
	base
	http    fetcher
	cookies *cookieStore
}

func newX(f fetcher, c *cookieStore) *xChannel { return &xChannel{base{platforms["x"]}, f, c} }

var statusPath = regexp.MustCompile(`(?i)/status(?:es)?/(\d+)`)

// statusID is the post id of an x.com or twitter.com status link, or "".
func statusID(raw any) (string, error) {
	u, err := assertHTTPURL(raw)
	if err != nil {
		return "", err
	}
	host := strings.TrimPrefix(strings.ToLower(u.Hostname()), "www.")
	if host != "x.com" && host != "twitter.com" {
		return "", nil
	}
	if m := statusPath.FindStringSubmatch(u.EscapedPath()); m != nil {
		return m[1], nil
	}
	return "", nil
}

func (c *xChannel) canHandleURL(raw string) bool {
	id, err := statusID(raw)
	return err == nil && id != ""
}

func (c *xChannel) headers(ctx context.Context, userID int64) map[string]string {
	h := map[string]string{"User-Agent": defaultUA, "Referer": "https://x.com/"}
	if cookie := c.cookies.header(ctx, userID, c.ID); cookie != "" {
		h["Cookie"] = cookie
	}
	return h
}

func (c *xChannel) check(ctx context.Context, userID int64) (obj, error) {
	summary := c.cookies.summary(ctx, userID, c.ID)
	s := c.baseStatus()
	s.set("cookie", summary)
	if summary.Configured {
		s.set("activeBackend", "x_syndication_cookies")
		s.set("message", "Reads X post links using imported cookies for better reliability.")
	} else {
		s.set("activeBackend", "x_syndication_public")
		s.set("message", "Reads public X post links when X allows anonymous access. Import cookies from the cloud computer browser for better reliability.")
	}
	return s, nil
}

func (c *xChannel) read(ctx context.Context, a readArgs) (any, error) {
	id, err := statusID(a.get("url"))
	if err != nil {
		return nil, err
	}
	if id == "" {
		return nil, badRequest("A public X post URL is required.")
	}
	source := "x_syndication_public"
	if c.cookies.header(ctx, a.userID, c.ID) != "" {
		source = "x_syndication_cookies"
	}
	data, err := c.http.json(ctx, "https://cdn.syndication.twimg.com/tweet-result?id="+encodeURIComponent(id)+"&lang=en", c.headers(ctx, a.userID))
	if err != nil {
		return nil, err
	}
	var author any
	if user := dig(data, "user"); truthy(user) {
		author = obj{{"name", or(dig(user, "name"), "")}, {"screenName", or(dig(user, "screen_name"), "")},
			{"profileImageUrl", or(dig(user, "profile_image_url_https"), nil)}}
	}
	photos := []any{}
	for _, p := range list(dig(data, "photos")) {
		photos = append(photos, obj{{"url", or(dig(p, "url"), dig(p, "expandedUrl"), "")}, {"width", or(dig(p, "width"), nil)}, {"height", or(dig(p, "height"), nil)}})
	}
	videos := []any{}
	for _, v := range list(dig(data, "video", "variants")) {
		videos = append(videos, obj{{"url", or(dig(v, "src"), dig(v, "url"), "")}, {"contentType", or(dig(v, "type"), dig(v, "content_type"), "")},
			{"bitrate", or(dig(v, "bitrate"), nil)}})
	}
	return obj{
		{"platform", c.ID}, {"id", id}, {"title", compactText(or(dig(data, "text"), ""), 120)}, {"text", compactText(or(dig(data, "text"), ""), 4000)},
		{"author", author}, {"createdAt", or(dig(data, "created_at"), nil)}, {"photos", photos}, {"videos", videos},
		{"url", "https://x.com/i/web/status/" + id}, {"source", source},
	}, nil
}
