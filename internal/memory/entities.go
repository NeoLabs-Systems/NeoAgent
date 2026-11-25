package memory

import (
	"context"
	"database/sql"
	"sort"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/memory/jsx"
)

// Entity is a named thing the agent's memories mention.
type Entity struct {
	ID           string   `json:"id"`
	Key          string   `json:"key"`
	Name         string   `json:"name"`
	Kind         string   `json:"kind"`
	Aliases      []string `json:"aliases"`
	Summary      string   `json:"summary"`
	MentionCount int64    `json:"mentionCount"`
	FirstSeenAt  *string  `json:"firstSeenAt"`
	LastSeenAt   *string  `json:"lastSeenAt"`
	Metadata     *jsx.Obj `json:"metadata"`
}

// EntityFilter narrows ListEntities.
type EntityFilter struct {
	AgentID string
	Limit   int
	Query   string
}

// lowercaseWords is the lowercase vocabulary of the agent's live memories,
// cached until they change.
func (m *Manager) lowercaseWords(ctx context.Context, userID int64, agentID string) (map[string]bool, error) {
	var count sql.NullInt64
	var updated sql.NullString
	if err := m.db.R.QueryRowContext(ctx,
		`SELECT COUNT(*) AS count, MAX(updated_at) AS updatedAt
       FROM memories WHERE user_id = ? AND agent_id = ? AND archived = 0`, userID, agentID).Scan(&count, &updated); err != nil {
		return nil, err
	}
	key := strings.Join([]string{itoa(userID), agentID, itoa(count.Int64), updated.String}, ":")
	m.lowercaseMu.Lock()
	defer m.lowercaseMu.Unlock()
	if m.lowercaseCache.key == key {
		return m.lowercaseCache.words, nil
	}
	contents, err := collect(ctx, m.db.R, scanString,
		`SELECT content FROM memories WHERE user_id = ? AND agent_id = ? AND archived = 0`, userID, agentID)
	if err != nil {
		return nil, err
	}
	words := CollectLowercaseWords(contents, nil)
	m.lowercaseCache.key, m.lowercaseCache.words = key, words
	return words, nil
}

// ListEntities lists the most mentioned entities of an agent.
func (m *Manager) ListEntities(ctx context.Context, userID int64, f EntityFilter) ([]Entity, error) {
	agentID, err := m.agentID(ctx, userID, f.AgentID)
	if err != nil {
		return nil, err
	}
	limit := f.Limit
	if limit == 0 {
		limit = 24
	}
	wanted := max(1, min(limit, 250))
	query := `SELECT ent.id, ent.entity_key, ent.name, ent.kind, ent.aliases_json, ent.summary, ent.mention_count,
	             ent.first_seen_at, ent.last_seen_at, ent.metadata_json, EXISTS (
                 SELECT 1 FROM memory_entity_mentions mem
                 JOIN memories m ON m.id = mem.memory_id AND m.archived = 0
                 WHERE mem.entity_id = ent.id AND mem.in_sentence = 1
               ) AS has_in_sentence_mention
               FROM memory_entities ent
               WHERE ent.user_id = ? AND ent.agent_id = ?
                 AND EXISTS (
                   SELECT 1 FROM memory_entity_mentions mem
                   JOIN memories m ON m.id = mem.memory_id AND m.archived = 0
                   WHERE mem.entity_id = ent.id
                 )`
	args := []any{userID, agentID}
	if normalized := jsx.Trim(f.Query); normalized != "" {
		query += ` AND (ent.entity_key LIKE ? OR ent.name LIKE ?)`
		args = append(args, "%"+CanonicalEntityKey(normalized)+"%", "%"+normalized+"%")
	}
	// Over-fetch: unconfirmed sentence-initial words are filtered out below.
	query += ` ORDER BY ent.mention_count DESC, ent.last_seen_at DESC LIMIT ?`
	args = append(args, wanted*4)
	lowercase, err := m.lowercaseWords(ctx, userID, agentID)
	if err != nil {
		return nil, err
	}
	type scanned struct {
		entity    Entity
		confirmed bool
	}
	rows, err := collect(ctx, m.db.R, func(r rowScanner) (scanned, error) {
		var e Entity
		var kind, aliases, summary, first, last, meta sql.NullString
		var mentions, hasInSentence sql.NullInt64
		if err := r.Scan(&e.ID, &e.Key, &e.Name, &kind, &aliases, &summary, &mentions, &first, &last, &meta, &hasInSentence); err != nil {
			return scanned{}, err
		}
		e.Kind = kind.String
		if e.Kind == "" {
			e.Kind = "concept"
		}
		e.Aliases = parseStringList(aliases.String, 16, 160)
		e.Summary = summary.String
		e.MentionCount = mentions.Int64
		e.FirstSeenAt, e.LastSeenAt = optionalString(first), optionalString(last)
		e.Metadata = jsx.ParseObject(meta.String)
		return scanned{e, IsConfirmedEntity(e.Name, hasInSentence.Int64 == 1, lowercase)}, nil
	}, query, args...)
	if err != nil {
		return nil, err
	}
	out := make([]Entity, 0, wanted)
	for _, row := range rows {
		if row.confirmed && len(out) < wanted {
			out = append(out, row.entity)
		}
	}
	return out, nil
}

