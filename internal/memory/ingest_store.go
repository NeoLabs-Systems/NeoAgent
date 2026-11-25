package memory

import (
	"context"
	"database/sql"

	"github.com/NeoLabs-Systems/neoagent/internal/memory/jsx"
)

// IngestionJob is one run that read source material into memory.
type IngestionJob struct {
	ID              string   `json:"id"`
	SourceType      string   `json:"sourceType"`
	ProviderKey     *string  `json:"providerKey"`
	ConnectionID    *int64   `json:"connectionId"`
	Status          string   `json:"status"`
	FreshnessPolicy *jsx.Obj `json:"freshnessPolicy"`
	Cursor          *jsx.Obj `json:"cursor"`
	Summary         *jsx.Obj `json:"summary"`
	Metadata        *jsx.Obj `json:"metadata"`
	DocumentCount   int      `json:"documentCount"`
	Error           *string  `json:"error"`
	StartedAt       *string  `json:"startedAt"`
	CompletedAt     *string  `json:"completedAt"`
	NextSyncAt      *string  `json:"nextSyncAt"`
	UpdatedAt       *string  `json:"updatedAt"`
}

// JobFilter narrows ListIngestionJobs.
type JobFilter struct {
	AgentID     string
	SourceType  string
	ProviderKey string
	Limit       int
}

// ListIngestionJobs lists the newest ingestion jobs of an agent.
func (m *Manager) ListIngestionJobs(ctx context.Context, userID int64, f JobFilter) ([]IngestionJob, error) {
	agentID, err := m.agentID(ctx, userID, f.AgentID)
	if err != nil {
		return nil, err
	}
	query := `SELECT id, source_type, provider_key, connection_id, status, freshness_policy_json, cursor_json, summary_json,
	       metadata_json, document_count, error_text, started_at, completed_at, next_sync_at, updated_at
               FROM memory_ingestion_jobs
               WHERE user_id = ? AND agent_id = ?`
	args := []any{userID, agentID}
	if f.SourceType != "" {
		query += ` AND source_type = ?`
		args = append(args, jsx.Trim(f.SourceType))
	}
	if f.ProviderKey != "" {
		query += ` AND provider_key = ?`
		args = append(args, jsx.Trim(f.ProviderKey))
	}
	limit := f.Limit
	if limit == 0 {
		limit = 25
	}
	query += ` ORDER BY updated_at DESC LIMIT ?`
	args = append(args, max(1, min(limit, 100)))
	return collect(ctx, m.db.R, func(r rowScanner) (IngestionJob, error) {
		var j IngestionJob
		var provider, status, freshness, cursor, summary, metadata, errText, started, completed, next, updated sql.NullString
		var connection, docs sql.NullInt64
		if err := r.Scan(&j.ID, &j.SourceType, &provider, &connection, &status, &freshness, &cursor, &summary, &metadata,
			&docs, &errText, &started, &completed, &next, &updated); err != nil {
			return j, err
		}
		j.ProviderKey = optionalString(provider)
		if connection.Valid {
			j.ConnectionID = &connection.Int64
		}
		j.Status = status.String
		if j.Status == "" {
			j.Status = "pending"
		}
		j.FreshnessPolicy, j.Cursor = jsx.ParseObject(freshness.String), jsx.ParseObject(cursor.String)
		j.Summary, j.Metadata = jsx.ParseObject(summary.String), jsx.ParseObject(metadata.String)
		j.DocumentCount = int(docs.Int64)
		j.Error, j.StartedAt, j.CompletedAt = optionalString(errText), optionalString(started), optionalString(completed)
		j.NextSyncAt, j.UpdatedAt = optionalString(next), optionalString(updated)
		return j, nil
	}, query, args...)
}

// JobRecord is what RecordIngestionJob stores. An empty ID makes a new job.
type JobRecord struct {
	ID            string
	SourceType    string
	ProviderKey   string
	ConnectionID  int64
	Status        string
	Summary       *jsx.Obj
	Metadata      *jsx.Obj
	DocumentCount int
	Error         string
	CompletedAt   string
}

