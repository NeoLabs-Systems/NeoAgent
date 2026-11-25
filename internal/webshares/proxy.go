package webshares

import (
	"bytes"
	"compress/flate"
	"compress/gzip"
	"context"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/httpx"
	"github.com/andybalholm/brotli"
)

// The public side of shared pages (web_shares/proxy.js): /<username>/<slug>/…
// is served from the port the share points at while the owner's computer
// runs. Anything that is not a live share falls through.

const (
	upstreamTimeout    = 60 * time.Second
	maxInjectedHTML    = 8 * 1024 * 1024
	shareRateWindow    = time.Minute
	shareRateLimit     = 600
	shareRateLimitBody = "Too many requests to this shared page; try again in a minute."
)

// SandboxPolicy gives a shared page an opaque origin of its own: it cannot
// read NeoAgent's cookies, storage or API.
const SandboxPolicy = "sandbox allow-scripts allow-forms allow-modals allow-popups " +
	"allow-popups-to-escape-sandbox allow-downloads allow-pointer-lock allow-presentation"

var (
	sharePath       = regexp.MustCompile(`(?i)^/([^/?#]+)/([a-z0-9-]{1,48})(/[^?#]*)?(\?.*)?$`)
	droppedRequest  = map[string]bool{"cookie": true, "authorization": true, "proxy-authorization": true, "host": true, "connection": true, "keep-alive": true, "te": true, "trailer": true, "transfer-encoding": true, "upgrade": true, "forwarded": true, "x-real-ip": true, "true-client-ip": true}
	droppedPrefixes = []string{"x-forwarded-", "cf-", "x-neoagent-"}
	droppedResponse = map[string]bool{"set-cookie": true, "clear-site-data": true, "strict-transport-security": true, "service-worker-allowed": true, "access-control-allow-credentials": true, "public-key-pins": true, "alt-svc": true, "x-neoagent-proxy": true, "connection": true, "keep-alive": true, "transfer-encoding": true, "trailer": true, "upgrade": true}
	localLocation   = regexp.MustCompile(`(?i)^https?://(?:localhost|127\.0\.0\.1|0\.0\.0\.0|\[::1\])(?::(\d+))?(/.*)?$`)
	htmlType        = regexp.MustCompile(`(?i)^text/html\b`)
)

// Proxy serves the shared pages.
type Proxy struct {
	Store  *Store
	Guests Guests
	// PublicURL is PUBLIC_URL, "" when unset.
	PublicURL  string
	TrustProxy bool
	Transport  http.RoundTripper
	Now        func() time.Time

	mu   sync.Mutex
	hits map[string]*window
}

type window struct {
	count int
	reset time.Time
}

// Wrap puts the proxy in front of the server's own handler.
func (p *Proxy) Wrap(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !p.serve(w, r) {
			next.ServeHTTP(w, r)
		}
	})
}

// rewriteLocation keeps a redirect to the app's own paths under the share.
func rewriteLocation(location, prefix string, port int64) string {
	if strings.HasPrefix(location, "/") && !strings.HasPrefix(location, "//") {
		return prefix + location
	}
	if m := localLocation.FindStringSubmatch(location); m != nil && (m[1] == "" || m[1] == strconv.FormatInt(port, 10)) {
		path := m[2]
		if path == "" {
			path = "/"
		}
		return prefix + path
	}
	return location
}

