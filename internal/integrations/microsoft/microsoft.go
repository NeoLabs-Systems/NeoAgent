// Package microsoft is the official Microsoft 365 integration: OAuth through
// Microsoft Entra and the Outlook, Calendar, OneDrive and Teams tools over
// Microsoft Graph.
package microsoft

import (
	"context"
	_ "embed"
	"encoding/json"
	"errors"
	"fmt"
	"net/url"
	"regexp"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/calendarwindow"
	"github.com/NeoLabs-Systems/neolabs-go/oauthclient"
)

//go:embed provider.json
var specJSON []byte

var baseScopes = []string{"openid", "profile", "email", "offline_access", "User.Read"}

func appScopes(extra ...string) []string { return append(append([]string{}, baseScopes...), extra...) }

// scopesByApp are the delegated Graph permissions each app asks for.
var scopesByApp = map[string][]string{
	"outlook":  appScopes("Mail.ReadWrite", "Mail.Send"),
	"calendar": appScopes("Calendars.ReadWrite"),
	"onedrive": appScopes("Files.ReadWrite.All"),
	"teams":    appScopes("Chat.ReadWrite", "ChannelMessage.Read.All"),
}

// allScopes lists the permissions of every app, app by app.
func allScopes() []string {
	var all []string
	for _, id := range []string{"outlook", "calendar", "onedrive", "teams"} {
		all = append(all, scopesByApp[id]...)
	}
	return all
}

type endpoints struct {
	login string // https://login.microsoftonline.com
	graph string // https://graph.microsoft.com
}

type provider struct {
	svc *integrations.Services
	ep  endpoints
}

// New is the Microsoft 365 provider.
func New(svc *integrations.Services) *integrations.OAuthProviderImpl {
	return newProvider(svc, endpoints{login: "https://login.microsoftonline.com", graph: "https://graph.microsoft.com"})
}

func newProvider(svc *integrations.Services, ep endpoints) *integrations.OAuthProviderImpl {
	p := &provider{svc: svc, ep: ep}
	app := integrations.NewOAuthApp(svc, integrations.OAuthAppSpec{
		ProviderKey:  "microsoft_365",
		Label:        "Microsoft 365",
		EnvPrefix:    "MICROSOFT",
		ConsoleURL:   "https://entra.microsoft.com/#view/Microsoft_AAD_RegisteredApps/ApplicationsListBlade",
		Notes:        "Register an app with a Web redirect URI set to the callback URL, create a client secret under Certificates & secrets, and add these delegated Microsoft Graph permissions.",
		Scopes:       allScopes(),
		Alternatives: []string{"phone"},
		Fields: []integrations.AppField{{
			Name: "tenantId", Label: "Tenant ID", Env: "MICROSOFT_OAUTH_TENANT_ID", DefaultValue: "common",
			Hint: "Leave blank to allow any work, school or personal account, or enter your directory (tenant) ID.",
		}},
	})
	return integrations.NewOAuthProvider(svc, integrations.LoadSpec(specJSON), app, integrations.OAuthHooks{
		Begin:   p.begin,
		Finish:  p.finish,
		Execute: p.execute,
		Sweep:   p.sweep,
		Test: func(ctx context.Context, tc *integrations.ToolContext) error {
			_, err := p.graph(ctx, tc, graphCall{path: "/v1.0/me", query: oauthclient.Query{{"$select", "id,displayName,userPrincipalName"}}})
			return err
		},
	})
}

func (p *provider) tenantURL(cfg integrations.OAuthConfig, endpoint string) string {
	return p.ep.login + "/" + url.PathEscape(cfg.Fields["tenantId"]) + "/oauth2/v2.0/" + endpoint
}

func (p *provider) begin(_ context.Context, in integrations.BeginInput) (integrations.BeginResult, error) {
	u, err := oauthclient.AppendQuery(p.tenantURL(in.OAuth, "authorize"),
		"client_id", in.OAuth.ClientID,
		"redirect_uri", in.OAuth.RedirectURI,
		"response_type", "code",
		"response_mode", "query",
		"scope", oauthclient.JoinScopes(scopesByApp[in.App.ID]...),
		"state", in.State,
		"prompt", "select_account")
	return integrations.BeginResult{URL: u, AppID: in.App.ID}, err
}

