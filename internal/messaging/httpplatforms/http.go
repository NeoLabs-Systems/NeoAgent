// Package httpplatforms holds the webhook- and REST-driven chat platforms: Google Chat, Teams, Matrix,
// Signal, LINE, Mattermost, BlueBubbles/iMessage, IRC/Twitch and the
// configurable generic platforms. Slack lives in its own package.
package httpplatforms

import (
	"bytes"
	"context"
	"crypto/rand"
	"crypto/subtle"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/netip"
	neturl "net/url"
	"regexp"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/ssrf"
)

const (
	maxResponseBytes = 2 * 1024 * 1024
	requestTimeout   = 15 * time.Second
)

// Deps are what the platforms need from the server.
type Deps struct {
	// Client sends every request to a user-configured address. Nil builds an
	// ssrf client that refuses internal destinations, unless AllowPrivate.
	Client *http.Client
	// AllowPrivate lets requests and IRC sockets reach private addresses, for
	// self-hosted Matrix, Signal or BlueBubbles servers on a LAN. Node had no
	// such limit.
	AllowPrivate bool
}

// HTTPClient is the client requests go through.
func (d Deps) HTTPClient() *http.Client {
	if d.Client != nil {
		return d.Client
	}
	return ssrf.NewClient(ssrf.Options{AllowPrivate: d.AllowPrivate, Timeout: requestTimeout})
}

// Dialer is the dialer IRC sockets use; it refuses internal addresses unless
// AllowPrivate.
func (d Deps) dialer() *net.Dialer {
	nd := &net.Dialer{Timeout: 20 * time.Second}
	if !d.AllowPrivate {
		nd.Control = func(_, address string, _ syscall.RawConn) error {
			ap, err := netip.ParseAddrPort(address)
			if err != nil {
				return err
			}
			return ssrf.CheckAddr(ap.Addr())
		}
	}
	return nd
}

// Settings is a stored platform configuration with JavaScript's `||` reading
// rules: the first truthy value wins.
type Settings map[string]any

func truthy(v any) bool {
	switch v := v.(type) {
	case nil:
		return false
	case string:
		return v != ""
	case bool:
		return v
	case float64:
		return v != 0
	}
	return true
}

func text(v any) string {
	switch v := v.(type) {
	case string:
		return v
	case float64:
		if v == float64(int64(v)) {
			return strconv.FormatInt(int64(v), 10)
		}
		return strconv.FormatFloat(v, 'g', -1, 64)
	case bool:
		return strconv.FormatBool(v)
	case nil:
		return ""
	}
	return "[object Object]"
}

// Str is `config.a || config.b || ”` as a string.
func (s Settings) Str(keys ...string) string {
	for _, k := range keys {
		if truthy(s[k]) {
			return text(s[k])
		}
	}
	return ""
}

func (s Settings) num(key string, fallback float64) float64 {
	switch v := s[key].(type) {
	case float64:
		if v != 0 {
			return v
		}
	case string:
		if f, err := strconv.ParseFloat(strings.TrimSpace(v), 64); err == nil && f != 0 {
			return f
		}
	}
	return fallback
}

func trimTrailingSlash(v string) string { return strings.TrimRight(v, "/") }

func newUUID() string {
	var b [16]byte
	_, _ = rand.Read(b[:])
	b[6] = b[6]&0x0f | 0x40
	b[8] = b[8]&0x3f | 0x80
	return fmt.Sprintf("%x-%x-%x-%x-%x", b[:4], b[4:6], b[6:8], b[8:10], b[10:])
}

func isoMillis(t time.Time) string { return t.UTC().Format("2006-01-02T15:04:05.000Z") }
func isoNow() string               { return isoMillis(time.Now()) }

// RequestError is a failed platform request.
type RequestError struct {
	Message     string
	Status      int
	SafeToRetry bool
}

func (e *RequestError) Error() string { return e.Message }

var (
	urlRedaction   = regexp.MustCompile(`(?i)https?://[^\s"'<>]+`)
	quotedSecret   = regexp.MustCompile(`(?i)\b(token|access_token|refresh_token|authorization)\b\s*[:=]\s*"[^"]*"`)
	unquotedSecret = regexp.MustCompile(`(?i)\b(token|access_token|refresh_token|authorization)\b\s*[:=]\s*[^,\s;"'}\]]+`)
)

// FetchJSON sends one request and returns the decoded JSON body (or the text
// when it is not JSON, nil when empty). A non-2xx answer is a *RequestError
// whose message quotes a redacted slice of the body.
func FetchJSON(ctx context.Context, client *http.Client, service, method, rawURL string, headers map[string]string, body []byte) (any, error) {
	ctx, cancel := context.WithTimeout(ctx, requestTimeout)
	defer cancel()
	var reader io.Reader
	if body != nil {
		reader = bytes.NewReader(body)
	}
	req, err := http.NewRequestWithContext(ctx, method, rawURL, reader)
	if err != nil {
		return nil, err
	}
	if body != nil {
		req.Header.Set("content-type", "application/json")
	}
	for k, v := range headers {
		req.Header.Set(k, v)
	}
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	raw, err := io.ReadAll(io.LimitReader(resp.Body, maxResponseBytes+1))
	if err != nil {
		return nil, err
	}
	if len(raw) > maxResponseBytes {
		return nil, fmt.Errorf("%s response exceeded %d bytes", service, maxResponseBytes)
	}
	var parsed any
	if len(raw) > 0 {
		if json.Unmarshal(raw, &parsed) != nil {
			parsed = string(raw)
		}
	}
	if resp.StatusCode < 200 || resp.StatusCode > 299 {
		detail := failureDetail(raw, parsed)
		if detail == "" {
			detail = http.StatusText(resp.StatusCode)
		}
		return nil, &RequestError{
			Message:     fmt.Sprintf("%s request failed (%d): %s", service, resp.StatusCode, detail),
			Status:      resp.StatusCode,
			SafeToRetry: resp.StatusCode == http.StatusTooManyRequests,
		}
	}
	return parsed, nil
}

