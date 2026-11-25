// Package cloudsec decides whether a user-supplied URL may be fetched from
// the server: http(s) only, and never a loopback, private or link-local
// address, whether written as a literal or reached through DNS. It mirrors the
// Node server's utils/cloud-security.js, including the texts it returns, which
// tell the user what to change.
package cloudsec

import (
	"context"
	"errors"
	"fmt"
	"net"
	"net/netip"
	"net/url"
	"regexp"
	"strconv"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/NeoLabs-Systems/neolabs-go/ssrf"
)

// Result is the verdict; Reason is set when the URL is not allowed.
type Result struct {
	Allowed bool
	Reason  string
}

func blocked(reason string) Result { return Result{Reason: reason} }

var (
	schemePrefix = regexp.MustCompile(`(?i)^[a-z][a-z0-9+-]*:`)
	// The ranges ssrf.CheckAddr does not know: deprecated site-local and the
	// IPv6 discard-only prefix.
	extraPrivate = []netip.Prefix{netip.MustParsePrefix("fec0::/10"), netip.MustParsePrefix("100::/64")}
)

var blockedSchemes = map[string]bool{
	"javascript": true, "file": true, "chrome": true, "chrome-extension": true,
	"about": true, "vbscript": true, "data": true,
}

// Adult-content TLDs, with the dot so ".com" is not matched.
var blockedTLDs = []string{".xxx", ".porn", ".sex", ".adult", ".sexy"}

// Check validates the URL without touching the network.
func Check(raw string) Result {
	if raw == "" {
		return blocked("No URL was given.")
	}
	trimmed := jsTrim(raw)
	if !schemePrefix.MatchString(trimmed) {
		return blocked(`"` + raw + `" has no scheme. Use a full URL such as https://` + trimmed)
	}
	u, host, ok := parseURL(raw)
	if !ok {
		return blocked(`"` + raw + `" is not a valid URL.`)
	}
	scheme := strings.ToLower(u.Scheme)
	if blockedSchemes[scheme] || (scheme != "http" && scheme != "https") {
		return blocked(fmt.Sprintf("The %s: scheme is not allowed. Only http:// and https:// URLs can be opened.", scheme))
	}
	shown := host
	if strings.Contains(host, ":") {
		shown = "[" + host + "]"
	}
	if isPrivateHost(host) {
		return blocked(shown + " is a local or private network address, which is not reachable from here.")
	}
	if isBlockedTLD(host) {
		return blocked(shown + " is on a blocked adult-content domain.")
	}
	return Result{Allowed: true}
}

// Lookup resolves a hostname to every address it has.
type Lookup func(ctx context.Context, host string) ([]netip.Addr, error)

// Checker adds the DNS step: a hostname that resolves to a private address is
// refused as well. The zero value resolves through the system resolver with a
// five second limit.
type Checker struct {
	Lookup  Lookup
	Timeout time.Duration
}

// Validate runs Check, then resolves a hostname and checks every address. The
// error is only ever ctx's, when the caller gave up.
func (c Checker) Validate(ctx context.Context, raw string) (Result, error) {
	if err := ctx.Err(); err != nil {
		return Result{}, err
	}
	if verdict := Check(raw); !verdict.Allowed {
		return verdict, nil
	}
	_, host, _ := parseURL(raw)
	if _, err := netip.ParseAddr(host); err == nil {
		return Result{Allowed: true}, nil
	}

	lookup, timeout := c.Lookup, c.Timeout
	if lookup == nil {
		lookup = func(ctx context.Context, host string) ([]netip.Addr, error) {
			return net.DefaultResolver.LookupNetIP(ctx, "ip", host)
		}
	}
	if timeout == 0 {
		timeout = 5 * time.Second
	}
	lookupCtx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()
	addrs, err := lookup(lookupCtx, host)
	if cerr := ctx.Err(); cerr != nil {
		return Result{}, cerr
	}
	if err != nil {
		return blocked(describeLookupFailure(host, lookupCtx.Err() != nil, err)), nil
	}
	if len(addrs) == 0 {
		return blocked(describeLookupFailure(host, false, nil)), nil
	}
	for _, addr := range addrs {
		if isPrivateAddr(addr) {
			return blocked(host + " resolves to a local or private network address, which is not reachable from here."), nil
		}
	}
	return Result{Allowed: true}, nil
}

