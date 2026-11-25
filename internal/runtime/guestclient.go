package runtime

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"regexp"
	"strings"
	"time"
)

// GuestHealthTimeout is how long a computer that boots straight into its
// cached kernel gets to answer its health check.
const GuestHealthTimeout = 100 * time.Second

// GuestError is a failure the guest agent answered with.
type GuestError struct {
	Status  int
	Message string
	Code    string
}

func (e *GuestError) Error() string { return e.Message }

// RequestOptions bound one guest request.
type RequestOptions struct {
	Timeout          time.Duration
	MaxResponseBytes int64
	// Retries is the number of retries after a connection failure; nil means 6
	// for GET/HEAD/OPTIONS and 0 otherwise.
	Retries    *int
	RetryDelay time.Duration
	// WorkspaceRoot pins the workspace of a local computer.
	WorkspaceRoot string
}

// Retries returns a pointer for RequestOptions.Retries.
func Retries(n int) *int { return &n }

// GuestClient talks to the guest agent of one computer over loopback.
type GuestClient struct {
	BaseURL    string
	Token      string
	OnActivity func()
	HTTP       *http.Client
}

// NewGuestClient creates a client for the agent at baseURL.
func NewGuestClient(baseURL, token string, onActivity func()) *GuestClient {
	return &GuestClient{
		BaseURL:    strings.TrimRight(baseURL, "/"),
		Token:      strings.TrimSpace(token),
		OnActivity: onActivity,
		// The agent is on loopback; never follow a proxy setting there.
		HTTP: &http.Client{Transport: &http.Transport{Proxy: nil, MaxIdleConnsPerHost: 4}},
	}
}

var retryableTransport = regexp.MustCompile(`(?i)fetch failed|ECONNREFUSED|ECONNRESET|socket hang up|timed out|connection refused|connection reset|EOF|timeout`)

// Request sends a JSON request and returns the JSON answer with its key order
// intact, so it can be forwarded as the guest wrote it. A non-JSON answer
// comes back as {"text": body}, like the Node client.
func (c *GuestClient) Request(ctx context.Context, method, path string, body any, o RequestOptions) (*Object, error) {
	method = strings.ToUpper(method)
	if method == "" {
		method = http.MethodGet
	}
	retries := 0
	if method == http.MethodGet || method == http.MethodHead || method == http.MethodOptions {
		retries = 6
	}
	if o.Retries != nil {
		retries = max(0, *o.Retries)
	}
	delay := max(100*time.Millisecond, o.RetryDelay)
	if o.RetryDelay == 0 {
		delay = time.Second
	}
	var payload []byte
	if body != nil {
		var err error
		if payload, err = json.Marshal(body); err != nil {
			return nil, err
		}
	}
	var lastErr error
	for attempt := 0; attempt <= retries; attempt++ {
		if err := ctx.Err(); err != nil {
			return nil, err
		}
		var reader io.Reader
		if payload != nil {
			reader = bytes.NewReader(payload)
		}
		out, err := c.do(ctx, method, path, reader, map[string]string{"content-type": "application/json"}, o, 30*time.Second, 32<<20, "Guest runtime")
		if err == nil {
			if c.OnActivity != nil {
				c.OnActivity()
			}
			return out, nil
		}
		if ctx.Err() != nil {
			return nil, ctx.Err()
		}
		lastErr = err
		var guestErr *GuestError
		if errors.As(err, &guestErr) || !retryableTransport.MatchString(err.Error()) || attempt == retries {
			return nil, err
		}
		if err := sleepCtx(ctx, delay); err != nil {
			return nil, err
		}
	}
	if lastErr == nil {
		lastErr = errors.New("Runtime request failed.")
	}
	return nil, lastErr
}

// RequestStream uploads body (for example a workspace archive) without retries.
func (c *GuestClient) RequestStream(ctx context.Context, method, path string, body io.Reader, contentType string, contentLength int64, headers map[string]string, o RequestOptions) (*Object, error) {
	h := map[string]string{}
	for k, v := range headers {
		h[k] = v
	}
	if contentType != "" {
		h["content-type"] = contentType
	}
	req, err := c.newRequest(ctx, method, path, body, h)
	if err != nil {
		return nil, err
	}
	if contentLength >= 0 {
		req.ContentLength = contentLength
	}
	out, err := c.send(req, o, 60*time.Second, 2<<20, "Guest runtime upload")
	if err == nil && c.OnActivity != nil {
		c.OnActivity()
	}
	return out, err
}

