// Package mcpserver manages the MCP servers an account connects its agents to:
// the /api/mcp routes, the rows in mcp_servers and the live connections the AI
// engine calls tools through. It mirrors the Node server's routes/mcp.js and
// services/mcp.
package mcpserver

import (
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
	"errors"
	"fmt"
	"net/url"
	"regexp"
	"strconv"
	"strings"
	"syscall"
	"time"
)

// ValidateEndpoint accepts an http(s) URL and returns it serialised the way
// JavaScript's URL.toString() does (lower-case host, default port dropped,
// "/" for an empty path).
func ValidateEndpoint(value string) (string, error) {
	u, err := url.Parse(strings.TrimSpace(value))
	if err != nil || u.Scheme == "" {
		return "", errors.New("MCP server must be a valid remote http(s) URL.")
	}
	scheme := strings.ToLower(u.Scheme)
	if scheme != "http" && scheme != "https" {
		return "", errors.New("MCP server must use http or https. Local stdio/process MCP is disabled.")
	}
	if u.Host == "" {
		return "", errors.New("MCP server must be a valid remote http(s) URL.")
	}
	u.Scheme = scheme
	host := strings.ToLower(u.Hostname())
	if strings.Contains(host, ":") {
		host = "[" + host + "]"
	}
	port := u.Port()
	if (scheme == "http" && port == "80") || (scheme == "https" && port == "443") {
		port = ""
	}
	u.Host = host
	if port != "" {
		u.Host = host + ":" + port
	}
	if u.Path == "" {
		u.Path = "/"
	}
	return u.String(), nil
}

var (
	slugJunk     = regexp.MustCompile(`[^a-z0-9]+`)
	refusedAddr  = regexp.MustCompile(`dial tcp (\S+): connect: connection refused`)
	httpStatusRe = regexp.MustCompile(`(?i)HTTP (\d+)`)
)

// slugFor is the part of a tool name that identifies its server.
func slugFor(name string, id int64) string {
	if name == "" {
		name = strconv.FormatInt(id, 10)
	}
	return strings.Trim(slugJunk.ReplaceAllString(strings.ToLower(name), "_"), "_")
}

// errorMessage turns a connection failure into one readable line.
func errorMessage(err error) string {
	raw := err.Error()
	lower := strings.ToLower(raw)
	if strings.Contains(lower, "<!doctype") || strings.Contains(lower, "<html") {
		if m := httpStatusRe.FindStringSubmatch(raw); m != nil {
			return "Server returned HTTP " + m[1] + " - the MCP endpoint may be down or misconfigured"
		}
		return "Server returned an HTML error page - the MCP endpoint may be down or misconfigured"
	}
	if errors.Is(err, syscall.ECONNREFUSED) || strings.Contains(raw, "connection refused") {
		if m := refusedAddr.FindStringSubmatch(raw); m != nil {
			return "Connection refused at " + m[1] + " - is the MCP server running?"
		}
		return "Connection refused - the MCP server is not reachable"
	}
	first, _, _ := strings.Cut(raw, "\n")
	return strings.TrimSpace(first)
}

func isoNow() string { return time.Now().UTC().Format("2006-01-02T15:04:05.000Z") }

const (
	oauthStateTTL = 10 * time.Minute
	oauthRedirect = "OAUTH_REDIRECT:"
)

var oauthStateRE = regexp.MustCompile(`^(\d+)::[a-f0-9]{32}$`)

func hashState(state string) string {
	sum := sha256.Sum256([]byte(state))
	return hex.EncodeToString(sum[:])
}

func newState(serverID int64) string {
	var b [16]byte
	_, _ = rand.Read(b[:])
	return fmt.Sprintf("%d::%s", serverID, hex.EncodeToString(b[:]))
}

// stateMatches compares the stored digest with the digest of state in
// constant time.
func stateMatches(expectedHex, state string) bool {
	expected, err := hex.DecodeString(expectedHex)
	actual, _ := hex.DecodeString(hashState(state))
	return err == nil && len(expected) == len(actual) && subtle.ConstantTimeCompare(expected, actual) == 1
}