func describeLookupFailure(host string, timedOut bool, err error) string {
	if timedOut {
		return fmt.Sprintf("DNS lookup for %s timed out. The domain may be down or misspelled; retry, or use a different URL.", host)
	}
	code := ""
	var dnsErr *net.DNSError
	switch {
	case errors.As(err, &dnsErr) && dnsErr.IsNotFound:
		code = " (ENOTFOUND)"
	case errors.As(err, &dnsErr) && dnsErr.IsTemporary:
		code = " (EAI_AGAIN)"
	}
	return fmt.Sprintf("Could not resolve %s%s. Check that the domain is spelled correctly and exists.", host, code)
}

func isPrivateHost(host string) bool {
	if host == "localhost" || host == "localhost.localdomain" ||
		strings.HasSuffix(host, ".local") || strings.HasSuffix(host, ".internal") || strings.HasSuffix(host, ".localhost") {
		return true
	}
	addr, err := netip.ParseAddr(host)
	return err == nil && isPrivateAddr(addr)
}

func isPrivateAddr(addr netip.Addr) bool {
	addr = addr.Unmap()
	if addr.Is6() && addr != netip.IPv6Unspecified() && addr != netip.IPv6Loopback() {
		raw := addr.As16()
		if allZero(raw[:12]) { // IPv4-compatible address such as ::7f00:1
			addr = netip.AddrFrom4([4]byte(raw[12:]))
		}
	}
	if ssrf.CheckAddr(addr) != nil {
		return true
	}
	for _, prefix := range extraPrivate {
		if prefix.Contains(addr) {
			return true
		}
	}
	return false
}

func allZero(b []byte) bool {
	for _, c := range b {
		if c != 0 {
			return false
		}
	}
	return true
}

func isBlockedTLD(host string) bool {
	for _, tld := range blockedTLDs {
		if host == tld[1:] || strings.HasSuffix(host, tld) {
			return true
		}
	}
	return false
}

// parseURL parses raw the way new URL() does for the cases that matter here
// and returns the host as the WHATWG URL standard writes it: lower case, IPv4
// in dotted decimal however it was typed (2130706433, 0x7f.1), IPv6 compressed
// and without brackets. A URL it cannot read is refused.
func parseURL(raw string) (*url.URL, string, bool) {
	u, err := url.Parse(stripURLWhitespace(raw))
	if err != nil {
		return nil, "", false
	}
	scheme := strings.ToLower(u.Scheme)
	if scheme != "http" && scheme != "https" {
		// Not fetched anyway; only the scheme is reported.
		return u, "", true
	}
	host, ok := normalizeHost(u.Hostname(), strings.HasPrefix(u.Host, "["))
	if !ok {
		return nil, "", false
	}
	return u, host, true
}

// stripURLWhitespace drops what the URL standard ignores: control characters
// and spaces around the URL, tabs and newlines anywhere.
func stripURLWhitespace(s string) string {
	s = strings.TrimFunc(s, func(r rune) bool { return r <= 0x20 })
	return strings.NewReplacer("\t", "", "\n", "", "\r", "").Replace(s)
}

func normalizeHost(host string, bracketed bool) (string, bool) {
	if host == "" {
		return "", false
	}
	if bracketed {
		addr, err := netip.ParseAddr(host)
		if err != nil || !addr.Is6() {
			return "", false
		}
		return formatIPv6(addr), true
	}
	host = strings.ToLower(host)
	if strings.ContainsAny(host, " #%/:<>?@[\\]^|") || strings.IndexFunc(host, func(r rune) bool { return r < 0x20 || r == 0x7f }) >= 0 {
		return "", false
	}
	if !utf8.ValidString(host) {
		return "", false
	}
	if endsInNumber(host) {
		return parseIPv4(host)
	}
	return host, true
}