// GraphEdge links two entities that live memories mention together.
type GraphEdge struct {
	Source string  `json:"source"`
	Target string  `json:"target"`
	Weight float64 `json:"weight"`
}

// EntityGraph is the entities with their co-occurrence links.
type EntityGraph struct {
	Nodes []Entity    `json:"nodes"`
	Edges []GraphEdge `json:"edges"`
}

// EntityGraphOf returns the most mentioned entities plus co-occurrence edges
// (two entities linked by the live memories that mention both), trimmed to
// each node's strongest links so the graph stays readable.
func (m *Manager) EntityGraphOf(ctx context.Context, userID int64, agentID string, limit int) (EntityGraph, error) {
	if limit == 0 {
		limit = 60
	}
	const linksPerNode = 6
	nodes, err := m.ListEntities(ctx, userID, EntityFilter{AgentID: agentID, Limit: limit})
	if err != nil {
		return EntityGraph{}, err
	}
	if len(nodes) < 2 {
		return EntityGraph{Nodes: nodes, Edges: []GraphEdge{}}, nil
	}
	ids := make([]string, len(nodes))
	for i, n := range nodes {
		ids[i] = n.ID
	}
	in := placeholders(len(ids))
	pairs, err := collect(ctx, m.db.R, func(r rowScanner) (GraphEdge, error) {
		var e GraphEdge
		err := r.Scan(&e.Source, &e.Target, &e.Weight)
		return e, err
	}, `SELECT a.entity_id AS source, b.entity_id AS target, COUNT(*) AS weight
       FROM memory_entity_mentions a
       JOIN memory_entity_mentions b ON b.memory_id = a.memory_id AND a.entity_id < b.entity_id
       JOIN memories m ON m.id = a.memory_id AND m.archived = 0
       WHERE a.entity_id IN (`+in+`) AND b.entity_id IN (`+in+`)
       GROUP BY a.entity_id, b.entity_id
       ORDER BY weight DESC`, append(anySlice(ids), anySlice(ids)...)...)
	if err != nil {
		return EntityGraph{}, err
	}
	linkCounts := map[string]int{}
	edges := []GraphEdge{}
	for _, pair := range pairs {
		if linkCounts[pair.Source] >= linksPerNode && linkCounts[pair.Target] >= linksPerNode {
			continue
		}
		linkCounts[pair.Source]++
		linkCounts[pair.Target]++
		edges = append(edges, pair)
	}
	return EntityGraph{Nodes: nodes, Edges: edges}, nil
}

// ListEntityMemories lists the live memories that mention an entity.
func (m *Manager) ListEntityMemories(ctx context.Context, userID int64, entityID, agentID string, limit int) ([]MemoryView, error) {
	scoped, err := m.agentID(ctx, userID, agentID)
	if err != nil {
		return nil, err
	}
	if limit == 0 {
		limit = 40
	}
	rows, err := collect(ctx, m.db.R, scanListRow,
		`SELECT m.id, m.category, m.content, m.summary, m.importance, m.confidence, m.access_count,
              m.memory_strength, m.last_accessed_at, m.pinned, m.archived, m.created_at, m.updated_at,
              m.scope_type, m.scope_id, m.source_type, m.source_id, m.source_label, m.stale_after_days, m.metadata_json
       FROM memory_entity_mentions mem
       JOIN memories m ON m.id = mem.memory_id
       WHERE mem.entity_id = ? AND m.user_id = ? AND m.agent_id = ? AND m.archived = 0
       ORDER BY m.importance DESC, m.updated_at DESC
       LIMIT ?`, entityID, userID, scoped, max(1, min(limit, 200)))
	if err != nil {
		return nil, err
	}
	return m.viewsWithEntities(ctx, rows)
}

