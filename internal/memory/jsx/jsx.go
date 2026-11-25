// Package jsx reproduces the parts of JavaScript the memory domain's stored
// bytes depend on: UTF-16 string lengths and slices, the whitespace that trim
// and \s know, JSON objects that keep their key order, and JSON.stringify's
// exact number and string forms. Memory rows are written by both the Node and
// the Go server, so the text they hold has to match byte for byte.
package jsx

import (
	"math"
	"regexp"
	"strconv"
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

// Len is the JavaScript length of s (UTF-16 code units).
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

// Slice is s.slice(from, to) for non-negative indices. A cut through a
// surrogate pair yields U+FFFD, as Go strings cannot hold a lone surrogate.
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
		return 0
	}
	if i > length {
		return length
	}
	return i
}

// UnitIndex converts a byte offset in s to a UTF-16 index.
func UnitIndex(s string, byteOffset int) int { return Len(s[:byteOffset]) }

// IndexFrom is s.indexOf(sub, from) in UTF-16 units: -1 when absent.
func IndexFrom(s, sub string, from int) int {
	if isASCII(s) {
		from = clamp(from, len(s))
		i := strings.Index(s[from:], sub)
		if i < 0 {
			return -1
		}
		return from + i
	}
	units := utf16.Encode([]rune(s))
	needle := utf16.Encode([]rune(sub))
	from = clamp(from, len(units))
	for i := from; i+len(needle) <= len(units); i++ {
		match := true
		for j := range needle {
			if units[i+j] != needle[j] {
				match = false
				break
			}
		}
		if match {
			return i
		}
	}
	return -1
}

// IsSpace is true for the characters String.prototype.trim removes.
func IsSpace(r rune) bool {
	switch r {
	case '\t', '\n', '\v', '\f', '\r', ' ', 0xa0, 0x1680, 0x2028, 0x2029, 0x202f, 0x205f, 0x3000, 0xfeff:
		return true
	}
	return r >= 0x2000 && r <= 0x200a
}

// Trim is String.prototype.trim.
func Trim(s string) string { return strings.TrimFunc(s, IsSpace) }

// TrimEnd is String.prototype.trimEnd.
func TrimEnd(s string) string { return strings.TrimRightFunc(s, IsSpace) }

// Collapse is text.replace(/\s+/g, ' ').trim().
func Collapse(s string) string { return Trim(spaceRun.ReplaceAllString(s, " ")) }

// ReplaceSpaceRuns is text.replace(/\s+/g, ' ') without the trim.
func ReplaceSpaceRuns(s string) string { return spaceRun.ReplaceAllString(s, " ") }

// Fields is text.split(/\s+/) after dropping empty parts, like
// `.trim().split(/\s+/).filter(Boolean)`.
func Fields(s string) []string { return strings.FieldsFunc(s, IsSpace) }

// FormatNumber is String(f) for a JavaScript number.
func FormatNumber(f float64) string {
	if f == 0 {
		return "0"
	}
	if math.IsNaN(f) || math.IsInf(f, 0) {
		return "null"
	}
	abs := math.Abs(f)
	format := byte('f')
	if abs < 1e-6 || abs >= 1e21 {
		format = 'e'
	}
	b := strconv.AppendFloat(nil, f, format, -1, 64)
	if format == 'e' {
		// e-09 becomes e-9, as in JavaScript.
		if n := len(b); n >= 4 && b[n-4] == 'e' && b[n-3] == '-' && b[n-2] == '0' {
			b[n-2] = b[n-1]
			b = b[:n-1]
		}
	}
	return string(b)
}

// Quote is JSON.stringify(s).
func Quote(s string) string {
	var b strings.Builder
	b.Grow(len(s) + 2)
	writeQuoted(&b, s)
	return b.String()
}

const hexDigits = "0123456789abcdef"

func writeQuoted(b *strings.Builder, s string) {
	b.WriteByte('"')
	for _, r := range s {
		switch r {
		case '"':
			b.WriteString(`\"`)
		case '\\':
			b.WriteString(`\\`)
		case '\b':
			b.WriteString(`\b`)
		case '\f':
			b.WriteString(`\f`)
		case '\n':
			b.WriteString(`\n`)
		case '\r':
			b.WriteString(`\r`)
		case '\t':
			b.WriteString(`\t`)
		default:
			if r < 0x20 {
				b.WriteString(`\u00`)
				b.WriteByte(hexDigits[r>>4])
				b.WriteByte(hexDigits[r&0xf])
			} else {
				b.WriteRune(r)
			}
		}
	}
	b.WriteByte('"')
}
