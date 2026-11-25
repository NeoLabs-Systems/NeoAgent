package memory

import (
	"context"
	"database/sql"
	"errors"
	"regexp"
	"sort"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/memory/jsx"
)

// ErrConversationNotFound is returned for a conversation the user does not own.
var ErrConversationNotFound = errors.New("Conversation not found.")

// ConversationParams find or create a conversation.
type ConversationParams struct {
	Platform       string
	PlatformChatID string
	Title          string
	SessionKey     string
	AgentID        string
}

// EnsureConversation returns the id of the conversation of a chat, creating it
// when it is new. The first web conversation of the main agent inherits the
// summary older versions kept in settings.
func (m *Manager) EnsureConversation(ctx context.Context, userID int64, p ConversationParams) (string, error) {
	scoped, err := m.agentID(ctx, userID, p.AgentID)
	if err != nil {
		return "", err
	}
	if p.Platform == "" {
		p.Platform = "web"
	}
	if p.Title == "" {
		p.Title = "Conversation"
	}
	var chat any
	if p.PlatformChatID != "" {
		chat = p.PlatformChatID
	}
	var id string
	found, err := one(ctx, m.db.W, []any{&id},
		`SELECT id FROM conversations WHERE user_id = ? AND agent_id = ? AND platform = ? AND COALESCE(platform_chat_id, '') = COALESCE(?, '')`,
		userID, scoped, p.Platform, chat)
	if err != nil {
		return "", err
	}
	if found && id != "" {
		return id, nil
	}

	conversationID := m.newID()
	migrated := ""
	if p.Platform == "web" {
		var slug sql.NullString
		if _, err := one(ctx, m.db.W, []any{&slug}, `SELECT slug FROM agents WHERE user_id = ? AND id = ?`, userID, scoped); err != nil {
			return "", err
		}
		if slug.String == "main" {
			var legacy sql.NullString
			if _, err := one(ctx, m.db.W, []any{&legacy}, `SELECT value FROM user_settings WHERE user_id = ? AND key = ?`, userID, "web_chat_summary"); err != nil {
				return "", err
			}
			if legacy.Valid {
				migrated = parseStringSetting(legacy.String)
			}
		}
	}
	_, err = m.db.W.ExecContext(ctx,
		`INSERT INTO conversations (id, user_id, agent_id, platform, platform_chat_id, title, session_key, summary, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))`,
		conversationID, userID, scoped, p.Platform, chat, p.Title, nilIfEmptyStr(p.SessionKey), nilIfEmptyStr(migrated))
	return conversationID, err
}

// AssertOwnedConversation returns the id when the user owns the conversation;
// any other id is treated as missing.
func (m *Manager) AssertOwnedConversation(ctx context.Context, userID int64, conversationID string) (string, error) {
	var id string
	found, err := one(ctx, m.db.R, []any{&id}, `SELECT id FROM conversations WHERE id = ? AND user_id = ?`, conversationID, userID)
	if err != nil {
		return "", err
	}
	if !found {
		return "", ErrConversationNotFound
	}
	return id, nil
}

// DefaultWebConversationID is the conversation of the app's primary chat.
func (m *Manager) DefaultWebConversationID(ctx context.Context, userID int64, agentID string) (string, error) {
	scoped, err := m.agentID(ctx, userID, agentID)
	if err != nil {
		return "", err
	}
	return m.EnsureConversation(ctx, userID, ConversationParams{
		Platform: "web", PlatformChatID: "primary", Title: "Web chat", SessionKey: "web:primary", AgentID: scoped,
	})
}

// ConversationState returns the working state of a thread: its stored members
// plus last_verified_facts.
func (m *Manager) ConversationState(ctx context.Context, conversationID string) (*jsx.Obj, error) {
	var working, verified sql.NullString
	if _, err := one(ctx, m.db.R, []any{&working, &verified},
		`SELECT working_state_json, last_verified_facts_json FROM conversations WHERE id = ?`, conversationID); err != nil {
		return nil, err
	}
	state := jsx.NewObj()
	if working.String != "" {
		if v, err := jsx.Parse(working.String); err == nil {
			if o, ok := v.(*jsx.Obj); ok {
				state = o.Clone()
			}
		}
	}
	facts := []any{}
	if verified.String != "" {
		if v, err := jsx.Parse(verified.String); err == nil {
			if list, ok := v.([]any); ok {
				facts = list
			}
		}
	}
	return state.Set("last_verified_facts", facts), nil
}

