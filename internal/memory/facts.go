package memory

import (
	"context"
	"database/sql"
	"math"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/memory/jsx"
)

// FactView is a stored fact as the API shows it.
type FactView struct {
	ID               string    `json:"id"`
	MemoryID         string    `json:"memoryId"`
	Subject          string    `json:"subject"`
	Predicate        string    `json:"predicate"`
	Object           string    `json:"object"`
	Category         string    `json:"category"`
	Confidence       float64   `json:"confidence"`
	EventTime        *string   `json:"eventTime"`
	ValidFrom        *string   `json:"validFrom"`
	ValidTo          *string   `json:"validTo"`
	LearnedAt        *string   `json:"learnedAt"`
	InvalidatedAt    *string   `json:"invalidatedAt"`
	Status           string    `json:"status"`
	SupersedesFactID *string   `json:"supersedesFactId"`
	SourceRef        SourceRef `json:"sourceRef"`
	Metadata         *jsx.Obj  `json:"metadata"`
}

// FactFilter narrows ListFacts. Times are ISO strings compared as text.
type FactFilter struct {
	AgentID   string
	Status    string
	Subject   string
	Predicate string
	ValidAt   string
	KnownAt   string
	Limit     int
}

// ListFacts lists the stored facts of an agent, newest learned first.
func (m *Manager) ListFacts(ctx context.Context, userID int64, f FactFilter) ([]FactView, error) {
	agentID, err := m.agentID(ctx, userID, f.AgentID)
	if err != nil {
		return nil, err
	}
	status, subject, predicate := jsx.Trim(f.Status), jsx.Trim(f.Subject), jsx.Trim(f.Predicate)
	validAt, knownAt := jsx.Trim(f.ValidAt), jsx.Trim(f.KnownAt)
	limit := f.Limit
	if limit == 0 {
		limit = 100
	}
	return collect(ctx, m.db.R, func(r rowScanner) (FactView, error) {
		var v FactView
		var category, eventTime, validFrom, validTo, learnedAt, invalidatedAt, status, supersedes, meta, created, updated sql.NullString
		var sourceType, sourceID, sourceLabel sql.NullString
		var confidence sql.NullFloat64
		if err := r.Scan(&v.ID, &v.MemoryID, &v.Subject, &v.Predicate, &v.Object, &category, &confidence, &eventTime,
			&validFrom, &validTo, &learnedAt, &invalidatedAt, &status, &supersedes, &meta, &created, &updated,
			&sourceType, &sourceID, &sourceLabel); err != nil {
			return v, err
		}
		v.Category = category.String
		v.Confidence = confidence.Float64
		v.EventTime, v.ValidFrom, v.ValidTo = optionalString(eventTime), optionalString(validFrom), optionalString(validTo)
		v.LearnedAt = optionalString(learnedAt)
		if v.LearnedAt == nil {
			v.LearnedAt = optionalString(created)
		}
		v.InvalidatedAt = optionalString(invalidatedAt)
		v.Status = orLabel(status.String, "active")
		v.SupersedesFactID = optionalString(supersedes)
		v.SourceRef = SourceRef{Type: optionalString(sourceType), ID: optionalString(sourceID), Label: optionalString(sourceLabel)}
		v.Metadata = jsx.ParseObject(meta.String)
		return v, nil
	}, `SELECT
         f.id, f.memory_id, f.subject, f.predicate, f.object, f.category,
         f.confidence, f.event_time, f.valid_from, f.valid_to, f.learned_at,
         f.invalidated_at, f.status, f.supersedes_fact_id, f.metadata_json,
         f.created_at, f.updated_at,
         m.source_type, m.source_id, m.source_label
       FROM memory_facts f
       JOIN memories m ON m.id = f.memory_id
       WHERE f.user_id = ? AND f.agent_id = ?
         AND (? = '' OR f.status = ?)
         AND (? = '' OR lower(f.subject) = lower(?))
         AND (? = '' OR lower(f.predicate) = lower(?))
         AND (? = '' OR COALESCE(f.valid_from, f.event_time, f.created_at) <= ?)
         AND (? = '' OR f.valid_to IS NULL OR f.valid_to > ?)
         AND (? = '' OR COALESCE(f.learned_at, f.created_at) <= ?)
       ORDER BY COALESCE(f.learned_at, f.created_at) DESC
       LIMIT ?`,
		userID, agentID, status, status, subject, subject, predicate, predicate,
		validAt, validAt, validAt, validAt, knownAt, knownAt, max(1, min(limit, 500)))
}

