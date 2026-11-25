package socialvideo

import (
	"regexp"
	"strings"
)

// jsSpace is what JavaScript's \s matches; Go's \s is ASCII only.
const jsSpace = `\s\x{0b}\x{a0}\x{1680}\x{2000}-\x{200a}\x{2028}\x{2029}\x{202f}\x{205f}\x{3000}\x{feff}`

var (
	spaceRun = regexp.MustCompile(`[` + jsSpace + `]+`)
	tagRe    = regexp.MustCompile(`<[^>]+>`)
)

// jsTrim is String.prototype.trim.
func jsTrim(s string) string {
	return strings.TrimFunc(s, func(r rune) bool {
		switch r {
		case '\t', '\n', '\v', '\f', '\r', ' ', 0xa0, 0x1680, 0x2028, 0x2029, 0x202f, 0x205f, 0x3000, 0xfeff:
			return true
		}
		return r >= 0x2000 && r <= 0x200a
	})
}

func collapseWhitespace(text string) string {
	return jsTrim(spaceRun.ReplaceAllString(text, " "))
}

// matchLower reports whether a lower-cased text matches a case-sensitive pattern.
func matchLower(pattern, text string) bool { return regexp.MustCompile(pattern).MatchString(text) }
