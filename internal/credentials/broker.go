package credentials

import (
	"context"
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"regexp"
	"strings"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/secretbox"
)

const (
	protectedFillTTL = 5 * time.Minute
	maxResponseBytes = 512 * 1024
)

var (
	allowedMethods   = map[string]bool{"GET": true, "POST": true, "PUT": true, "PATCH": true, "DELETE": true}
	allowedAuthTypes = map[string]bool{"bearer": true, "basic": true, "header": true}
	pathPrefixDots   = regexp.MustCompile(`(?:^|/)\.\.?($|/)`)
	encodedPathBytes = regexp.MustCompile(`(?i)%(?:2e|2f|5c)`)
	headerNamePart   = regexp.MustCompile(`^[A-Za-z0-9-]+$`)
)

// Vault is the Bitwarden driver (services/credentials/bitwarden_cli.js).
type Vault interface {
	Sync(ctx context.Context, userID int64, agentID string) error
	ListItems(ctx context.Context, userID int64, agentID string) ([]Item, error)
	GetItem(ctx context.Context, userID int64, agentID, itemRef string) (Item, error)
}

// Agents resolves the agent a request is about; agentscope.Resolver does.
type Agents interface {
	Resolve(ctx context.Context, userID int64, candidate string) (string, error)
}

// Config wires the broker.
type Config struct {
	DB     *dbx.DB
	Box    *secretbox.Box
	Agents Agents
	Vault  Vault
	// Requester sends the bound HTTP requests. It must refuse private
	// addresses (services/network/safe_request.js does).
	Requester Requester
	// Browsers is set when the runtime is ready; see SetBrowsers.
	Browsers Browsers
	Now      func() time.Time
}

// Broker holds credential bindings and brokers their use.
type Broker struct {
	db        *dbx.DB
	box       *secretbox.Box
	agents    Agents
	vault     Vault
	requester Requester
	now       func() time.Time

	mu       sync.Mutex
	browsers Browsers
	fills    map[string]protectedFill
}

type protectedFill struct {
	userID    int64
	agentID   string
	bindingID string
	expiresAt time.Time
}

// New builds the broker.
func New(cfg Config) *Broker {
	now := cfg.Now
	if now == nil {
		now = time.Now
	}
	return &Broker{
		db: cfg.DB, box: cfg.Box, agents: cfg.Agents, vault: cfg.Vault, requester: cfg.Requester,
		browsers: cfg.Browsers, now: now, fills: map[string]protectedFill{},
	}
}

// SetBrowsers hands the broker the runtime that owns the browsers, which
// starts after the broker does.
func (b *Broker) SetBrowsers(browsers Browsers) {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.browsers = browsers
}

type scope struct {
	userID  int64
	agentID string
}

func (b *Broker) scope(ctx context.Context, userID int64, agentID string) (scope, error) {
	if userID <= 0 {
		return scope{}, errors.New("A valid user is required.")
	}
	id, err := b.agents.Resolve(ctx, userID, agentID)
	if err != nil {
		return scope{}, err
	}
	return scope{userID: userID, agentID: id}, nil
}

func newUUID() string {
	var raw [16]byte
	_, _ = rand.Read(raw[:])
	raw[6] = raw[6]&0x0f | 0x40
	raw[8] = raw[8]&0x3f | 0x80
	h := hex.EncodeToString(raw[:])
	return h[:8] + "-" + h[8:12] + "-" + h[12:16] + "-" + h[16:20] + "-" + h[20:]
}

func normalizeHTTPSOrigin(value any) (string, error) {
	text, err := requireText(value, "Origin")
	if err != nil {
		return "", err
	}
	u, err := parseURL(text)
	if err != nil {
		return "", err
	}
	if u.Scheme != "https" || u.User != nil {
		return "", errors.New("Credential targets must use an HTTPS origin without embedded credentials.")
	}
	return origin(u), nil
}

