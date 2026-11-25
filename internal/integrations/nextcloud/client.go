package nextcloud

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/dav"
	"github.com/NeoLabs-Systems/neolabs-go/oauthclient"
)

const userAgent = "NeoAgent Nextcloud Integration"

func text(v any) string { return strings.TrimSpace(integrations.Str(v)) }

func normalizeBaseURL(v any) (string, error) { return dav.NormalizeServerURL(v, "Nextcloud URL") }

type account struct{ baseURL, username, appPassword string }

func parseAccount(c map[string]any) (account, error) {
	base, err := normalizeBaseURL(c["baseUrl"])
	if err != nil {
		return account{}, err
	}
	user, err := integrations.RequireText(c["username"], "Nextcloud username")
	if err != nil {
		return account{}, err
	}
	pass, err := integrations.RequireText(c["appPassword"], "Nextcloud app password")
	if err != nil {
		return account{}, err
	}
	return account{baseURL: base, username: user, appPassword: pass}, nil
}

func (a account) authorization() string {
	return "Basic " + base64.StdEncoding.EncodeToString([]byte(a.username+":"+a.appPassword))
}

type reqOpts struct {
	method   string
	headers  map[string]string
	body     []byte
	query    []queryPair
	prefix   string
	label    string
	service  string
	maxBytes int64
}

type queryPair struct {
	key   string
	value any
}

type answer struct {
	status int
	header http.Header
	body   []byte
	url    string
}

func (a answer) ok() bool { return a.status >= 200 && a.status <= 299 }

// resolveInstanceURL keeps an absolute path on the instance's origin.
func resolveInstanceURL(baseURL, path string) (*url.URL, error) {
	normalized, err := normalizeBaseURL(baseURL)
	if err != nil {
		return nil, err
	}
	base, _ := url.Parse(normalized)
	raw := strings.TrimSpace(path)
	if raw == "" {
		return nil, errors.New("path is required.")
	}
	if !strings.HasPrefix(raw, "/") {
		return nil, errors.New("Nextcloud path must be absolute and start with /.")
	}
	u, err := base.Parse(raw)
	if err != nil || u.Scheme+"://"+u.Host != base.Scheme+"://"+base.Host {
		return nil, errors.New("Nextcloud path must stay on the connected instance origin.")
	}
	return u, nil
}

func (p *Provider) instanceRequest(ctx context.Context, baseURL, path string, o reqOpts) (answer, error) {
	u, err := resolveInstanceURL(baseURL, path)
	if err != nil {
		return answer{}, err
	}
	if o.prefix != "" {
		decoded, _ := url.PathUnescape(u.EscapedPath())
		if !strings.HasPrefix(decoded, o.prefix) {
			label := o.label
			if label == "" {
				label = "Nextcloud path"
			}
			return answer{}, fmt.Errorf("%s must start with %s.", label, o.prefix)
		}
	}
	if len(o.query) > 0 {
		var params oauthclient.Query
		for _, q := range o.query {
			if q.value == nil || q.value == "" {
				continue
			}
			params.Set(q.key, integrations.Str(q.value))
		}
		withQuery, err := oauthclient.SetParams(u.String(), params)
		if err != nil {
			return answer{}, err
		}
		u, _ = url.Parse(withQuery)
	}
	header := map[string]string{"User-Agent": userAgent}
	for k, v := range o.headers {
		header[k] = v
	}
	service := o.service
	if service == "" {
		service = "Nextcloud"
	}
	method := strings.ToUpper(o.method)
	if method == "" {
		method = "GET"
	}
	resp, err := p.svc.SelfHostedClient(service).Do(ctx, oauthclient.Request{Method: method, URL: u.String(), Header: header, Body: o.body, MaxBytes: o.maxBytes})
	if err != nil {
		return answer{}, err
	}
	if resp.Status >= 300 && resp.Status < 400 {
		return answer{}, errors.New("Nextcloud redirected the request; redirects are not followed.")
	}
	return answer{status: resp.Status, header: resp.Header, body: resp.Body, url: u.String()}, nil
}

func (p *Provider) authenticated(ctx context.Context, a account, path string, o reqOpts) (answer, error) {
	headers := map[string]string{"Authorization": a.authorization()}
	for k, v := range o.headers {
		headers[k] = v
	}
	o.headers = headers
	return p.instanceRequest(ctx, a.baseURL, path, o)
}

func decodeJSON(body []byte) (any, bool) {
	if len(strings.TrimSpace(string(body))) == 0 {
		return nil, true
	}
	dec := json.NewDecoder(strings.NewReader(string(body)))
	dec.UseNumber()
	var v any
	if dec.Decode(&v) != nil {
		return nil, false
	}
	return v, true
}

// unwrapOcs returns ocs.data, or fails on an OCS error status.
func unwrapOcs(data any) (any, error) {
	meta, _ := integrations.Get(data, "ocs", "meta").(map[string]any)
	if meta != nil {
		if status, ok := integrations.JSNumber(meta["statuscode"]); ok && status >= 400 {
			if msg := text(meta["message"]); msg != "" {
				return nil, errors.New(msg)
			}
			return nil, fmt.Errorf("Nextcloud OCS request failed (%s).", integrations.Str(meta["statuscode"]))
		}
	}
	if ocs, ok := integrations.Get(data, "ocs").(map[string]any); ok {
		if inner, has := ocs["data"]; has {
			return inner, nil
		}
	}
	return data, nil
}

