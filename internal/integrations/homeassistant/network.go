package homeassistant

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"net/http"
	"net/netip"
	"net/url"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/cloudsec"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neolabs-go/oauthclient"
)

// text is trimText: the trimmed String of a truthy value, else "".
func text(v any) string {
	if !integrations.Truthy(v) {
		return ""
	}
	return strings.TrimSpace(integrations.Str(v))
}

func requireText(v any, label string) (string, error) {
	t := text(v)
	if t == "" {
		return "", fmt.Errorf("%s is required.", label)
	}
	return t, nil
}

// normalizeBaseURL accepts only an HTTPS origin on port 443 or 8123, without
// credentials, query or fragment, and returns it without a trailing slash.
func normalizeBaseURL(value any) (string, error) {
	raw, err := requireText(value, "Home Assistant URL")
	if err != nil {
		return "", err
	}
	u, err := url.Parse(raw)
	if err != nil || u.Scheme == "" || u.Host == "" {
		return "", errors.New("Home Assistant URL must be a valid absolute HTTPS URL.")
	}
	if strings.ToLower(u.Scheme) != "https" {
		return "", errors.New("Home Assistant URL must use HTTPS.")
	}
	if u.User != nil {
		return "", errors.New("Home Assistant URL must not include credentials.")
	}
	port := u.Port()
	if port == "443" {
		port = ""
	}
	if port != "" && port != "8123" {
		return "", errors.New("Home Assistant URL must use port 443 or 8123.")
	}
	host := strings.ToLower(u.Hostname())
	if strings.Contains(host, ":") {
		host = "[" + host + "]"
	}
	if port != "" {
		host += ":" + port
	}
	path := strings.TrimRight(u.EscapedPath(), "/")
	return "https://" + host + path, nil
}

// hostOf is the bare host name or address of a normalised base URL.
func hostOf(baseURL string) string {
	u, _ := url.Parse(baseURL)
	return strings.Trim(u.Hostname(), "[]")
}

func blockedAddr(addr netip.Addr) bool { return cloudsec.IsPrivateHost(addr.Unmap().String()) }

// assertPublicEndpoint refuses a host that is, or resolves to, a private,
// loopback or reserved address.
func (p *provider) assertPublicEndpoint(ctx context.Context, baseURL string) error {
	host := hostOf(baseURL)
	if addr, err := netip.ParseAddr(host); err == nil && blockedAddr(addr) {
		return errors.New("Home Assistant URL must not point to a private, loopback, or link-local address.")
	}
	addrs, err := p.lookup(ctx, host)
	if err != nil {
		msg := err.Error()
		var dnsErr *net.DNSError
		if errors.As(err, &dnsErr) {
			msg = "getaddrinfo ENOTFOUND " + host
		}
		return fmt.Errorf("Could not resolve Home Assistant host: %s", msg)
	}
	if len(addrs) == 0 {
		return errors.New("Could not resolve Home Assistant host.")
	}
	for _, a := range addrs {
		if blockedAddr(a) {
			return errors.New("Home Assistant URL resolves to a private, loopback, or reserved address.")
		}
	}
	return nil
}

// buildURL resolves path on the instance and keeps it under /api/.
func buildURL(baseURL, path string, query map[string]any) (string, error) {
	base, err := url.Parse(baseURL)
	if err != nil {
		return "", err
	}
	ref, err := url.Parse(path)
	if err != nil {
		return "", errors.New("Home Assistant API path must stay on the connected origin and start with /api/.")
	}
	target := base.ResolveReference(ref)
	if target.Scheme != base.Scheme || target.Host != base.Host || !strings.HasPrefix(target.EscapedPath(), "/api/") {
		return "", errors.New("Home Assistant API path must stay on the connected origin and start with /api/.")
	}
	target.Fragment = ""
	var params oauthclient.Query
	for _, k := range integrations.SortedKeys(query) {
		v := query[k]
		if v == nil {
			continue
		}
		if s := strings.TrimSpace(integrations.Str(v)); s != "" {
			params = append(params, [2]string{k, s})
		}
	}
	if len(params) == 0 {
		return target.String(), nil
	}
	return oauthclient.SetParams(target.String(), params)
}

type credentials struct {
	BaseURL string
	Token   string
}

type requestOptions struct {
	method string
	path   string
	query  map[string]any
	body   any
}

var methods = map[string]bool{"GET": true, "POST": true, "PUT": true, "PATCH": true, "DELETE": true}

// request calls the instance's REST API; redirects are not followed.
func (p *provider) request(ctx context.Context, c credentials, o requestOptions) (any, error) {
	baseURL, err := normalizeBaseURL(c.BaseURL)
	if err != nil {
		return nil, err
	}
	token, err := requireText(c.Token, "Home Assistant token")
	if err != nil {
		return nil, err
	}
	if err := p.assertPublicEndpoint(ctx, baseURL); err != nil {
		return nil, err
	}
	method := strings.ToUpper(strings.TrimSpace(o.method))
	if method == "" {
		method = "GET"
	}
	if !methods[method] {
		return nil, errors.New("Unsupported Home Assistant API method.")
	}
	target, err := buildURL(baseURL, o.path, o.query)
	if err != nil {
		return nil, err
	}
	resp, err := p.client().Do(ctx, oauthclient.Request{
		Method: method, URL: target, JSON: o.body,
		Header: map[string]string{"Authorization": "Bearer " + token},
	})
	if err != nil {
		return nil, err
	}
	if resp.Status >= 300 && resp.Status < 400 {
		return nil, errors.New("Home Assistant redirected the API request; redirects are not followed.")
	}
	body := string(resp.Body)
	var data any
	if body != "" {
		dec := json.NewDecoder(strings.NewReader(body))
		dec.UseNumber()
		if dec.Decode(&data) != nil {
			data = body
		}
	}
	if resp.Status < 200 || resp.Status > 299 {
		statusLine := fmt.Sprintf("%d %s", resp.Status, http.StatusText(resp.Status))
		message := statusLine
		if obj, ok := data.(map[string]any); ok {
			message = integrations.Str(integrations.Or(obj["message"], obj["error"], statusLine))
		} else if body != "" {
			message = body
		}
		return nil, fmt.Errorf("Home Assistant request failed: %s", strings.TrimSpace(message))
	}
	return data, nil
}

// client is the bounded JSON client, without redirects.
func (p *provider) client() *oauthclient.Client {
	return &oauthclient.Client{HTTP: p.http, Service: "Home Assistant", TimeoutCode: "INTEGRATION_HTTP_TIMEOUT", TooLargeCode: "INTEGRATION_RESPONSE_TOO_LARGE"}
}