// Reconciliation is what ReconcileFacts changed.
type Reconciliation struct {
	Expired               int64 `json:"expired"`
	LowConfidence         int64 `json:"lowConfidence"`
	InvalidatedDuplicates int64 `json:"invalidatedDuplicates"`
	Restored              int   `json:"restored"`
}

// ReconcileFacts tidies the fact store: it restores accidental supersessions,
// expires facts past their window, flags weak facts for review and marks
// duplicates. minimumConfidence is clamped to 0..1; pass 0.35 for the default.
func (m *Manager) ReconcileFacts(ctx context.Context, userID int64, agentID string, minimumConfidence float64) (Reconciliation, error) {
	scoped, err := m.agentID(ctx, userID, agentID)
	if err != nil {
		return Reconciliation{}, err
	}
	minimumConfidence = math.Min(math.Max(minimumConfidence, 0), 1)
	now := m.nowISO()
	var out Reconciliation
	if out.Restored, err = m.restoreAccidentalSupersessions(ctx, userID, scoped); err != nil {
		return out, err
	}
	res, err := m.db.W.ExecContext(ctx,
		`UPDATE memory_facts
       SET status = 'expired', invalidated_at = COALESCE(invalidated_at, datetime('now')),
           updated_at = datetime('now')
       WHERE user_id = ? AND agent_id = ? AND status = 'active'
         AND valid_to IS NOT NULL AND valid_to <= ?`, userID, scoped, now)
	if err != nil {
		return out, err
	}
	out.Expired, _ = res.RowsAffected()
	res, err = m.db.W.ExecContext(ctx,
		`UPDATE memory_facts
       SET status = 'review', updated_at = datetime('now')
       WHERE user_id = ? AND agent_id = ? AND status = 'active' AND confidence < ?`, userID, scoped, minimumConfidence)
	if err != nil {
		return out, err
	}
	out.LowConfidence, _ = res.RowsAffected()

	groups, err := collect(ctx, m.db.W, func(r rowScanner) (string, error) {
		var subject, predicate, object, ids sql.NullString
		var count int64
		err := r.Scan(&subject, &predicate, &object, &ids, &count)
		return ids.String, err
	}, `SELECT subject, predicate, object, GROUP_CONCAT(id) AS ids, COUNT(*) AS count
       FROM memory_facts
       WHERE user_id = ? AND agent_id = ? AND status = 'active'
       GROUP BY lower(subject), lower(predicate), lower(object)
       HAVING COUNT(*) > 1`, userID, scoped)
	if err != nil {
		return out, err
	}
	for _, group := range groups {
		var ids []string
		for _, id := range strings.Split(group, ",") {
			if id != "" {
				ids = append(ids, id)
			}
		}
		if len(ids) == 0 {
			continue
		}
		keep := ids[len(ids)-1]
		for _, id := range ids[:len(ids)-1] {
			res, err := m.db.W.ExecContext(ctx,
				`UPDATE memory_facts
           SET status = 'duplicate', invalidated_at = datetime('now'),
               supersedes_fact_id = COALESCE(supersedes_fact_id, ?), updated_at = datetime('now')
           WHERE id = ?`, keep, id)
			if err != nil {
				return out, err
			}
			n, _ := res.RowsAffected()
			out.InvalidatedDuplicates += n
		}
	}
	return out, nil
}

