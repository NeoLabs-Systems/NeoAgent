package messaging

import (
	"context"
	"database/sql"
	"encoding/json"
	"slices"
	"strings"
)

const maxSuggestions = 24

// rememberSuggestions keeps the newest refused senders of a connection.
func (m *Manager) rememberSuggestions(key connKey, fresh []Suggestion) {
	if len(fresh) == 0 {
		return
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	seen := map[string]bool{}
	var kept []Suggestion
	for _, s := range append(slices.Clone(fresh), m.suggestions[key]...) {
		id := targetKey(s.Bucket, s.Rule.Scope, s.Rule.Value, s.Rule.SpaceScope, s.Rule.SpaceValue)
		if s.Bucket == "" || seen[id] || len(kept) == maxSuggestions {
			continue
		}
		seen[id] = true
		kept = append(kept, s)
	}
	m.suggestions[key] = kept
}

func targetKey(parts ...string) string { return strings.Join(parts, ":") }

// GetAccessCatalog is the access screen's data: capabilities, the policy, the
// people and spaces the platform knows or recently heard from, and the refused
// senders that could be allowed.
func (m *Manager) GetAccessCatalog(ctx context.Context, userID int64, agentID, platform string) (map[string]any, error) {
	agentID = m.resolveAgent(ctx, userID, agentID)
	policy, err := m.store.LoadAccessPolicy(ctx, userID, agentID, platform)
	if err != nil {
		return nil, err
	}
	key := connKey{userID: userID, agentID: agentID, platform: platform}
	m.mu.Lock()
	suggested := slices.Clone(m.suggestions[key])
	m.mu.Unlock()
	known := m.ListAccessTargets(ctx, userID, agentID, platform)
	recent, err := m.recentTargets(ctx, key)
	if err != nil {
		return nil, err
	}

	caps := PlatformCapabilities(platform)
	seen := map[string]bool{}
	first := func(id string) bool {
		if seen[id] {
			return false
		}
		seen[id] = true
		return true
	}
	discovered := []AccessTarget{}
	for _, t := range append(known, recent...) {
		if t.Bucket == "directRules" && caps.SupportsSharedPolicy && slices.Contains(caps.SharedActorRuleScopes, t.Scope) {
			t.Bucket = "sharedActorRules"
		}
		if first(targetKey(t.Bucket, t.Scope, t.Value, t.SpaceScope, t.SpaceValue)) {
			discovered = append(discovered, t)
		}
	}
	offered := []Suggestion{}
	for _, s := range suggested {
		if first(targetKey(s.Bucket, s.Rule.Scope, s.Rule.Value, s.Rule.SpaceScope, s.Rule.SpaceValue)) {
			offered = append(offered, s)
		}
	}
	return map[string]any{
		"platform":          platform,
		"capabilities":      caps,
		"policy":            policy,
		"summary":           SummarizeAccessPolicy(platform, policy),
		"discoveredTargets": discovered,
		"suggestedTargets":  offered,
	}, nil
}

// recentTargets turns the latest stored chats of a connection into targets.
func (m *Manager) recentTargets(ctx context.Context, key connKey) ([]AccessTarget, error) {
	if m.cfg.DB == nil {
		return nil, nil
	}
	rows, err := m.cfg.DB.R.QueryContext(ctx, `SELECT platform_chat_id, metadata FROM messages
		WHERE user_id = ? AND agent_id = ? AND platform = ? AND platform_chat_id IS NOT NULL
		ORDER BY id DESC LIMIT 40`, key.userID, key.agentID, key.platform)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []AccessTarget
	for rows.Next() {
		var chatID string
		var metadata sql.NullString
		if err := rows.Scan(&chatID, &metadata); err != nil {
			return nil, err
		}
		row := RecentRow{PlatformChatID: chatID}
		if json.Unmarshal([]byte(metadata.String), &row.Metadata) != nil {
			row.Metadata = nil
		}
		if t, ok := ClassifyRecentTarget(key.platform, row); ok {
			out = append(out, t)
		}
	}
	return out, rows.Err()
}