func normalizePathPrefix(value any) (string, error) {
	text := "/"
	if truthy(value) {
		if t := jsTrim(jsString(value)); t != "" {
			text = t
		}
	}
	if !strings.HasPrefix(text, "/") || strings.Contains(text, `\`) || pathPrefixDots.MatchString(text) || encodedPathBytes.MatchString(text) {
		return "", errors.New("Credential API path prefixes must start with /.")
	}
	return text, nil
}

func pathMatchesPrefix(pathname, prefix string) bool {
	if prefix == "/" {
		return true
	}
	normalized := strings.TrimSuffix(prefix, "/")
	return pathname == normalized || strings.HasPrefix(pathname, normalized+"/")
}

// fieldConfig is the sealed field_config_encrypted column. Browser bindings
// name the username and password fields, HTTP bindings the secret field.
type fieldConfig struct {
	SecretField   string  `json:"secretField,omitempty"`
	UsernameField *string `json:"usernameField,omitempty"`
	PasswordField string  `json:"passwordField,omitempty"`
}

// browserFieldConfig and httpFieldConfig keep Node's key order and its nulls.
type browserFieldConfig struct {
	UsernameField string `json:"usernameField"`
	PasswordField string `json:"passwordField"`
}

type httpFieldConfig struct {
	SecretField   string  `json:"secretField"`
	UsernameField *string `json:"usernameField"`
}

// targetConfig is the target_config_json column.
type targetConfig struct {
	Origins    []string `json:"origins,omitempty"`
	Origin     string   `json:"origin,omitempty"`
	PathPrefix string   `json:"pathPrefix,omitempty"`
	Methods    []string `json:"methods,omitempty"`
	AuthType   string   `json:"authType,omitempty"`
	HeaderName string   `json:"headerName,omitempty"`
}

type browserTarget struct {
	Origins []string `json:"origins"`
}

type httpTarget struct {
	Origin     string   `json:"origin"`
	PathPrefix string   `json:"pathPrefix"`
	Methods    []string `json:"methods"`
	AuthType   string   `json:"authType"`
	HeaderName *string  `json:"headerName"`
}

type row struct {
	id, providerKey, alias, usageType string
	connectionID                      int64
	itemRef, fieldConfig, target      string
	createdAt, updatedAt              sql.NullString
}

const bindingColumns = `id, provider_key, connection_id, alias, usage_type, item_ref_encrypted, field_config_encrypted, target_config_json, created_at, updated_at`

func scanRow(s interface{ Scan(...any) error }) (row, error) {
	var r row
	err := s.Scan(&r.id, &r.providerKey, &r.connectionID, &r.alias, &r.usageType, &r.itemRef, &r.fieldConfig, &r.target, &r.createdAt, &r.updatedAt)
	return r, err
}

func (b *Broker) bindingRow(ctx context.Context, sc scope, bindingID string) (*row, error) {
	r, err := scanRow(b.db.W.QueryRowContext(ctx, `SELECT `+bindingColumns+` FROM credential_bindings
		WHERE id = ? AND user_id = ? AND agent_id = ?`, bindingID, sc.userID, sc.agentID))
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &r, nil
}

// binding is a stored binding with its sealed parts opened.
type binding struct {
	row
	itemRefPlain string
	fields       fieldConfig
	targetConfig targetConfig
}

func (b *Broker) decode(r *row) (*binding, error) {
	if r == nil {
		return nil, nil
	}
	ref, err := b.box.Open(r.itemRef)
	if err != nil {
		return nil, err
	}
	fields, err := b.box.Open(r.fieldConfig)
	if err != nil {
		return nil, err
	}
	out := &binding{row: *r, itemRefPlain: ref}
	_ = json.Unmarshal([]byte(fields), &out.fields)
	_ = json.Unmarshal([]byte(r.target), &out.targetConfig)
	return out, nil
}

// Binding is what a binding looks like to its owner.
type Binding struct {
	ID          string  `json:"id"`
	Alias       string  `json:"alias"`
	ProviderKey string  `json:"providerKey"`
	UsageType   string  `json:"usageType"`
	Target      any     `json:"target"`
	CreatedAt   *string `json:"createdAt"`
	UpdatedAt   *string `json:"updatedAt"`
}

type publicBrowserTarget struct {
	Origins []string `json:"origins"`
}

type publicHTTPTarget struct {
	Origin     *string  `json:"origin,omitempty"`
	PathPrefix *string  `json:"pathPrefix,omitempty"`
	Methods    []string `json:"methods"`
	AuthType   *string  `json:"authType,omitempty"`
	HeaderName *string  `json:"headerName,omitempty"`
}

func optional(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

func nullable(s sql.NullString) *string {
	if !s.Valid {
		return nil
	}
	return &s.String
}

func (b *Broker) public(r *row) (*Binding, error) {
	d, err := b.decode(r)
	if err != nil || d == nil {
		return nil, err
	}
	out := &Binding{
		ID: d.id, Alias: d.alias, ProviderKey: d.providerKey, UsageType: d.usageType,
		CreatedAt: nullable(d.createdAt), UpdatedAt: nullable(d.updatedAt),
	}
	t := d.targetConfig
	if d.usageType == "browser" {
		out.Target = publicBrowserTarget{Origins: orEmpty(t.Origins)}
		return out, nil
	}
	target := publicHTTPTarget{Origin: optional(t.Origin), PathPrefix: optional(t.PathPrefix), Methods: orEmpty(t.Methods), AuthType: optional(t.AuthType)}
	if t.AuthType == "header" {
		target.HeaderName = optional(t.HeaderName)
	}
	out.Target = target
	return out, nil
}

func orEmpty(l []string) []string {
	if l == nil {
		return []string{}
	}
	return l
}

// ListBindings are the agent's bindings, by alias.
func (b *Broker) ListBindings(ctx context.Context, userID int64, agentID string) ([]Binding, error) {
	sc, err := b.scope(ctx, userID, agentID)
	if err != nil {
		return nil, err
	}
	rows, err := b.db.W.QueryContext(ctx, `SELECT `+bindingColumns+` FROM credential_bindings
		WHERE user_id = ? AND agent_id = ? ORDER BY lower(alias), created_at`, sc.userID, sc.agentID)
	if err != nil {
		return nil, err
	}
	var stored []row
	for rows.Next() {
		r, err := scanRow(rows)
		if err != nil {
			rows.Close()
			return nil, err
		}
		stored = append(stored, r)
	}
	if err := rows.Close(); err != nil {
		return nil, err
	}
	out := []Binding{}
	for i := range stored {
		p, err := b.public(&stored[i])
		if err != nil {
			return nil, err
		}
		out = append(out, *p)
	}
	return out, nil
}

// ListVaultItems syncs the vault and lists its items without their secrets.
func (b *Broker) ListVaultItems(ctx context.Context, userID int64, agentID string) ([]SafeItem, error) {
	sc, err := b.scope(ctx, userID, agentID)
	if err != nil {
		return nil, err
	}
	if err := b.vault.Sync(ctx, sc.userID, sc.agentID); err != nil {
		return nil, err
	}
	items, err := b.vault.ListItems(ctx, sc.userID, sc.agentID)
	if err != nil {
		return nil, err
	}
	out := []SafeItem{}
	for _, item := range items {
		if s := sanitizeItem(item); s.ID != "" {
			out = append(out, s)
		}
	}
	return out, nil
}

// values are a binding about to be stored.
type values struct {
	alias, usageType string
	connectionID     int64
	itemRef          string
	fieldConfig      any
	targetConfig     any
}

func (b *Broker) bindingValues(ctx context.Context, sc scope, input map[string]any) (*values, error) {
	alias, err := requireText(input["alias"], "Binding alias")
	if err != nil {
		return nil, err
	}
	alias = truncate(alias, 120)
	usageType := trimText(input["usageType"])
	if usageType != "browser" && usageType != "http" {
		return nil, errors.New("Binding usageType must be browser or http.")
	}
	connNumber := toNumber(input["connectionId"])
	if math.IsNaN(connNumber) || math.IsInf(connNumber, 0) || connNumber != math.Trunc(connNumber) || connNumber <= 0 {
		return nil, errors.New("A connected Bitwarden account is required.")
	}
	connectionID := int64(connNumber)
	var found int64
	err = b.db.W.QueryRowContext(ctx, `SELECT id FROM integration_connections
		WHERE id = ? AND user_id = ? AND agent_id = ? AND provider_key = 'bitwarden' AND status = 'connected'`,
		connectionID, sc.userID, sc.agentID).Scan(&found)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, errors.New("The Bitwarden connection was not found.")
	}
	if err != nil {
		return nil, err
	}
	itemRef, err := requireText(input["itemId"], "Bitwarden item")
	if err != nil {
		return nil, err
	}
	item, err := b.vault.GetItem(ctx, sc.userID, sc.agentID, itemRef)
	if err != nil {
		return nil, err
	}
	out := &values{alias: alias, usageType: usageType, connectionID: connectionID, itemRef: itemRef}
	if usageType == "browser" {
		return out, b.browserValues(out, item, input)
	}
	return out, httpValues(out, item, input)
}

func truncate(s string, units int) string {
	if utf16Len(s) <= units {
		return s
	}
	return utf16Slice(s, 0, units)
}

func (b *Broker) browserValues(out *values, item Item, input map[string]any) error {
	available := itemOrigins(item)
	var requested []string
	if l, ok := input["origins"].([]any); ok {
		for _, o := range l {
			n, err := normalizeHTTPSOrigin(o)
			if err != nil {
				return err
			}
			requested = append(requested, n)
		}
	}
	origins := requested
	if len(origins) == 0 {
		origins = available
	}
	ok := len(origins) > 0
	for _, o := range origins {
		if !contains(available, o) {
			ok = false
		}
	}
	if !ok {
		return errors.New("Browser credential origins must be selected from HTTPS URIs saved on the Bitwarden item.")
	}
	if readItemField(item, "login.password") == "" {
		return errors.New("The selected Bitwarden item does not contain a login password.")
	}
	out.fieldConfig = browserFieldConfig{UsernameField: "login.username", PasswordField: "login.password"}
	out.targetConfig = browserTarget{Origins: sortedUnique(origins)}
	return nil
}

func httpValues(out *values, item Item, input map[string]any) error {
	authType := strings.ToLower(trimText(input["authType"]))
	if !allowedAuthTypes[authType] {
		return errors.New("HTTP authType must be bearer, basic, or header.")
	}
	secretField, err := requireText(input["secretField"], "Secret field")
	if err != nil {
		return err
	}
	if readItemField(item, secretField) == "" {
		return errors.New("The selected Bitwarden secret field is empty.")
	}
	origin, err := normalizeHTTPSOrigin(input["origin"])
	if err != nil {
		return err
	}
	pathPrefix, err := normalizePathPrefix(input["pathPrefix"])
	if err != nil {
		return err
	}
	rawMethods := []any{"GET"}
	if l, ok := input["methods"].([]any); ok {
		rawMethods = l
	}
	var methods []string
	for _, m := range rawMethods {
		method := strings.ToUpper(jsTrimNone(m))
		if allowedMethods[method] && !contains(methods, method) {
			methods = append(methods, method)
		}
	}
	if len(methods) == 0 {
		return errors.New("At least one supported HTTP method is required.")
	}
	var headerName *string
	if authType == "header" {
		name, err := requireText(input["headerName"], "Header name")
		if err != nil {
			return err
		}
		headerName = &name
	}
	if headerName != nil && !headerNamePart.MatchString(*headerName) {
		return errors.New("Credential header names may contain only letters, numbers, and hyphens.")
	}
	if headerName != nil {
		switch strings.ToLower(*headerName) {
		case "authorization", "cookie", "set-cookie":
			return errors.New("Use bearer or basic authentication for reserved authentication headers.")
		}
	}
	var usernameField *string
	if authType == "basic" {
		name, err := requireText(input["usernameField"], "Username field")
		if err != nil {
			return err
		}
		usernameField = &name
	}
	out.fieldConfig = httpFieldConfig{SecretField: secretField, UsernameField: usernameField}
	out.targetConfig = httpTarget{Origin: origin, PathPrefix: pathPrefix, Methods: methods, AuthType: authType, HeaderName: headerName}
	return nil
}

// jsTrimNone is String(value || ”) without the trim.
func jsTrimNone(v any) string {
	if !truthy(v) {
		return ""
	}
	return jsString(v)
}

func contains(l []string, s string) bool {
	for _, e := range l {
		if e == s {
			return true
		}
	}
	return false
}

func sortedUnique(l []string) []string {
	out := []string{}
	for _, s := range l {
		if !contains(out, s) {
			out = append(out, s)
		}
	}
	sortStrings(out)
	return out
}

// sealed returns the three stored forms of a binding's secrets.
func (b *Broker) sealed(v *values) (item, fields, target string, err error) {
	if item, err = b.box.Seal(v.itemRef); err != nil {
		return
	}
	raw, err := json.Marshal(v.fieldConfig)
	if err != nil {
		return
	}
	if fields, err = b.box.Seal(string(raw)); err != nil {
		return
	}
	t, err := json.Marshal(v.targetConfig)
	return item, fields, string(t), err
}

// CreateBinding binds a vault item.
func (b *Broker) CreateBinding(ctx context.Context, userID int64, agentID string, input map[string]any) (*Binding, error) {
	sc, err := b.scope(ctx, userID, agentID)
	if err != nil {
		return nil, err
	}
	v, err := b.bindingValues(ctx, sc, input)
	if err != nil {
		return nil, err
	}
	item, fields, target, err := b.sealed(v)
	if err != nil {
		return nil, err
	}
	id := newUUID()
	_, err = b.db.W.ExecContext(ctx, `INSERT INTO credential_bindings (
		id, user_id, agent_id, provider_key, connection_id, alias, usage_type,
		item_ref_encrypted, field_config_encrypted, target_config_json
	) VALUES (?, ?, ?, 'bitwarden', ?, ?, ?, ?, ?, ?)`,
		id, sc.userID, sc.agentID, v.connectionID, v.alias, v.usageType, item, fields, target)
	if err != nil {
		return nil, err
	}
	return b.reload(ctx, sc, id)
}

func (b *Broker) reload(ctx context.Context, sc scope, id string) (*Binding, error) {
	r, err := b.bindingRow(ctx, sc, id)
	if err != nil {
		return nil, err
	}
	return b.public(r)
}

// UpdateBinding changes a binding; what the input leaves out stays.
func (b *Broker) UpdateBinding(ctx context.Context, userID int64, agentID, bindingID string, input map[string]any) (*Binding, error) {
	sc, err := b.scope(ctx, userID, agentID)
	if err != nil {
		return nil, err
	}
	r, err := b.bindingRow(ctx, sc, bindingID)
	if err != nil {
		return nil, err
	}
	current, err := b.decode(r)
	if err != nil {
		return nil, err
	}
	if current == nil {
		return nil, errors.New("Credential binding not found.")
	}
	t := current.targetConfig
	merged := map[string]any{
		"alias":         firstSet(input["alias"], current.alias),
		"usageType":     firstSet(input["usageType"], current.usageType),
		"connectionId":  firstSet(input["connectionId"], float64(current.connectionID)),
		"itemId":        firstSet(input["itemId"], current.itemRefPlain),
		"origins":       firstSet(input["origins"], stringsToAny(t.Origins)),
		"origin":        firstSet(input["origin"], nilIfEmpty(t.Origin)),
		"pathPrefix":    firstSet(input["pathPrefix"], nilIfEmpty(t.PathPrefix)),
		"methods":       firstSet(input["methods"], stringsToAny(t.Methods)),
		"authType":      firstSet(input["authType"], nilIfEmpty(t.AuthType)),
		"headerName":    firstSet(input["headerName"], nilIfEmpty(t.HeaderName)),
		"secretField":   firstSet(input["secretField"], nilIfEmpty(current.fields.SecretField)),
		"usernameField": firstSet(input["usernameField"], derefOrNil(current.fields.UsernameField)),
	}
	v, err := b.bindingValues(ctx, sc, merged)
	if err != nil {
		return nil, err
	}
	item, fields, target, err := b.sealed(v)
	if err != nil {
		return nil, err
	}
	_, err = b.db.W.ExecContext(ctx, `UPDATE credential_bindings
		SET connection_id = ?, alias = ?, usage_type = ?, item_ref_encrypted = ?,
		    field_config_encrypted = ?, target_config_json = ?, updated_at = datetime('now')
		WHERE id = ? AND user_id = ? AND agent_id = ?`,
		v.connectionID, v.alias, v.usageType, item, fields, target, bindingID, sc.userID, sc.agentID)
	if err != nil {
		return nil, err
	}
	return b.reload(ctx, sc, bindingID)
}

func stringsToAny(l []string) any {
	if l == nil {
		return nil
	}
	out := make([]any, len(l))
	for i, s := range l {
		out[i] = s
	}
	return out
}

func nilIfEmpty(s string) any {
	if s == "" {
		return nil
	}
	return s
}

func derefOrNil(s *string) any {
	if s == nil {
		return nil
	}
	return *s
}

// DeleteBinding removes a binding and reports whether there was one.
func (b *Broker) DeleteBinding(ctx context.Context, userID int64, agentID, bindingID string) (bool, error) {
	sc, err := b.scope(ctx, userID, agentID)
	if err != nil {
		return false, err
	}
	res, err := b.db.W.ExecContext(ctx, `DELETE FROM credential_bindings WHERE id = ? AND user_id = ? AND agent_id = ?`,
		bindingID, sc.userID, sc.agentID)
	if err != nil {
		return false, err
	}
	n, err := res.RowsAffected()
	return n > 0, err
}

// SummarizeBindings is the one-line list the model sees.
func (b *Broker) SummarizeBindings(ctx context.Context, userID int64, agentID string) (string, error) {
	bindings, err := b.ListBindings(ctx, userID, agentID)
	if err != nil {
		return "", err
	}
	if len(bindings) == 0 {
		return "No Bitwarden credential bindings are configured.", nil
	}
	parts := make([]string, len(bindings))
	for i, bd := range bindings {
		var targets string
		switch t := bd.Target.(type) {
		case publicBrowserTarget:
			targets = strings.Join(t.Origins, ", ")
		case publicHTTPTarget:
			targets = fmt.Sprintf("%s %s%s", strings.Join(t.Methods, "/"), deref(t.Origin), deref(t.PathPrefix))
		}
		parts[i] = fmt.Sprintf("%s: %s (%s; %s)", bd.ID, bd.Alias, bd.UsageType, targets)
	}
	return strings.Join(parts, "; "), nil
}

func deref(s *string) string {
	if s == nil {
		return "undefined"
	}
	return *s
}

// RunContext says which run a use belongs to.
type RunContext struct{ RunID string }

// codedError is an error with a machine code, such as the vault's.
type codedError interface{ ErrorCode() string }

func (b *Broker) audit(ctx context.Context, sc scope, bindingID, operation, target, outcome string, cause error, runID string) error {
	var code any
	var coded codedError
	if errors.As(cause, &coded) && coded.ErrorCode() != "" {
		code = coded.ErrorCode()
	}
	// A cancelled request still leaves its trace.
	_, err := b.db.W.ExecContext(context.WithoutCancel(ctx), `INSERT INTO credential_usage_audit (
		id, user_id, agent_id, run_id, binding_id, operation, target, outcome, error_code
	) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		newUUID(), sc.userID, sc.agentID, nilIfEmpty(runID), nilIfEmpty(bindingID), operation, nilIfEmpty(target), outcome, code)
	return err
}
