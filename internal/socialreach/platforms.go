package socialreach

import (
	"regexp"
	"strings"
)

type platform struct {
	ID, Label string
	Tier      int
	SetupKind string
	Hosts     []string
	Domains   []string
}

var platforms = map[string]platform{
	"rss":    {"rss", "RSS / Atom", 0, "none", nil, nil},
	"v2ex":   {"v2ex", "V2EX", 0, "none", []string{"v2ex.com", "www.v2ex.com"}, []string{"v2ex.com"}},
	"github": {"github", "GitHub", 0, "optional_auth", []string{"github.com", "www.github.com"}, []string{"github.com"}},
	"social_video": {"social_video", "Social video links", 0, "none",
		[]string{"youtube.com", "www.youtube.com", "youtu.be", "tiktok.com", "www.tiktok.com", "instagram.com", "www.instagram.com", "instagr.am", "x.com", "www.x.com", "twitter.com", "www.twitter.com"},
		[]string{"youtube.com", "youtu.be", "tiktok.com", "instagram.com", "x.com", "twitter.com"}},
	"xueqiu": {"xueqiu", "Xueqiu", 1, "cookies", []string{"xueqiu.com", "www.xueqiu.com", "stock.xueqiu.com"}, []string{"xueqiu.com"}},
	"x":      {"x", "X / Twitter", 2, "cookies", []string{"x.com", "twitter.com", "www.x.com", "www.twitter.com"}, []string{"x.com", "twitter.com"}},
	"reddit": {"reddit", "Reddit", 2, "none", []string{"reddit.com", "www.reddit.com", "old.reddit.com"}, []string{"reddit.com"}},
}

var platformJunk = regexp.MustCompile(`[^a-z0-9_]+`)

func normalizePlatformID(value string) string {
	id := platformJunk.ReplaceAllString(strings.ToLower(jsTrim(value)), "_")
	switch id {
	case "twitter":
		return "x"
	case "youtube", "tiktok", "instagram", "reels":
		return "social_video"
	}
	return id
}

func platformDefinition(id string) (platform, bool) {
	p, ok := platforms[normalizePlatformID(id)]
	return p, ok
}