// restoreAccidentalSupersessions undoes what locally built facts did when they
// superseded each other for sharing a category and first capitalized word,
// hiding memories nothing had replaced.
func (m *Manager) restoreAccidentalSupersessions(ctx context.Context, userID int64, agentID string) (int, error) {
	type row struct {
		oldID, oldMemoryID, oldMeta, nextID, nextMemoryID, nextMeta, oldContent, nextContent string
	}
	rows, err := collect(ctx, m.db.W, func(r rowScanner) (row, error) {
		var x row
		var oldMeta, nextMeta, oldContent, nextContent sql.NullString
		err := r.Scan(&x.oldID, &x.oldMemoryID, &oldMeta, &x.nextID, &x.nextMemoryID, &nextMeta, &oldContent, &nextContent)
		x.oldMeta, x.nextMeta, x.oldContent, x.nextContent = oldMeta.String, nextMeta.String, oldContent.String, nextContent.String
		return x, err
	}, `SELECT
         old.id AS old_id, old.memory_id AS old_memory_id, old.metadata_json AS old_metadata,
         next.id AS next_id, next.memory_id AS next_memory_id, next.metadata_json AS next_metadata,
         old_memory.content AS old_content, next_memory.content AS next_content
       FROM memory_facts next
       JOIN memory_facts old ON old.id = next.supersedes_fact_id
       JOIN memories next_memory ON next_memory.id = next.memory_id
       JOIN memories old_memory ON old_memory.id = old.memory_id
       WHERE next.user_id = ? AND next.agent_id = ? AND old.status = 'superseded'`, userID, agentID)
	if err != nil {
		return 0, err
	}
	restored := 0
	err = atomically(ctx, m.db.W, func(q queryer) error {
		for _, r := range rows {
			oldMeta, nextMeta := jsx.ParseObject(r.oldMeta), jsx.ParseObject(r.nextMeta)
			if oldMeta.Value("extractedBy") != "local_memory_intelligence" {
				continue
			}
			if nextMeta.Value("extractedBy") != "local_memory_intelligence" || nextMeta.Truthy("replacedMemory") {
				continue
			}
			if IsValueChange(r.nextContent, r.oldContent) {
				continue
			}
			if _, err := q.ExecContext(ctx,
				`UPDATE memory_facts
           SET status = 'active', valid_to = NULL, invalidated_at = NULL, updated_at = datetime('now')
           WHERE id = ?`, r.oldID); err != nil {
				return err
			}
			if _, err := q.ExecContext(ctx, `UPDATE memory_facts SET supersedes_fact_id = NULL WHERE id = ?`, r.nextID); err != nil {
				return err
			}
			if _, err := q.ExecContext(ctx,
				`DELETE FROM memory_relations
           WHERE from_memory_id = ? AND to_memory_id = ? AND relation_type = 'updates'`, r.nextMemoryID, r.oldMemoryID); err != nil {
				return err
			}
			restored++
		}
		return nil
	})
	return restored, err
}

// Profile is what memory knows about the user: stable facts and current context.
type Profile struct {
	Static  []string `json:"static"`
	Dynamic []string `json:"dynamic"`
}

// UserProfile builds the auto-maintained profile from the active, non-assumed
// facts of an agent. limit is clamped to 4..30; 0 means 16.
func (m *Manager) UserProfile(ctx context.Context, userID int64, agentID string, limit int) (Profile, error) {
	scoped, err := m.agentID(ctx, userID, agentID)
	if err != nil {
		return Profile{}, err
	}
	if limit == 0 {
		limit = 16
	}
	limit = max(4, min(limit, 30))
	type row struct {
		content, category, sourceType, metadata, factMetadata string
		confidence                                            *float64
	}
	rows, err := collect(ctx, m.db.R, func(r rowScanner) (row, error) {
		var x row
		var category, sourceType, meta, factMeta sql.NullString
		var importance, confidence sql.NullFloat64
		var updated sql.NullString
		err := r.Scan(&x.content, &category, &importance, &confidence, &updated, &sourceType, &meta, &factMeta)
		x.category, x.sourceType, x.metadata, x.factMetadata = category.String, sourceType.String, meta.String, factMeta.String
		x.confidence = nullableFloat(confidence)
		return x, err
	}, `SELECT
         m.content, m.category, m.importance, m.confidence, m.updated_at, m.source_type, m.metadata_json,
         f.metadata_json AS fact_metadata_json
       FROM memories m
       JOIN memory_facts f ON f.memory_id = m.id
       WHERE m.user_id = ? AND m.agent_id = ? AND m.archived = 0
         AND f.status = 'active'
         AND (f.valid_to IS NULL OR datetime(f.valid_to) > datetime('now'))
       ORDER BY m.importance DESC, m.confidence DESC, m.updated_at DESC
       LIMIT ?`, userID, scoped, limit*3)
	if err != nil {
		return Profile{}, err
	}
	profile := Profile{Static: []string{}, Dynamic: []string{}}
	seen := map[string]bool{}
	for _, r := range rows {
		content := jsx.Collapse(r.content)
		if r.sourceType == "memory_ingestion" {
			continue
		}
		// The profile reads as what is known about the user; a guess is not that.
		if Provenance(r.content, r.confidence, jsx.ParseObject(r.metadata)) == "assumption" {
			continue
		}
		key := jsx.Lower(content)
		if content == "" || seen[key] {
			continue
		}
		seen[key] = true
		isStatic := jsx.ParseObject(r.factMetadata).Value("isStatic") == true ||
			r.category == "identity" || r.category == "preferences" || r.category == "contacts" || r.category == "assistant_self"
		target := &profile.Dynamic
		if isStatic {
			target = &profile.Static
		}
		if len(*target) < (limit+1)/2 {
			*target = append(*target, jsx.Head(content, 500))
		}
		if len(profile.Static)+len(profile.Dynamic) >= limit {
			break
		}
	}
	return profile, nil
}

