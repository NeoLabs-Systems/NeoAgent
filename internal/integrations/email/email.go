// Package email is the Email & Calendar integration: mail over IMAP and SMTP
// with an app password, calendars and contacts over CalDAV and CardDAV, and
// read-only calendars from an iCal link.
package email

import (
	"context"
	_ "embed"
	"encoding/json"
	"errors"
	"fmt"
	"net/url"
	"regexp"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/dav"
)

//go:embed provider.json
var specJSON []byte

const (
	key   = "email"
	label = "Email & Calendar"
)

var (
	emailPattern = regexp.MustCompile(`^[^\s@]+@[^\s@]+\.[^\s@]+$`)
	whitespace   = regexp.MustCompile(`\s+`)
	appLabels    = map[string]string{"mail": "Mail", "calendar": "Calendar", "contacts": "Contacts", "calendar_feed": "Calendar link"}
)

func text(v any) string { return strings.TrimSpace(integrations.Str(v)) }

// Provider is the Email & Calendar integration.
type Provider struct {
	*integrations.AccountProvider
	svc *integrations.Services
}

// New builds the provider.
func New(svc *integrations.Services) *Provider {
	p := &Provider{svc: svc}
	p.AccountProvider = integrations.NewAccountProvider(svc, integrations.LoadSpec(specJSON), integrations.AccountHooks{
		Env: func(integrations.Scope) integrations.Env {
			return integrations.Env{Configured: true, Missing: []string{}, Summary: label + " connects with an app password from your mail provider.", SetupMode: "user"}
		},
		Execute: p.execute,
		Test: func(ctx context.Context, tc *integrations.ToolContext) error {
			if u := text(tc.Credentials["url"]); u != "" {
				_, err := p.fetchFeed(ctx, u)
				return err
			}
			a, err := accountOf(tc.Credentials)
			if err != nil {
				return err
			}
			return verifyMailbox(ctx, a)
		},
		Disconnect: func(ctx context.Context, tc *integrations.ToolContext) error {
			return p.svc.DeleteSiblingConnections(ctx, tc.Connection)
		},
	})
	return p
}

func accountOf(creds map[string]any) (account, error) {
	raw, err := json.Marshal(creds)
	if err != nil {
		return account{}, err
	}
	var a account
	err = json.Unmarshal(raw, &a)
	return a, err
}

func davAuth(a account) dav.Auth { return dav.Auth{Username: a.Username, Password: a.Password} }

func (p *Provider) execute(ctx context.Context, name string, args map[string]any, tc *integrations.ToolContext) (any, error) {
	if text(tc.Credentials["url"]) != "" {
		if out, ok, err := p.feedTool(ctx, name, args, tc.Credentials); ok {
			return out, err
		}
		return nil, fmt.Errorf("Unsupported %s tool: %s", label, name)
	}
	a, err := accountOf(tc.Credentials)
	if err != nil {
		return nil, err
	}
	if out, ok, err := mailTool(ctx, name, args, a); ok {
		return out, err
	}
	client := p.svc.SelfHostedClient("DAV server")
	if a.CalDAV != nil {
		store := dav.NewStore(client, dav.Location{Origin: a.CalDAV.Origin, Home: a.CalDAV.Home}, davAuth(a))
		if out, ok, err := dav.Calendar(ctx, "caldav", name, args, store); ok {
			return out, err
		}
	}
	if a.CardDAV != nil {
		store := dav.NewStore(client, dav.Location{Origin: a.CardDAV.Origin, Home: a.CardDAV.Home}, davAuth(a))
		if out, ok, err := dav.Contacts(ctx, "carddav", name, args, store); ok {
			return out, err
		}
	}
	return nil, fmt.Errorf("Unsupported %s tool: %s", label, name)
}

// ---- setup ---------------------------------------------------------------------

