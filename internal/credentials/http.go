package credentials

import (
	"context"
	"encoding/base64"
	"errors"
	"fmt"
	"math"
	"strings"
	"time"
)

// Request is an HTTP request for the Requester.
type Request struct {
	Method  string
	URL     string
	Headers map[string]string
	// Body is nil when the request has none.
	Body             *string
	Timeout          time.Duration
	MaxResponseBytes int
}

// Response is what the Requester got back. Headers are already stripped of
// cookies and challenges.
type Response struct {
	Status    int
	Headers   map[string]string
	Body      string
	Truncated bool
}

// Requester sends requests to public addresses only
// (services/network/safe_request.js executeSafeHttpRequest).
type Requester interface {
	Do(ctx context.Context, req Request) (Response, error)
}

// HTTPResult is what a bound request returns to the model.
type HTTPResult struct {
	Status    int               `json:"status"`
	Headers   map[string]string `json:"headers"`
	Body      string            `json:"body"`
	Truncated bool              `json:"truncated"`
}

// HTTPRequest sends a request with the binding's authentication added. The
// request must match the binding's origin, path prefix and methods.
func (b *Broker) HTTPRequest(ctx context.Context, userID int64, agentID string, input map[string]any, rc RunContext) (*HTTPResult, error) {
	sc, err := b.scope(ctx, userID, agentID)
	if err != nil {
		return nil, err
	}
	r, err := b.bindingRow(ctx, sc, jsString(input["binding_id"]))
	if err != nil {
		return nil, err
	}
	bd, err := b.decode(r)
	if err != nil {
		return nil, err
	}
	if bd == nil || bd.usageType != "http" {
		return nil, errors.New("HTTP credential binding not found.")
	}
	method := "GET"
	if truthy(input["method"]) {
		method = strings.ToUpper(jsString(input["method"]))
	}
	rawURL, err := requireText(input["url"], "Request URL")
	if err != nil {
		return nil, err
	}
	// The encoded-byte check looks at the address as written, before the
	// parser resolves any dot segments.
	u, err := parseURL(rawURL)
	if err != nil {
		return nil, err
	}
	target := bd.targetConfig
	if u.Scheme != "https" || encodedPathBytes.MatchString(beforeQuery(rawURL)) ||
		origin(u) != target.Origin || !pathMatchesPrefix(pathname(u), target.PathPrefix) || !contains(target.Methods, method) {
		return nil, errors.New("Credential request does not match the binding target policy.")
	}

	headers := map[string]string{}
	if h := object(input["headers"]); h != nil {
		for name, value := range h {
			headers[name] = jsString(value)
		}
	}
	blocked := map[string]bool{"authorization": true, "cookie": true, strings.ToLower(target.HeaderName): true}
	for name := range headers {
		if blocked[strings.ToLower(name)] {
			return nil, errors.New("Authentication and cookie headers are controlled by the credential binding.")
		}
	}

	label := fmt.Sprintf("%s %s%s", method, origin(u), pathname(u))
	result, err := useItem(b, ctx, sc, bd, func(item Item) (*HTTPResult, error) {
		secret := readItemField(item, bd.fields.SecretField)
		username := ""
		if bd.fields.UsernameField != nil && *bd.fields.UsernameField != "" {
			username = readItemField(item, *bd.fields.UsernameField)
		}
		if secret == "" {
			return nil, errors.New("The bound Bitwarden secret is empty.")
		}
		switch target.AuthType {
		case "bearer":
			headers["Authorization"] = "Bearer " + secret
		case "basic":
			headers["Authorization"] = "Basic " + base64.StdEncoding.EncodeToString([]byte(username+":"+secret))
		case "header":
			headers[target.HeaderName] = secret
		}
		request := Request{
			Method: method, URL: u.String(), Headers: headers,
			Timeout: timeout(input["timeout_ms"]), MaxResponseBytes: maxResponseBytes,
		}
		if (method == "POST" || method == "PUT" || method == "PATCH") && !nullish(input["body"]) {
			body := jsString(input["body"])
			request.Body = &body
		}
		response, err := b.requester.Do(ctx, request)
		if err != nil {
			return nil, err
		}
		resolved := []string{secret, username, username + ":" + secret, "Bearer " + secret}
		if err := b.audit(ctx, sc, bd.id, "http_request", label, "success", nil, rc.RunID); err != nil {
			return nil, err
		}
		return &HTTPResult{
			Status:    response.Status,
			Headers:   safeResponseHeaders(response.Headers, resolved),
			Body:      redactResolvedValues(response.Body, resolved),
			Truncated: response.Truncated,
		}, nil
	})
	if err != nil {
		_ = b.audit(ctx, sc, bd.id, "http_request", label, "failed", err, rc.RunID)
		return nil, err
	}
	return result, nil
}

// beforeQuery is the address without its query and fragment.
func beforeQuery(raw string) string {
	if i := strings.IndexAny(raw, "?#"); i >= 0 {
		return raw[:i]
	}
	return raw
}

// timeout is Math.max(1000, Math.min(Number(v || 30000), 120000)) ms; a
// value that is not a number leaves the Requester's own default.
func timeout(v any) time.Duration {
	n := 30000.0
	if truthy(v) {
		n = toNumber(v)
	}
	if math.IsNaN(n) {
		return 0
	}
	return time.Duration(math.Max(1000, math.Min(n, 120000))) * time.Millisecond
}

// useItem syncs the vault, loads the bound item and runs work with it.
func useItem[T any](b *Broker, ctx context.Context, sc scope, bd *binding, work func(Item) (T, error)) (T, error) {
	var zero T
	if bd.providerKey != "bitwarden" {
		return zero, fmt.Errorf("Unsupported credential provider: %s", bd.providerKey)
	}
	if err := b.vault.Sync(ctx, sc.userID, sc.agentID); err != nil {
		return zero, err
	}
	item, err := b.vault.GetItem(ctx, sc.userID, sc.agentID, bd.itemRefPlain)
	if err != nil {
		return zero, err
	}
	return work(item)
}
