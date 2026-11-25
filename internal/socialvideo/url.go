package socialvideo

import (
	"errors"
	"fmt"
	"strings"
)

// Supported reports whether a platform id is one the extractor can read.
func supported(platform string) bool {
	switch platform {
	case "youtube", "tiktok", "instagram", "x":
		return true
	}
	return false
}

// Detected is a normalized video link and the platform it belongs to.
type Detected struct {
	Platform      string
	NormalizedURL string
}

// parsedURL is the part of the WHATWG URL a social link needs: Node used
// `new URL()`, so the same serialization rules are applied by hand.
type parsedURL struct {
	scheme, userinfo, host, port, path string
	query                              *string // nil when the URL has no query
	hasHash                            bool
}

var errInvalidURL = errors.New("Invalid URL")

func (u *parsedURL) String() string {
	var b strings.Builder
	b.WriteString(u.scheme + "://")
	if u.userinfo != "" {
		b.WriteString(u.userinfo + "@")
	}
	b.WriteString(u.host)
	if u.port != "" {
		b.WriteString(":" + u.port)
	}
	b.WriteString(u.path)
	if u.query != nil {
		b.WriteString("?" + *u.query)
	}
	return b.String()
}

func parseHTTPURL(raw string) (*parsedURL, error) {
	raw = strings.Map(func(r rune) rune {
		if r == '\t' || r == '\n' || r == '\r' {
			return -1
		}
		return r
	}, raw)
	i := strings.Index(raw, "://")
	if i < 1 {
		return nil, errInvalidURL
	}
	u := &parsedURL{scheme: strings.ToLower(raw[:i])}
	if u.scheme != "http" && u.scheme != "https" {
		return nil, errors.New("Only http and https URLs are supported.")
	}
	rest := raw[i+3:]
	if h := strings.IndexByte(rest, '#'); h >= 0 {
		u.hasHash = true
		rest = rest[:h]
	}
	if q := strings.IndexByte(rest, '?'); q >= 0 {
		query := encodeSet(rest[q+1:], queryEncoded)
		u.query = &query
		rest = rest[:q]
	}
	authority, path := rest, ""
	if s := strings.IndexAny(rest, `/\`); s >= 0 {
		authority, path = rest[:s], rest[s:]
	}
	if at := strings.LastIndexByte(authority, '@'); at >= 0 {
		u.userinfo = authority[:at]
		authority = authority[at+1:]
	}
	host := authority
	if c := strings.LastIndexByte(authority, ':'); c >= 0 && !strings.HasSuffix(authority, "]") {
		host, u.port = authority[:c], authority[c+1:]
	}
	if host == "" || strings.ContainsAny(host, " #%/:<>?@[\\]^|") {
		return nil, errInvalidURL
	}
	for _, r := range u.port {
		if r < '0' || r > '9' {
			return nil, errInvalidURL
		}
	}
	if len(u.port) > 5 {
		return nil, errInvalidURL
	}
	if u.port != "" {
		n := 0
		fmt.Sscan(u.port, &n)
		if n > 65535 {
			return nil, errInvalidURL
		}
		if (u.scheme == "http" && n == 80) || (u.scheme == "https" && n == 443) {
			u.port = ""
		} else {
			u.port = fmt.Sprint(n)
		}
	}
	u.host = strings.ToLower(host)
	u.path = cleanPath(encodeSet(strings.ReplaceAll(path, `\`, "/"), pathEncoded))
	return u, nil
}

func pathEncoded(b byte) bool {
	switch b {
	case ' ', '"', '#', '<', '>', '?', '`', '{', '}':
		return true
	}
	return b < 0x20 || b > 0x7e
}

func queryEncoded(b byte) bool {
	switch b {
	case ' ', '"', '#', '<', '>', '\'':
		return true
	}
	return b < 0x20 || b > 0x7e
}

func encodeSet(s string, in func(byte) bool) string {
	var b strings.Builder
	for i := 0; i < len(s); i++ {
		if in(s[i]) {
			fmt.Fprintf(&b, "%%%02X", s[i])
		} else {
			b.WriteByte(s[i])
		}
	}
	return b.String()
}

// cleanPath resolves "." and ".." segments the way URL parsing does.
func cleanPath(p string) string {
	if p == "" {
		return "/"
	}
	segs := strings.Split(p[1:], "/")
	var out []string
	for i, s := range segs {
		last := i == len(segs)-1
		switch strings.ToLower(s) {
		case ".", "%2e":
			if last {
				out = append(out, "")
			}
		case "..", ".%2e", "%2e.", "%2e%2e":
			if len(out) > 0 {
				out = out[:len(out)-1]
			}
			if last {
				out = append(out, "")
			}
		default:
			out = append(out, s)
		}
	}
	return "/" + strings.Join(out, "/")
}

type param struct{ name, value string }