// SetupConfig lists the providers to pick from and the accounts so far.
func (p *Provider) SetupConfig(ctx context.Context, scope integrations.Scope) (any, error) {
	rows, err := p.svc.DB.R.QueryContext(ctx, `SELECT app_key, account_email, metadata_json FROM integration_connections
		WHERE user_id=? AND agent_id=? AND provider_key=? AND status='connected' ORDER BY account_email`, scope.UserID, scope.AgentID, key)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	type acct struct {
		email  string
		preset any
		apps   []string
	}
	var order []string
	accounts := map[string]*acct{}
	for rows.Next() {
		var app, email string
		var meta *string
		if err := rows.Scan(&app, &email, &meta); err != nil {
			return nil, err
		}
		a, ok := accounts[email]
		if !ok {
			var m map[string]any
			if meta != nil {
				_ = json.Unmarshal([]byte(*meta), &m)
			}
			a = &acct{email: email, preset: m["preset"]}
			if !dyn.Truthy(a.preset) {
				a.preset = nil
			}
			accounts[email] = a
			order = append(order, email)
		}
		appLabel := appLabels[app]
		if appLabel == "" {
			appLabel = app
		}
		a.apps = append(a.apps, appLabel)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	list := make([]dyn.Ordered, 0, len(order))
	for _, email := range order {
		a := accounts[email]
		list = append(list, dyn.Ordered{{Key: "email", Value: a.email}, {Key: "preset", Value: a.preset}, {Key: "apps", Value: a.apps}})
	}
	clients := make([]dyn.Ordered, len(presets))
	for i, pr := range presets {
		clients[i] = pr.forClient()
	}
	return dyn.Ordered{{Key: "presets", Value: clients}, {Key: "accounts", Value: list}}, nil
}

// SaveSetup connects an account: it signs in once, discovers the calendar
// and address book homes, and stores one row per app.
func (p *Provider) SaveSetup(ctx context.Context, scope integrations.Scope, config map[string]any) (any, error) {
	if pr := findPreset(config["preset"]); pr != nil && pr.feed {
		return p.saveFeed(ctx, scope, config)
	}
	pr := findPreset(config["preset"])
	if pr == nil {
		return nil, errors.New("Choose your mail provider.")
	}
	if pr.unsupported {
		return nil, errors.New(pr.help)
	}
	email := strings.ToLower(text(config["email"]))
	if !emailPattern.MatchString(email) {
		return nil, errors.New("Enter a valid email address.")
	}
	rawPassword, err := integrations.RequireText(config["password"], "App password")
	if err != nil {
		return nil, err
	}
	a := account{Email: email, Username: text(config["username"]), Password: rawPassword, IMAP: pr.imap, SMTP: pr.smtp, SavesSentMail: pr.savesSentMail}
	if a.Username == "" {
		a.Username = email
	}
	caldavURL, carddavURL := pr.caldavURL, pr.carddavURL
	if pr.custom {
		if a.IMAP, err = parseServer(config["imap"], "imap"); err != nil {
			return nil, err
		}
		if a.SMTP, err = parseServer(config["smtp"], "smtp"); err != nil {
			return nil, err
		}
		caldavURL, carddavURL = text(config["caldavUrl"]), text(config["carddavUrl"])
	} else {
		// Providers display app passwords in groups; the spaces are not part of it.
		a.Password = whitespace.ReplaceAllString(rawPassword, "")
	}
	if config["calendar"] == false {
		caldavURL = ""
	}
	if config["contacts"] == false {
		carddavURL = ""
	}
	if err := verifyMailbox(ctx, a); err != nil {
		return nil, err
	}
	client := p.svc.SelfHostedClient("DAV server")
	for _, d := range []struct {
		url  string
		kind string
		dest **location
	}{{caldavURL, "caldav", &a.CalDAV}, {carddavURL, "carddav", &a.CardDAV}} {
		if d.url == "" {
			continue
		}
		loc, err := dav.Discover(ctx, client, d.url, d.kind, davAuth(a))
		if err != nil {
			return nil, err
		}
		*d.dest = &location{Origin: loc.Origin, Home: loc.Home}
	}
	creds, err := credentialsOf(a)
	if err != nil {
		return nil, err
	}
	apps := []string{"mail"}
	if a.CalDAV != nil {
		apps = append(apps, "calendar")
	}
	if a.CardDAV != nil {
		apps = append(apps, "contacts")
	}
	for _, app := range apps {
		if _, err := p.svc.UpsertAccountApp(ctx, integrations.AccountApp{Scope: scope, ProviderKey: key, AppKey: app, AccountEmail: email,
			Scopes: []string{app}, Credentials: creds, Metadata: map[string]any{"preset": pr.id}}); err != nil {
			return nil, err
		}
	}
	placeholders := strings.TrimSuffix(strings.Repeat("?,", len(apps)), ",")
	params := []any{scope.UserID, scope.AgentID, key, email}
	for _, app := range apps {
		params = append(params, app)
	}
	if _, err := p.svc.DB.W.ExecContext(ctx, `DELETE FROM integration_connections
		WHERE user_id=? AND agent_id=? AND provider_key=? AND account_email=? AND app_key NOT IN (`+placeholders+`)`, params...); err != nil {
		return nil, err
	}
	return p.SetupConfig(ctx, scope)
}

// credentialsOf is the stored credentials object, in Node's member order.
func credentialsOf(a account) (map[string]any, error) {
	raw, err := json.Marshal(a)
	if err != nil {
		return nil, err
	}
	return integrations.ParseCredentials(string(raw)), nil
}

func (p *Provider) saveFeed(ctx context.Context, scope integrations.Scope, config map[string]any) (any, error) {
	feedURL, err := normalizeFeedURL(config["url"])
	if err != nil {
		return nil, err
	}
	cal, err := p.fetchFeed(ctx, feedURL)
	if err != nil {
		return nil, err
	}
	name := text(config["name"])
	if name == "" {
		name = calendarName(cal)
	}
	if name == "" {
		u, _ := url.Parse(feedURL)
		name = u.Hostname()
	}
	if _, err := p.svc.UpsertAccountApp(ctx, integrations.AccountApp{Scope: scope, ProviderKey: key, AppKey: "calendar_feed", AccountEmail: name,
		Scopes: []string{"ical:read"}, Credentials: map[string]any{"url": feedURL, "name": name}, Metadata: map[string]any{"preset": "ical"}}); err != nil {
		return nil, err
	}
	return p.SetupConfig(ctx, scope)
}