func (p *provider) finish(ctx context.Context, in integrations.FinishInput) (integrations.FinishResult, error) {
	raw, err := p.svc.Client("Microsoft 365").JSON(ctx, oauthclient.Request{
		Method: "POST", URL: p.tenantURL(in.OAuth, "token"),
		Form: [][2]string{
			{"client_id", in.OAuth.ClientID}, {"client_secret", in.OAuth.ClientSecret}, {"grant_type", "authorization_code"},
			{"code", in.Code}, {"redirect_uri", in.OAuth.RedirectURI}, {"scope", oauthclient.JoinScopes(scopesByApp[in.App.ID]...)},
		},
	})
	if err != nil {
		return integrations.FinishResult{}, err
	}
	token := integrations.Object(raw)
	profileRaw, err := p.svc.Client("Microsoft 365").JSON(ctx, oauthclient.Request{
		URL:    p.ep.graph + "/v1.0/me?$select=id,displayName,mail,userPrincipalName",
		Header: map[string]string{"Authorization": "Bearer " + integrations.Str(token["access_token"])},
	})
	if err != nil {
		return integrations.FinishResult{}, err
	}
	profile := integrations.Object(profileRaw)
	email := strings.TrimSpace(integrations.Str(integrations.Or(profile["mail"], profile["userPrincipalName"], profile["displayName"], profile["id"], "")))
	if email == "" {
		return integrations.FinishResult{}, errors.New("Microsoft 365 OAuth did not return a stable account identifier.")
	}
	creds := oauthclient.Credentials{"expires_at": oauthclient.ExpiresAt(token["expires_in"], false, p.svc.Now())}
	for _, k := range []string{"access_token", "refresh_token", "expires_in", "scope", "token_type"} {
		if v, ok := token[k]; ok {
			creds[k] = v
		}
	}
	return integrations.FinishResult{
		AppID: in.App.ID, AccountEmail: email, Credentials: creds, Scopes: scopesByApp[in.App.ID],
		Metadata: map[string]any{
			"id":                integrations.Or(profile["id"], nil),
			"displayName":       integrations.Or(profile["displayName"], nil),
			"mail":              integrations.Or(profile["mail"], nil),
			"userPrincipalName": integrations.Or(profile["userPrincipalName"], nil),
		},
	}, nil
}

func (p *provider) refresh(ctx context.Context, cfg integrations.OAuthConfig, creds oauthclient.Credentials) (oauthclient.Credentials, error) {
	refreshToken := strings.TrimSpace(creds.String("refresh_token"))
	if refreshToken == "" {
		return nil, errors.New("Microsoft 365 refresh token is missing. Reconnect this integration account.")
	}
	form := [][2]string{
		{"client_id", cfg.ClientID}, {"client_secret", cfg.ClientSecret}, {"grant_type", "refresh_token"}, {"refresh_token", refreshToken},
	}
	if scope := creds.String("scope"); scope != "" {
		form = append(form, [2]string{"scope", scope})
	}
	raw, err := p.svc.Client("Microsoft 365 token refresh").JSON(ctx, oauthclient.Request{
		Method: "POST", URL: p.tenantURL(cfg, "token"), Form: form,
	})
	if err != nil {
		return nil, err
	}
	token := integrations.Object(raw)
	if strings.TrimSpace(integrations.Str(token["access_token"])) == "" {
		return nil, errors.New("Microsoft 365 token refresh did not return an access token.")
	}
	next := creds.Clone()
	next["access_token"] = token["access_token"]
	next["refresh_token"] = integrations.Or(token["refresh_token"], refreshToken)
	if v, ok := token["expires_in"]; ok {
		next["expires_in"] = v
	} else {
		delete(next, "expires_in")
	}
	next["expires_at"] = oauthclient.ExpiresAt(token["expires_in"], false, p.svc.Now())
	setIfAny(next, "scope", token["scope"], creds["scope"])
	setIfAny(next, "token_type", token["token_type"], creds["token_type"])
	return next, nil
}