// UpdateConversationState stores the working state of a thread.
func (m *Manager) UpdateConversationState(ctx context.Context, conversationID string, state *jsx.Obj) error {
	state = objOrEmpty(state)
	verified, _ := state.Value("last_verified_facts").([]any)
	if verified == nil {
		verified = []any{}
	}
	_, err := m.db.W.ExecContext(ctx,
		`UPDATE conversations
       SET working_state_json = ?, last_verified_facts_json = ?, updated_at = datetime('now')
       WHERE id = ?`, jsx.Marshal(state), jsx.Marshal(verified), conversationID)
	return err
}

func stringList(v any) []string {
	list, ok := v.([]any)
	if !ok || len(list) == 0 {
		return nil
	}
	out := make([]string, len(list))
	for i, item := range list {
		out[i] = jsx.ToString(item)
		if jsx.Nullish(item) {
			out[i] = ""
		}
	}
	return out
}

// ConversationStateMessage renders the working state of a thread for the
// prompt, or "" when it has none.
func (m *Manager) ConversationStateMessage(ctx context.Context, conversationID string) (string, error) {
	if conversationID == "" {
		return "", nil
	}
	state, err := m.ConversationState(ctx, conversationID)
	if err != nil || state.Len() == 0 {
		return "", err
	}
	var sections []string
	if summary := state.Value("summary"); jsx.Truthy(summary) {
		sections = append(sections, "Summary: "+jsx.ToString(summary))
	}
	if items := stringList(state.Value("open_commitments")); items != nil {
		sections = append(sections, "Open commitments:\n- "+strings.Join(items, "\n- "))
	}
	if items := stringList(state.Value("unresolved_questions")); items != nil {
		sections = append(sections, "Unresolved questions:\n- "+strings.Join(items, "\n- "))
	}
	if items := stringList(state.Value("referenced_entities")); items != nil {
		sections = append(sections, "Referenced entities: "+strings.Join(items, ", "))
	}
	if items := stringList(state.Value("last_verified_facts")); items != nil {
		sections = append(sections, "Last verified facts:\n- "+strings.Join(items, "\n- "))
	}
	if len(sections) == 0 {
		return "", nil
	}
	return "[Thread working state]\n" + strings.Join(sections, "\n\n"), nil
}

// SaveConversation appends one turn to the conversation history of a run.
func (m *Manager) SaveConversation(ctx context.Context, userID int64, agentID, agentRunID, role, content string, metadata *jsx.Obj) error {
	scoped, err := m.agentID(ctx, userID, agentID)
	if err != nil {
		return err
	}
	_, err = m.db.W.ExecContext(ctx,
		`INSERT INTO conversation_history (user_id, agent_id, agent_run_id, role, content, metadata) VALUES (?, ?, ?, ?, ?, ?)`,
		userID, scoped, nilIfEmptyStr(agentRunID), role, content, jsx.Marshal(objOrEmpty(metadata)))
	return err
}

var (
	markTags = regexp.MustCompile(`</?mark>`)
)

func stripHighlight(text string) string { return markTags.ReplaceAllString(text, "") }

// buildExcerpt cuts the part of a text around the query, with ellipses.
func buildExcerpt(text, query string) string {
	raw := stripHighlight(text)
	needle := jsx.Lower(jsx.Trim(query))
	if raw == "" {
		return ""
	}
	if needle == "" {
		return jsx.Head(raw, 220)
	}
	pos := jsx.IndexFrom(jsx.Lower(raw), needle, 0)
	if pos == -1 {
		return jsx.Head(raw, 220)
	}
	length := jsx.Len(raw)
	start := max(0, pos-80)
	end := min(length, pos+jsx.Len(needle)+140)
	prefix, suffix := "", ""
	if start > 0 {
		prefix = "..."
	}
	if end < length {
		suffix = "..."
	}
	return prefix + jsx.Slice(raw, start, end) + suffix
}

