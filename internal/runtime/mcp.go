package runtime

import (
	"errors"
	"net/url"
	"strings"
)

// ValidateRemoteMCPEndpoint accepts only remote http(s) MCP servers and
// returns the URL in its normalized form. Local stdio/process MCP is disabled.
func ValidateRemoteMCPEndpoint(value string) (string, error) {
	u, err := url.Parse(strings.TrimSpace(value))
	if err != nil || u.Scheme == "" || u.Host == "" && u.Opaque == "" {
		return "", errors.New("MCP server must be a valid remote http(s) URL.")
	}
	if u.Scheme != "http" && u.Scheme != "https" {
		return "", errors.New("MCP server must use http or https. Local stdio/process MCP is disabled.")
	}
	return normalizeURL(u), nil
}

// normalizeURL writes u the way the WHATWG URL standard does for http(s):
// lower-case host, no default port, and "/" for an empty path.
func normalizeURL(u *url.URL) string {
	n := *u
	n.Scheme = strings.ToLower(n.Scheme)
	host := strings.ToLower(n.Hostname())
	port := n.Port()
	if (n.Scheme == "http" && port == "80") || (n.Scheme == "https" && port == "443") {
		port = ""
	}
	if strings.Contains(host, ":") {
		host = "[" + host + "]"
	}
	n.Host = host
	if port != "" {
		n.Host = host + ":" + port
	}
	if n.Path == "" {
		n.Path = "/"
	}
	return n.String()
}