// setIfAny stores the first truthy value; when none is, the key is dropped.
func setIfAny(m oauthclient.Credentials, key string, values ...any) {
	if v := integrations.Or(append(values, nil)...); v != nil {
		m[key] = v
		return
	}
	delete(m, key)
}

// graphURL builds a Graph request URL; only the Graph host is reachable.
func (p *provider) graphURL(path string, query oauthclient.Query) (string, error) {
	base, _ := url.Parse(p.ep.graph)
	raw := strings.TrimSpace(path)
	target := raw
	if !strings.HasPrefix(raw, "http") {
		if !strings.HasPrefix(raw, "/") {
			raw = "/" + raw
		}
		target = p.ep.graph + raw
	}
	u, err := url.Parse(target)
	if err != nil {
		return "", err
	}
	if u.Scheme != base.Scheme || u.Hostname() != base.Hostname() {
		return "", errors.New("Microsoft Graph request URL must target graph.microsoft.com.")
	}
	var params oauthclient.Query
	for _, kv := range query {
		if strings.TrimSpace(kv[1]) != "" {
			params = append(params, kv)
		}
	}
	return oauthclient.SetParams(u.String(), params)
}

type graphCall struct {
	method string
	path   string
	query  oauthclient.Query
	body   any
	header map[string]string
}

func (p *provider) graph(ctx context.Context, tc *integrations.ToolContext, c graphCall) (json.RawMessage, error) {
	target, err := p.graphURL(c.path, c.query)
	if err != nil {
		return nil, err
	}
	out, _, err := oauthclient.WithRefresh(ctx, tc.Credentials,
		func(ctx context.Context, creds oauthclient.Credentials) (oauthclient.Credentials, error) {
			next, err := p.refresh(ctx, tc.OAuth, creds)
			if err == nil {
				tc.UpdateCredentials(next)
			}
			return next, err
		},
		func(creds oauthclient.Credentials) (json.RawMessage, error) {
			headers := map[string]string{"Authorization": "Bearer " + creds.String("access_token")}
			for k, v := range c.header {
				headers[k] = v
			}
			return p.svc.Client("Microsoft Graph").JSON(ctx, oauthclient.Request{
				Method: strings.ToUpper(orDefault(c.method, "GET")), URL: target, Header: headers, JSON: c.body,
			})
		}, nil)
	return out, err
}

func orDefault(s, fallback string) string {
	if s == "" {
		return fallback
	}
	return s
}

func emailRecipients(values any) []map[string]any {
	var parts []string
	if list, ok := values.([]any); ok {
		for _, v := range list {
			parts = append(parts, strings.TrimSpace(textOf(v)))
		}
	} else {
		for _, v := range strings.Split(textOf(values), ",") {
			parts = append(parts, strings.TrimSpace(v))
		}
	}
	out := []map[string]any{}
	for _, address := range parts {
		if address != "" {
			out = append(out, map[string]any{"emailAddress": map[string]any{"address": address}})
		}
	}
	return out
}

func textOf(v any) string {
	if !integrations.Truthy(v) {
		return ""
	}
	return integrations.Str(v)
}

var zoned = regexp.MustCompile(`(?i)z$|[+-]\d{2}:?\d{2}$`)

// graphDateTime reads a Graph dateTimeTimeZone as an ISO time; Graph answers
// UTC times without the trailing Z when asked for the UTC zone.
func graphDateTime(value any) *string {
	dt := strings.TrimSpace(textOf(integrations.Get(value, "dateTime")))
	if dt == "" {
		return nil
	}
	if !zoned.MatchString(dt) && strings.EqualFold(textOf(integrations.Get(value, "timeZone")), "UTC") {
		dt += "Z"
	}
	return &dt
}

