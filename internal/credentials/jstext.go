package credentials

import (
	"errors"
	"math"
	"net/url"
	"strconv"
	"strings"
	"unicode"
	"unicode/utf16"

	"golang.org/x/net/idna"
)

// The model hands the broker JSON objects, and Node read them with JavaScript's
// loose conversions. These helpers keep those conversions.

// truthy is JavaScript truthiness for a decoded JSON value.
func truthy(v any) bool {
	switch t := v.(type) {
	case nil:
		return false
	case bool:
		return t
	case string:
		return t != ""
	case float64:
		return t != 0 && !math.IsNaN(t)
	}
	return true
}

// jsString is String(v) for a decoded JSON value.
func jsString(v any) string {
	switch t := v.(type) {
	case nil:
		return ""
	case string:
		return t
	case bool:
		return strconv.FormatBool(t)
	case float64:
		return formatNumber(t)
	case []any:
		parts := make([]string, len(t))
		for i, e := range t {
			if e != nil {
				parts[i] = jsString(e)
			}
		}
		return strings.Join(parts, ",")
	}
	return "[object Object]"
}

func formatNumber(f float64) string {
	if f == math.Trunc(f) && math.Abs(f) < 1e21 {
		return strconv.FormatFloat(f, 'f', -1, 64)
	}
	return strconv.FormatFloat(f, 'g', -1, 64)
}

// trimText is String(value || ”).trim().
func trimText(v any) string {
	if !truthy(v) {
		return ""
	}
	return jsTrim(jsString(v))
}

func jsTrim(s string) string {
	return strings.TrimFunc(s, func(r rune) bool {
		return (unicode.IsSpace(r) && r != 0x85) || r == 0xFEFF
	})
}

// requireText is requireText(value, label) of utils/text.js.
func requireText(v any, label string) (string, error) {
	text := trimText(v)
	if text == "" {
		return "", errors.New(label + " is required.")
	}
	return text, nil
}

// toNumber is Number(v) for a decoded JSON value; NaN when it has no number.
func toNumber(v any) float64 {
	switch t := v.(type) {
	case nil:
		return 0
	case bool:
		if t {
			return 1
		}
		return 0
	case float64:
		return t
	case string:
		s := jsTrim(t)
		if s == "" {
			return 0
		}
		f, err := strconv.ParseFloat(s, 64)
		if err != nil {
			return math.NaN()
		}
		return f
	}
	return math.NaN()
}

// nullish is v == null.
func nullish(v any) bool { return v == nil }

// firstSet is `a ?? b`.
func firstSet(a, b any) any {
	if nullish(a) {
		return b
	}
	return a
}

// utf16Len is the JavaScript length of s.
func utf16Len(s string) int { return len(utf16.Encode([]rune(s))) }

func utf16Slice(s string, from, to int) string {
	units := utf16.Encode([]rune(s))
	return string(utf16.Decode(units[from:to]))
}

// parseURL reads a URL the way `new URL(text)` does for http(s) addresses:
// tabs and newlines vanish, backslashes in the path are slashes, the host is
// lower-case ASCII, a default port is dropped and "." and ".." segments are
// resolved. The result serialises like URL.toString().
func parseURL(text string) (*url.URL, error) {
	errInvalid := errors.New("Invalid URL")
	text = strings.NewReplacer("\t", "", "\n", "", "\r", "").Replace(text)
	if lower := strings.ToLower(text); strings.HasPrefix(lower, "http:") || strings.HasPrefix(lower, "https:") {
		head, tail := text, ""
		if i := strings.IndexAny(text, "?#"); i >= 0 {
			head, tail = text[:i], text[i:]
		}
		text = strings.ReplaceAll(head, `\`, "/") + tail
	}
	u, err := url.Parse(text)
	if err != nil || u.Scheme == "" || u.Host == "" {
		return nil, errInvalid
	}
	u.Scheme = strings.ToLower(u.Scheme)
	if u.Scheme != "http" && u.Scheme != "https" {
		return u, nil
	}
	host := strings.ToLower(u.Hostname())
	if strings.Contains(host, ":") {
		host = "[" + host + "]"
	} else if ascii, err := idna.Lookup.ToASCII(host); err == nil && ascii != "" {
		host = ascii
	} else {
		return nil, errInvalid
	}
	port := u.Port()
	if (u.Scheme == "https" && port == "443") || (u.Scheme == "http" && port == "80") {
		port = ""
	}
	u.Host = host
	if port != "" {
		u.Host = host + ":" + port
	}
	escaped := resolveDots(u.EscapedPath())
	if escaped == "" {
		escaped = "/"
	}
	decoded, err := url.PathUnescape(escaped)
	if err != nil {
		return nil, errInvalid
	}
	u.Path, u.RawPath = decoded, escaped
	return u, nil
}

// resolveDots removes "." and ".." segments, as the URL parser does (the
// percent-encoded spellings count as dots too).
func resolveDots(p string) string {
	if p == "" {
		return ""
	}
	segs := strings.Split(p, "/")
	var out []string
	for i, s := range segs {
		switch strings.ToLower(s) {
		case ".", "%2e":
			if i == len(segs)-1 {
				out = append(out, "")
			}
		case "..", ".%2e", "%2e.", "%2e%2e":
			if len(out) > 1 {
				out = out[:len(out)-1]
			}
			if i == len(segs)-1 {
				out = append(out, "")
			}
		default:
			out = append(out, s)
		}
	}
	res := strings.Join(out, "/")
	if !strings.HasPrefix(res, "/") {
		res = "/" + res
	}
	return res
}

// origin is URL.origin of a parsed http(s) URL.
func origin(u *url.URL) string { return u.Scheme + "://" + u.Host }

// pathname is URL.pathname: the path as it is sent, percent-encoded.
func pathname(u *url.URL) string { return u.EscapedPath() }