func objOrEmpty(o *jsx.Obj) *jsx.Obj {
	if o == nil {
		return jsx.NewObj()
	}
	return o
}

// RecordIngestionJob inserts a job or updates the one with the same id.
func (m *Manager) RecordIngestionJob(ctx context.Context, userID int64, agentID string, job JobRecord) (string, error) {
	scoped, err := m.agentID(ctx, userID, agentID)
	if err != nil {
		return "", err
	}
	id := jsx.Trim(job.ID)
	if id == "" {
		id = m.newID()
	}
	sourceType := jsx.Trim(job.SourceType)
	if sourceType == "" {
		sourceType = "unknown"
	}
	status := jsx.Trim(job.Status)
	if status == "" {
		status = "completed"
	}
	var connection any
	if job.ConnectionID > 0 {
		connection = job.ConnectionID
	}
	_, err = m.db.W.ExecContext(ctx,
		`INSERT INTO memory_ingestion_jobs (
        id, user_id, agent_id, source_type, provider_key, connection_id, status,
        freshness_policy_json, cursor_json, summary_json, metadata_json, document_count,
        error_text, started_at, completed_at, next_sync_at, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, COALESCE(?, datetime('now')), ?, ?, datetime('now'), datetime('now'))
      ON CONFLICT(id) DO UPDATE SET
        status = excluded.status,
        freshness_policy_json = excluded.freshness_policy_json,
        cursor_json = excluded.cursor_json,
        summary_json = excluded.summary_json,
        metadata_json = excluded.metadata_json,
        document_count = excluded.document_count,
        error_text = excluded.error_text,
        completed_at = excluded.completed_at,
        next_sync_at = excluded.next_sync_at,
        updated_at = excluded.updated_at`,
		id, userID, scoped, sourceType, jsx.Trim(job.ProviderKey), connection, status,
		"{}", "{}", jsx.Marshal(objOrEmpty(job.Summary)), jsx.Marshal(objOrEmpty(job.Metadata)), job.DocumentCount,
		nilIfEmptyStr(jsx.Trim(job.Error)), nil, nilIfEmptyStr(job.CompletedAt), nil)
	return id, err
}

// UpsertIngestionDocument stores a source document, replacing the one with the
// same external id, and returns its id.
func (m *Manager) UpsertIngestionDocument(ctx context.Context, userID int64, agentID string, doc Document) (string, error) {
	scoped, err := m.agentID(ctx, userID, agentID)
	if err != nil {
		return "", err
	}
	providerKey := jsx.Trim(doc.ProviderKey)
	connectionID := int64(0)
	if doc.ConnectionID > 0 {
		connectionID = doc.ConnectionID
	}
	sourceType := jsx.Trim(doc.SourceType)
	if sourceType == "" {
		sourceType = "unknown"
	}
	externalObjectID := jsx.Trim(doc.ExternalObjectID)
	content := jsx.Trim(doc.Content)
	if externalObjectID == "" || content == "" {
		return "", errIngestionDocument
	}

	var existingID, existingMeta sql.NullString
	if _, err := one(ctx, m.db.W, []any{&existingID, &existingMeta},
		`SELECT id, metadata_json
       FROM memory_ingestion_documents
       WHERE user_id = ? AND agent_id = ? AND source_type = ? AND provider_key = ? AND connection_id = ? AND external_object_id = ?`,
		userID, scoped, sourceType, providerKey, connectionID, externalObjectID); err != nil {
		return "", err
	}
	docID := existingID.String
	if docID == "" {
		docID = m.newID()
	}
	metadata := jsx.ParseObject(existingMeta.String).Assign(objOrEmpty(doc.Metadata))
	normalizedType := jsx.Trim(doc.NormalizedType)
	if normalizedType == "" {
		normalizedType = sourceType
	}
	salience := doc.Salience
	if !jsx.IsFinite(salience) || salience == 0 {
		salience = 5
	}
	_, err = m.db.W.ExecContext(ctx,
		`INSERT INTO memory_ingestion_documents (
        id, user_id, agent_id, source_type, normalized_type, provider_key, connection_id,
        external_object_id, source_account, title, content, summary, salience, source_timestamp,
        metadata_json, payload_json, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'), datetime('now'))
      ON CONFLICT(id) DO UPDATE SET
        normalized_type = excluded.normalized_type,
        source_account = excluded.source_account,
        title = excluded.title,
        content = excluded.content,
        summary = excluded.summary,
        salience = excluded.salience,
        source_timestamp = excluded.source_timestamp,
        metadata_json = excluded.metadata_json,
        payload_json = excluded.payload_json,
        updated_at = excluded.updated_at`,
		docID, userID, scoped, sourceType, normalizedType, providerKey, connectionID, externalObjectID,
		nilIfEmptyStr(jsx.Trim(doc.SourceAccount)), nilIfEmptyStr(jsx.Trim(doc.Title)), content,
		nilIfEmptyStr(jsx.Trim(doc.Summary)), max(1, min(10, salience)), nilIfEmptyStr(doc.SourceTimestamp),
		jsx.Marshal(metadata), jsx.Marshal(objOrEmpty(doc.Payload)))
	return docID, err
}