func (u *parsedURL) params() []param {
	if u.query == nil {
		return nil
	}
	var out []param
	for _, pair := range strings.Split(*u.query, "&") {
		if pair == "" {
			continue
		}
		name, value, _ := strings.Cut(pair, "=")
		out = append(out, param{formDecode(name), formDecode(value)})
	}
	return out
}

func (u *parsedURL) setParams(params []param) {
	if len(params) == 0 {
		u.query = nil
		return
	}
	parts := make([]string, len(params))
	for i, p := range params {
		parts[i] = formEncode(p.name) + "=" + formEncode(p.value)
	}
	q := strings.Join(parts, "&")
	u.query = &q
}

func formDecode(s string) string {
	s = strings.ReplaceAll(s, "+", " ")
	var out []byte
	for i := 0; i < len(s); i++ {
		if s[i] == '%' && i+2 < len(s) && isHex(s[i+1]) && isHex(s[i+2]) {
			out = append(out, unhex(s[i+1])<<4|unhex(s[i+2]))
			i += 2
			continue
		}
		out = append(out, s[i])
	}
	return strings.ToValidUTF8(string(out), "�")
}

func isHex(c byte) bool {
	return c >= '0' && c <= '9' || c >= 'a' && c <= 'f' || c >= 'A' && c <= 'F'
}

func unhex(c byte) byte {
	switch {
	case c >= 'a':
		return c - 'a' + 10
	case c >= 'A':
		return c - 'A' + 10
	}
	return c - '0'
}

func formEncode(s string) string {
	var b strings.Builder
	for i := 0; i < len(s); i++ {
		c := s[i]
		switch {
		case c >= 'a' && c <= 'z', c >= 'A' && c <= 'Z', c >= '0' && c <= '9', c == '*', c == '-', c == '.', c == '_':
			b.WriteByte(c)
		case c == ' ':
			b.WriteByte('+')
		default:
			fmt.Fprintf(&b, "%%%02X", c)
		}
	}
	return b.String()
}

func normalizeInputURL(input string) (*parsedURL, error) {
	raw := jsTrim(input)
	if raw == "" {
		return nil, errors.New("url is required.")
	}
	if !hasScheme(raw) {
		raw = "https://" + raw
	}
	u, err := parseHTTPURL(raw)
	if err != nil {
		return nil, err
	}
	params := u.params()
	kept := params[:0:0]
	changed := false
	for _, p := range params {
		if strings.HasPrefix(p.name, "utm_") || p.name == "si" {
			changed = true
			continue
		}
		kept = append(kept, p)
	}
	if changed {
		u.setParams(kept)
	}
	return u, nil
}

// hasScheme is /^[a-z]+:\/\//i.
func hasScheme(s string) bool {
	i := strings.Index(s, "://")
	if i < 1 {
		return false
	}
	for _, r := range s[:i] {
		if !(r >= 'a' && r <= 'z' || r >= 'A' && r <= 'Z') {
			return false
		}
	}
	return true
}

// DetectPlatform names the platform a hostname belongs to, or "unknown".
func DetectPlatform(hostname string) string {
	host := strings.ToLower(hostname)
	switch {
	case host == "youtu.be" || host == "youtube.com" || strings.HasSuffix(host, ".youtube.com"):
		return "youtube"
	case host == "tiktok.com" || strings.HasSuffix(host, ".tiktok.com"):
		return "tiktok"
	case host == "instagram.com" || host == "instagr.am" || strings.HasSuffix(host, ".instagram.com"):
		return "instagram"
	case host == "x.com" || strings.HasSuffix(host, ".x.com") || host == "twitter.com" || strings.HasSuffix(host, ".twitter.com"):
		return "x"
	}
	return "unknown"
}

func canonicalize(u *parsedURL, platform string) {
	switch platform {
	case "youtube":
		if u.host == "youtu.be" {
			id := strings.SplitN(strings.TrimLeft(u.path, "/"), "/", 2)[0]
			u.host = "www.youtube.com"
			u.path = "/watch"
			if id != "" {
				params := u.params()
				done := false
				kept := params[:0:0]
				for _, p := range params {
					if p.name != "v" {
						kept = append(kept, p)
					} else if !done {
						done = true
						kept = append(kept, param{"v", id})
					}
				}
				if !done {
					kept = append(kept, param{"v", id})
				}
				u.setParams(kept)
			}
			return
		}
		u.host = "www.youtube.com"
	case "x":
		u.host = "x.com"
	}
}

// NormalizeAndDetect canonicalizes a social video link and finds its platform.
func NormalizeAndDetect(input string) (Detected, error) {
	u, err := normalizeInputURL(input)
	if err != nil {
		return Detected{}, err
	}
	platform := DetectPlatform(u.host)
	if !supported(platform) {
		return Detected{}, errors.New("Unsupported social video URL. Supported platforms: YouTube, TikTok, Instagram, and X.")
	}
	canonicalize(u, platform)
	return Detected{Platform: platform, NormalizedURL: u.String()}, nil
}
