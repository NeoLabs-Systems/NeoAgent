package handlers

import (
	"context"
	"crypto/tls"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/netip"
	"net/url"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/cloudsec"
)

// The http_request tool (services/network/safe_request.js): one request to a
// public http(s) address, redirects followed by hand so every hop is checked,
// the body cut at a safety limit.

const (
	httpDefaultTimeout   = 30 * time.Second
	httpMaxTimeout       = 120 * time.Second
	httpMaxResponseBytes = 512 * 1024
	httpMaxRedirects     = 5
)

var (
	httpAllowedMethods = map[string]bool{"GET": true, "POST": true, "PUT": true, "DELETE": true, "PATCH": true}
	httpRedirects      = map[int]bool{301: true, 302: true, 303: true, 307: true, 308: true}
	httpSensitive      = []string{"authorization", "cookie", "proxy-authorization"}
	httpHiddenResponse = map[string]bool{"proxy-authenticate": true, "set-cookie": true, "www-authenticate": true}
)

// HTTPRequester runs http_request. LookupHost resolves names (net.DefaultResolver
// when nil); AllowPrivate lifts the private-address refusal
// (NEOAGENT_HTTP_ALLOW_PRIVATE=true).
type HTTPRequester struct {
	UserAgent    string
	AllowPrivate bool
	LookupHost   func(ctx context.Context, host string) ([]netip.Addr, error)
	// Transport replaces the dialing transport in tests.
	Transport http.RoundTripper
	// MaxResponseBytes overrides the 512 KiB limit when positive.
	MaxResponseBytes int
}

// errRequest is a refusal the tool reports as {error}.
type errRequest struct{ msg string }

func (e errRequest) Error() string { return e.msg }

func requestErr(format string, a ...any) error { return errRequest{fmt.Sprintf(format, a...)} }

// normalizeHeaders lowercases names and drops hop-by-hop ones.
func normalizeHeaders(value any) map[string][]string {
	out := map[string][]string{}
	m, ok := value.(dyn.Map)
	if !ok {
		return out
	}
	for raw, v := range m {
		name := strings.ToLower(strings.TrimSpace(raw))
		if name == "" || v == nil || name == "host" || name == "connection" || name == "transfer-encoding" {
			continue
		}
		if list, ok := v.([]any); ok {
			vals := make([]string, len(list))
			for i, item := range list {
				vals[i] = dyn.String(item)
			}
			out[name] = vals
			continue
		}
		out[name] = []string{dyn.String(v)}
	}
	return out
}

func parseHTTPURL(value string) (*url.URL, error) {
	trimmed := strings.TrimSpace(value)
	parsed, err := url.Parse(trimmed)
	if err != nil || parsed.Scheme == "" || (parsed.Host == "" && parsed.Opaque == "") {
		return nil, requestErr(`"%s" is not a valid URL. Use a full http(s) URL such as https://example.com/path.`, value)
	}
	parsed.Scheme = strings.ToLower(parsed.Scheme)
	if parsed.Scheme != "http" && parsed.Scheme != "https" {
		return nil, requestErr("URL scheme not allowed. Only http and https are permitted.")
	}
	if parsed.User != nil {
		return nil, requestErr("Credentials in request URLs are not permitted. Use headers instead.")
	}
	parsed.Host = strings.ToLower(parsed.Host)
	if parsed.Path == "" {
		parsed.Path = "/"
	}
	return parsed, nil
}

func (h *HTTPRequester) resolve(ctx context.Context, u *url.URL) (netip.Addr, error) {
	host := strings.Trim(u.Hostname(), "[]")
	if !h.AllowPrivate && cloudsec.IsPrivateHost(host) {
		return netip.Addr{}, requestErr("%s is a private, loopback, or reserved network address, which is not permitted.", host)
	}
	if addr, err := netip.ParseAddr(host); err == nil {
		return addr, nil
	}
	lookup := h.LookupHost
	if lookup == nil {
		lookup = func(ctx context.Context, host string) ([]netip.Addr, error) {
			return net.DefaultResolver.LookupNetIP(ctx, "ip", host)
		}
	}
	addrs, err := lookup(ctx, host)
	if err != nil {
		if ctx.Err() != nil {
			return netip.Addr{}, ctx.Err()
		}
		return netip.Addr{}, requestErr("Could not resolve %s: %s", host, err.Error())
	}
	if len(addrs) == 0 {
		return netip.Addr{}, requestErr("Could not resolve %s.", host)
	}
	if !h.AllowPrivate {
		for _, a := range addrs {
			if cloudsec.IsPrivateHost(a.Unmap().String()) {
				return netip.Addr{}, requestErr("%s resolves to a private, loopback, or reserved address, which is not permitted.", host)
			}
		}
	}
	return addrs[0].Unmap(), nil
}

type httpResponse struct {
	status    int
	headers   http.Header
	body      string
	truncated bool
}