func (p *Provider) fetchStatus(ctx context.Context, baseURL string) error {
	normalized, err := normalizeBaseURL(baseURL)
	if err != nil {
		return err
	}
	raw, err := p.svc.SelfHostedClient("Nextcloud status").JSON(ctx, oauthclient.Request{URL: normalized + "/status.php",
		Header: map[string]string{"User-Agent": userAgent, "Accept": "application/json"}})
	if err != nil {
		return err
	}
	data := integrations.Object(raw)
	if text(data["version"]) == "" || data["installed"] == false {
		return errors.New("The URL did not identify itself as a Nextcloud server.")
	}
	return nil
}

type user struct{ id, displayName, email string }

func (p *Provider) fetchUser(ctx context.Context, creds map[string]any) (user, error) {
	a, err := parseAccount(creds)
	if err != nil {
		return user{}, err
	}
	res, err := p.authenticated(ctx, a, "/ocs/v2.php/cloud/user", reqOpts{
		headers: map[string]string{"Accept": "application/json", "OCS-APIRequest": "true"},
		prefix:  "/ocs/v2.php/", label: "Nextcloud OCS path", service: "Nextcloud user",
	})
	if err != nil {
		return user{}, err
	}
	if !res.ok() {
		return user{}, fmt.Errorf("Nextcloud rejected the account credentials (%d).", res.status)
	}
	data, ok := decodeJSON(res.body)
	if !ok {
		data = nil
	}
	inner, err := unwrapOcs(data)
	if err != nil {
		return user{}, err
	}
	u, _ := inner.(map[string]any)
	return user{
		id:          text(u["id"]),
		displayName: text(integrations.Or(u["display-name"], u["displayname"], u["displayName"])),
		email:       text(u["email"]),
	}, nil
}

type ocsOpts struct {
	method  any
	query   map[string]any
	ordered []queryPair
	json    any
	form    [][2]string
	service string
}

func (p *Provider) ocs(ctx context.Context, a account, path string, o ocsOpts) (any, error) {
	method := strings.ToUpper(integrations.Str(o.method))
	if o.method == nil || method == "" {
		method = "GET"
	}
	switch method {
	case "GET", "POST", "PUT", "PATCH", "DELETE":
	default:
		return nil, errors.New("Nextcloud OCS method must be GET, POST, PUT, PATCH, or DELETE.")
	}
	headers := map[string]string{"Accept": "application/json", "OCS-APIRequest": "true"}
	var body []byte
	switch {
	case o.json != nil:
		headers["Content-Type"] = "application/json"
		body, _ = oauthclient.MarshalJS(o.json)
	case o.form != nil:
		headers["Content-Type"] = "application/x-www-form-urlencoded"
		body = []byte(oauthclient.EncodeQuery(o.form))
	}
	query := o.ordered
	for _, k := range integrations.SortedKeys(o.query) {
		query = append(query, queryPair{k, o.query[k]})
	}
	service := o.service
	if service == "" {
		service = "Nextcloud OCS"
	}
	res, err := p.authenticated(ctx, a, path, reqOpts{method: method, headers: headers, body: body, query: query,
		prefix: "/ocs/v2.php/", label: "Nextcloud OCS path", service: service})
	if err != nil {
		return nil, err
	}
	data, ok := decodeJSON(res.body)
	if !ok {
		data = string(res.body)
	}
	if !res.ok() {
		var message any
		if m, isObj := data.(map[string]any); isObj {
			message = integrations.Or(integrations.Get(m, "ocs", "meta", "message"), m["message"], m["error"])
		} else {
			message = string(res.body)
		}
		msg := text(message)
		if msg == "" {
			msg = fmt.Sprintf("%d %s", res.status, http.StatusText(res.status))
		}
		return nil, fmt.Errorf("Nextcloud OCS request failed: %s", msg)
	}
	return unwrapOcs(data)
}

type davOpts struct {
	method   string
	headers  map[string]string
	body     []byte
	accept   string
	maxBytes int64
	service  string
}

func (p *Provider) dav(ctx context.Context, a account, path string, o davOpts) (answer, error) {
	method := strings.ToUpper(o.method)
	if method == "" {
		method = "PROPFIND"
	}
	accept := o.accept
	if accept == "" {
		accept = "application/xml, text/xml, */*"
	}
	headers := map[string]string{"Accept": accept}
	for k, v := range o.headers {
		headers[k] = v
	}
	service := o.service
	if service == "" {
		service = "Nextcloud WebDAV"
	}
	res, err := p.authenticated(ctx, a, path, reqOpts{method: method, headers: headers, body: o.body,
		prefix: "/remote.php/dav/", label: "Nextcloud WebDAV path", service: service, maxBytes: o.maxBytes})
	if err != nil {
		return answer{}, err
	}
	if !res.ok() {
		return answer{}, fmt.Errorf("Nextcloud WebDAV request failed (%d): %s", res.status, sliceUTF16(strings.TrimSpace(string(res.body)), 300))
	}
	return res, nil
}

func sliceUTF16(s string, n int) string {
	units := 0
	for i, r := range s {
		w := 1
		if r > 0xFFFF {
			w = 2
		}
		if units+w > n {
			return s[:i]
		}
		units += w
	}
	return s
}

// davStore is a calendar or address book home of the account.
func (p *Provider) davStore(creds map[string]any, collection string) (dav.Store, error) {
	a, err := parseAccount(creds)
	if err != nil {
		return dav.Store{}, err
	}
	return dav.Store{
		Home: "/remote.php/dav/" + collection + "/" + dav.EncodeURIComponent(a.username) + "/",
		Do: func(ctx context.Context, path string, r dav.Request) (string, error) {
			var body []byte
			if r.Body != "" {
				body = []byte(r.Body)
			}
			res, err := p.dav(ctx, a, path, davOpts{method: r.Method, headers: r.Headers, body: body, accept: r.Accept})
			if err != nil {
				return "", err
			}
			return string(res.body), nil
		},
	}, nil
}
