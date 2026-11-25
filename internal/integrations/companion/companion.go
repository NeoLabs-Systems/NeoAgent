// Package companion is the OAuth contract NeoLabs servers (NeoCloud, NeoRecall)
// offer NeoAgent: the person enters the server URL once, NeoAgent registers
// itself through the companion bootstrap endpoint, then signs accounts in with
// PKCE and keeps rotating refresh tokens. The servers are self-hosted, often on
// a private network, so private addresses are allowed (as in Node).
package companion

import (
	"context"
	"encoding/json"
	"fmt"
	"math"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/cloudsec"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neolabs-go/oauthclient"
)

// Text is trimText: the trimmed String of a truthy value, else "".
func Text(v any) string {
	if !integrations.Truthy(v) {
		return ""
	}
	return strings.TrimSpace(integrations.Str(v))
}

// Required is the trimmed text or "<name> is required.".
func Required(v any, name string) (string, error) {
	t := Text(v)
	if t == "" {
		return "", fmt.Errorf("%s is required.", name)
	}
	return t, nil
}

// EncodeComponent is encodeURIComponent.
func EncodeComponent(s string) string {
	var b strings.Builder
	for _, c := range []byte(s) {
		if c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c >= '0' && c <= '9' || strings.IndexByte("-_.!~*'()", c) >= 0 {
			b.WriteByte(c)
		} else {
			fmt.Fprintf(&b, "%%%02X", c)
		}
	}
	return b.String()
}

// Server is one kind of companion server.
type Server struct {
	// Label names the product in errors ("NeoCloud").
	Label string
	// URLLabel names the setting ("NeoCloud server URL").
	URLLabel string
	HTTP     *http.Client
	Now      func() time.Time
}

func (s Server) now() time.Time {
	if s.Now != nil {
		return s.Now()
	}
	return time.Now()
}

// NormalizeBaseURL accepts a host with or without scheme (http for a private
// host, https otherwise) and returns the URL without a trailing slash.
func (s Server) NormalizeBaseURL(value any) (string, error) {
	raw := Text(value)
	if raw == "" {
		return "", fmt.Errorf("%s is required.", s.URLLabel)
	}
	candidate := raw
	if !strings.Contains(raw, "://") {
		host := strings.SplitN(raw, "/", 2)[0]
		scheme := "https"
		if isPrivateHostPort(host) {
			scheme = "http"
		}
		candidate = scheme + "://" + raw
	}
	u, err := url.Parse(candidate)
	if err != nil || u.Host == "" {
		return "", fmt.Errorf("%s must be a valid HTTP or HTTPS URL.", s.URLLabel)
	}
	scheme := strings.ToLower(u.Scheme)
	if scheme != "http" && scheme != "https" || u.User != nil || u.Fragment != "" {
		return "", fmt.Errorf("%s must be HTTP(S), without credentials or a fragment.", s.URLLabel)
	}
	host := strings.ToLower(u.Host)
	if scheme == "https" {
		host = strings.TrimSuffix(host, ":443")
	} else {
		host = strings.TrimSuffix(host, ":80")
	}
	out := scheme + "://" + host + strings.TrimRight(u.EscapedPath(), "/")
	if u.RawQuery != "" {
		out += "?" + u.RawQuery
	}
	return strings.TrimRight(out, "/"), nil
}

// isPrivateHostPort classifies host[:port] like the Node isPrivateHost.
func isPrivateHostPort(hostport string) bool {
	h := strings.ToLower(strings.TrimSpace(hostport))
	if strings.HasPrefix(h, "[") {
		if i := strings.Index(h, "]"); i > 0 {
			h = h[1:i]
		}
	} else if strings.Count(h, ":") == 1 {
		h = h[:strings.Index(h, ":")]
	}
	return cloudsec.IsPrivateHost(h)
}

// Host is the host[:port] of a normalised base URL.
func Host(baseURL string) string {
	u, err := url.Parse(baseURL)
	if err != nil {
		return ""
	}
	return u.Host
}

// Fetch is the bounded JSON call every companion request makes.
func (s Server) Fetch(ctx context.Context, service string, r oauthclient.Request) (map[string]any, any, error) {
	raw, err := (&oauthclient.Client{HTTP: s.HTTP, Service: service, TimeoutCode: "INTEGRATION_HTTP_TIMEOUT", TooLargeCode: "INTEGRATION_RESPONSE_TOO_LARGE"}).JSON(ctx, r)
	if err != nil {
		return nil, nil, err
	}
	var value any
	dec := json.NewDecoder(strings.NewReader(string(raw)))
	dec.UseNumber()
	_ = dec.Decode(&value)
	obj, _ := value.(map[string]any)
	if obj == nil {
		obj = map[string]any{}
	}
	return obj, value, nil
}

// Bootstrap registers NeoAgent as the server's companion client.
func (s Server) Bootstrap(ctx context.Context, baseURL, callbackURL string) (map[string]any, error) {
	obj, _, err := s.Fetch(ctx, s.Label+" companion bootstrap", oauthclient.Request{
		Method: "POST", URL: baseURL + "/api/oauth/companion/neoagent/bootstrap",
		JSON: Ordered{{"redirectUri", callbackURL}, {"appName", "NeoAgent"}},
	})
	return obj, err
}

