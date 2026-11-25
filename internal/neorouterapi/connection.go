package neorouterapi

import (
	"context"
	"fmt"
	"math"
	"net/url"
	"regexp"
	"strconv"
	"strings"

	"golang.org/x/net/idna"
)

// Roles are the kinds of work that can go through a NeoRouter.
var Roles = []string{"chat", "system_one", "transcription", "live", "embeddings", "images", "search"}

// Environment names of the server's own connection.
const (
	envBaseURL = "NEOROUTER_BASE_URL"
	envAPIKey  = "NEOROUTER_API_KEY"
	envRoles   = "NEOROUTER_ROLES"

	// ProviderID is the provider the person's own key is stored under.
	ProviderID = "neorouter"
)

// Connection is a NeoRouter NeoAgent works through. Scope is "server" or
// "user"; a user's own connection wins over the server's.
type Connection struct {
	Scope   string
	APIBase string
	Origin  string
	APIKey  string
	// Roles are the roles that go through this router, in Roles order.
	Roles []string
}

// HasRole reports whether role goes through this connection.
func (c *Connection) HasRole(role string) bool {
	if c == nil {
		return false
	}
	for _, r := range c.Roles {
		if r == role {
			return true
		}
	}
	return false
}

var schemePrefix = regexp.MustCompile(`(?i)^https?://`)

// APIBaseFor turns "router.local:3333" or "https://router.example.com/app/"
// into the /v1 API base, or "" when the address is not usable.
func APIBaseFor(address string) string {
	raw := strings.TrimSpace(address)
	if raw == "" {
		return ""
	}
	if !schemePrefix.MatchString(raw) {
		raw = "https://" + raw
	}
	origin, ok := originOf(raw)
	if !ok {
		return ""
	}
	return origin + "/v1"
}

// originOf is URL.origin of an http(s) address, which fails for an address
// with credentials or without a usable host.
func originOf(raw string) (string, bool) {
	raw = strings.NewReplacer("\t", "", "\n", "", "\r", "").Replace(raw)
	if i := strings.IndexAny(raw, "/?#\\"); i >= 0 && strings.HasPrefix(raw[i:], "\\") {
		raw = raw[:i] + "/" + raw[i+1:]
	}
	u, err := url.Parse(raw)
	if err != nil || u.Host == "" || u.User != nil {
		return "", false
	}
	scheme := strings.ToLower(u.Scheme)
	host := strings.ToLower(u.Hostname())
	if host == "" {
		return "", false
	}
	if strings.Contains(host, ":") {
		host = "[" + host + "]"
	} else if ascii, err := idna.Lookup.ToASCII(host); err == nil && ascii != "" {
		host = ascii
	} else {
		return "", false
	}
	port := u.Port()
	if port != "" {
		n, err := strconv.Atoi(port)
		if err != nil || n > math.MaxUint16 {
			return "", false
		}
		port = strconv.Itoa(n)
	}
	if (scheme == "https" && port == "443") || (scheme == "http" && port == "80") {
		port = ""
	}
	if port != "" {
		host += ":" + port
	}
	return scheme + "://" + host, true
}

// NormalizeRoles keeps the known roles of a stored value, in Roles order. An
// unset value means every role.
func NormalizeRoles(value any) []string {
	if value == nil {
		return append([]string(nil), Roles...)
	}
	var list []string
	if items, ok := value.([]any); ok {
		for _, item := range items {
			list = append(list, stringOf(item))
		}
	} else {
		list = strings.Split(stringOf(value), ",")
	}
	wanted := map[string]bool{}
	for _, r := range list {
		wanted[strings.TrimSpace(r)] = true
	}
	out := []string{}
	for _, r := range Roles {
		if wanted[r] {
			out = append(out, r)
		}
	}
	return out
}

// stringOf is String(v) for the JSON values a setting can hold.
func stringOf(v any) string {
	switch t := v.(type) {
	case nil:
		return "null"
	case string:
		return t
	case float64:
		return strconv.FormatFloat(t, 'f', -1, 64)
	case bool:
		return strconv.FormatBool(t)
	case []any:
		parts := make([]string, len(t))
		for i, e := range t {
			if e != nil {
				parts[i] = stringOf(e)
			}
		}
		return strings.Join(parts, ",")
	}
	return "[object Object]"
}

func build(scope, apiBase, apiKey string, roles []string) *Connection {
	if apiBase == "" || apiKey == "" {
		return nil
	}
	origin, _ := strings.CutSuffix(apiBase, "/v1")
	return &Connection{Scope: scope, APIBase: apiBase, Origin: origin, APIKey: apiKey, Roles: roles}
}

// ServerConnection is the connection the admin set up, kept in the
// environment; nil when there is none.
func (s *Service) ServerConnection() *Connection {
	get := func(name string) string { return strings.TrimSpace(s.env.Get(name)) }
	var roles any
	if v := s.env.Get(envRoles); v != "" {
		roles = v
	}
	return build("server", APIBaseFor(get(envBaseURL)), get(envAPIKey), NormalizeRoles(roles))
}

// UserConnection is a person's own connection, from their sign-in; nil when
// they have none.
func (s *Service) UserConnection(ctx context.Context, userID int64, agentID string) (*Connection, error) {
	if userID == 0 {
		return nil, nil
	}
	key, baseURL, roles, err := s.settings.NeoRouter(ctx, userID, agentID)
	if err != nil {
		return nil, fmt.Errorf("read NeoRouter settings: %w", err)
	}
	key = strings.TrimSpace(key)
	if key == "" {
		return nil, nil
	}
	return build("user", APIBaseFor(baseURL), key, NormalizeRoles(roles)), nil
}

// ConnectionFor is the person's own connection, else the server's.
func (s *Service) ConnectionFor(ctx context.Context, userID int64, agentID string) (*Connection, error) {
	own, err := s.UserConnection(ctx, userID, agentID)
	if own != nil || err != nil {
		return own, err
	}
	return s.ServerConnection(), nil
}

// ForRole is the connection that handles role for this person, or nil.
func (s *Service) ForRole(ctx context.Context, userID int64, agentID, role string) (*Connection, error) {
	conn, err := s.ConnectionFor(ctx, userID, agentID)
	if err != nil || !conn.HasRole(role) {
		return nil, err
	}
	return conn, nil
}

// ProviderServesRole is true for every provider but NeoRouter, which serves
// only the roles it has.
func (s *Service) ProviderServesRole(ctx context.Context, providerID string, userID int64, agentID, role string) (bool, error) {
	if providerID != ProviderID {
		return true, nil
	}
	conn, err := s.ForRole(ctx, userID, agentID, role)
	return conn != nil, err
}