type documentError string

func (e documentError) Error() string { return string(e) }

const errIngestionDocument = documentError("Ingestion documents require externalObjectId and content.")

// ListIngestedObjectIDs lists the external ids already ingested from a connection.
func (m *Manager) ListIngestedObjectIDs(ctx context.Context, userID, connectionID int64, agentID string) (map[string]bool, error) {
	scoped, err := m.agentID(ctx, userID, agentID)
	if err != nil {
		return nil, err
	}
	ids, err := collect(ctx, m.db.R, scanString,
		`SELECT external_object_id
       FROM memory_ingestion_documents
       WHERE user_id = ? AND agent_id = ? AND connection_id = ?`, userID, scoped, max(connectionID, 0))
	if err != nil {
		return nil, err
	}
	set := make(map[string]bool, len(ids))
	for _, id := range ids {
		set[id] = true
	}
	return set, nil
}

// StoredDocument is an ingested document as listed.
type StoredDocument struct {
	ID               string   `json:"id"`
	SourceType       string   `json:"sourceType"`
	NormalizedType   string   `json:"normalizedType"`
	ProviderKey      *string  `json:"providerKey"`
	ConnectionID     *int64   `json:"connectionId"`
	ExternalObjectID string   `json:"externalObjectId"`
	SourceAccount    *string  `json:"sourceAccount"`
	Title            *string  `json:"title"`
	Content          string   `json:"content"`
	Summary          *string  `json:"summary"`
	Salience         float64  `json:"salience"`
	SourceTimestamp  *string  `json:"sourceTimestamp"`
	Metadata         *jsx.Obj `json:"metadata"`
	Payload          *jsx.Obj `json:"payload"`
	CreatedAt        string   `json:"createdAt"`
	UpdatedAt        string   `json:"updatedAt"`
}

// DocumentFilter narrows ListIngestionDocuments.
type DocumentFilter struct {
	AgentID     string
	SourceType  string
	ProviderKey string
	Limit       int
}

