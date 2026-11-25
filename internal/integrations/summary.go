package integrations

import (
	"encoding/json"
	"fmt"
	"sort"
	"strings"
)

// Env says whether an integration can connect accounts yet.
type Env struct {
	Configured   bool     `json:"configured"`
	Missing      []string `json:"missing"`
	Summary      string   `json:"summary"`
	SetupMode    string   `json:"setupMode,omitempty"`
	Alternatives []string `json:"alternatives,omitzero"`
}

// AccountSnapshot is one connected (or connectable) account.
type AccountSnapshot struct {
	ID                     *int64  `json:"id"`
	Status                 string  `json:"status"`
	Connected              bool    `json:"connected"`
	AccountEmail           *string `json:"accountEmail"`
	LastConnectedAt        *string `json:"lastConnectedAt"`
	AccessMode             string  `json:"accessMode"`
	SupportsConnectionTest bool    `json:"supportsConnectionTest"`
}

// AppConnection rolls an app's accounts up.
type AppConnection struct {
	Status       string  `json:"status"`
	Connected    bool    `json:"connected"`
	AccountCount int     `json:"accountCount"`
	AccountEmail *string `json:"accountEmail"`
	// AppCount is set by single-app providers whose app reports it (Bitwarden).
	AppCount        *int    `json:"appCount,omitempty"`
	LastConnectedAt *string `json:"lastConnectedAt"`
}

// AppSnapshot is one app with its accounts.
type AppSnapshot struct {
	ID                     string            `json:"id"`
	Label                  string            `json:"label"`
	Description            string            `json:"description"`
	Accounts               []AccountSnapshot `json:"accounts"`
	Connection             AppConnection     `json:"connection"`
	AvailableToolCount     int               `json:"availableToolCount"`
	SupportsConnectionTest bool              `json:"supportsConnectionTest"`
}

// ProviderConnection rolls a provider's apps up.
type ProviderConnection struct {
	Status          string  `json:"status"`
	Connected       bool    `json:"connected"`
	AccountEmail    *string `json:"accountEmail"`
	AccountCount    int     `json:"accountCount"`
	AppCount        int     `json:"appCount"`
	LastConnectedAt *string `json:"lastConnectedAt"`
}

// Snapshot is what the apps show for one provider.
type Snapshot struct {
	ID                     string
	Label                  string
	Description            string
	Icon                   string
	Apps                   []AppSnapshot
	Env                    Env
	Connection             ProviderConnection
	AvailableToolCount     int
	SupportsConnectionTest bool
	// Extra are further members of the object (connectPrompt, memoryCoverage).
	Extra map[string]any
	// Decorated, when set, is the whole snapshot as other domains completed it
	// (memory coverage); it replaces the fields above in JSON.
	Decorated json.RawMessage
}

// extraOrder is where the optional members sit, as clients have always
// received them: after availableToolCount, before supportsConnectionTest,
// with memoryCoverage last.
var extraOrder = []string{"credentialBindingsSummary", "connectPrompt", "supportsMultipleAccounts", "connectionMethod", "signInCoversAllApps"}

// MarshalJSON writes the members in the order clients have always received.
func (s Snapshot) MarshalJSON() ([]byte, error) {
	if len(s.Decorated) > 0 {
		return s.Decorated, nil
	}
	var b strings.Builder
	first := true
	write := func(key string, v any) error {
		raw, err := json.Marshal(v)
		if err != nil {
			return err
		}
		if !first {
			b.WriteByte(',')
		}
		first = false
		k, _ := json.Marshal(key)
		b.Write(k)
		b.WriteByte(':')
		b.Write(raw)
		return nil
	}
	b.WriteByte('{')
	fixed := []struct {
		k string
		v any
	}{{"id", s.ID}, {"label", s.Label}, {"description", s.Description}}
	for _, f := range fixed {
		if err := write(f.k, f.v); err != nil {
			return nil, err
		}
	}
	if s.Icon != "" {
		if err := write("icon", s.Icon); err != nil {
			return nil, err
		}
	}
	apps := s.Apps
	if apps == nil {
		apps = []AppSnapshot{}
	}
	for _, f := range []struct {
		k string
		v any
	}{{"apps", apps}, {"env", s.Env}, {"connection", s.Connection}, {"availableToolCount", s.AvailableToolCount}} {
		if err := write(f.k, f.v); err != nil {
			return nil, err
		}
	}
	done := map[string]bool{}
	for _, k := range extraOrder {
		if v, ok := s.Extra[k]; ok {
			if err := write(k, v); err != nil {
				return nil, err
			}
			done[k] = true
		}
	}
	rest := make([]string, 0, len(s.Extra))
	for k := range s.Extra {
		if !done[k] && k != "memoryCoverage" {
			rest = append(rest, k)
		}
	}
	sort.Strings(rest)
	for _, k := range rest {
		if err := write(k, s.Extra[k]); err != nil {
			return nil, err
		}
	}
	if err := write("supportsConnectionTest", s.SupportsConnectionTest); err != nil {
		return nil, err
	}
	if v, ok := s.Extra["memoryCoverage"]; ok {
		if err := write("memoryCoverage", v); err != nil {
			return nil, err
		}
	}
	b.WriteByte('}')
	return []byte(b.String()), nil
}

