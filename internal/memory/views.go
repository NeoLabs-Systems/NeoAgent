package memory

import (
	"context"
	"database/sql"
	"fmt"
	"sort"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/memory/jsx"
)

type viewDraft struct {
	viewType          string
	subjectKey        string
	title             string
	summary           string
	markdownText      string
	sourceMemoryIDs   []string
	sourceDocumentIDs []string
	metadata          *jsx.Obj
}

func memorySummaryLine(v MemoryView) string {
	names := make([]string, len(v.Entities))
	for i, e := range v.Entities {
		names[i] = e.Name
	}
	return SummarizeForPrompt(v.Content, names)
}

// firstClause is content.split(/[.!?\n]/)[0].
func firstClause(content string) string {
	if i := strings.IndexAny(content, ".!?\n"); i >= 0 {
		return content[:i]
	}
	return content
}

func orLabel(s, fallback string) string {
	if s == "" {
		return fallback
	}
	return s
}

func docTitle(d StoredDocument) string { return derefOr(d.Title, d.NormalizedType) }

func docText(d StoredDocument) string { return derefOr(d.Summary, d.Content) }

// MaterializeKnowledgeViews rebuilds the summaries of what an agent's memory
// holds: by topic, entity, recent facts, account, time, project and person.
func (m *Manager) MaterializeKnowledgeViews(ctx context.Context, userID int64, agentID string) ([]KnowledgeView, error) {
	scoped, err := m.agentID(ctx, userID, agentID)
	if err != nil {
		return nil, err
	}
	memories, err := m.ListMemories(ctx, userID, ListOptions{AgentID: scoped, Limit: 200})
	if err != nil {
		return nil, err
	}
	documents, err := m.ListIngestionDocuments(ctx, userID, DocumentFilter{AgentID: scoped, Limit: 200})
	if err != nil {
		return nil, err
	}
	entities, err := m.ListEntities(ctx, userID, EntityFilter{AgentID: scoped, Limit: 48})
	if err != nil {
		return nil, err
	}
	var views []viewDraft

	var topicOrder []string
	topicGroups := map[string][]MemoryView{}
	for _, memory := range memories {
		key := orLabel(memory.Category, "episodic")
		if _, ok := topicGroups[key]; !ok {
			topicOrder = append(topicOrder, key)
		}
		topicGroups[key] = append(topicGroups[key], memory)
	}
	for _, topic := range topicOrder {
		items := topicGroups[topic]
		lines := make([]string, 0, 6)
		for _, item := range items[:min(6, len(items))] {
			lines = append(lines, "- "+memorySummaryLine(item))
		}
		summary := strings.Join(lines, "\n")
		ids := make([]string, len(items))
		for i, item := range items {
			ids[i] = item.ID
		}
		views = append(views, viewDraft{
			viewType: "topic", subjectKey: topic, title: strings.ReplaceAll(topic, "_", " "),
			summary: jsx.Head(summary, 320), markdownText: "# " + topic + "\n\n" + summary,
			sourceMemoryIDs: ids, metadata: jsx.O("itemCount", len(items), "category", topic),
		})
	}

	for _, entity := range entities[:min(24, len(entities))] {
		type memberRow struct{ id, content, category, summary string }
		rows, err := collect(ctx, m.db.R, func(r rowScanner) (memberRow, error) {
			var x memberRow
			var importance sql.NullFloat64
			var summary, created, updated sql.NullString
			var category sql.NullString
			err := r.Scan(&x.id, &x.content, &category, &importance, &summary, &created, &updated)
			x.category, x.summary = category.String, summary.String
			return x, err
		}, `SELECT m.id, m.content, m.category, m.importance, m.summary, m.created_at, m.updated_at
         FROM memory_entity_mentions mem
         JOIN memories m ON m.id = mem.memory_id
         WHERE mem.entity_id = ? AND m.archived = 0
         ORDER BY m.importance DESC, m.updated_at DESC
         LIMIT 8`, entity.ID)
		if err != nil {
			return nil, err
		}
		if len(rows) == 0 {
			continue
		}
		lines := make([]string, len(rows))
		ids := make([]string, len(rows))
		for i, r := range rows {
			lines[i] = "- [" + NormalizeMemoryCategory(r.category) + "] " + orLabel(r.summary, r.content)
			ids[i] = r.id
		}
		joined := strings.Join(lines, "\n")
		views = append(views, viewDraft{
			viewType: "entity", subjectKey: entity.Key, title: entity.Name,
			summary:         jsx.Head(joined, 520),
			markdownText:    fmt.Sprintf("# %s\n\nKind: %s\nMentions: %d\n\n%s", entity.Name, entity.Kind, entity.MentionCount, joined),
			sourceMemoryIDs: ids,
			metadata:        jsx.O("entityId", entity.ID, "entityKey", entity.Key, "kind", entity.Kind, "mentionCount", entity.MentionCount),
		})
	}

	type factRow struct{ memoryID, subject, object string }
	factRows, err := collect(ctx, m.db.R, func(r rowScanner) (factRow, error) {
		var x factRow
		var id, predicate, category, updated sql.NullString
		var confidence sql.NullFloat64
		err := r.Scan(&id, &x.memoryID, &x.subject, &predicate, &x.object, &category, &confidence, &updated)
		return x, err
	}, `SELECT id, memory_id, subject, predicate, object, category, confidence, updated_at
       FROM memory_facts
       WHERE user_id = ? AND agent_id = ?
       ORDER BY updated_at DESC
       LIMIT 20`, userID, scoped)
	if err != nil {
		return nil, err
	}
	if len(factRows) > 0 {
		lines := make([]string, 0, 10)
		for _, f := range factRows[:min(10, len(factRows))] {
			lines = append(lines, "- "+f.subject+": "+f.object)
		}
		joined := strings.Join(lines, "\n")
		memoryIDs := make([]string, len(factRows))
		for i, f := range factRows {
			memoryIDs[i] = f.memoryID
		}
		views = append(views, viewDraft{
			viewType: "facts", subjectKey: "recent", title: "Recent extracted facts",
			summary: jsx.Head(joined, 520), markdownText: "# Recent extracted facts\n\n" + joined,
			sourceMemoryIDs: uniqueStrings(memoryIDs), metadata: jsx.O("itemCount", len(factRows)),
		})
	}

	var accountOrder []string
	accountGroups := map[string][]StoredDocument{}
	for _, doc := range documents {
		key := derefOr(doc.ProviderKey, "local") + ":" + derefOr(doc.SourceAccount, "default")
		if _, ok := accountGroups[key]; !ok {
			accountOrder = append(accountOrder, key)
		}
		accountGroups[key] = append(accountGroups[key], doc)
	}
	for _, key := range accountOrder {
		items := accountGroups[key]
		lead := items[0]
		lines := make([]string, 0, 4)
		for _, item := range items[:min(4, len(items))] {
			lines = append(lines, "- "+docTitle(item)+": "+docText(item))
		}
		joined := strings.Join(lines, "\n")
		ids := make([]string, len(items))
		for i, item := range items {
			ids[i] = item.ID
		}
		provider, account := derefOr(lead.ProviderKey, "local"), derefOr(lead.SourceAccount, "account")
		var providerMeta, accountMeta any
		if lead.ProviderKey != nil {
			providerMeta = *lead.ProviderKey
		}
		if lead.SourceAccount != nil {
			accountMeta = *lead.SourceAccount
		}
		views = append(views, viewDraft{
			viewType: "account", subjectKey: key, title: provider + " " + account,
			summary: jsx.Head(joined, 320), markdownText: "# " + provider + " / " + account + "\n\n" + joined,
			sourceDocumentIDs: ids,
			metadata:          jsx.O("providerKey", providerMeta, "sourceAccount", accountMeta, "itemCount", len(items)),
		})
	}

	timeline := append([]StoredDocument(nil), documents...)
	sort.SliceStable(timeline, func(a, b int) bool { return localeCompare(timeline[b].UpdatedAt, timeline[a].UpdatedAt) < 0 })
	if len(timeline) > 8 {
		timeline = timeline[:8]
	}
	if len(timeline) > 0 {
		parts := make([]string, len(timeline))
		lines := make([]string, len(timeline))
		ids := make([]string, len(timeline))
		for i, item := range timeline {
			parts[i] = docTitle(item) + ": " + docText(item)
			lines[i] = "- " + parts[i]
			ids[i] = item.ID
		}
		views = append(views, viewDraft{
			viewType: "timeline", subjectKey: "recent", title: "Recent knowledge changes",
			summary:           jsx.Head(strings.Join(parts, " | "), 320),
			markdownText:      "# Recent knowledge changes\n\n" + strings.Join(lines, "\n"),
			sourceDocumentIDs: ids, metadata: jsx.O("itemCount", len(timeline)),
		})
	}

	var projects, people []MemoryView
	for _, memory := range memories {
		switch memory.Category {
		case "projects":
			projects = append(projects, memory)
		case "contacts", "identity":
			people = append(people, memory)
		}
	}
	for _, memory := range projects[:min(12, len(projects))] {
		title := orLabel(jsx.Head(firstClause(memory.Content), 120), "Project")
		views = append(views, viewDraft{
			viewType: "project", subjectKey: memory.ID, title: title,
			summary: jsx.Head(memory.Content, 320), markdownText: "# " + title + "\n\n" + memory.Content,
			sourceMemoryIDs: []string{memory.ID}, metadata: jsx.O("importance", memory.Importance),
		})
	}
	for _, memory := range people[:min(12, len(people))] {
		title := orLabel(jsx.Head(firstClause(memory.Content), 120), "Person")
		views = append(views, viewDraft{
			viewType: "person", subjectKey: memory.ID, title: title,
			summary: jsx.Head(memory.Content, 320), markdownText: "# " + title + "\n\n" + memory.Content,
			sourceMemoryIDs: []string{memory.ID}, metadata: jsx.O("category", memory.Category),
		})
	}

	for _, view := range views {
		if err := m.storeView(ctx, userID, scoped, view); err != nil {
			return nil, err
		}
	}
	return m.ListKnowledgeViews(ctx, userID, ViewFilter{AgentID: scoped, Limit: 64})
}