// ListIngestionDocuments lists the newest ingested documents of an agent.
func (m *Manager) ListIngestionDocuments(ctx context.Context, userID int64, f DocumentFilter) ([]StoredDocument, error) {
	agentID, err := m.agentID(ctx, userID, f.AgentID)
	if err != nil {
		return nil, err
	}
	query := `SELECT id, source_type, normalized_type, provider_key, connection_id, external_object_id, source_account, title,
	       content, summary, salience, source_timestamp, metadata_json, payload_json, created_at, updated_at
               FROM memory_ingestion_documents
               WHERE user_id = ? AND agent_id = ?`
	args := []any{userID, agentID}
	if f.SourceType != "" {
		query += ` AND source_type = ?`
		args = append(args, jsx.Trim(f.SourceType))
	}
	if f.ProviderKey != "" {
		query += ` AND provider_key = ?`
		args = append(args, jsx.Trim(f.ProviderKey))
	}
	limit := f.Limit
	if limit == 0 {
		limit = 40
	}
	query += ` ORDER BY updated_at DESC LIMIT ?`
	args = append(args, max(1, min(limit, 200)))
	return collect(ctx, m.db.R, func(r rowScanner) (StoredDocument, error) {
		var d StoredDocument
		var provider, account, title, summary, timestamp, meta, payload, created, updated sql.NullString
		var connection sql.NullInt64
		var salience sql.NullFloat64
		if err := r.Scan(&d.ID, &d.SourceType, &d.NormalizedType, &provider, &connection, &d.ExternalObjectID, &account, &title,
			&d.Content, &summary, &salience, &timestamp, &meta, &payload, &created, &updated); err != nil {
			return d, err
		}
		d.ProviderKey = optionalString(provider)
		if connection.Valid && connection.Int64 != 0 {
			d.ConnectionID = &connection.Int64
		}
		d.SourceAccount, d.Title, d.Summary = optionalString(account), optionalString(title), optionalString(summary)
		d.Salience = salience.Float64
		d.SourceTimestamp = optionalString(timestamp)
		d.Metadata, d.Payload = jsx.ParseObject(meta.String), jsx.ParseObject(payload.String)
		d.CreatedAt, d.UpdatedAt = created.String, updated.String
		return d, nil
	}, query, args...)
}

// DeleteIngestionDocument removes a document with its chunks and the memories
// that only it supported. It reports whether the document existed.
func (m *Manager) DeleteIngestionDocument(ctx context.Context, userID int64, agentID, documentID string) (bool, error) {
	scoped, err := m.agentID(ctx, userID, agentID)
	if err != nil {
		return false, err
	}
	var id string
	found, err := one(ctx, m.db.W, []any{&id},
		`SELECT id FROM memory_ingestion_documents WHERE id = ? AND user_id = ? AND agent_id = ?`, documentID, userID, scoped)
	if err != nil || !found {
		return false, err
	}
	if _, err := m.PruneSourceChunks(ctx, documentID, nil); err != nil {
		return false, err
	}
	_, err = m.db.W.ExecContext(ctx, `DELETE FROM memory_ingestion_documents WHERE id = ?`, documentID)
	return err == nil, err
}

// PruneSourceChunks deletes the chunks of a document that are not retained,
// and the memories whose only source they were. It returns how many chunks it
// deleted.
func (m *Manager) PruneSourceChunks(ctx context.Context, documentID string, retainedChunkIDs []string) (int, error) {
	retained := map[string]bool{}
	for _, id := range normalizeStringArray(retainedChunkIDs, 1000, 80) {
		retained[id] = true
	}
	type link struct{ chunkID, memoryID string }
	existing, err := collect(ctx, m.db.W, func(r rowScanner) (link, error) {
		var l link
		var memory sql.NullString
		err := r.Scan(&l.chunkID, &memory)
		l.memoryID = memory.String
		return l, err
	}, `SELECT chunk.id, links.memory_id
       FROM memory_source_chunks chunk
       LEFT JOIN memory_source_links links ON links.chunk_id = chunk.id
       WHERE chunk.document_id = ?`, documentID)
	if err != nil {
		return 0, err
	}
	stale := newOrderedSet()
	for _, l := range existing {
		if !retained[l.chunkID] {
			stale.add(l.chunkID)
		}
	}
	if len(stale.items) == 0 {
		return 0, nil
	}
	staleMemories := newOrderedSet()
	for _, l := range existing {
		if stale.has(l.chunkID) && l.memoryID != "" {
			staleMemories.add(l.memoryID)
		}
	}
	err = atomically(ctx, m.db.W, func(q queryer) error {
		if _, err := q.ExecContext(ctx, `DELETE FROM memory_source_chunks WHERE id IN (`+placeholders(len(stale.items))+`)`, anySlice(stale.items)...); err != nil {
			return err
		}
		entityIDs, err := m.entityIDsForMemories(ctx, q, staleMemories.items)
		if err != nil {
			return err
		}
		for _, memoryID := range staleMemories.items {
			var one int
			found, err := one2(ctx, q, &one, `SELECT 1 FROM memory_source_links WHERE memory_id = ? LIMIT 1`, memoryID)
			if err != nil {
				return err
			}
			if !found {
				if err := m.deleteMemoryIndex(ctx, q, memoryID, false); err != nil {
					return err
				}
				if _, err := q.ExecContext(ctx, `DELETE FROM memories WHERE id = ?`, memoryID); err != nil {
					return err
				}
			}
		}
		return m.pruneOrphanEntities(ctx, q, entityIDs)
	})
	return len(stale.items), err
}

