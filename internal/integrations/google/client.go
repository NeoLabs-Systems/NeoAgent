package google

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neolabs-go/oauthclient"
)

// endpoints are the Google hosts. Tests point them at a fake server.
type endpoints struct {
	auth, token, revoke, userinfo string
	api, gmail, docs, sheets      string
	upload                        string
	// isAPIHost vets the host of an api_request tool call.
	isAPIHost func(host string) bool
}

func googleEndpoints() endpoints {
	return endpoints{
		auth:     "https://accounts.google.com/o/oauth2/v2/auth",
		token:    "https://oauth2.googleapis.com/token",
		revoke:   "https://oauth2.googleapis.com/revoke",
		userinfo: "https://www.googleapis.com/oauth2/v2/userinfo",
		api:      "https://www.googleapis.com",
		gmail:    "https://gmail.googleapis.com",
		docs:     "https://docs.googleapis.com",
		sheets:   "https://sheets.googleapis.com",
		upload:   "https://www.googleapis.com/upload",
		isAPIHost: func(host string) bool {
			host = strings.ToLower(strings.TrimSuffix(strings.TrimSpace(host), "."))
			return host == "googleapis.com" || strings.HasSuffix(host, ".googleapis.com")
		},
	}
}

// eagerRefresh is how long before expiry a token is renewed.
const eagerRefresh = 5 * time.Minute

// session is one tool call's authorized access to Google.
type session struct {
	p  *provider
	tc *integrations.ToolContext
}

func (s *session) creds() oauthclient.Credentials { return s.tc.Credentials }

func expiryMillis(c oauthclient.Credentials) (int64, bool) {
	n, ok := integrations.JSNumber(c["expiry_date"])
	if !ok || n == 0 {
		return 0, false
	}
	return int64(n), true
}

// accessToken returns a usable access token, renewing it first when it is
// missing or about to expire.
func (s *session) accessToken(ctx context.Context) (string, error) {
	c := s.creds()
	access := c.String("access_token")
	refresh := c.String("refresh_token")
	if access == "" && refresh == "" {
		return "", errors.New("No access, refresh token, API key or refresh handler callback is set.")
	}
	expiring := false
	if ms, ok := expiryMillis(c); ok {
		expiring = ms <= s.p.svc.Now().Add(eagerRefresh).UnixMilli()
	}
	if access != "" && !expiring {
		return access, nil
	}
	if err := s.refresh(ctx); err != nil {
		return "", err
	}
	return s.creds().String("access_token"), nil
}

// tokenError turns an OAuth endpoint failure into the error text the Google
// client library gave: the error code, or its description.
func tokenError(res *oauthclient.Response) error {
	var data map[string]any
	_ = json.Unmarshal(res.Body, &data)
	msg := integrations.Str(integrations.Or(data["error"], data["error_description"], nil))
	if msg == "" {
		msg = fmt.Sprintf("Request failed with status code %d", res.Status)
	}
	return &oauthclient.Error{Status: res.Status, Message: msg, Data: data, Header: res.Header}
}

func (s *session) refresh(ctx context.Context) error {
	refresh := s.creds().String("refresh_token")
	if refresh == "" {
		return errors.New("No refresh token is set.")
	}
	res, err := s.p.svc.Client("Google").Do(ctx, oauthclient.Request{
		Method: "POST", URL: s.p.ep.token,
		Form: [][2]string{
			{"refresh_token", refresh}, {"client_id", s.tc.OAuth.ClientID},
			{"client_secret", s.tc.OAuth.ClientSecret}, {"grant_type", "refresh_token"},
		},
	})
	if err != nil {
		return err
	}
	if res.Status < 200 || res.Status > 299 {
		return tokenError(res)
	}
	tokens := s.p.tokensFrom(integrations.Object(res.Body))
	tokens["refresh_token"] = refresh
	s.tc.UpdateCredentials(tokens)
	return nil
}

// tokensFrom turns a token response into stored credentials: expires_in
// becomes the absolute expiry_date in milliseconds.
func (p *provider) tokensFrom(token map[string]any) oauthclient.Credentials {
	out := oauthclient.Credentials{}
	for k, v := range token {
		out[k] = v
	}
	if integrations.Truthy(out["expires_in"]) {
		if n, ok := integrations.JSNumber(out["expires_in"]); ok {
			out["expiry_date"] = p.svc.Now().UnixMilli() + int64(n*1000)
		}
		delete(out, "expires_in")
	}
	return out
}

// response is a Google API answer.
type response struct {
	status int
	body   []byte
}

// object decodes the body as a JSON object.
func (r response) object() map[string]any { return integrations.Object(r.body) }

// call performs an authorized request. A failing status is an error carrying
// Google's own message.
func (s *session) call(ctx context.Context, method, rawURL string, query oauthclient.Query, body any) (response, error) {
	return s.send(ctx, method, rawURL, query, body, nil, 0)
}

