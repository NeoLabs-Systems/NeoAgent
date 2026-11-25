// Package security holds the tool security baseline: which category a tool
// call belongs to, the owner's policy per category, delegated permissions,
// deterministic trust review of calls from runs that read outside content or
// answer someone other than the owner, and the approval gate that asks the
// owner before a call runs.
package security

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/tools"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
)

// Categories are the tool categories with the policy each starts with.
var Categories = []string{"shell", "file_write", "android_privileged", "desktop_control", "browser_privileged", "credential_use", "network_write",
	"user_contact", "skill_mutation", "agent_creation", "external"}

// DefaultPolicy is what each category needs from the owner when no policy row exists.
var DefaultPolicy = map[string]string{
	"shell": "require_approval", "file_write": "require_approval", "android_privileged": "require_approval", "desktop_control": "require_approval",
	"browser_privileged": "require_approval", "credential_use": "require_approval", "network_write": "require_approval", "user_contact": "require_approval",
	"skill_mutation": "deny", "agent_creation": "require_approval", "external": "require_approval",
}

var validPolicies = map[string]bool{"allow": true, "deny": true, "require_approval": true}
var validModes = map[string]bool{"default": true, "allow_all": true, "always_ask": true}

const securityModeKey = "tool_security_mode"

// Catalog is what the tool definitions say about security: which tools are
// built in, which are safe, and the category of each. A name in none of them
// is third-party and lands in "external", so a new capability can never
// silently bypass policy.
type Catalog struct {
	builtIn  map[string]bool
	safe     map[string]bool
	category map[string]string
}

// NewCatalog reads the policy traits of the tool registry.
func NewCatalog(registry *tools.Registry) *Catalog {
	c := &Catalog{builtIn: map[string]bool{}, safe: map[string]bool{}, category: map[string]string{}}
	for _, name := range registry.StaticNames() {
		policy := registry.Meta(name, nil).Policy
		if policy["external"] == true {
			continue
		}
		c.builtIn[name] = true
		if policy["safe"] == true {
			c.safe[name] = true
		}
		if category, _ := policy["category"].(string); category != "" {
			c.category[name] = category
		}
	}
	return c
}

// Safe says whether a tool bypasses every policy.
func (c *Catalog) Safe(name string) bool { return c.safe[name] }

// CategoryFor is the category of a call; "" for built-ins that are read-only
// or deliberately uncategorized. Unknown names are "external".
func (c *Catalog) CategoryFor(name string, args map[string]any) string {
	switch name {
	case "http_request":
		method := strings.ToUpper(strings.TrimSpace(fmt.Sprint(orDefault(args["method"], "GET"))))
		if method == "" || method == "GET" || method == "HEAD" || method == "OPTIONS" {
			return ""
		}
		return "network_write"
	case "share_web_page":
		if fmt.Sprint(orDefault(args["action"], "")) == "share" {
			return "network_write"
		}
		return ""
	}
	if category := c.category[name]; category != "" {
		return category
	}
	if c.builtIn[name] || c.safe[name] {
		return ""
	}
	return "external"
}

func orDefault(v, fallback any) any {
	if v == nil {
		return fallback
	}
	return v
}

// Policies reads and writes the owner's security mode and category policies.
type Policies struct {
	DB      *dbx.DB
	Catalog *Catalog
	// ModeOverride forces a mode for this process (headless runs).
	ModeOverride string
}

// Mode is the user's security mode: "default", "allow_all" or "always_ask".
func (p *Policies) Mode(ctx context.Context, userID int64) string {
	if validModes[p.ModeOverride] {
		return p.ModeOverride
	}
	var mode string
	_ = p.DB.R.QueryRowContext(ctx, `SELECT value FROM user_settings WHERE user_id = ? AND key = ?`, userID, securityModeKey).Scan(&mode)
	if validModes[mode] {
		return mode
	}
	return "default"
}

// SetMode stores the security mode.
func (p *Policies) SetMode(ctx context.Context, userID int64, mode string) error {
	if !validModes[mode] {
		return fmt.Errorf("Invalid security mode: %s. Must be default, allow_all, or always_ask", mode)
	}
	_, err := p.DB.W.ExecContext(ctx, `INSERT INTO user_settings (user_id, key, value) VALUES (?, ?, ?) ON CONFLICT(user_id, key) DO UPDATE SET value = excluded.value`,
		userID, securityModeKey, mode)
	return err
}

// Policy is the effective policy for a call: "allow", "deny" or "require_approval".
func (p *Policies) Policy(ctx context.Context, userID int64, name string, args map[string]any) string {
	if p.Catalog.Safe(name) {
		return "allow"
	}
	category := p.Catalog.CategoryFor(name, args)
	if category == "" {
		return "allow"
	}
	var policy string
	if p.DB.R.QueryRowContext(ctx, `SELECT policy FROM tool_policies WHERE user_id = ? AND category = ?`, userID, category).Scan(&policy) == nil && policy != "" {
		return policy
	}
	if d := DefaultPolicy[category]; d != "" {
		return d
	}
	return "allow"
}