func (m *Manager) storeView(ctx context.Context, userID int64, agentID string, v viewDraft) error {
	var existing sql.NullString
	if _, err := one(ctx, m.db.W, []any{&existing},
		`SELECT id FROM materialized_knowledge_views
         WHERE user_id = ? AND agent_id = ? AND view_type = ? AND subject_key = ?`, userID, agentID, v.viewType, v.subjectKey); err != nil {
		return err
	}
	id := existing.String
	if id == "" {
		id = m.newID()
	}
	_, err := m.db.W.ExecContext(ctx,
		`INSERT INTO materialized_knowledge_views (
          id, user_id, agent_id, view_type, subject_key, title, summary, markdown_text,
          source_memory_ids_json, source_document_ids_json, metadata_json, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'), datetime('now'))
        ON CONFLICT(id) DO UPDATE SET
          title = excluded.title,
          summary = excluded.summary,
          markdown_text = excluded.markdown_text,
          source_memory_ids_json = excluded.source_memory_ids_json,
          source_document_ids_json = excluded.source_document_ids_json,
          metadata_json = excluded.metadata_json,
          updated_at = excluded.updated_at`,
		id, userID, agentID, v.viewType, v.subjectKey, v.title, v.summary, v.markdownText,
		jsx.Marshal(normalizeStringArray(v.sourceMemoryIDs, 48, 64)),
		jsx.Marshal(normalizeStringArray(v.sourceDocumentIDs, 48, 64)),
		jsx.Marshal(objOrEmpty(v.metadata)))
	return err
}