// send is call with extra headers and a response size limit.
func (s *session) send(ctx context.Context, method, rawURL string, query oauthclient.Query, body any, headers map[string]string, maxBytes int64) (response, error) {
	if len(query) > 0 {
		var err error
		if rawURL, err = addQuery(rawURL, query); err != nil {
			return response{}, err
		}
	}
	retried := false
	for {
		token, err := s.accessToken(ctx)
		if err != nil {
			return response{}, err
		}
		h := map[string]string{}
		for k, v := range headers {
			h[k] = v
		}
		h["Authorization"] = "Bearer " + token
		req := oauthclient.Request{Method: method, URL: rawURL, Header: h, NoRetry: true, MaxBytes: maxBytes, Timeout: 60 * time.Second}
		if body != nil {
			if raw, ok := body.([]byte); ok {
				req.Body = raw
			} else {
				req.JSON = body
			}
		}
		res, err := s.p.svc.Client("Google").Do(ctx, req)
		if err != nil {
			return response{}, err
		}
		if res.Status == http.StatusUnauthorized && !retried && s.creds().String("refresh_token") != "" {
			retried = true
			if err := s.refresh(ctx); err != nil {
				return response{}, err
			}
			continue
		}
		if res.Status < 200 || res.Status > 299 {
			return response{}, apiError(res)
		}
		return response{status: res.Status, body: res.Body}, nil
	}
}

// apiError is a Google API failure: the message of its error object, else its
// code, else the status.
func apiError(res *oauthclient.Response) error {
	var data map[string]any
	_ = json.Unmarshal(res.Body, &data)
	msg := ""
	switch e := data["error"].(type) {
	case map[string]any:
		msg = integrations.Str(e["message"])
	case string:
		msg = integrations.Str(integrations.Or(data["error_description"], e))
	}
	if msg == "" {
		msg = fmt.Sprintf("Request failed with status code %d", res.Status)
	}
	return &oauthclient.Error{Status: res.Status, Message: msg, Data: data, Header: res.Header}
}

func addQuery(rawURL string, query oauthclient.Query) (string, error) {
	u, err := url.Parse(rawURL)
	if err != nil {
		return "", err
	}
	if u.RawQuery != "" {
		u.RawQuery += "&"
	}
	// Repeated keys stay repeated (metadataHeaders, scope lists).
	u.RawQuery += oauthclient.EncodeQuery(query)
	return u.String(), nil
}

// apiRequest is the shared *_api_request tool: an authenticated call to a
// googleapis.com URL the model chose.
func (s *session) apiRequest(ctx context.Context, args map[string]any, baseURL string) (any, error) {
	method := strings.ToUpper(strings.TrimSpace(orDefault(textOf(args["method"]), "GET")))
	switch method {
	case "GET", "POST", "PUT", "PATCH", "DELETE":
	default:
		return nil, errors.New("method must be one of GET, POST, PUT, PATCH, DELETE.")
	}
	target, err := s.p.requireAPIURL(integrations.Or(args["path"], args["url"]), baseURL)
	if err != nil {
		return nil, err
	}
	var query oauthclient.Query
	if q, ok := args["query"].(map[string]any); ok {
		for _, k := range integrations.SortedKeys(q) {
			switch v := q[k].(type) {
			case []any:
				for _, e := range v {
					query = append(query, [2]string{k, integrations.Str(e)})
				}
			case nil:
			default:
				query = append(query, [2]string{k, integrations.Str(v)})
			}
		}
	}
	headers := map[string]string{}
	if h, ok := args["headers"].(map[string]any); ok {
		for k, v := range h {
			headers[k] = integrations.Str(v)
		}
	}
	var body any
	if has(args, "body") && args["body"] != nil {
		body = args["body"]
	}
	if len(query) > 0 {
		if target, err = addQuery(target, query); err != nil {
			return nil, err
		}
	}
	res, err := s.send(ctx, method, target, nil, body, headers, 0)
	if err != nil {
		return nil, err
	}
	return apiResult{Status: res.status, StatusText: http.StatusText(res.status), Data: decodeData(res.body, args["response_type"] == "arraybuffer")}, nil
}

// apiResult is the answer of an api_request tool.
type apiResult struct {
	Status     int    `json:"status"`
	StatusText string `json:"statusText"`
	Data       any    `json:"data"`
}

// decodeData is what an HTTP client hands back: parsed JSON when the body is
// JSON, else the text; base64 for binary requests.
func decodeData(body []byte, binary bool) any {
	if binary {
		return base64.StdEncoding.EncodeToString(body)
	}
	var v json.RawMessage
	if json.Unmarshal(body, &v) == nil && len(bytes.TrimSpace(body)) > 0 {
		return v
	}
	return string(body)
}

func (p *provider) requireAPIURL(pathOrURL any, baseURL string) (string, error) {
	raw := trimmed(pathOrURL)
	if raw == "" {
		return "", errors.New("path is required.")
	}
	base := strings.TrimSuffix(orDefault(baseURL, "https://www.googleapis.com"), "/")
	var target string
	if strings.HasPrefix(raw, "http://") || strings.HasPrefix(raw, "https://") {
		target = raw
	} else {
		if !strings.HasPrefix(raw, "/") {
			raw = "/" + raw
		}
		target = base + raw
	}
	u, err := url.Parse(target)
	if err != nil {
		return "", err
	}
	if !p.ep.allowInsecure() && u.Scheme != "https" || !p.ep.isAPIHost(u.Hostname()) {
		return "", errors.New("Google API request URL must target a googleapis.com host.")
	}
	return u.String(), nil
}

func (e endpoints) allowInsecure() bool { return !strings.HasPrefix(e.api, "https://") }

func itoa(n int) string { return strconv.Itoa(n) }