func summarizeEvent(event map[string]any) calendarwindow.Summary {
	pick := func(v any) *string {
		if integrations.Truthy(v) {
			s := integrations.Str(v)
			return &s
		}
		return nil
	}
	status := "confirmed"
	if integrations.Truthy(event["isCancelled"]) {
		status = "cancelled"
	}
	attendees := []string{}
	if list, ok := event["attendees"].([]any); ok {
		for _, a := range list {
			if address := integrations.Get(a, "emailAddress", "address"); integrations.Truthy(address) {
				attendees = append(attendees, integrations.Str(address))
			}
		}
	}
	return calendarwindow.Summary{
		ID: textOf(event["id"]), Status: &status, Summary: textOf(event["subject"]),
		Description: pick(event["bodyPreview"]), Location: pick(integrations.Get(event, "location", "displayName")),
		HTMLLink: pick(event["webLink"]), AllDay: event["isAllDay"] == true,
		Start: graphDateTime(event["start"]), End: graphDateTime(event["end"]), Attendees: attendees,
	}
}

var (
	graphToolName = regexp.MustCompile(`^microsoft_365_.*_graph_request$`)
	calendarPath  = regexp.MustCompile(`(?i)/calendar(?:View)?(?:\?|$)|/events(?:\?|$)`)
)

func top(args map[string]any, def, max float64) oauthclient.Query {
	return oauthclient.Query{{"$top", integrations.Clamp(args["top"], def, 1, max)}}
}

