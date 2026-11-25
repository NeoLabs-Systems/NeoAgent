package admin

import (
	"net/url"
	"regexp"
	"strconv"
	"strings"
)

var urlScheme = regexp.MustCompile(`^([A-Za-z][A-Za-z0-9+.-]*):(.*)$`)

// parseableScheme answers whether `new URL(text)` succeeds in Node and, if so,
// which scheme it reports (lower case). The settings routes only use it to
// reject text no URL parser accepts, so it covers the WHATWG rules that decide
// that: a scheme, and for http-like schemes a usable host and port.
func parseableScheme(text string) (string, bool) {
	text = strings.Map(func(r rune) rune {
		if r == '\t' || r == '\n' || r == '\r' {
			return -1
		}
		return r
	}, text)
	text = strings.TrimFunc(text, func(r rune) bool { return r <= 0x20 })
	match := urlScheme.FindStringSubmatch(text)
	if match == nil {
		return "", false
	}
	scheme, rest := strings.ToLower(match[1]), match[2]
	switch scheme {
	case "http", "https", "ftp", "ws", "wss":
		return scheme, specialAuthorityOK(strings.TrimLeft(rest, `/\`))
	case "file":
		return scheme, true
	}
	if strings.HasPrefix(rest, "//") {
		authority, _, _ := strings.Cut(rest[2:], "/")
		host := authority[strings.LastIndex(authority, "@")+1:]
		return scheme, !strings.ContainsAny(host, " <>^|\\[]#?")
	}
	return scheme, true
}

func specialAuthorityOK(rest string) bool {
	end := strings.IndexAny(rest, `/\?#`)
	if end < 0 {
		end = len(rest)
	}
	authority := rest[:end]
	hostPort := authority[strings.LastIndex(authority, "@")+1:]
	host, port := hostPort, ""
	if strings.HasPrefix(hostPort, "[") {
		closing := strings.Index(hostPort, "]")
		if closing < 0 {
			return false
		}
		host, port = hostPort[:closing+1], hostPort[closing+1:]
		if port != "" && port[0] != ':' {
			return false
		}
		port = strings.TrimPrefix(port, ":")
		if !validPort(port) {
			return false
		}
		return len(host) > 2 && strings.Trim(host[1:len(host)-1], "0123456789abcdefABCDEF:.") == ""
	}
	if i := strings.Index(hostPort, ":"); i >= 0 {
		host, port = hostPort[:i], hostPort[i+1:]
	}
	if !validPort(port) {
		return false
	}
	decoded, err := url.PathUnescape(host)
	if err != nil {
		decoded = host
	}
	if decoded == "" || strings.ContainsAny(decoded, " #%/:<>?@[\\]^|\x7f") {
		return false
	}
	for _, r := range decoded {
		if r < 0x20 {
			return false
		}
	}
	return true
}

func validPort(port string) bool {
	if port == "" {
		return true
	}
	n, err := strconv.Atoi(port)
	return err == nil && n >= 0 && n <= 65535 && strings.Trim(port, "0123456789") == ""
}