// KnowledgeView is a materialized summary of what memory knows about a topic,
// an entity, an account or a time span.
type KnowledgeView struct {
	ID                string   `json:"id"`
	ViewType          string   `json:"viewType"`
	SubjectKey        string   `json:"subjectKey"`
	Title             string   `json:"title"`
	Summary           string   `json:"summary"`
	MarkdownText      string   `json:"markdownText"`
	SourceMemoryIDs   []string `json:"sourceMemoryIds"`
	SourceDocumentIDs []string `json:"sourceDocumentIds"`
	Metadata          *jsx.Obj `json:"metadata"`
	UpdatedAt         *string  `json:"updatedAt"`
}

// ViewFilter narrows ListKnowledgeViews.
type ViewFilter struct {
	AgentID  string
	ViewType string
	Limit    int
}

// ListKnowledgeViews lists the newest knowledge views of an agent.
func (m *Manager) ListKnowledgeViews(ctx context.Context, userID int64, f ViewFilter) ([]KnowledgeView, error) {
	agentID, err := m.agentID(ctx, userID, f.AgentID)
	if err != nil {
		return nil, err
	}
	query := `SELECT id, view_type, subject_key, title, summary, markdown_text, source_memory_ids_json,
	       source_document_ids_json, metadata_json, updated_at
               FROM materialized_knowledge_views
               WHERE user_id = ? AND agent_id = ?`
	args := []any{userID, agentID}
	if f.ViewType != "" {
		query += ` AND view_type = ?`
		args = append(args, jsx.Trim(f.ViewType))
	}
	limit := f.Limit
	if limit == 0 {
		limit = 40
	}
	query += ` ORDER BY updated_at DESC LIMIT ?`
	args = append(args, max(1, min(limit, 100)))
	return collect(ctx, m.db.R, func(r rowScanner) (KnowledgeView, error) {
		var v KnowledgeView
		var summary, markdown, memories, documents, meta, updated sql.NullString
		if err := r.Scan(&v.ID, &v.ViewType, &v.SubjectKey, &v.Title, &summary, &markdown, &memories, &documents, &meta, &updated); err != nil {
			return v, err
		}
		v.Summary, v.MarkdownText = summary.String, markdown.String
		v.SourceMemoryIDs = parseStringList(memories.String, 24, 160)
		v.SourceDocumentIDs = parseStringList(documents.String, 24, 160)
		v.Metadata = jsx.ParseObject(meta.String)
		v.UpdatedAt = optionalString(updated)
		return v, nil
	}, query, args...)
}

// KnowledgeChange is a recently changed document or view.
type KnowledgeChange struct {
	Kind        string  `json:"kind"`
	ID          string  `json:"id"`
	Title       string  `json:"title"`
	Summary     string  `json:"summary"`
	SourceType  string  `json:"sourceType"`
	ProviderKey any     `json:"providerKey"`
	UpdatedAt   *string `json:"updatedAt"`
}

// ListRecentKnowledgeChanges merges the newest documents and views by time.
func (m *Manager) ListRecentKnowledgeChanges(ctx context.Context, userID int64, agentID string, limit int) ([]KnowledgeChange, error) {
	if limit == 0 {
		limit = 8
	}
	docs, err := m.ListIngestionDocuments(ctx, userID, DocumentFilter{AgentID: agentID, Limit: limit})
	if err != nil {
		return nil, err
	}
	views, err := m.ListKnowledgeViews(ctx, userID, ViewFilter{AgentID: agentID, Limit: limit})
	if err != nil {
		return nil, err
	}
	var changes []KnowledgeChange
	for _, d := range docs {
		title := derefOr(d.Title, d.NormalizedType)
		summary := derefOr(d.Summary, d.Content)
		var provider any
		if d.ProviderKey != nil {
			provider = *d.ProviderKey
		}
		changes = append(changes, KnowledgeChange{"document", d.ID, title, summary, d.SourceType, provider, strPtrOf(d.UpdatedAt)})
	}
	for _, v := range views {
		changes = append(changes, KnowledgeChange{"view", v.ID, v.Title, v.Summary, v.ViewType, nilIfFalsy(v.Metadata.Value("providerKey")), v.UpdatedAt})
	}
	sort.SliceStable(changes, func(a, b int) bool {
		return localeCompare(derefOr(changes[b].UpdatedAt, ""), derefOr(changes[a].UpdatedAt, "")) < 0
	})
	if n := max(1, min(limit, 24)); len(changes) > n {
		changes = changes[:n]
	}
	if changes == nil {
		changes = []KnowledgeChange{}
	}
	return changes, nil
}

func derefOr(p *string, fallback string) string {
	if p != nil && *p != "" {
		return *p
	}
	return fallback
}

func strPtrOf(s string) *string { return &s }