func (p *provider) execute(ctx context.Context, name string, args map[string]any, tc *integrations.ToolContext) (any, error) {
	run := integrations.RunFrom(ctx)
	switch name {
	case "microsoft_365_outlook_list_messages":
		folder := strings.TrimSpace(orDefault(textOf(args["folder_id"]), "inbox"))
		path := "/v1.0/me/mailFolders/inbox/messages"
		if folder != "inbox" {
			path = "/v1.0/me/mailFolders/" + url.PathEscape(folder) + "/messages"
		}
		query := top(args, 10, 50)
		// Graph refuses $orderby next to $search; search results already come
		// newest first.
		if integrations.Truthy(args["query"]) {
			query = append(query, [2]string{"$search", `"` + strings.ReplaceAll(integrations.Str(args["query"]), `"`, `\"`) + `"`})
		} else {
			query = append(query, [2]string{"$orderby", "receivedDateTime desc"})
		}
		return p.graph(ctx, tc, graphCall{path: path, query: query})

	case "microsoft_365_outlook_send_mail":
		subject, err := integrations.RequireText(args["subject"], "subject")
		if err != nil {
			return nil, err
		}
		_, err = p.graph(ctx, tc, graphCall{method: "POST", path: "/v1.0/me/sendMail", body: map[string]any{
			"message": map[string]any{
				"subject":      subject,
				"body":         map[string]any{"contentType": "Text", "content": textOf(args["body_text"])},
				"toRecipients": emailRecipients(args["to"]),
				"ccRecipients": emailRecipients(args["cc"]),
			},
			"saveToSentItems": args["save_to_sent_items"] != false,
		}})
		if err != nil {
			return nil, err
		}
		return map[string]any{"sent": true}, nil

	case "microsoft_365_calendar_list_events":
		hasWindow := integrations.Truthy(args["start"]) && integrations.Truthy(args["end"])
		if run.Automatic() && !hasWindow {
			return nil, errors.New("Automatic calendar checks require both start and end. Query a bounded event-start window derived from the task schedule and requested reminder offset.")
		}
		query := top(args, 10, 50)
		path := "/v1.0/me/events"
		if hasWindow {
			path = "/v1.0/me/calendarView"
			query = append(query, [2]string{"startDateTime", integrations.Str(args["start"])}, [2]string{"endDateTime", integrations.Str(args["end"])})
		} else {
			query = append(query, [2]string{"$orderby", "start/dateTime"})
		}
		raw, err := p.graph(ctx, tc, graphCall{path: path, query: query, header: map[string]string{"Prefer": `outlook.timezone="UTC"`}})
		if err != nil {
			return nil, err
		}
		events := []calendarwindow.Summary{}
		if values, ok := integrations.Object(raw)["value"].([]any); ok {
			for _, v := range values {
				if m, ok := v.(map[string]any); ok {
					events = append(events, summarizeEvent(m))
				}
			}
		}
		return calendarwindow.Finalize(events, calendarwindow.Options{
			TimeMin: textOf(args["start"]), TimeMax: textOf(args["end"]),
			IncludeOngoing: args["include_ongoing"] == true, IncludeAllDay: args["include_all_day"] == true,
			AutomaticReminder: run.Automatic() && args["include_ongoing"] != true, ScheduledAt: run.ScheduledAt,
		}), nil

	case "microsoft_365_calendar_create_event":
		subject, err := integrations.RequireText(args["subject"], "subject")
		if err != nil {
			return nil, err
		}
		start, err := integrations.RequireText(args["start"], "start")
		if err != nil {
			return nil, err
		}
		end, err := integrations.RequireText(args["end"], "end")
		if err != nil {
			return nil, err
		}
		zone := orDefault(textOf(args["timezone"]), "UTC")
		attendees := []map[string]any{}
		for _, r := range emailRecipients(args["attendees"]) {
			r["type"] = "required"
			attendees = append(attendees, r)
		}
		return p.graph(ctx, tc, graphCall{method: "POST", path: "/v1.0/me/events", body: map[string]any{
			"subject":   subject,
			"body":      map[string]any{"contentType": "Text", "content": textOf(args["body_text"])},
			"start":     map[string]any{"dateTime": start, "timeZone": zone},
			"end":       map[string]any{"dateTime": end, "timeZone": zone},
			"attendees": attendees,
		}})

	case "microsoft_365_onedrive_list_children":
		path := "/v1.0/me/drive/root/children"
		if integrations.Truthy(args["item_id"]) {
			path = "/v1.0/me/drive/items/" + url.PathEscape(integrations.Str(args["item_id"])) + "/children"
		}
		return p.graph(ctx, tc, graphCall{path: path, query: top(args, 25, 200)})

	case "microsoft_365_teams_list_chats":
		return p.graph(ctx, tc, graphCall{path: "/v1.0/me/chats", query: top(args, 20, 50)})

	case "microsoft_365_teams_list_chat_messages":
		chat, err := integrations.RequireText(args["chat_id"], "chat_id")
		if err != nil {
			return nil, err
		}
		return p.graph(ctx, tc, graphCall{path: "/v1.0/me/chats/" + url.PathEscape(chat) + "/messages", query: top(args, 20, 50)})

	case "microsoft_365_teams_send_chat_message":
		chat, err := integrations.RequireText(args["chat_id"], "chat_id")
		if err != nil {
			return nil, err
		}
		content, err := integrations.RequireText(args["content"], "content")
		if err != nil {
			return nil, err
		}
		kind := "text"
		if strings.ToLower(orDefault(textOf(args["content_type"]), "text")) == "html" {
			kind = "html"
		}
		return p.graph(ctx, tc, graphCall{method: "POST", path: "/v1.0/chats/" + url.PathEscape(chat) + "/messages",
			body: map[string]any{"body": map[string]any{"contentType": kind, "content": content}}})
	}

	if graphToolName.MatchString(name) {
		if p.svc.Env("NEOAGENT_ENABLE_MICROSOFT_DYNAMIC_GRAPH_REQUEST") != "true" {
			return nil, errors.New("microsoft_365_*_graph_request tools are disabled by default. Set NEOAGENT_ENABLE_MICROSOFT_DYNAMIC_GRAPH_REQUEST=true to enable them.")
		}
		if run.Automatic() && strings.ToUpper(strings.TrimSpace(orDefault(textOf(args["method"]), "GET"))) == "GET" && calendarPath.MatchString(textOf(args["path"])) {
			return nil, errors.New("Automatic calendar checks must use microsoft_365_calendar_list_events with an explicit start and end window.")
		}
		path, err := integrations.RequireText(args["path"], "path")
		if err != nil {
			return nil, err
		}
		call := graphCall{method: textOf(args["method"]), path: path}
		if q, ok := args["query"].(map[string]any); ok {
			for _, k := range integrations.SortedKeys(q) {
				if q[k] != nil {
					call.query = append(call.query, [2]string{k, integrations.Str(q[k])})
				}
			}
		}
		if integrations.Truthy(args["body"]) {
			call.body = args["body"]
		}
		return p.graph(ctx, tc, call)
	}
	return nil, fmt.Errorf("Unknown tool: %s", name)
}