// ConversationSummary is a conversation in the recent list.
type ConversationSummary struct {
	ID             string  `json:"id"`
	Title          string  `json:"title"`
	Platform       string  `json:"platform"`
	PlatformChatID *string `json:"platformChatId"`
	UpdatedAt      string  `json:"updatedAt"`
	Summary        string  `json:"summary"`
	Preview        string  `json:"preview"`
}

const noSummary = "No summary available."

// RecentConversations lists the latest conversations of an agent. An agent
// with none falls back to the titles of its runs.
func (m *Manager) RecentConversations(ctx context.Context, userID int64, agentID string, limit int) ([]ConversationSummary, error) {
	scoped, err := m.agentID(ctx, userID, agentID)
	if err != nil {
		return nil, err
	}
	if limit == 0 {
		limit = 20
	}
	type row struct {
		id, title, platform, summary, working, updated, latest string
		chat                                                   *string
	}
	rows, err := collect(ctx, m.db.R, func(r rowScanner) (row, error) {
		var x row
		var title, platform, chat, summary, working, updated, latest sql.NullString
		err := r.Scan(&x.id, &title, &platform, &chat, &summary, &working, &updated, &latest)
		x.title, x.platform, x.chat, x.summary = title.String, platform.String, optionalString(chat), summary.String
		x.working, x.updated, x.latest = working.String, updated.String, latest.String
		return x, err
	}, `
      SELECT
        c.id,
        c.title,
        c.platform,
        c.platform_chat_id,
        c.summary,
        c.working_state_json,
        c.updated_at,
        (
          SELECT content
          FROM conversation_messages cm
          WHERE cm.conversation_id = c.id
          ORDER BY cm.created_at DESC, cm.id DESC
          LIMIT 1
        ) AS latest_content
      FROM conversations c
      WHERE c.user_id = ? AND c.agent_id = ?
      ORDER BY datetime(c.updated_at) DESC
      LIMIT ?
    `, userID, scoped, limit)
	if err != nil {
		return nil, err
	}

	if len(rows) == 0 {
		type run struct{ id, title, created, completed, latest string }
		runs, err := collect(ctx, m.db.R, func(r rowScanner) (run, error) {
			var x run
			var title, created, completed, status, latest sql.NullString
			err := r.Scan(&x.id, &title, &created, &completed, &status, &latest)
			x.title, x.created, x.completed, x.latest = title.String, created.String, completed.String, latest.String
			return x, err
		}, `
        SELECT
          ar.id AS run_id,
          ar.title,
          ar.created_at,
          ar.completed_at,
          ar.status,
          (
            SELECT content
            FROM conversation_history ch
            WHERE ch.agent_run_id = ar.id
            ORDER BY ch.created_at DESC
            LIMIT 1
          ) AS latest_content
        FROM agent_runs ar
        WHERE ar.user_id = ? AND ar.agent_id = ?
        ORDER BY COALESCE(ar.completed_at, ar.created_at) DESC
        LIMIT ?
      `, userID, scoped, limit)
		if err != nil {
			return nil, err
		}
		out := make([]ConversationSummary, len(runs))
		for i, r := range runs {
			summary := orLabel(buildExcerpt(r.latest, ""), noSummary)
			out[i] = ConversationSummary{ID: r.id, Title: orLabel(r.title, "web conversation"), Platform: "web",
				UpdatedAt: orLabel(r.completed, r.created), Summary: summary, Preview: summary}
		}
		return out, nil
	}

	out := make([]ConversationSummary, len(rows))
	for i, r := range rows {
		summary := r.summary
		if summary == "" {
			if working, err := jsx.Parse(r.working); err == nil {
				if o, ok := working.(*jsx.Obj); ok && jsx.Truthy(o.Value("summary")) {
					summary = jsx.ToString(o.Value("summary"))
				}
			}
		}
		if summary == "" {
			summary = buildExcerpt(r.latest, "")
		}
		platform := orLabel(r.platform, "web")
		summary = orLabel(summary, noSummary)
		out[i] = ConversationSummary{ID: r.id, Title: orLabel(r.title, orLabel(r.platform, "chat")+" conversation"),
			Platform: platform, PlatformChatID: r.chat, UpdatedAt: r.updated, Summary: summary, Preview: summary}
	}
	return out, nil
}

