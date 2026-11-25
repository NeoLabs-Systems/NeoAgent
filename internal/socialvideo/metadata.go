package socialvideo

import (
	"regexp"
	"strings"
)

// decodeHTMLEntities replaces entities one after another, as Node did, so
// "&amp;lt;" ends as "<" like the original.
func decodeHTMLEntities(text string) string {
	for _, pair := range [][2]string{{"&amp;", "&"}, {"&lt;", "<"}, {"&gt;", ">"}, {"&quot;", `"`}, {"&#39;", "'"}} {
		text = strings.ReplaceAll(text, pair[0], pair[1])
	}
	text = hexApostrophe.ReplaceAllString(text, "'")
	return jsTrim(text)
}

var (
	hexApostrophe = regexp.MustCompile(`(?i)&#x27;`)
	titleRe       = regexp.MustCompile(`(?is)<title[^>]*>(.*?)</title>`)
	canonicalRe   = regexp.MustCompile(`(?is)<link\b[^>]*>`)
	relCanon      = regexp.MustCompile(`(?i)\brel=["'][^"']*canonical[^"']*["']`)
	hrefRe        = regexp.MustCompile(`(?i)\bhref=["']([^"']+)["']`)
)

func readHTMLTitle(html string) string {
	m := titleRe.FindStringSubmatch(html)
	if m == nil {
		return ""
	}
	return collapseWhitespace(decodeHTMLEntities(m[1]))
}

// readCanonicalURL finds the first link tag that names itself canonical and
// carries an href.
func readCanonicalURL(html string) string {
	for _, tag := range canonicalRe.FindAllString(html, -1) {
		if !relCanon.MatchString(tag) {
			continue
		}
		if m := hrefRe.FindStringSubmatch(tag); m != nil {
			return jsTrim(m[1])
		}
	}
	return ""
}

func readMetaTagContent(html, key, attr string) string {
	escaped := regexp.QuoteMeta(key)
	pattern := regexp.MustCompile(`(?is)<meta[^>]+` + attr + `=["']` + escaped + `["'][^>]*content=["'](.*?)["'][^>]*>|<meta[^>]+content=["'](.*?)["'][^>]*` + attr + `=["']` + escaped + `["'][^>]*>`)
	m := pattern.FindStringSubmatch(html)
	content := ""
	if m != nil {
		content = m[1]
		if content == "" {
			content = m[2]
		}
	}
	return collapseWhitespace(decodeHTMLEntities(content))
}

// PageMetadata is what a public page says about itself.
type PageMetadata struct {
	Title        string
	Description  string
	CanonicalURL string
}

func firstNonEmpty(values ...string) string {
	for _, v := range values {
		if v != "" {
			return v
		}
	}
	return ""
}

func extractPublicMetadata(html, fallbackURL string) PageMetadata {
	return PageMetadata{
		Title: firstNonEmpty(readMetaTagContent(html, "og:title", "property"),
			readMetaTagContent(html, "twitter:title", "name"), readHTMLTitle(html)),
		Description: firstNonEmpty(readMetaTagContent(html, "description", "name"),
			readMetaTagContent(html, "og:description", "property"),
			readMetaTagContent(html, "twitter:description", "name")),
		CanonicalURL: firstNonEmpty(readCanonicalURL(html), fallbackURL),
	}
}
