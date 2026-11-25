// Package delegation is the account access model: who manages whom, which
// tool categories a managed account may use, and the invite links that put an
// account under a manager.
package delegation

import (
	"context"
	"encoding/json"
)

// Permissions are the delegable tool categories, the ones the security policy
// governs, in the order clients list them.
var Permissions = []string{"shell", "file_write", "android_privileged", "desktop_control", "browser_privileged",
	"credential_use", "network_write", "user_contact", "skill_mutation", "agent_creation", "external"}

// MaxChainDepth is the most managers an account can have above it.
const MaxChainDepth = 4

func knownPermission(key string) bool {
	for _, p := range Permissions {
		if p == key {
			return true
		}
	}
	return false
}

// parseAllowed reads an allow-list, keeping only known permissions.
func parseAllowed(raw string) map[string]bool {
	var list []any
	_ = json.Unmarshal([]byte(raw), &list)
	out := map[string]bool{}
	for _, v := range list {
		if s, ok := v.(string); ok && knownPermission(s) {
			out[s] = true
		}
	}
	return out
}

// allowedList is an allow-list in its stored order, known keys only.
func allowedList(raw string) []string {
	var list []any
	_ = json.Unmarshal([]byte(raw), &list)
	out := []string{}
	for _, v := range list {
		if s, ok := v.(string); ok && knownPermission(s) {
			out = append(out, s)
		}
	}
	return out
}

type hop struct {
	managed, manager int64
	allowed          map[string]bool
	since            string
}

// managerChain lists the delegations from userID upward, nearest first. The
// depth bound keeps a corrupted (cyclic) table from recursing forever.
func (s *Service) managerChain(ctx context.Context, q querier, userID int64) ([]hop, error) {
	rows, err := q.QueryContext(ctx, `
    WITH RECURSIVE chain(managed_user_id, manager_user_id, allowed_permissions_json, created_at, depth) AS (
      SELECT managed_user_id, manager_user_id, allowed_permissions_json, created_at, 1
      FROM user_delegations
      WHERE managed_user_id = ?
      UNION ALL
      SELECT d.managed_user_id, d.manager_user_id, d.allowed_permissions_json, d.created_at, chain.depth + 1
      FROM user_delegations d
      JOIN chain ON d.managed_user_id = chain.manager_user_id
      WHERE chain.depth <= ?
    )
    SELECT managed_user_id, manager_user_id, allowed_permissions_json, created_at
    FROM chain
    ORDER BY depth`, userID, MaxChainDepth)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []hop
	for rows.Next() {
		var h hop
		var raw string
		if err := rows.Scan(&h.managed, &h.manager, &raw, &h.since); err != nil {
			return nil, err
		}
		h.allowed = parseAllowed(raw)
		out = append(out, h)
	}
	return out, rows.Err()
}

// Grant is one permission as resolved for an account. SetBy is the manager
// whose decision is in force: for a denial the highest manager who denied it,
// for an allowed permission the direct manager (who could still take it away);
// zero when nobody manages the account.
type Grant struct {
	Allowed bool
	SetBy   int64
}

// Resolve applies the chain rules: an unmanaged account holds everything; a
// manager's allow-list denies everything missing from it for that account and
// everyone below; walking from the top down, the first denial wins.
func (s *Service) Resolve(ctx context.Context, userID int64) (map[string]Grant, error) {
	return s.resolve(ctx, s.db.R, userID)
}

func (s *Service) resolve(ctx context.Context, q querier, userID int64) (map[string]Grant, error) {
	chain, err := s.managerChain(ctx, q, userID)
	if err != nil {
		return nil, err
	}
	resolved := map[string]Grant{}
	for _, k := range Permissions {
		resolved[k] = Grant{Allowed: true}
	}
	for i := len(chain) - 1; i >= 0; i-- {
		for _, k := range Permissions {
			if resolved[k].Allowed && !chain[i].allowed[k] {
				resolved[k] = Grant{Allowed: false, SetBy: chain[i].manager}
			}
		}
	}
	var direct int64
	if len(chain) > 0 {
		direct = chain[0].manager
	}
	for k, g := range resolved {
		if g.Allowed {
			g.SetBy = direct
			resolved[k] = g
		}
	}
	return resolved, nil
}

// IsPermitted reports whether an account may use a tool category. Unknown
// categories are not delegable and always allowed.
func (s *Service) IsPermitted(ctx context.Context, userID int64, permission string) (bool, error) {
	if !knownPermission(permission) {
		return true, nil
	}
	resolved, err := s.Resolve(ctx, userID)
	if err != nil {
		return false, err
	}
	return resolved[permission].Allowed, nil
}

func (s *Service) held(ctx context.Context, q querier, userID int64) (map[string]bool, error) {
	resolved, err := s.resolve(ctx, q, userID)
	if err != nil {
		return nil, err
	}
	out := map[string]bool{}
	for k, g := range resolved {
		if g.Allowed {
			out[k] = true
		}
	}
	return out, nil
}