func nonEmpty(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

// sortConnections orders rows by account email, newest first within one.
func sortConnections(rows []Connection) []Connection {
	out := append([]Connection(nil), rows...)
	sort.SliceStable(out, func(i, j int) bool {
		li, lj := strings.ToLower(out[i].AccountEmail), strings.ToLower(out[j].AccountEmail)
		if li != lj {
			return li < lj
		}
		return out[i].UpdatedAt > out[j].UpdatedAt
	})
	return out
}

func summarizeAccountRow(row *Connection, env Env) AccountSnapshot {
	if !env.Configured {
		acc := AccountSnapshot{Status: "env_not_configured", AccessMode: AccessMode(row)}
		if row != nil {
			id := row.ID
			acc.ID, acc.AccountEmail, acc.LastConnectedAt = &id, nonEmpty(row.AccountEmail), nonEmpty(row.LastConnectedAt)
		}
		return acc
	}
	if row == nil {
		return AccountSnapshot{Status: "not_connected", AccessMode: AccessReadWrite}
	}
	id := row.ID
	status := row.Status
	if status == "" {
		status = "not_connected"
	}
	return AccountSnapshot{
		ID: &id, Status: status, Connected: row.Status == "connected",
		AccountEmail: nonEmpty(row.AccountEmail), LastConnectedAt: nonEmpty(row.LastConnectedAt),
		AccessMode: AccessMode(row),
	}
}

func latest(accounts []AccountSnapshot) *string {
	var best string
	for _, a := range accounts {
		if a.LastConnectedAt != nil && *a.LastConnectedAt > best {
			best = *a.LastConnectedAt
		}
	}
	return nonEmpty(best)
}

func connectedOnly(accounts []AccountSnapshot) []AccountSnapshot {
	var out []AccountSnapshot
	for _, a := range accounts {
		if a.Connected {
			out = append(out, a)
		}
	}
	return out
}

// SummarizeApp builds an app's snapshot; toolCount is the number of tools the
// app offers once connected.
func SummarizeApp(app App, rows []Connection, env Env, toolCount int) AppSnapshot {
	accounts := []AccountSnapshot{}
	for _, row := range sortConnections(rows) {
		row := row
		accounts = append(accounts, summarizeAccountRow(&row, env))
	}
	connected := connectedOnly(accounts)
	status := "not_connected"
	switch {
	case !env.Configured:
		status = "env_not_configured"
	case len(connected) > 0:
		status = "connected"
	default:
		for _, a := range accounts {
			if a.Status == "authorizing" {
				status = "authorizing"
			}
		}
	}
	snap := AppSnapshot{
		ID: app.ID, Label: app.Label, Description: app.Description, Accounts: accounts,
		Connection: AppConnection{Status: status, Connected: len(connected) > 0, AccountCount: len(connected), LastConnectedAt: latest(connected)},
	}
	if len(connected) == 1 {
		snap.Connection.AccountEmail = connected[0].AccountEmail
	}
	if env.Configured && len(connected) > 0 {
		snap.AvailableToolCount = toolCount
	}
	return snap
}

// SummarizeProvider rolls the apps up into the provider card's connection.
func SummarizeProvider(apps []AppSnapshot, env Env) (ProviderConnection, int) {
	var connectedApps int
	var accounts []AccountSnapshot
	tools := 0
	for _, app := range apps {
		tools += app.AvailableToolCount
		if app.Connection.Connected {
			connectedApps++
			accounts = append(accounts, connectedOnly(app.Accounts)...)
		}
	}
	status := "not_connected"
	switch {
	case !env.Configured:
		status = "env_not_configured"
	case len(accounts) > 0:
		status = "connected"
	}
	conn := ProviderConnection{Status: status, Connected: len(accounts) > 0, AccountCount: len(accounts), AppCount: connectedApps, LastConnectedAt: latest(accounts)}
	if len(accounts) == 1 {
		conn.AccountEmail = accounts[0].AccountEmail
	}
	return conn, tools
}

// ConnectedAppSummary is one line naming every connected account.
func ConnectedAppSummary(apps []AppSnapshot) string {
	var parts []string
	for _, app := range apps {
		if !app.Connection.Connected {
			continue
		}
		var emails []string
		for _, a := range connectedOnly(app.Accounts) {
			if a.AccountEmail != nil {
				emails = append(emails, *a.AccountEmail)
			} else {
				emails = append(emails, fmt.Sprintf("connection %d", *a.ID))
			}
		}
		parts = append(parts, app.Label+": "+strings.Join(emails, ", "))
	}
	return strings.Join(parts, " | ")
}

// FormatAccountSummary is how an app's accounts stand, in one phrase.
func FormatAccountSummary(app AppSnapshot) string {
	var emails []string
	for _, a := range connectedOnly(app.Accounts) {
		if a.AccountEmail != nil {
			emails = append(emails, *a.AccountEmail)
		} else {
			emails = append(emails, fmt.Sprintf("connection %d", *a.ID))
		}
	}
	switch len(emails) {
	case 0:
		return "no connected accounts"
	case 1:
		return "connected as " + emails[0]
	}
	return fmt.Sprintf("connected with %d accounts: %s", len(emails), strings.Join(emails, ", "))
}

// DescribeIncompleteSetup is what the model tells someone who asks for an
// integration that is not set up.
func DescribeIncompleteSetup(label string, env Env) string {
	if env.SetupMode == "user" {
		return label + ": setup is user-managed and is not complete yet. If the user wants to use it, tell them to open Official Integrations and finish setup in their account first."
	}
	return label + ": workspace setup is not complete yet. If the user wants to use it, tell them to open Official Integrations and ask an administrator to finish setup first."
}