func formatIPv6(addr netip.Addr) string {
	raw := addr.As16()
	var groups [8]uint16
	for i := range groups {
		groups[i] = uint16(raw[2*i])<<8 | uint16(raw[2*i+1])
	}
	bestStart, bestLen := -1, 1
	for i := 0; i < 8; {
		if groups[i] != 0 {
			i++
			continue
		}
		j := i
		for j < 8 && groups[j] == 0 {
			j++
		}
		if j-i > bestLen {
			bestStart, bestLen = i, j-i
		}
		i = j
	}
	var b strings.Builder
	for i := 0; i < 8; i++ {
		if i == bestStart {
			b.WriteString("::")
			i += bestLen - 1
			continue
		}
		if b.Len() > 0 && !strings.HasSuffix(b.String(), ":") {
			b.WriteByte(':')
		}
		b.WriteString(strconv.FormatUint(uint64(groups[i]), 16))
	}
	return b.String()
}

// endsInNumber is the URL standard's test for a host that must be an IPv4
// address: its last label is all digits or a 0x number.
func endsInNumber(host string) bool {
	parts := strings.Split(host, ".")
	if parts[len(parts)-1] == "" {
		if len(parts) == 1 {
			return false
		}
		parts = parts[:len(parts)-1]
	}
	last := parts[len(parts)-1]
	if last != "" && strings.Trim(last, "0123456789") == "" {
		return true
	}
	_, ok := parseIPv4Number(last)
	return ok
}

func parseIPv4Number(s string) (uint64, bool) {
	if s == "" {
		return 0, false
	}
	radix := 10
	switch {
	case len(s) >= 2 && (s[:2] == "0x" || s[:2] == "0X"):
		s, radix = s[2:], 16
	case len(s) >= 2 && s[0] == '0':
		s, radix = s[1:], 8
	}
	if s == "" {
		return 0, true
	}
	n, err := strconv.ParseUint(s, radix, 64)
	return n, err == nil
}

func parseIPv4(host string) (string, bool) {
	parts := strings.Split(host, ".")
	if parts[len(parts)-1] == "" && len(parts) > 1 {
		parts = parts[:len(parts)-1]
	}
	if len(parts) > 4 {
		return "", false
	}
	numbers := make([]uint64, len(parts))
	for i, part := range parts {
		n, ok := parseIPv4Number(part)
		if !ok {
			return "", false
		}
		numbers[i] = n
	}
	last := len(numbers) - 1
	for _, n := range numbers[:last] {
		if n > 255 {
			return "", false
		}
	}
	limit := uint64(1) << (8 * (4 - uint(last)))
	if numbers[last] >= limit {
		return "", false
	}
	ip := numbers[last]
	for i, n := range numbers[:last] {
		ip += n << (8 * (3 - uint(i)))
	}
	return fmt.Sprintf("%d.%d.%d.%d", ip>>24&255, ip>>16&255, ip>>8&255, ip&255), true
}

// jsTrim is String.prototype.trim: it strips the whitespace JavaScript knows.
func jsTrim(s string) string {
	return strings.TrimFunc(s, func(r rune) bool {
		switch r {
		case '\t', '\n', '\v', '\f', '\r', ' ', 0xa0, 0x1680, 0x2028, 0x2029, 0x202f, 0x205f, 0x3000, 0xfeff:
			return true
		}
		return r >= 0x2000 && r <= 0x200a
	})
}

// ValidHTTPURL reports whether raw is an http(s) URL with a host and without
// embedded credentials.
func ValidHTTPURL(raw string) bool {
	u, host, ok := parseURL(raw)
	if !ok || host == "" || u.User != nil {
		return false
	}
	scheme := strings.ToLower(u.Scheme)
	return scheme == "http" || scheme == "https"
}

// IsPrivateHost reports a loopback, private, link-local or reserved host name
// or address (isPrivateHost of utils/cloud-security).
func IsPrivateHost(host string) bool { return isPrivateHost(host) }