// CategoryPolicy is the stored policy of a category, or its default.
func (p *Policies) CategoryPolicy(ctx context.Context, userID int64, category string) string {
	var policy string
	if p.DB.R.QueryRowContext(ctx, `SELECT policy FROM tool_policies WHERE user_id = ? AND category = ?`, userID, category).Scan(&policy) == nil && policy != "" {
		return policy
	}
	return DefaultPolicy[category]
}

// SetPolicy stores a category policy.
func (p *Policies) SetPolicy(ctx context.Context, userID int64, category, policy string) error {
	if _, ok := DefaultPolicy[category]; !ok {
		return fmt.Errorf("Unknown tool category: %s", category)
	}
	if !validPolicies[policy] {
		return fmt.Errorf("Invalid policy value: %s. Must be allow, deny, or require_approval", policy)
	}
	_, err := p.DB.W.ExecContext(ctx, `INSERT INTO tool_policies (user_id, category, policy, updated_at) VALUES (?, ?, ?, datetime('now'))
		ON CONFLICT(user_id, category) DO UPDATE SET policy = excluded.policy, updated_at = excluded.updated_at`, userID, category, policy)
	return err
}

// All is every category policy of a user, defaults filled in, in category order.
func (p *Policies) All(ctx context.Context, userID int64) map[string]string {
	out := map[string]string{}
	for _, c := range Categories {
		out[c] = DefaultPolicy[c]
	}
	rows, err := p.DB.R.QueryContext(ctx, `SELECT category, policy FROM tool_policies WHERE user_id = ?`, userID)
	if err != nil {
		return out
	}
	defer rows.Close()
	for rows.Next() {
		var category, policy string
		if rows.Scan(&category, &policy) == nil {
			if _, ok := out[category]; ok {
				out[category] = policy
			}
		}
	}
	return out
}

// Permission is a delegated permission as it stands for an account.
type Permission struct {
	Allowed bool
	// SetBy is the manager whose decision is in force; 0 when nobody manages
	// the account.
	SetBy int64
}

const maxChainDepth = 4

// ResolvePermissions applies the manager chain: an unmanaged account holds
// every permission; walking from the top down the first denial wins.
func ResolvePermissions(ctx context.Context, db *dbx.DB, userID int64) map[string]Permission {
	type hop struct {
		manager int64
		allowed map[string]bool
	}
	var chain []hop
	rows, err := db.R.QueryContext(ctx, `WITH RECURSIVE chain(managed_user_id, manager_user_id, allowed_permissions_json, created_at, depth) AS (
		SELECT managed_user_id, manager_user_id, allowed_permissions_json, created_at, 1 FROM user_delegations WHERE managed_user_id = ?
		UNION ALL
		SELECT d.managed_user_id, d.manager_user_id, d.allowed_permissions_json, d.created_at, chain.depth + 1
		FROM user_delegations d JOIN chain ON d.managed_user_id = chain.manager_user_id WHERE chain.depth <= ?)
		SELECT manager_user_id, allowed_permissions_json FROM chain ORDER BY depth`, userID, maxChainDepth)
	if err == nil {
		for rows.Next() {
			var manager int64
			var raw sql.NullString
			if rows.Scan(&manager, &raw) != nil {
				continue
			}
			var list []any
			_ = json.Unmarshal([]byte(raw.String), &list)
			allowed := map[string]bool{}
			for _, v := range list {
				if s, ok := v.(string); ok {
					if _, known := DefaultPolicy[s]; known {
						allowed[s] = true
					}
				}
			}
			chain = append(chain, hop{manager, allowed})
		}
		rows.Close()
	}
	resolved := map[string]Permission{}
	for _, c := range Categories {
		resolved[c] = Permission{Allowed: true}
	}
	for i := len(chain) - 1; i >= 0; i-- {
		for _, c := range Categories {
			if resolved[c].Allowed && !chain[i].allowed[c] {
				resolved[c] = Permission{Allowed: false, SetBy: chain[i].manager}
			}
		}
	}
	if len(chain) > 0 {
		for _, c := range Categories {
			if p := resolved[c]; p.Allowed {
				p.SetBy = chain[0].manager
				resolved[c] = p
			}
		}
	}
	return resolved
}

// Permitted says whether delegation leaves a category on for an account.
func Permitted(ctx context.Context, db *dbx.DB, userID int64, permission string) bool {
	if _, ok := DefaultPolicy[permission]; !ok {
		return true
	}
	return ResolvePermissions(ctx, db, userID)[permission].Allowed
}

// ManagerLocks are the categories a manager took away, with who did.
func ManagerLocks(ctx context.Context, db *dbx.DB, userID int64) map[string]any {
	locks := map[string]any{}
	for key, p := range ResolvePermissions(ctx, db, userID) {
		if p.Allowed {
			continue
		}
		var username string
		var display sql.NullString
		if db.R.QueryRowContext(ctx, `SELECT username, display_name FROM users WHERE id = ?`, p.SetBy).Scan(&username, &display) != nil {
			locks[key] = nil
			continue
		}
		var displayName any
		if display.String != "" {
			displayName = display.String
		}
		locks[key] = map[string]any{"id": p.SetBy, "username": username, "displayName": displayName}
	}
	return locks
}