func one2(ctx context.Context, q queryer, dest any, query string, args ...any) (bool, error) {
	return one(ctx, q, []any{dest}, query, args...)
}

// OverviewProvider is the per-provider summary of recent ingestion jobs.
type OverviewProvider struct {
	ProviderKey   string   `json:"providerKey"`
	SourceTypes   []string `json:"sourceTypes"`
	Status        string   `json:"status"`
	LastRefreshAt *string  `json:"lastRefreshAt"`
	DocumentCount int      `json:"documentCount"`
	Error         *string  `json:"error"`
}

// IngestionOverview summarizes the recent ingestion jobs by provider.
func (m *Manager) IngestionOverview(ctx context.Context, userID int64, agentID string, limit int) ([]OverviewProvider, error) {
	if limit == 0 {
		limit = 12
	}
	jobs, err := m.ListIngestionJobs(ctx, userID, JobFilter{AgentID: agentID, Limit: limit})
	if err != nil {
		return nil, err
	}
	var order []string
	byProvider := map[string]*OverviewProvider{}
	for _, job := range jobs {
		key := "local:" + job.SourceType
		if job.ProviderKey != nil && *job.ProviderKey != "" {
			key = *job.ProviderKey
		}
		if _, ok := byProvider[key]; !ok {
			p := &OverviewProvider{ProviderKey: key, SourceTypes: []string{}, Status: job.Status,
				LastRefreshAt: firstNonNil(job.CompletedAt, job.UpdatedAt), Error: job.Error}
			byProvider[key] = p
			order = append(order, key)
		}
		cur := byProvider[key]
		if !contains(cur.SourceTypes, job.SourceType) {
			cur.SourceTypes = append(cur.SourceTypes, job.SourceType)
		}
		cur.DocumentCount += job.DocumentCount
		if cur.Status != "failed" && job.Status == "failed" {
			cur.Status = "failed"
		}
		if cur.Error == nil && job.Error != nil {
			cur.Error = job.Error
		}
	}
	out := make([]OverviewProvider, 0, len(order))
	for _, key := range order {
		out = append(out, *byProvider[key])
	}
	return out, nil
}

// EmbeddingIndexStats says how much of the embedded memory the band index covers.
type EmbeddingIndexStats struct {
	Embedded int64   `json:"embedded"`
	Indexed  int64   `json:"indexed"`
	Coverage float64 `json:"coverage"`
}

// Stats are the counts shown on the memory overview.
type Stats struct {
	Total              int64               `json:"total"`
	Active             int64               `json:"active"`
	Archived           int64               `json:"archived"`
	Facts              int64               `json:"facts"`
	Entities           int64               `json:"entities"`
	KnowledgeViews     int64               `json:"knowledgeViews"`
	IngestionDocuments int64               `json:"ingestionDocuments"`
	SourceChunks       int64               `json:"sourceChunks"`
	EmbeddingIndex     EmbeddingIndexStats `json:"embeddingIndex"`
	AverageImportance  float64             `json:"averageImportance"`
	AverageConfidence  float64             `json:"averageConfidence"`
}

func (m *Manager) count(ctx context.Context, query string, args ...any) (int64, error) {
	var n sql.NullInt64
	err := m.db.R.QueryRowContext(ctx, query, args...).Scan(&n)
	return n.Int64, err
}

