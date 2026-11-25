// Package textx holds the string behaviours of JavaScript that the prompts and
// run records depend on: lengths and slices count UTF-16 code units, and
// "whitespace" is the wider set that String.prototype.trim and \s know. The
// Node harness cut text at these positions, so the Go harness must cut at the
// same ones to produce the same model input.
package textx

import (
	"regexp"
	"strings"
	"unicode/utf16"
	"unicode/utf8"
)

// SpaceClass is the character class of JavaScript's \s, for use inside a regexp.
const SpaceClass = `\t\n\v\f\r \x{a0}\x{1680}\x{2000}-\x{200a}\x{2028}\x{2029}\x{202f}\x{205f}\x{3000}\x{feff}`

var spaceRun = regexp.MustCompile(`[` + SpaceClass + `]+`)

func isASCII(s string) bool {
	for i := 0; i < len(s); i++ {
		if s[i] >= utf8.RuneSelf {
			return false
		}
	}
	return true
}

// Len is the JavaScript length of s.
func Len(s string) int {
	if isASCII(s) {
		return len(s)
	}
	n := 0
	for _, r := range s {
		if r >= 0x10000 {
			n += 2
		} else {
			n++
		}
	}
	return n
}

// Slice is s.slice(from, to) with JavaScript semantics for negative and
// out-of-range indices. A cut through a surrogate pair yields U+FFFD, as Go
// strings cannot hold a lone surrogate.
func Slice(s string, from, to int) string {
	if isASCII(s) {
		from, to = clamp(from, len(s)), clamp(to, len(s))
		if from >= to {
			return ""
		}
		return s[from:to]
	}
	units := utf16.Encode([]rune(s))
	from, to = clamp(from, len(units)), clamp(to, len(units))
	if from >= to {
		return ""
	}
	return string(utf16.Decode(units[from:to]))
}

// Head is s.slice(0, n).
func Head(s string, n int) string { return Slice(s, 0, n) }

func clamp(i, length int) int {
	if i < 0 {
		i += length
		if i < 0 {
			return 0
		}
		return i
	}
	if i > length {
		return length
	}
	return i
}

// Trim is String.prototype.trim.
func Trim(s string) string {
	return strings.TrimFunc(s, IsSpace)
}

// TrimEnd is String.prototype.trimEnd.
func TrimEnd(s string) string {
	return strings.TrimRightFunc(s, IsSpace)
}

// IsSpace reports JavaScript whitespace.
func IsSpace(r rune) bool {
	switch r {
	case '\t', '\n', '\v', '\f', '\r', ' ', 0xa0, 0x1680, 0x2028, 0x2029, 0x202f, 0x205f, 0x3000, 0xfeff:
		return true
	}
	return r >= 0x2000 && r <= 0x200a
}

// Collapse is text.replace(/\s+/g, ' ').trim().
func Collapse(s string) string {
	return Trim(spaceRun.ReplaceAllString(s, " "))
}

// LastIndex is s.lastIndexOf(sub) in UTF-16 units, or -1.
func LastIndex(s, sub string) int {
	i := strings.LastIndex(s, sub)
	if i < 0 {
		return -1
	}
	return Len(s[:i])
}