// Token calls the token endpoint.
func (s Server) Token(ctx context.Context, baseURL string, form [][2]string) (map[string]any, error) {
	obj, _, err := s.Fetch(ctx, s.Label+" OAuth token", oauthclient.Request{Method: "POST", URL: baseURL + "/oauth/token", Form: form})
	return obj, err
}

// Userinfo names the signed-in account.
func (s Server) Userinfo(ctx context.Context, baseURL, accessToken string) (map[string]any, error) {
	obj, _, err := s.Fetch(ctx, s.Label+" userinfo", oauthclient.Request{URL: baseURL + "/oauth/userinfo", Header: map[string]string{"Authorization": "Bearer " + accessToken}})
	return obj, err
}

// Revoke revokes both tokens of a connection; the first failure is returned
// after both were tried.
func (s Server) Revoke(ctx context.Context, creds map[string]any) error {
	baseURL, err := s.NormalizeBaseURL(creds["baseUrl"])
	if err != nil {
		return err
	}
	clientID := Text(creds["client_id"])
	if clientID == "" {
		return nil
	}
	var first error
	for _, token := range []string{Text(creds["refresh_token"]), Text(creds["access_token"])} {
		if token == "" {
			continue
		}
		_, _, err := s.Fetch(ctx, s.Label+" OAuth revocation", oauthclient.Request{Method: "POST", URL: baseURL + "/oauth/revoke", Form: [][2]string{{"client_id", clientID}, {"token", token}}})
		if err != nil && first == nil {
			first = err
		}
	}
	return first
}

// ExpiresAtMs is now plus expires_in seconds (one hour when absent).
func (s Server) ExpiresAtMs(expiresIn any) int64 {
	n, ok := integrations.JSNumber(expiresIn)
	if !ok || n == 0 {
		n = 3600
	}
	return s.now().UnixMilli() + int64(math.Max(1, n)*1000)
}

// Authorization is a usable access token and the credentials it came from.
type Authorization struct {
	BaseURL     string
	AccessToken string
	Credentials map[string]any
	// Refreshed is true when the credentials were renewed and must be stored.
	Refreshed bool
}

// Authenticate returns a token valid for at least a minute, refreshing it
// when needed. The server rotates refresh tokens.
func (s Server) Authenticate(ctx context.Context, creds map[string]any) (Authorization, error) {
	baseURL, err := s.NormalizeBaseURL(creds["baseUrl"])
	if err != nil {
		return Authorization{}, err
	}
	if expires, ok := integrations.JSNumber(creds["expires_at_ms"]); ok && Text(creds["access_token"]) != "" && expires > float64(s.now().UnixMilli()+60_000) {
		return Authorization{BaseURL: baseURL, AccessToken: integrations.Str(creds["access_token"]), Credentials: creds}, nil
	}
	if Text(creds["refresh_token"]) == "" || Text(creds["client_id"]) == "" {
		return Authorization{}, fmt.Errorf("%s refresh token is missing. Reconnect the %s account.", s.Label, s.Label)
	}
	refreshed, err := s.Token(ctx, baseURL, [][2]string{{"grant_type", "refresh_token"}, {"client_id", integrations.Str(creds["client_id"])}, {"refresh_token", integrations.Str(creds["refresh_token"])}})
	if err != nil {
		return Authorization{}, err
	}
	next := map[string]any{}
	for k, v := range creds {
		next[k] = v
	}
	next["access_token"] = Text(refreshed["access_token"])
	if rt := Text(refreshed["refresh_token"]); rt != "" {
		next["refresh_token"] = rt
	}
	next["expires_at_ms"] = s.ExpiresAtMs(refreshed["expires_in"])
	if scope := Text(refreshed["scope"]); scope != "" {
		next["scope"] = scope
	}
	return Authorization{BaseURL: baseURL, AccessToken: integrations.Str(next["access_token"]), Credentials: next, Refreshed: true}, nil
}

// Ordered is a JSON object that keeps its member order.
type Ordered [][2]any

// MarshalJSON writes the members in order.
func (o Ordered) MarshalJSON() ([]byte, error) {
	out := []byte{'{'}
	for i, kv := range o {
		if i > 0 {
			out = append(out, ',')
		}
		k, _ := json.Marshal(kv[0])
		v, err := oauthclient.MarshalJS(kv[1])
		if err != nil {
			return nil, err
		}
		out = append(append(append(out, k...), ':'), v...)
	}
	return append(out, '}'), nil
}

// Compact drops null, undefined and empty-string members, so the server
// applies its defaults.
func Compact(o Ordered) Ordered {
	out := Ordered{}
	for _, kv := range o {
		switch v := kv[1].(type) {
		case nil:
			continue
		case string:
			if v == "" {
				continue
			}
		}
		out = append(out, kv)
	}
	return out
}

// AppendQuery adds the non-empty values as a query string, URLSearchParams
// style.
func AppendQuery(path string, query Ordered) string {
	var q oauthclient.Query
	for _, kv := range query {
		if kv[1] == nil {
			continue
		}
		v := integrations.Str(kv[1])
		if v == "" {
			continue
		}
		q.Set(kv[0].(string), v)
	}
	encoded := oauthclient.EncodeQuery(q)
	if encoded == "" {
		return path
	}
	return path + "?" + encoded
}