// MemoryStats counts what an agent's memory holds.
func (m *Manager) MemoryStats(ctx context.Context, userID int64, agentID string) (Stats, error) {
	scoped, err := m.agentID(ctx, userID, agentID)
	if err != nil {
		return Stats{}, err
	}
	var s Stats
	var total, active, archived sql.NullInt64
	var avgImportance, avgConfidence sql.NullFloat64
	if err := m.db.R.QueryRowContext(ctx,
		`SELECT
         COUNT(*) AS total,
         SUM(CASE WHEN archived = 0 THEN 1 ELSE 0 END) AS active,
         SUM(CASE WHEN archived = 1 THEN 1 ELSE 0 END) AS archived,
         AVG(COALESCE(importance, 0)) AS avg_importance,
         AVG(COALESCE(confidence, 0.7)) AS avg_confidence
       FROM memories
       WHERE user_id = ? AND agent_id = ?`, userID, scoped).Scan(&total, &active, &archived, &avgImportance, &avgConfidence); err != nil {
		return s, err
	}
	s.Total, s.Active, s.Archived = total.Int64, active.Int64, archived.Int64
	s.AverageImportance, s.AverageConfidence = avgImportance.Float64, avgConfidence.Float64
	// Count what recall can actually use: entities and current facts attached
	// to non-archived memories, not superseded history or archived leftovers.
	counts := []struct {
		dest  *int64
		query string
	}{
		{&s.Entities, `SELECT COUNT(DISTINCT mention.entity_id) AS count
       FROM memory_entity_mentions mention
       JOIN memories m ON m.id = mention.memory_id
       WHERE m.user_id = ? AND m.agent_id = ? AND m.archived = 0`},
		{&s.Facts, `SELECT COUNT(*) AS count
       FROM memory_facts f
       JOIN memories m ON m.id = f.memory_id
       WHERE f.user_id = ? AND f.agent_id = ? AND f.status = 'active' AND m.archived = 0`},
		{&s.KnowledgeViews, `SELECT COUNT(*) AS count FROM materialized_knowledge_views WHERE user_id = ? AND agent_id = ?`},
		{&s.IngestionDocuments, `SELECT COUNT(*) AS count FROM memory_ingestion_documents WHERE user_id = ? AND agent_id = ?`},
		{&s.SourceChunks, `SELECT COUNT(*) AS count FROM memory_source_chunks WHERE user_id = ? AND agent_id = ?`},
	}
	for _, c := range counts {
		if *c.dest, err = m.count(ctx, c.query, userID, scoped); err != nil {
			return s, err
		}
	}
	var embedded, indexed sql.NullInt64
	if err := m.db.R.QueryRowContext(ctx,
		`SELECT
         COUNT(DISTINCT CASE WHEN m.embedding IS NOT NULL THEN m.id END) AS embedded,
         COUNT(DISTINCT CASE WHEN idx.memory_id IS NOT NULL THEN m.id END) AS indexed
       FROM memories m
       LEFT JOIN memory_embedding_bands idx ON idx.memory_id = m.id
       WHERE m.user_id = ? AND m.agent_id = ? AND m.archived = 0`, userID, scoped).Scan(&embedded, &indexed); err != nil {
		return s, err
	}
	s.EmbeddingIndex = EmbeddingIndexStats{Embedded: embedded.Int64, Indexed: indexed.Int64, Coverage: 1}
	if embedded.Int64 > 0 {
		s.EmbeddingIndex.Coverage = float64(indexed.Int64) / float64(embedded.Int64)
	}
	return s, nil
}

// CountMemoriesCreatedSince tells new memories from duplicates that resolved to
// older ones.
func (m *Manager) CountMemoriesCreatedSince(ctx context.Context, ids []string, since string) (int64, error) {
	if len(ids) == 0 {
		return 0, nil
	}
	return m.count(ctx, `SELECT COUNT(*) AS count FROM memories
       WHERE id IN (`+placeholders(len(ids))+`)
         AND datetime(created_at) >= datetime(?)`, append(anySlice(ids), since)...)
}
