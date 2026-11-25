package memory

import (
	"context"
	"database/sql"

	"github.com/NeoLabs-Systems/neoagent/internal/memory/jsx"
)

// CoreKeys are the core memory keys that are always injected into the prompt.
var CoreKeys = []string{"user_profile", "preferences", "ai_personality"}

// CoreMemory returns an agent's always-injected key-value pairs; values that
// are JSON text are parsed, others stay strings.
func (m *Manager) CoreMemory(ctx context.Context, userID int64, agentID string) (*jsx.Obj, error) {
	scoped, err := m.agentID(ctx, userID, agentID)
	if err != nil {
		return nil, err
	}
	type kv struct{ key, value string }
	rows, err := collect(ctx, m.db.R, func(r rowScanner) (kv, error) {
		var x kv
		var value sql.NullString
		err := r.Scan(&x.key, &value)
		x.value = value.String
		if !value.Valid {
			x.value = "null"
		}
		return x, err
	}, `SELECT key, value FROM core_memory WHERE user_id = ? AND agent_id = ?`, userID, scoped)
	if err != nil {
		return nil, err
	}
	core := jsx.NewObj()
	for _, r := range rows {
		if v, err := jsx.Parse(r.value); err == nil {
			core.Set(r.key, v)
		} else {
			core.Set(r.key, r.value)
		}
	}
	return core, nil
}

// coreText is how a core memory value is stored: objects as JSON, the rest as text.
func coreText(value any) string {
	switch v := value.(type) {
	case nil, *jsx.Obj, []any:
		return jsx.Marshal(v)
	case string:
		return v
	}
	return jsx.ToString(value)
}

// UpdateCore sets one core memory value.
func (m *Manager) UpdateCore(ctx context.Context, userID int64, agentID, key string, value any) error {
	scoped, err := m.agentID(ctx, userID, agentID)
	if err != nil {
		return err
	}
	_, err = m.db.W.ExecContext(ctx,
		`INSERT INTO core_memory (user_id, agent_id, key, value, updated_at)
       VALUES (?, ?, ?, ?, datetime('now'))
       ON CONFLICT(user_id, agent_id, key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at`,
		userID, scoped, key, coreText(value))
	return err
}

// DeleteCore removes one core memory value.
func (m *Manager) DeleteCore(ctx context.Context, userID int64, agentID, key string) error {
	scoped, err := m.agentID(ctx, userID, agentID)
	if err != nil {
		return err
	}
	_, err = m.db.W.ExecContext(ctx, `DELETE FROM core_memory WHERE user_id = ? AND agent_id = ? AND key = ?`, userID, scoped, key)
	return err
}

// parseStringSetting reads a setting stored as a JSON string, or as plain text.
func parseStringSetting(value string) string {
	if v, err := jsx.Parse(value); err == nil {
		if s, ok := v.(string); ok {
			return s
		}
	}
	return value
}

// AssistantBehaviorNotes are the persona notes of an agent. The main agent
// falls back to the account-wide setting older versions wrote.
func (m *Manager) AssistantBehaviorNotes(ctx context.Context, userID int64, agentID string) (string, error) {
	scoped, err := m.agentID(ctx, userID, agentID)
	if err != nil {
		return "", err
	}
	var value sql.NullString
	found, err := one(ctx, m.db.R, []any{&value}, `SELECT value FROM agent_settings WHERE user_id = ? AND agent_id = ? AND key = ?`,
		userID, scoped, "assistant_behavior_notes")
	if err != nil {
		return "", err
	}
	if !found {
		isMain, err := m.agents.IsMain(ctx, userID, scoped)
		if err != nil {
			return "", err
		}
		if isMain {
			if _, err := one(ctx, m.db.R, []any{&value}, `SELECT value FROM user_settings WHERE user_id = ? AND key = ?`,
				userID, "assistant_behavior_notes"); err != nil {
				return "", err
			}
		}
	}
	if !value.Valid {
		return "", nil
	}
	return parseStringSetting(value.String), nil
}

// SetAssistantBehaviorNotes stores the persona notes of an agent.
func (m *Manager) SetAssistantBehaviorNotes(ctx context.Context, userID int64, agentID, content string) error {
	scoped, err := m.agentID(ctx, userID, agentID)
	if err != nil {
		return err
	}
	_, err = m.db.W.ExecContext(ctx,
		`INSERT INTO agent_settings (user_id, agent_id, key, value)
       VALUES (?, ?, ?, ?)
       ON CONFLICT(user_id, agent_id, key) DO UPDATE SET value = excluded.value`,
		userID, scoped, "assistant_behavior_notes", content)
	return err
}

// SelfState is how the assistant sees itself: identity and focus.
type SelfState struct {
	Identity  *jsx.Obj `json:"identity"`
	Focus     *jsx.Obj `json:"focus"`
	UpdatedAt *string  `json:"updatedAt"`
}