func (h *HTTPRequester) once(ctx context.Context, u *url.URL, addr netip.Addr, method string, headers map[string][]string, body *string) (httpResponse, error) {
	transport := h.Transport
	if transport == nil {
		port := u.Port()
		if port == "" {
			port = map[string]string{"http": "80", "https": "443"}[u.Scheme]
		}
		target := net.JoinHostPort(addr.String(), port)
		dialer := &net.Dialer{Timeout: 30 * time.Second}
		transport = &http.Transport{
			DialContext: func(ctx context.Context, network, _ string) (net.Conn, error) {
				return dialer.DialContext(ctx, network, target)
			},
			TLSClientConfig:        &tls.Config{ServerName: strings.Trim(u.Hostname(), "[]"), MinVersion: tls.VersionTLS12},
			MaxResponseHeaderBytes: 32 * 1024,
			DisableKeepAlives:      true,
		}
	}
	var reader io.Reader
	if body != nil {
		reader = strings.NewReader(*body)
	}
	req, err := http.NewRequestWithContext(ctx, method, u.String(), reader)
	if err != nil {
		return httpResponse{}, err
	}
	for name, vals := range headers {
		if name == "content-length" {
			continue
		}
		for _, v := range vals {
			req.Header.Add(name, v)
		}
	}
	if body == nil {
		req.ContentLength = 0
	}
	client := &http.Client{Transport: transport, CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }}
	resp, err := client.Do(req)
	if err != nil {
		return httpResponse{}, err
	}
	defer resp.Body.Close()
	if httpRedirects[resp.StatusCode] && resp.Header.Get("Location") != "" {
		return httpResponse{status: resp.StatusCode, headers: resp.Header}, nil
	}
	limit := httpMaxResponseBytes
	if h.MaxResponseBytes > 0 {
		limit = h.MaxResponseBytes
	}
	data, err := io.ReadAll(io.LimitReader(resp.Body, int64(limit)+1))
	if err != nil {
		return httpResponse{}, err
	}
	truncated := len(data) > limit
	if truncated {
		data = data[:limit]
	}
	return httpResponse{status: resp.StatusCode, headers: resp.Header, body: strings.ToValidUTF8(string(data), "�"), truncated: truncated}, nil
}

func sanitizeResponseHeaders(headers http.Header) dyn.Map {
	out := dyn.Map{}
	for name, vals := range headers {
		lower := strings.ToLower(name)
		if lower == "" || httpHiddenResponse[lower] {
			continue
		}
		out[lower] = strings.Join(vals, ", ")
	}
	return out
}

// Do runs one http_request call. A refusal or network failure is an error
// whose message the tool reports; cancellation returns the context's error.
func (h *HTTPRequester) Do(ctx context.Context, args dyn.Map) (dyn.Map, error) {
	method := strings.ToUpper(strings.TrimSpace(dyn.Str(args["method"])))
	if method == "" {
		method = "GET"
	}
	if !httpAllowedMethods[method] {
		return nil, requestErr("Unsupported HTTP method: %s", method)
	}
	timeout := httpDefaultTimeout
	if ms, ok := dyn.Float(args["timeout_ms"]); ok && ms != 0 {
		timeout = time.Duration(ms) * time.Millisecond
	}
	timeout = min(max(timeout, 100*time.Millisecond), httpMaxTimeout)
	current, err := parseHTTPURL(dyn.Str(args["url"]))
	if err != nil {
		return nil, err
	}
	headers := normalizeHeaders(args["headers"])
	var body *string
	if args["body"] != nil && method != "GET" && method != "DELETE" {
		b := dyn.String(args["body"])
		body = &b
		if _, ok := headers["content-type"]; !ok {
			headers["content-type"] = []string{"application/json"}
		}
	}
	if _, ok := headers["user-agent"]; !ok {
		headers["user-agent"] = []string{h.UserAgent}
	}
	reqCtx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()
	redirects := []any{}
	for count := 0; count <= httpMaxRedirects; count++ {
		addr, err := h.resolve(reqCtx, current)
		if err == nil {
			var resp httpResponse
			resp, err = h.once(reqCtx, current, addr, method, headers, body)
			if err == nil {
				location := resp.headers.Get("Location")
				if !httpRedirects[resp.status] || location == "" {
					text := resp.body
					if resp.truncated {
						text += "\n...[truncated at response safety limit]"
					}
					return dyn.Map{
						"status":    float64(resp.status),
						"headers":   sanitizeResponseHeaders(resp.headers),
						"body":      text,
						"finalUrl":  current.String(),
						"redirects": redirects,
						"truncated": resp.truncated,
					}, nil
				}
				if count >= httpMaxRedirects {
					return nil, requestErr("Request exceeded the %d-redirect limit.", httpMaxRedirects)
				}
				ref, perr := current.Parse(location)
				if perr != nil {
					return nil, requestErr(`"%s" is not a valid URL. Use a full http(s) URL such as https://example.com/path.`, location)
				}
				next, perr := parseHTTPURL(ref.String())
				if perr != nil {
					return nil, perr
				}
				redirects = append(redirects, next.String())
				method, headers, body = redirected(current, next, method, headers, body, resp.status)
				current = next
				continue
			}
		}
		if ctx.Err() != nil {
			return nil, ctx.Err()
		}
		if errors.Is(reqCtx.Err(), context.DeadlineExceeded) {
			return nil, requestErr("Request timed out after %dms.", timeout.Milliseconds())
		}
		return nil, err
	}
	return nil, requestErr("Request exceeded the %d-redirect limit.", httpMaxRedirects)
}

func redirected(prev, next *url.URL, method string, headers map[string][]string, body *string, status int) (string, map[string][]string, *string) {
	out := make(map[string][]string, len(headers))
	for k, v := range headers {
		out[k] = v
	}
	if status == 303 || ((status == 301 || status == 302) && method == "POST") {
		method, body = "GET", nil
		delete(out, "content-length")
		delete(out, "content-type")
	}
	if prev.Scheme != next.Scheme || prev.Host != next.Host {
		for _, name := range httpSensitive {
			delete(out, name)
		}
	}
	return method, out, body
}