func failureDetail(raw []byte, parsed any) string {
	var detail string
	switch p := parsed.(type) {
	case string:
		detail = p
	default:
		var compact bytes.Buffer
		if len(raw) == 0 || json.Compact(&compact, raw) != nil {
			compact.Reset()
			compact.WriteString(`""`)
		}
		detail = compact.String()
	}
	if r := []rune(detail); len(r) > 300 {
		detail = string(r[:300])
	}
	detail = urlRedaction.ReplaceAllString(detail, "[redacted-url]")
	detail = quotedSecret.ReplaceAllString(detail, "$1=[redacted]")
	return unquotedSecret.ReplaceAllString(detail, "$1=[redacted]")
}

// encodeURIComponent escapes like JavaScript's function of that name.
func encodeURIComponent(s string) string {
	var b strings.Builder
	for _, c := range []byte(s) {
		switch {
		case c >= 'A' && c <= 'Z', c >= 'a' && c <= 'z', c >= '0' && c <= '9',
			strings.IndexByte("-_.!~*'()", c) >= 0:
			b.WriteByte(c)
		default:
			fmt.Fprintf(&b, "%%%02X", c)
		}
	}
	return b.String()
}

var templateKey = regexp.MustCompile(`\{([a-zA-Z0-9_]+)\}`)

// buildURL fills {name} placeholders with percent-encoded values; unknown names
// become empty.
func buildURL(template string, values map[string]string) string {
	return templateKey.ReplaceAllStringFunc(template, func(m string) string {
		return encodeURIComponent(values[m[1:len(m)-1]])
	})
}

// parseHeaders reads a header map given as an object or a JSON object string.
func parseHeaders(v any) map[string]string {
	var m map[string]any
	switch v := v.(type) {
	case map[string]any:
		m = v
	case string:
		if json.Unmarshal([]byte(v), &m) != nil {
			return nil
		}
	}
	out := make(map[string]string, len(m))
	for k, val := range m {
		out[k] = text(val)
	}
	return out
}

// jsonPath is the dotted-path lookup of the generic webhook mapping. Missing
// segments and non-objects read as nil.
func jsonPath(input any, path string) any {
	if path == "" {
		return nil
	}
	current := input
	for _, part := range strings.Split(path, ".") {
		switch c := current.(type) {
		case map[string]any:
			current = c[part]
		case []any:
			i, err := strconv.Atoi(part)
			if err != nil || i < 0 || i >= len(c) {
				return nil
			}
			current = c[i]
		default:
			return nil
		}
	}
	return current
}

// firstTruthy is a chain of `||`.
func firstTruthy(values ...any) any {
	for _, v := range values {
		if truthy(v) {
			return v
		}
	}
	return nil
}

func safeEqual(a, b string) bool {
	if a == "" || b == "" {
		return false
	}
	size := max(len(a), len(b))
	pa, pb := make([]byte, size), make([]byte, size)
	copy(pa, a)
	copy(pb, b)
	return subtle.ConstantTimeCompare(pa, pb) == 1 && len(a) == len(b)
}

// InboundAllowed checks the shared secret of a webhook: a configured
// inboundSecret or webhookSecret, sent as x-neoagent-token, x-webhook-token or
// the body's "token".
func InboundAllowed(s Settings, headers http.Header, body any) bool {
	secret := strings.TrimSpace(s.Str("inboundSecret", "webhookSecret"))
	if secret == "" {
		return false
	}
	supplied := firstTruthy(
		nilIfEmpty(headers.Get("x-neoagent-token")),
		nilIfEmpty(headers.Get("x-webhook-token")),
		jsonPath(body, "token"),
	)
	return safeEqual(text(supplied), secret)
}

func nilIfEmpty(s string) any {
	if s == "" {
		return nil
	}
	return s
}

// ParseBody decodes a webhook's JSON body; anything else reads as an empty
// object, as Express's parser leaves req.body.
func ParseBody(body []byte) any {
	var v any
	if json.Unmarshal(body, &v) != nil {
		return map[string]any{}
	}
	if v == nil {
		return map[string]any{}
	}
	return v
}

func trimSpace(s string) string {
	return strings.TrimFunc(s, func(r rune) bool {
		return r == ' ' || r == '\t' || r == '\n' || r == '\r' || r == '\u00a0' || r == '\ufeff'
	})
}

// queryEscape is URLSearchParams' encoding of one value.
func queryEscape(s string) string { return neturl.QueryEscape(s) }

func jsNum(v any) float64 {
	switch v := v.(type) {
	case float64:
		return v
	case string:
		f, _ := strconv.ParseFloat(strings.TrimSpace(v), 64)
		return f
	}
	return 0
}