// ConversationMatch is one matching message of a session.
type ConversationMatch struct {
	Role      string `json:"role"`
	CreatedAt string `json:"createdAt"`
	Excerpt   string `json:"excerpt"`
}

// ConversationHit is a session that matched a search.
type ConversationHit struct {
	SessionID  string              `json:"sessionId"`
	Source     string              `json:"source"`
	Title      string              `json:"title"`
	Platform   string              `json:"platform"`
	CreatedAt  string              `json:"createdAt"`
	Score      float64             `json:"score"`
	Matches    []ConversationMatch `json:"matches"`
	MatchCount int                 `json:"matchCount"`
	Summary    string              `json:"summary"`
}

type messageHit struct {
	source, sessionID, title, role, createdAt, platform, snippet string
	score                                                        float64
}

func scanMessageHit(withPlatform bool) func(rowScanner) (messageHit, error) {
	return func(r rowScanner) (messageHit, error) {
		var h messageHit
		var source, messageID, session, title, role, created, platform, snippet sql.NullString
		var score sql.NullFloat64
		var err error
		if withPlatform {
			err = r.Scan(&source, &messageID, &session, &title, &role, &created, &platform, &snippet, &score)
		} else {
			err = r.Scan(&source, &messageID, &session, &title, &role, &created, &snippet, &score)
		}
		h = messageHit{source.String, session.String, title.String, role.String, created.String, platform.String, snippet.String, score.Float64}
		return h, err
	}
}

// SearchConversationsOptions tune SearchConversations.
type SearchConversationsOptions struct {
	AgentID  string
	Limit    int // matching messages read per source
	Sessions int // sessions returned
}

