package socialreach

import (
	"context"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
)

const (
	defaultUA     = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
	fetchTimeout  = 20 * time.Second
	maxBodyBytes  = 2 * 1024 * 1024
	defaultAccept = "text/plain,text/html,application/xml,application/rss+xml,application/atom+xml,*/*"
)

// reachError is a failure with the HTTP status the route answers with.
type reachError struct {
	Status  int
	Message string
}

func (e *reachError) Error() string { return e.Message }

func badRequest(message string) error { return &reachError{400, message} }

// fetcher reads public pages and APIs through an SSRF-safe client.
type fetcher struct{ client *http.Client }

type fetchOptions struct {
	headers map[string]string
	// strict marks fetches of addresses a user chose (feeds): an oversized
	// body is a 502 there.
	strict bool
}

func (f fetcher) text(ctx context.Context, rawURL string, o fetchOptions) (string, error) {
	ctx, cancel := context.WithTimeout(ctx, fetchTimeout)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, rawURL, nil)
	if err != nil {
		return "", err
	}
	req.Header.Set("User-Agent", defaultUA)
	req.Header.Set("Accept", defaultAccept)
	for k, v := range o.headers {
		req.Header.Set(k, v)
	}
	resp, err := f.client.Do(req)
	if err != nil {
		return "", f.wrap(ctx, err)
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(io.LimitReader(resp.Body, maxBodyBytes+1))
	if err != nil {
		return "", f.wrap(ctx, err)
	}
	if len(body) > maxBodyBytes {
		if o.strict {
			return "", &reachError{502, "Response exceeded the Social Reach safety limit."}
		}
		return "", &reachError{500, fmt.Sprintf("Social Reach response exceeded the %d-byte safety limit.", maxBodyBytes)}
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return "", &reachError{resp.StatusCode, fmt.Sprintf("Request failed with HTTP %d", resp.StatusCode)}
	}
	return string(body), nil
}

func (f fetcher) wrap(ctx context.Context, err error) error {
	if errors.Is(ctx.Err(), context.DeadlineExceeded) {
		return &reachError{500, fmt.Sprintf("Social Reach request timed out after %dms.", fetchTimeout.Milliseconds())}
	}
	return err
}

// json fetches and decodes a JSON document.
func (f fetcher) json(ctx context.Context, rawURL string, headers map[string]string) (any, error) {
	if headers == nil {
		headers = map[string]string{}
	}
	if _, set := headers["Accept"]; !set {
		headers["Accept"] = "application/json,*/*"
	}
	body, err := f.text(ctx, rawURL, fetchOptions{headers: headers})
	if err != nil {
		return nil, err
	}
	v, err := decode([]byte(body))
	if err != nil {
		return nil, &reachError{502, "Social Reach returned malformed JSON."}
	}
	return v, nil
}

// assertHTTPURL accepts what people paste: with or without the scheme.
func assertHTTPURL(value any) (*url.URL, error) {
	raw := jsTrim(str(value))
	if len(raw) < 7 || (!strings.EqualFold(raw[:7], "http://") && !(len(raw) >= 8 && strings.EqualFold(raw[:8], "https://"))) {
		raw = "https://" + raw
	}
	u, err := url.Parse(raw)
	if err != nil || u.Hostname() == "" {
		return nil, badRequest("A valid http or https URL is required.")
	}
	u.Scheme = strings.ToLower(u.Scheme)
	u.Host = strings.ToLower(u.Host)
	return u, nil
}

// assertAbsolute parses a URL that must already carry a scheme.
func assertAbsolute(raw string) (*url.URL, error) {
	u, err := url.Parse(raw)
	if err != nil || u.Scheme == "" || u.Hostname() == "" {
		return nil, errors.New("invalid url")
	}
	return u, nil
}