func (c *GuestClient) newRequest(ctx context.Context, method, path string, body io.Reader, headers map[string]string) (*http.Request, error) {
	req, err := http.NewRequestWithContext(ctx, method, c.BaseURL+path, body)
	if err != nil {
		return nil, err
	}
	for k, v := range headers {
		req.Header.Set(k, v)
	}
	if c.Token != "" {
		req.Header.Set("Authorization", "Bearer "+c.Token)
	}
	return req, nil
}

func (c *GuestClient) do(ctx context.Context, method, path string, body io.Reader, headers map[string]string, o RequestOptions, defTimeout time.Duration, defMax int64, service string) (*Object, error) {
	req, err := c.newRequest(ctx, method, path, body, headers)
	if err != nil {
		return nil, err
	}
	return c.send(req, o, defTimeout, defMax, service)
}

func (c *GuestClient) send(req *http.Request, o RequestOptions, defTimeout time.Duration, defMax int64, service string) (*Object, error) {
	timeout := o.Timeout
	if timeout <= 0 {
		timeout = defTimeout
	}
	limit := o.MaxResponseBytes
	if limit <= 0 {
		limit = defMax
	}
	ctx, cancel := context.WithTimeout(req.Context(), timeout)
	defer cancel()
	resp, err := c.HTTP.Do(req.WithContext(ctx))
	if err != nil {
		if ctx.Err() == context.DeadlineExceeded && req.Context().Err() == nil {
			return nil, &CodedError{Message: fmt.Sprintf("%s request timed out after %dms.", service, timeout.Milliseconds()), Code: "RUNTIME_HTTP_TIMEOUT"}
		}
		return nil, err
	}
	defer resp.Body.Close()
	raw, err := io.ReadAll(io.LimitReader(resp.Body, limit+1))
	if err != nil {
		return nil, err
	}
	if int64(len(raw)) > limit {
		return nil, &CodedError{Message: fmt.Sprintf("%s response exceeded %d bytes.", service, limit), Code: "RUNTIME_HTTP_RESPONSE_TOO_LARGE"}
	}
	payload := obj("text", string(raw))
	if strings.Contains(resp.Header.Get("Content-Type"), "application/json") {
		payload = newOmap()
		_ = json.Unmarshal(raw, payload)
	}
	if resp.StatusCode < 200 || resp.StatusCode > 299 {
		message := payload.String("error")
		if message == "" {
			message = payload.String("text")
		}
		if message == "" {
			message = fmt.Sprintf("Runtime request failed: %d", resp.StatusCode)
		}
		return nil, &GuestError{Status: resp.StatusCode, Message: message, Code: payload.String("code")}
	}
	return payload, nil
}

// WaitForHealth polls /health until the agent answers or timeout passes.
// alive reports whether the guest is still running.
func (c *GuestClient) WaitForHealth(ctx context.Context, timeout time.Duration, alive func() bool) (*Object, error) {
	if timeout <= 0 {
		timeout = GuestHealthTimeout
	}
	deadline := time.Now().Add(timeout)
	var lastErr error
	for time.Now().Before(deadline) {
		if err := ctx.Err(); err != nil {
			return nil, err
		}
		if alive != nil && !alive() {
			return nil, errors.New("Guest runtime process exited unexpectedly during bootstrap.")
		}
		health, err := c.Request(ctx, http.MethodGet, "/health", nil, RequestOptions{Timeout: 2 * time.Second, Retries: Retries(0)})
		if err == nil {
			status := health.String("status")
			if health.String("runtime") == "guest-agent" || status == "ok" || status == "starting" {
				return health, nil
			}
			lastErr = errors.New("Guest agent health check returned a non-ok status.")
		} else {
			lastErr = err
		}
		if err := sleepCtx(ctx, time.Second); err != nil {
			return nil, err
		}
	}
	if lastErr != nil {
		return nil, fmt.Errorf("Timed out waiting for the guest runtime to become ready: %s", lastErr.Error())
	}
	return nil, errors.New("Timed out waiting for the guest runtime to become ready.")
}

func sleepCtx(ctx context.Context, d time.Duration) error {
	t := time.NewTimer(d)
	defer t.Stop()
	select {
	case <-ctx.Done():
		return ctx.Err()
	case <-t.C:
		return nil
	}
}