// SearchConversations finds the sessions whose messages match a query, best
// session first, with the matching excerpts.
func (m *Manager) SearchConversations(ctx context.Context, userID int64, query string, o SearchConversationsOptions) ([]ConversationHit, error) {
	scoped, err := m.agentID(ctx, userID, o.AgentID)
	if err != nil {
		return nil, err
	}
	ftsQuery := BuildFtsQuery(query)
	limit := o.Limit
	if limit == 0 {
		limit = 24
	}
	maxHits := max(6, min(limit, 60))
	if ftsQuery == "" {
		return []ConversationHit{}, nil
	}
	rd := m.db.R

	web, err := collect(ctx, rd, scanMessageHit(false), `
        SELECT
          'web' AS source,
          ch.id AS message_id,
          COALESCE(ch.agent_run_id, 'web:' || ch.id) AS session_id,
          COALESCE(ar.title, 'Web chat') AS title,
          ch.role,
          ch.created_at,
          snippet(conversation_history_fts, 0, '<mark>', '</mark>', ' ... ', 16) AS snippet,
          bm25(conversation_history_fts) AS score
        FROM conversation_history_fts
        JOIN conversation_history ch ON ch.id = conversation_history_fts.rowid
        LEFT JOIN agent_runs ar ON ar.id = ch.agent_run_id
        WHERE conversation_history_fts MATCH ? AND ch.user_id = ? AND ch.agent_id = ?
        ORDER BY score
        LIMIT ?
      `, ftsQuery, userID, scoped, maxHits)
	var messages []messageHit
	if err == nil {
		messages, err = collect(ctx, rd, scanMessageHit(true), `
        SELECT
          'message' AS source,
          m.id AS message_id,
          COALESCE(m.run_id, m.platform || ':' || COALESCE(m.platform_chat_id, m.id)) AS session_id,
          COALESCE(ar.title, json_extract(m.metadata, '$.senderName'), m.platform_chat_id, m.platform, 'Message thread') AS title,
          m.role,
          m.created_at,
          m.platform,
          snippet(messages_fts, 0, '<mark>', '</mark>', ' ... ', 16) AS snippet,
          bm25(messages_fts) AS score
        FROM messages_fts
        JOIN messages m ON m.id = messages_fts.rowid
        LEFT JOIN agent_runs ar ON ar.id = m.run_id
        WHERE messages_fts MATCH ? AND m.user_id = ? AND m.agent_id = ?
        ORDER BY score
        LIMIT ?
      `, ftsQuery, userID, scoped, maxHits)
	}
	if err != nil {
		like := "%" + jsx.Trim(query) + "%"
		if web, err = collect(ctx, rd, scanMessageHit(false), `
        SELECT
          'web' AS source,
          ch.id AS message_id,
          COALESCE(ch.agent_run_id, 'web:' || ch.id) AS session_id,
          COALESCE(ar.title, 'Web chat') AS title,
          ch.role,
          ch.created_at,
          ch.content AS snippet,
          0 AS score
        FROM conversation_history ch
        LEFT JOIN agent_runs ar ON ar.id = ch.agent_run_id
        WHERE ch.user_id = ? AND ch.agent_id = ? AND ch.content LIKE ?
        ORDER BY ch.created_at DESC
        LIMIT ?
      `, userID, scoped, like, maxHits); err != nil {
			return nil, err
		}
		if messages, err = collect(ctx, rd, scanMessageHit(true), `
        SELECT
          'message' AS source,
          m.id AS message_id,
          COALESCE(m.run_id, m.platform || ':' || COALESCE(m.platform_chat_id, m.id)) AS session_id,
          COALESCE(ar.title, json_extract(m.metadata, '$.senderName'), m.platform_chat_id, m.platform, 'Message thread') AS title,
          m.role,
          m.created_at,
          m.platform,
          m.content AS snippet,
          0 AS score
        FROM messages m
        LEFT JOIN agent_runs ar ON ar.id = m.run_id
        WHERE m.user_id = ? AND m.agent_id = ? AND m.content LIKE ?
        ORDER BY m.created_at DESC
        LIMIT ?
      `, userID, scoped, like, maxHits); err != nil {
			return nil, err
		}
	}

	var order []string
	grouped := map[string]*ConversationHit{}
	for _, hit := range append(web, messages...) {
		key := hit.source + ":" + hit.sessionID
		group, ok := grouped[key]
		if !ok {
			group = &ConversationHit{SessionID: hit.sessionID, Source: hit.source, Title: orLabel(hit.title, "Untitled session"),
				Platform: orLabel(hit.platform, "web"), CreatedAt: hit.createdAt, Score: hit.score, Matches: []ConversationMatch{}}
			grouped[key] = group
			order = append(order, key)
		}
		group.Score = min(group.Score, hit.score)
		if hit.createdAt > group.CreatedAt {
			group.CreatedAt = hit.createdAt
		}
		if len(group.Matches) < 3 {
			group.Matches = append(group.Matches, ConversationMatch{Role: hit.role, CreatedAt: hit.createdAt, Excerpt: buildExcerpt(hit.snippet, query)})
		}
	}
	sessions := make([]*ConversationHit, len(order))
	for i, key := range order {
		sessions[i] = grouped[key]
	}
	sort.SliceStable(sessions, func(a, b int) bool {
		if sessions[a].Score != sessions[b].Score {
			return sessions[a].Score < sessions[b].Score
		}
		return localeCompare(sessions[b].CreatedAt, sessions[a].CreatedAt) < 0
	})
	count := o.Sessions
	if count == 0 {
		count = 8
	}
	count = max(1, min(count, 12))
	if len(sessions) > count {
		sessions = sessions[:count]
	}
	out := make([]ConversationHit, len(sessions))
	for i, s := range sessions {
		lines := make([]string, len(s.Matches))
		for j, match := range s.Matches {
			lines[j] = match.Role + ": " + match.Excerpt
		}
		s.MatchCount = len(s.Matches)
		s.Summary = strings.Join(lines, "\n")
		out[i] = *s
	}
	return out, nil
}
