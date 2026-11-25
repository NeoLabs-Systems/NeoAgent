// Package dav holds what every DAV-backed integration shares: server URLs and
// paths inside a WebDAV home, the XML and iCalendar/vCard reading and writing,
// and the CalDAV calendar and CardDAV contact tools.
package dav

import (
	"errors"
	"fmt"
	"net/url"
	"regexp"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/cloudsec"
)

func text(v any) string {
	switch t := v.(type) {
	case nil:
		return ""
	case string:
		return strings.TrimSpace(t)
	}
	return strings.TrimSpace(fmt.Sprint(v))
}

var portSuffix = regexp.MustCompile(`:\d+$`)

// privateHost classifies host[:port] the way setup forms pass it.
func privateHost(hostPart string) bool {
	h := strings.ToLower(strings.TrimSpace(hostPart))
	if strings.HasPrefix(h, "[") {
		if end := strings.Index(h, "]"); end > 0 {
			h = h[1:end]
		}
	} else if strings.Count(h, ":") <= 1 {
		h = portSuffix.ReplaceAllString(h, "")
	}
	return cloudsec.IsPrivateHost(h)
}

// NormalizeServerURL is a DAV server's base URL: HTTPS unless it is on a
// private network, never carrying credentials, query or fragment, and without
// a trailing slash.
func NormalizeServerURL(value any, label string) (string, error) {
	raw := text(value)
	if raw == "" {
		return "", fmt.Errorf("%s is required.", label)
	}
	candidate := raw
	if !strings.Contains(raw, "://") {
		scheme := "https"
		if privateHost(strings.SplitN(raw, "/", 2)[0]) {
			scheme = "http"
		}
		candidate = scheme + "://" + raw
	}
	u, err := url.Parse(candidate)
	if err != nil || u.Host == "" {
		return "", fmt.Errorf("%s must be a valid HTTP or HTTPS URL.", label)
	}
	u.Scheme = strings.ToLower(u.Scheme)
	if (u.Scheme != "http" && u.Scheme != "https") || u.User != nil || u.Fragment != "" || strings.HasSuffix(candidate, "#") {
		return "", fmt.Errorf("%s must be HTTP(S), without credentials or a fragment.", label)
	}
	u.Host = strings.ToLower(u.Host)
	if (u.Scheme == "https" && strings.HasSuffix(u.Host, ":443")) || (u.Scheme == "http" && strings.HasSuffix(u.Host, ":80")) {
		u.Host = u.Host[:strings.LastIndex(u.Host, ":")]
	}
	u.Path = strings.TrimRight(u.Path, "/")
	u.RawPath = ""
	u.RawQuery, u.ForceQuery = "", false
	return strings.TrimRight(u.String(), "/"), nil
}

// NormalizeRemotePath is a path inside a home: slashes normalized, "." and
// empty segments dropped, and ".." refused.
func NormalizeRemotePath(value any) (string, error) {
	raw := strings.ReplaceAll(text(value), `\`, "/")
	if raw == "" || raw == "/" {
		return "", nil
	}
	var parts []string
	for _, part := range strings.Split(raw, "/") {
		if part == "" || part == "." {
			continue
		}
		if part == ".." {
			return "", errors.New("Path must not contain parent traversal segments.")
		}
		parts = append(parts, part)
	}
	return strings.Join(parts, "/"), nil
}

// EncodePathSegments percent-encodes each segment of a normalized path.
func EncodePathSegments(value any) (string, error) {
	normalized, err := NormalizeRemotePath(value)
	if err != nil {
		return "", err
	}
	var parts []string
	for _, part := range strings.Split(normalized, "/") {
		if part != "" {
			parts = append(parts, EncodeURIComponent(part))
		}
	}
	return strings.Join(parts, "/"), nil
}

// EncodeURIComponent is JavaScript's encodeURIComponent.
func EncodeURIComponent(s string) string {
	const keep = "-_.!~*'()"
	var b strings.Builder
	for i := 0; i < len(s); i++ {
		c := s[i]
		if c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c >= '0' && c <= '9' || strings.IndexByte(keep, c) >= 0 {
			b.WriteByte(c)
			continue
		}
		fmt.Fprintf(&b, "%%%02X", c)
	}
	return b.String()
}

// HrefToRemotePath turns a DAV href into a path relative to prefix (the home).
// A path that climbs out of its home is empty.
func HrefToRemotePath(href, prefix string) string {
	raw := text(href)
	if raw == "" {
		return ""
	}
	pathname := raw
	if strings.HasPrefix(raw, "http://") || strings.HasPrefix(raw, "https://") {
		if u, err := url.Parse(raw); err == nil {
			pathname = u.EscapedPath()
		}
	}
	decoded := pathname
	if d, err := url.PathUnescape(pathname); err == nil {
		decoded = d
	}
	decoded = strings.TrimRight(decoded, "/")
	if decoded == "" {
		decoded = "/"
	}
	marker := strings.TrimRight(strings.TrimSuffix(prefix, "/"), "/")
	if decoded == marker {
		return ""
	}
	rest := strings.TrimLeft(decoded, "/")
	if strings.HasPrefix(decoded, marker+"/") {
		rest = decoded[len(marker)+1:]
	}
	out, err := NormalizeRemotePath(rest)
	if err != nil {
		return ""
	}
	return out
}