// AssistantSelfState reads the self state of an agent.
func (m *Manager) AssistantSelfState(ctx context.Context, userID int64, agentID string) (SelfState, error) {
	scoped, err := m.agentID(ctx, userID, agentID)
	if err != nil {
		return SelfState{}, err
	}
	var identity, focus, updated sql.NullString
	if _, err := one(ctx, m.db.R, []any{&identity, &focus, &updated},
		`SELECT identity_json, focus_json, updated_at FROM assistant_self_state WHERE user_id = ? AND agent_id = ?`, userID, scoped); err != nil {
		return SelfState{}, err
	}
	return SelfState{Identity: jsx.ParseObject(identity.String), Focus: jsx.ParseObject(focus.String), UpdatedAt: optionalString(updated)}, nil
}

// UpdateAssistantSelfState merges identity and focus patches into the stored state.
func (m *Manager) UpdateAssistantSelfState(ctx context.Context, userID int64, agentID string, identity, focus *jsx.Obj) (SelfState, error) {
	scoped, err := m.agentID(ctx, userID, agentID)
	if err != nil {
		return SelfState{}, err
	}
	current, err := m.AssistantSelfState(ctx, userID, scoped)
	if err != nil {
		return SelfState{}, err
	}
	nextIdentity := current.Identity.Clone().Assign(identity)
	nextFocus := current.Focus.Clone().Assign(focus)
	if _, err := m.db.W.ExecContext(ctx,
		`INSERT INTO assistant_self_state (user_id, agent_id, identity_json, focus_json, updated_at)
       VALUES (?, ?, ?, ?, datetime('now'))
       ON CONFLICT(user_id, agent_id) DO UPDATE SET
         identity_json = excluded.identity_json,
         focus_json = excluded.focus_json,
         updated_at = excluded.updated_at`,
		userID, scoped, jsx.Marshal(nextIdentity), jsx.Marshal(nextFocus)); err != nil {
		return SelfState{}, err
	}
	return m.AssistantSelfState(ctx, userID, scoped)
}

// backfillMemoryIntelligence gives memories saved before facts and entities
// existed their summary, hash, facts and entities. Memories without an agent
// are skipped: no recall can reach them.
func (m *Manager) backfillMemoryIntelligence(ctx context.Context, limit int) {
	type row struct {
		id, content                                     string
		userID                                          int64
		agentID, category, summary, hash                string
		sourceType, sourceID, sourceLabel, metadataJSON string
	}
	rows, err := collect(ctx, m.db.W, func(r rowScanner) (row, error) {
		var x row
		var agent, category, summary, hash, st, si, sl, meta sql.NullString
		err := r.Scan(&x.id, &x.userID, &agent, &category, &x.content, &summary, &hash, &st, &si, &sl, &meta)
		x.agentID, x.category, x.summary, x.hash = agent.String, category.String, summary.String, hash.String
		x.sourceType, x.sourceID, x.sourceLabel, x.metadataJSON = st.String, si.String, sl.String, meta.String
		return x, err
	}, `SELECT m.id, m.user_id, m.agent_id, m.category, m.content, m.summary, m.memory_hash,
	        m.source_type, m.source_id, m.source_label, m.metadata_json
         FROM memories m
         LEFT JOIN memory_facts f ON f.memory_id = m.id
         WHERE m.archived = 0 AND f.id IS NULL
           AND COALESCE(m.source_type, '') != 'memory_ingestion'
         ORDER BY m.updated_at DESC
         LIMIT ?`, max(1, min(limit, 5000)))
	if err != nil {
		m.log.Error("memory: backfill intelligence failed", "error", err)
		return
	}
	for _, r := range rows {
		category := NormalizeMemoryCategory(r.category)
		content := jsx.Trim(r.content)
		if content == "" || r.agentID == "" {
			continue
		}
		summary := r.summary
		if summary == "" {
			summary = SummarizeForPrompt(content, entityNames(ExtractEntities(content, DefaultMaxEntities)))
		}
		hash := r.hash
		if hash == "" {
			hash = StableHash(category + ":" + content)
		}
		if _, err := m.db.W.ExecContext(ctx,
			`UPDATE memories
             SET summary = COALESCE(summary, ?),
                 confidence = COALESCE(confidence, 0.7),
                 memory_hash = COALESCE(memory_hash, ?)
             WHERE id = ?`, summary, hash, r.id); err != nil {
			m.log.Error("memory: backfill intelligence failed", "error", err)
			return
		}
		in := intelligenceInput{content: content, category: category,
			sourceRef: NewSourceRef(r.sourceType, r.sourceID, r.sourceLabel), metadata: jsx.ParseObject(r.metadataJSON)}
		if _, err := m.upsertMemoryIntelligence(ctx, r.userID, r.agentID, r.id, in); err != nil {
			m.log.Error("memory: backfill intelligence failed", "error", err)
			return
		}
	}
}