// KnownMemories lists what memory already holds that relates to a query (the
// profile plus the closest matches), as plain statements for an extraction
// prompt to skip.
func (m *Manager) KnownMemories(ctx context.Context, userID int64, agentID, query string) ([]string, error) {
	profile, err := m.UserProfile(ctx, userID, agentID, 0)
	if err != nil {
		return nil, err
	}
	recalled, err := m.RecallMemory(ctx, userID, query, 25, RecallOptions{AgentID: agentID, NoReinforce: true})
	if err != nil {
		return nil, err
	}
	known := []string{}
	seen := map[string]bool{}
	add := func(content string) {
		text := jsx.Collapse(content)
		key := jsx.Lower(text)
		if text == "" || seen[key] {
			return
		}
		seen[key] = true
		known = append(known, text)
	}
	for _, c := range profile.Static {
		add(c)
	}
	for _, c := range profile.Dynamic {
		add(c)
	}
	for _, r := range recalled {
		if r.SourceRef.typeValue() != "memory_ingestion" {
			add(r.Content)
		}
	}
	return known, nil
}

// KnownFact is a stored subject, predicate and value.
type KnownFact struct {
	Subject   string `json:"subject"`
	Predicate string `json:"predicate"`
	Object    string `json:"object"`
}

// KnownFacts lists facts already stored around a topic, so extraction can reuse
// their subject and predicate. Without that, a changed value gets a new
// wording and replaces nothing.
func (m *Manager) KnownFacts(ctx context.Context, userID int64, agentID, query string, limit int) ([]KnownFact, error) {
	scoped, err := m.agentID(ctx, userID, agentID)
	if err != nil {
		return nil, err
	}
	if limit == 0 {
		limit = 12
	}
	var ids []string
	for _, hit := range m.searchMemoryFts(ctx, m.db.R, userID, scoped, query, 40) {
		ids = append(ids, hit.memoryID)
	}
	if len(ids) == 0 {
		return []KnownFact{}, nil
	}
	type row struct {
		fact KnownFact
		meta string
	}
	rows, err := collect(ctx, m.db.R, func(r rowScanner) (row, error) {
		var x row
		var meta sql.NullString
		err := r.Scan(&x.fact.Subject, &x.fact.Predicate, &x.fact.Object, &meta)
		x.meta = meta.String
		return x, err
	}, `SELECT subject, predicate, object, metadata_json
       FROM memory_facts
       WHERE memory_id IN (`+placeholders(len(ids))+`) AND status = 'active'
       ORDER BY learned_at DESC`, anySlice(ids)...)
	if err != nil {
		return nil, err
	}
	facts := []KnownFact{}
	for _, r := range rows {
		if jsx.ParseObject(r.meta).Value("extractedBy") != "local_memory_intelligence" && len(facts) < limit {
			facts = append(facts, r.fact)
		}
	}
	return facts, nil
}

// SimilarMemory is a current memory worded like a text.
type SimilarMemory struct {
	ID      string `json:"id"`
	Content string `json:"content"`
}

// FindSimilarMemories lists current memories worded like content, for a caller
// to review after saving it.
func (m *Manager) FindSimilarMemories(ctx context.Context, userID int64, content, agentID string, scope *ScopeInput, excludeID string, limit int) ([]SimilarMemory, error) {
	scoped, err := m.agentID(ctx, userID, agentID)
	if err != nil {
		return nil, err
	}
	if limit == 0 {
		limit = 3
	}
	rows, err := m.currentSimilarMemories(ctx, m.db.R, userID, scoped, normalizeScope(scope, scoped), content, nil)
	if err != nil {
		return nil, err
	}
	out := []SimilarMemory{}
	for _, r := range rows {
		if r.id != excludeID && KeywordSimilarity(content, r.content) >= 0.5 && len(out) < limit {
			out = append(out, SimilarMemory{ID: r.id, Content: r.content})
		}
	}
	return out, nil
}