// hasDotSegment refuses "." and ".." segments, raw or encoded, which could
// step out of /proxy/<port> to the guest agent's own routes.
func hasDotSegment(pathname string) bool {
	for _, segment := range regexp.MustCompile(`[/\\]`).Split(pathname, -1) {
		decoded, err := url.PathUnescape(segment)
		if err != nil {
			return true
		}
		if decoded == "." || decoded == ".." || strings.ContainsAny(decoded, `/\`) {
			return true
		}
	}
	return false
}

func (p *Proxy) now() time.Time {
	if p.Now != nil {
		return p.Now()
	}
	return time.Now()
}

// limit is express-rate-limit with draft-7 headers: 600 requests a minute per
// client.
func (p *Proxy) limit(w http.ResponseWriter, r *http.Request) bool {
	key := httpx.ClientIP(r, p.TrustProxy)
	now := p.now()
	p.mu.Lock()
	if p.hits == nil {
		p.hits = map[string]*window{}
	}
	win := p.hits[key]
	if win == nil || !now.Before(win.reset) {
		win = &window{reset: now.Add(shareRateWindow)}
		p.hits[key] = win
		for k, v := range p.hits {
			if !now.Before(v.reset) {
				delete(p.hits, k)
			}
		}
	}
	win.count++
	count, reset := win.count, win.reset
	p.mu.Unlock()
	seconds := int((reset.Sub(now) + time.Second - 1) / time.Second)
	w.Header().Set("RateLimit-Policy", fmt.Sprintf("%d;w=%d", shareRateLimit, int(shareRateWindow.Seconds())))
	w.Header().Set("RateLimit", fmt.Sprintf("limit=%d, remaining=%d, reset=%d", shareRateLimit, max(0, shareRateLimit-count), seconds))
	if count > shareRateLimit {
		w.Header().Set("Retry-After", strconv.Itoa(seconds))
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		w.WriteHeader(http.StatusTooManyRequests)
		_, _ = io.WriteString(w, shareRateLimitBody)
		return false
	}
	return true
}

func sendOffline(w http.ResponseWriter, s *publicShare) {
	h := w.Header()
	h.Set("Content-Type", "text/html; charset=utf-8")
	h.Set("Cache-Control", "no-store")
	h.Set("Retry-After", "30")
	h.Set("Content-Security-Policy", "default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'")
	h.Set("X-Robots-Tag", "noindex, nofollow")
	w.WriteHeader(http.StatusServiceUnavailable)
	title := s.title
	if title == "" {
		title = s.slug
	}
	_, _ = io.WriteString(w, offlinePage(s.username, title))
}

// serve answers a request for a live share; false hands it on.
func (p *Proxy) serve(w http.ResponseWriter, r *http.Request) bool {
	m := sharePath.FindStringSubmatch(r.RequestURI)
	if m == nil {
		return false
	}
	share, err := p.Store.findPublic(r.Context(), m[1], m[2])
	if err != nil || share == nil {
		return false
	}
	prefix := "/" + m[1] + "/" + share.slug
	rest, query := m[3], m[4]
	if rest == "" {
		expressRedirect(w, r, http.StatusPermanentRedirect, prefix+"/"+query)
		return true
	}
	if hasDotSegment(rest) {
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		w.WriteHeader(http.StatusBadRequest)
		_, _ = io.WriteString(w, "Bad request.")
		return true
	}
	if !p.limit(w, r) {
		return true
	}
	secure := r.TLS != nil || strings.HasPrefix(strings.ToLower(p.PublicURL), "https:")
	if r.Method == http.MethodGet && rest == hideNoticePath {
		back, _ := url.ParseQuery(strings.TrimPrefix(query, "?"))
		target := back.Get("back")
		if !strings.HasPrefix(target, prefix+"/") || strings.Contains(target, "//") {
			target = prefix + "/"
		}
		cookie := noticeCookie + "=hidden; Path=/; Max-Age=31536000; SameSite=Lax; HttpOnly"
		if secure {
			cookie += "; Secure"
		}
		w.Header().Set("Set-Cookie", cookie)
		w.Header().Set("Cache-Control", "no-store")
		expressRedirect(w, r, http.StatusSeeOther, target)
		return true
	}
	base, token, ok := "", "", false
	if p.Guests != nil {
		base, token, ok = p.Guests.RunningGuest(userKey(share.userID))
	}
	if !ok {
		sendOffline(w, share)
		return true
	}
	p.forward(w, r, share, base, token, prefix, rest, query)
	return true
}

func (p *Proxy) forwardedHeaders(r *http.Request, prefix, token string) http.Header {
	out := http.Header{}
	for name, values := range r.Header {
		lower := strings.ToLower(name)
		if droppedRequest[lower] {
			continue
		}
		skip := false
		for _, pre := range droppedPrefixes {
			if strings.HasPrefix(lower, pre) {
				skip = true
			}
		}
		if !skip {
			out[name] = values
		}
	}
	proto, host := "http", r.Host
	if r.TLS != nil {
		proto = "https"
	}
	if u, err := url.Parse(p.PublicURL); err == nil && p.PublicURL != "" {
		proto, host = u.Scheme, u.Host
	}
	out.Set("Authorization", "Bearer "+token)
	out.Set("X-Forwarded-Proto", proto)
	out.Set("X-Forwarded-Host", host)
	out.Set("X-Forwarded-Prefix", prefix)
	return out
}

func responseHeaders(upstream http.Header, prefix string, port int64) http.Header {
	out := http.Header{}
	for name, values := range upstream {
		lower := strings.ToLower(name)
		if droppedResponse[lower] {
			continue
		}
		if lower == "location" {
			rewritten := make([]string, len(values))
			for i, v := range values {
				rewritten[i] = rewriteLocation(v, prefix, port)
			}
			values = rewritten
		}
		out[name] = values
	}
	out["Content-Security-Policy"] = append(out.Values("Content-Security-Policy"), SandboxPolicy)
	out.Set("X-Content-Type-Options", "nosniff")
	out.Set("X-Robots-Tag", "noindex, nofollow")
	return out
}

func wantsNotice(r *http.Request, resp *http.Response) bool {
	if r.Method != http.MethodGet || resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return false
	}
	if !htmlType.MatchString(resp.Header.Get("Content-Type")) || noticeHidden(r.Header.Get("Cookie")) {
		return false
	}
	if dest := r.Header.Get("Sec-Fetch-Dest"); dest != "" {
		return dest == "document"
	}
	return r.Header.Get("X-Requested-With") == "" && r.Header.Get("Hx-Request") == ""
}

// decoder reads a body in its content encoding; ok=false for one it cannot.
func decoder(encoding string, body io.Reader) (io.Reader, bool) {
	switch strings.ToLower(strings.TrimSpace(encoding)) {
	case "", "identity":
		return body, true
	case "gzip", "x-gzip":
		zr, err := gzip.NewReader(body)
		if err != nil {
			return nil, false
		}
		return zr, true
	case "deflate":
		return flate.NewReader(body), true
	case "br":
		return brotli.NewReader(body), true
	}
	return nil, false
}

func copyHeaders(w http.ResponseWriter, h http.Header) {
	for k, v := range h {
		w.Header()[k] = v
	}
}

func (p *Proxy) forward(w http.ResponseWriter, r *http.Request, share *publicShare, base, token, prefix, rest, query string) {
	target, err := url.Parse(strings.TrimRight(base, "/"))
	if err != nil {
		sendOffline(w, share)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), upstreamTimeout)
	defer cancel()
	// Built by hand: the path keeps its encoding and is never cleaned.
	target.Opaque = "//" + target.Host + "/proxy/" + strconv.FormatInt(share.port, 10) + rest
	target.RawQuery = strings.TrimPrefix(query, "?")
	req, err := http.NewRequestWithContext(ctx, r.Method, target.String(), r.Body)
	if err != nil {
		sendOffline(w, share)
		return
	}
	req.URL = target
	req.Header = p.forwardedHeaders(r, prefix, token)
	req.ContentLength = r.ContentLength
	transport := p.Transport
	if transport == nil {
		transport = http.DefaultTransport
	}
	resp, err := transport.RoundTrip(req)
	if err != nil {
		sendOffline(w, share)
		return
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusBadGateway && resp.Header.Get("X-Neoagent-Proxy") != "" {
		sendOffline(w, share)
		return
	}
	headers := responseHeaders(resp.Header, prefix, share.port)
	if wantsNotice(r, resp) {
		if body, ok := decoder(resp.Header.Get("Content-Encoding"), resp.Body); ok {
			p.relayWithNotice(w, resp, headers, body, noticeMarkup(share.username, prefix, prefix+rest+query))
			return
		}
	}
	copyHeaders(w, headers)
	w.WriteHeader(resp.StatusCode)
	_, _ = io.Copy(w, resp.Body)
}

func (p *Proxy) relayWithNotice(w http.ResponseWriter, resp *http.Response, headers http.Header, body io.Reader, notice string) {
	var buf bytes.Buffer
	n, err := io.CopyN(&buf, body, maxInjectedHTML+1)
	if err != nil && err != io.EOF {
		w.WriteHeader(http.StatusBadGateway)
		return
	}
	if n > maxInjectedHTML {
		// A page this large is relayed as it is rather than held in memory.
		headers.Del("Content-Length")
		headers.Del("Content-Encoding")
		copyHeaders(w, headers)
		w.WriteHeader(resp.StatusCode)
		_, _ = w.Write(buf.Bytes())
		_, _ = io.Copy(w, body)
		return
	}
	html := injectNotice(buf.String(), notice)
	for _, name := range []string{"Content-Length", "Content-Encoding", "Etag", "Last-Modified"} {
		headers.Del(name)
	}
	headers.Set("Vary", strings.Join(append(headers.Values("Vary"), "Cookie"), ", "))
	copyHeaders(w, headers)
	w.WriteHeader(resp.StatusCode)
	_, _ = io.WriteString(w, html)
}

// expressRedirect answers as Express 5's res.redirect: a text or HTML note by
// the Accept header, with Vary: Accept.
func expressRedirect(w http.ResponseWriter, r *http.Request, status int, location string) {
	h := w.Header()
	h.Set("Location", location)
	h.Add("Vary", "Accept")
	accept := strings.ToLower(r.Header.Get("Accept"))
	message := http.StatusText(status) + ". Redirecting to "
	var body string
	if strings.Contains(accept, "text/html") && !strings.Contains(accept, "text/plain") {
		h.Set("Content-Type", "text/html; charset=utf-8")
		body = "<p>" + message + escapeHTML(location) + "</p>"
	} else {
		h.Set("Content-Type", "text/plain; charset=utf-8")
		body = message + location
	}
	w.WriteHeader(status)
	if r.Method != http.MethodHead {
		_, _ = io.WriteString(w, body)
	}
}
