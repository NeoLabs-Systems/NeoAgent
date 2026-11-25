package memory

import (
	"context"
	"database/sql"

	"github.com/NeoLabs-Systems/neoagent/internal/memory/jsx"
)

// FactContext is an active fact of a recalled memory with its history.
type FactContext struct {
	ID        string        `json:"id"`
	Subject   string        `json:"subject"`
	Predicate string        `json:"predicate"`
	Object    string        `json:"object"`
	Relation  any           `json:"relation"`
	ValidFrom *string       `json:"validFrom"`
	ValidTo   *string       `json:"validTo"`
	LearnedAt *string       `json:"learnedAt"`
	Previous  *PreviousFact `json:"previous"`
	Related   []RelatedFact `json:"related"`
}

// PreviousFact is the fact an active fact replaced.
type PreviousFact struct {
	ID        string  `json:"id"`
	Object    string  `json:"object"`
	ValidFrom *string `json:"validFrom"`
	ValidTo   *string `json:"validTo"`
	LearnedAt *string `json:"learnedAt"`
}

// RelatedFact is a fact of a memory linked to the recalled one.
type RelatedFact struct {
	FactID    string `json:"factId"`
	Relation  string `json:"relation"`
	Subject   string `json:"subject"`
	Predicate string `json:"predicate"`
	Object    string `json:"object"`
}

type ftsHit struct {
	memoryID string
	rank     float64
}

// buildAnyTermFtsQuery matches any one word: a natural question never has all
// its words in one memory.
func buildAnyTermFtsQuery(query string) string {
	var terms []string
	for _, word := range uniqueInOrder(WordsOf(query)) {
		if len(terms) >= 32 {
			break
		}
		if t := BuildFtsQuery(word); t != "" {
			terms = append(terms, t)
		}
	}
	if len(terms) == 0 {
		return ""
	}
	return "{content entities} : (" + joinStrings(terms, " OR ") + ")"
}

func joinStrings(items []string, sep string) string {
	out := ""
	for i, item := range items {
		if i > 0 {
			out += sep
		}
		out += item
	}
	return out
}

// searchMemoryFts finds memories whose text shares any word with the query,
// best match first. A query SQLite cannot run finds nothing.
func (m *Manager) searchMemoryFts(ctx context.Context, q queryer, userID int64, agentID, query string, limit int) []ftsHit {
	ftsQuery := buildAnyTermFtsQuery(query)
	if ftsQuery == "" {
		return nil
	}
	if limit == 0 {
		limit = 40
	}
	hits, err := collect(ctx, q, func(r rowScanner) (ftsHit, error) {
		var h ftsHit
		err := r.Scan(&h.memoryID, &h.rank)
		return h, err
	}, `SELECT memory_id, bm25(memories_fts) AS rank
         FROM memories_fts
         WHERE memories_fts MATCH ? AND user_id = ? AND agent_id = ?
         ORDER BY rank
         LIMIT ?`, ftsQuery, userID, agentID, max(1, min(limit, 120)))
	if err != nil {
		return nil
	}
	return hits
}

// weighQueryTerms weights the words of a query by how often this user's
// memories use each word.
func (m *Manager) weighQueryTerms(ctx context.Context, q queryer, userID int64, agentID, query string, candidates []memoryRow) (float64, []QueryTerm) {
	ftsAvailable := true
	count := func(ftsQuery string) float64 {
		var n int64
		err := q.QueryRowContext(ctx,
			`SELECT COUNT(*) AS count FROM memories_fts
           WHERE memories_fts MATCH ? AND user_id = ? AND agent_id = ?`, ftsQuery, userID, agentID).Scan(&n)
		if err != nil {
			ftsAvailable = false
			return 0 // Fall back to the scoped candidate corpus below.
		}
		return float64(n)
	}
	var total int64
	_ = q.QueryRowContext(ctx, `SELECT COUNT(*) AS count FROM memories WHERE user_id = ? AND agent_id = ? AND archived = 0`, userID, agentID).Scan(&total)
	terms := WeighQueryTerms(query, float64(total), func(term string) float64 {
		return count("{content entities} : " + BuildFtsQuery(term))
	})
	if !ftsAvailable {
		terms = WeighQueryTerms(query, float64(len(candidates)), func(term string) float64 {
			n := 0
			for _, c := range candidates {
				if WordMatches(term, wordSet(WordsOf(c.content))) {
					n++
				}
			}
			return float64(n)
		})
	}
	return float64(total), terms
}

type entityHit struct {
	memoryID     string
	mentionCount float64
}

// searchEntityMemoryIds finds memories through exact entity names only: as
// substrings, "What" finds WhatsApp and "Wie" finds Wiesbaden.
func (m *Manager) searchEntityMemoryIds(ctx context.Context, q queryer, userID int64, agentID, query string, limit int) ([]entityHit, error) {
	keys := newOrderedSet()
	for _, e := range ExtractEntities(query, DefaultMaxEntities) {
		keys.add(e.Key)
	}
	for _, k := range ExtractKeywords(query, 8) {
		keys.add(CanonicalEntityKey(k))
	}
	var keyList []string
	for _, k := range keys.items {
		if k != "" {
			keyList = append(keyList, k)
		}
	}
	if len(keyList) == 0 {
		return nil, nil
	}
	if limit == 0 {
		limit = 40
	}
	var order []string
	results := map[string]entityHit{}
	for _, key := range keyList {
		rows, err := collect(ctx, q, func(r rowScanner) (entityHit, error) {
			var h entityHit
			var mentions sql.NullFloat64
			err := r.Scan(&h.memoryID, &mentions)
			h.mentionCount = mentions.Float64
			return h, err
		}, `SELECT mem.memory_id, ent.mention_count
       FROM memory_entities ent
       JOIN memory_entity_mentions mem ON mem.entity_id = ent.id
       WHERE ent.user_id = ? AND ent.agent_id = ? AND ent.entity_key = ?
       ORDER BY ent.last_seen_at DESC
       LIMIT ?`, userID, agentID, key, max(1, min(limit, 80)))
		if err != nil {
			return nil, err
		}
		for _, row := range rows {
			known, ok := results[row.memoryID]
			// The rarest entity two texts share says the most.
			if !ok || row.mentionCount < known.mentionCount {
				if !ok {
					order = append(order, row.memoryID)
				}
				results[row.memoryID] = row
			}
		}
	}
	out := make([]entityHit, 0, len(order))
	for _, id := range order {
		out = append(out, results[id])
	}
	if capacity := max(1, min(limit, 120)); len(out) > capacity {
		out = out[:capacity]
	}
	return out, nil
}

type memoryLink struct{ from, to string }

func (m *Manager) relatedMemoryLinks(ctx context.Context, q queryer, memoryIDs []string, limit int) ([]memoryLink, error) {
	ids := normalizeStringArray(memoryIDs, 800, 80)
	if len(ids) == 0 {
		return nil, nil
	}
	if limit == 0 {
		limit = 80
	}
	args := append(anySlice(ids), anySlice(ids)...)
	args = append(args, max(1, min(limit, 400)))
	return collect(ctx, q, func(r rowScanner) (memoryLink, error) {
		var l memoryLink
		err := r.Scan(&l.from, &l.to)
		return l, err
	}, `SELECT DISTINCT from_memory_id AS from_id, to_memory_id AS to_id
       FROM memory_relations
       WHERE from_memory_id IN (`+placeholders(len(ids))+`) OR to_memory_id IN (`+placeholders(len(ids))+`)
       LIMIT ?`, args...)
}

// recordRetrievalEvent keeps the telemetry of one recall. It never fails a recall.
func (m *Manager) recordRetrievalEvent(ctx context.Context, userID int64, agentID, query string, scope MemoryScope, requestedK, candidateCount int,
	vectorHits, lexicalHits, entityHits, relationHits int, results []RecallResult, startedAt int64) {
	contextChars := 0
	ids := make([]string, len(results))
	for i, r := range results {
		text := r.Summary
		if text == "" {
			text = r.Content
		}
		contextChars += jsx.Len(text)
		ids[i] = r.ID
	}
	_, err := m.db.W.ExecContext(ctx,
		`INSERT INTO memory_retrieval_events (
           user_id, agent_id, query_hash, scope_type, scope_id, requested_k,
           candidate_count, semantic_candidate_count, lexical_candidate_count,
           entity_candidate_count, relation_candidate_count, result_count,
           result_ids_json, context_tokens_estimate, latency_ms
         ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		userID, agentID, StableHash(query), scope.Type, strPtr(scope.ID), requestedK,
		candidateCount, vectorHits, lexicalHits, entityHits, relationHits, len(results),
		jsx.Marshal(ids), (contextChars+3)/4, m.nowMS()-startedAt)
	if err != nil {
		m.log.Error("memory: could not record retrieval telemetry", "error", err)
	}
}

func (m *Manager) entitiesForMemoryIDs(ctx context.Context, memoryIDs []string) (map[string][]EntityRef, error) {
	ids := normalizeStringArray(memoryIDs, 200, 80)
	byMemory := map[string][]EntityRef{}
	if len(ids) == 0 {
		return byMemory, nil
	}
	type row struct {
		memoryID string
		ref      EntityRef
	}
	rows, err := collect(ctx, m.db.R, func(r rowScanner) (row, error) {
		var x row
		var kind sql.NullString
		var mentions sql.NullInt64
		err := r.Scan(&x.memoryID, &x.ref.ID, &x.ref.Key, &x.ref.Name, &kind, &mentions)
		x.ref.Kind = kind.String
		if x.ref.Kind == "" {
			x.ref.Kind = "concept"
		}
		x.ref.MentionCount = mentions.Int64
		return x, err
	}, `SELECT mem.memory_id, ent.id, ent.entity_key, ent.name, ent.kind, ent.mention_count
       FROM memory_entity_mentions mem
       JOIN memory_entities ent ON ent.id = mem.entity_id
       WHERE mem.memory_id IN (`+placeholders(len(ids))+`)
       ORDER BY ent.mention_count DESC, ent.name ASC`, anySlice(ids)...)
	if err != nil {
		return nil, err
	}
	for _, r := range rows {
		if len(byMemory[r.memoryID]) < 8 {
			byMemory[r.memoryID] = append(byMemory[r.memoryID], r.ref)
		}
	}
	return byMemory, nil
}

func memoryRowIDs(rows []memoryRow) []string {
	ids := make([]string, len(rows))
	for i, r := range rows {
		ids[i] = r.id
	}
	return ids
}

func (m *Manager) attachEntities(ctx context.Context, rows []memoryRow) error {
	byMemory, err := m.entitiesForMemoryIDs(ctx, memoryRowIDs(rows))
	if err != nil {
		return err
	}
	for i := range rows {
		rows[i].entities = byMemory[rows[i].id]
		if rows[i].entities == nil {
			rows[i].entities = []EntityRef{}
		}
	}
	return nil
}

func optionalString(n sql.NullString) *string {
	if !n.Valid || n.String == "" {
		return nil
	}
	return &n.String
}

func (m *Manager) attachFactContext(ctx context.Context, rows []memoryRow) error {
	ids := normalizeStringArray(memoryRowIDs(rows), 200, 80)
	if len(ids) == 0 {
		return nil
	}
	in := placeholders(len(ids))

	// Facts and their supersession chain: one row per fact. Relations are
	// queried separately below instead of joined in here: memory_relations is
	// keyed by memory_id, not fact_id, so joining it alongside memory_facts
	// produces a cross product.
	type factRow struct {
		memoryID string
		ctx      FactContext
	}
	facts, err := collect(ctx, m.db.R, func(r rowScanner) (factRow, error) {
		var x factRow
		var validFrom, validTo, learnedAt, meta, prevID, prevObject, prevFrom, prevTo, prevLearned sql.NullString
		if err := r.Scan(&x.memoryID, &x.ctx.ID, &x.ctx.Subject, &x.ctx.Predicate, &x.ctx.Object, &validFrom, &validTo,
			&learnedAt, &meta, &prevID, &prevObject, &prevFrom, &prevTo, &prevLearned); err != nil {
			return x, err
		}
		x.ctx.Relation = jsx.Or(jsx.ParseObject(meta.String).Lookup("relation"), "new")
		x.ctx.ValidFrom, x.ctx.ValidTo, x.ctx.LearnedAt = optionalString(validFrom), optionalString(validTo), optionalString(learnedAt)
		if prevID.Valid && prevID.String != "" {
			x.ctx.Previous = &PreviousFact{ID: prevID.String, Object: prevObject.String,
				ValidFrom: optionalString(prevFrom), ValidTo: optionalString(prevTo), LearnedAt: optionalString(prevLearned)}
		}
		return x, nil
	}, `SELECT
         current.memory_id,
         current.id,
         current.subject,
         current.predicate,
         current.object,
         current.valid_from,
         current.valid_to,
         current.learned_at,
         current.metadata_json,
         previous.id AS previous_id,
         previous.object AS previous_object,
         previous.valid_from AS previous_valid_from,
         previous.valid_to AS previous_valid_to,
         previous.learned_at AS previous_learned_at
       FROM memory_facts current
       LEFT JOIN memory_facts previous ON previous.id = current.supersedes_fact_id
       WHERE current.memory_id IN (`+in+`)
         AND current.status = 'active'
       ORDER BY current.learned_at DESC, current.created_at DESC`, anySlice(ids)...)
	if err != nil {
		return err
	}

	// Related facts via memory_relations, kept per memory and capped so a
	// richly linked memory cannot reintroduce an unbounded prompt.
	const maxRelatedPerMemory = 5
	type relationRow struct {
		from string
		fact RelatedFact
	}
	relations, err := collect(ctx, m.db.R, func(r rowScanner) (relationRow, error) {
		var x relationRow
		var target string
		err := r.Scan(&x.from, &target, &x.fact.Relation, &x.fact.FactID, &x.fact.Subject, &x.fact.Predicate, &x.fact.Object)
		return x, err
	}, `SELECT
         relation.from_memory_id,
         relation.to_memory_id AS relation_target_memory_id,
         relation.relation_type,
         related.id AS related_fact_id,
         related.subject AS related_subject,
         related.predicate AS related_predicate,
         related.object AS related_object
       FROM memory_relations relation
       JOIN memory_facts related ON related.memory_id = relation.to_memory_id AND related.status = 'active'
       WHERE relation.from_memory_id IN (`+in+`)
       ORDER BY related.learned_at DESC, related.created_at DESC`, anySlice(ids)...)
	if err != nil {
		return err
	}
	relatedByMemory := map[string][]RelatedFact{}
	for _, r := range relations {
		if len(relatedByMemory[r.from]) < maxRelatedPerMemory {
			relatedByMemory[r.from] = append(relatedByMemory[r.from], r.fact)
		}
	}

	byMemory := map[string][]FactContext{}
	for _, f := range facts {
		fc := f.ctx
		fc.Related = relatedByMemory[f.memoryID]
		if fc.Related == nil {
			fc.Related = []RelatedFact{}
		}
		byMemory[f.memoryID] = append(byMemory[f.memoryID], fc)
	}
	for i := range rows {
		rows[i].facts = byMemory[rows[i].id]
		if rows[i].facts == nil {
			rows[i].facts = []FactContext{}
		}
	}
	return nil
}

func (m *Manager) attachSourceContext(ctx context.Context, rows []memoryRow) error {
	ids := normalizeStringArray(memoryRowIDs(rows), 200, 80)
	if len(ids) == 0 {
		return nil
	}
	type linkRow struct {
		memoryID string
		link     SourceLink
	}
	links, err := collect(ctx, m.db.R, func(r rowScanner) (linkRow, error) {
		var x linkRow
		var timestamp, title, method sql.NullString
		var relevance sql.NullFloat64
		err := r.Scan(&x.memoryID, &timestamp, &relevance, &method, &x.link.ChunkID, &x.link.ChunkIndex, &x.link.CharStart,
			&x.link.CharEnd, &x.link.DocumentID, &x.link.ExternalObjectID, &x.link.SourceType, &title)
		x.link.SourceTimestamp = optionalString(timestamp)
		x.link.RelevanceScore = relevance.Float64
		x.link.ExtractionMethod = method.String
		x.link.Title = nullableString(title)
		return x, err
	}, `SELECT
         links.memory_id,
         links.source_timestamp,
         links.relevance_score,
         links.extraction_method,
         chunk.id AS chunk_id,
         chunk.chunk_index,
         chunk.char_start,
         chunk.char_end,
         document.id AS document_id,
         document.external_object_id,
         document.source_type,
         document.title
       FROM memory_source_links links
       JOIN memory_source_chunks chunk ON chunk.id = links.chunk_id
       JOIN memory_ingestion_documents document ON document.id = links.source_document_id
       WHERE links.memory_id IN (`+placeholders(len(ids))+`)
       ORDER BY links.relevance_score DESC, chunk.chunk_index ASC`, anySlice(ids)...)
	if err != nil {
		return err
	}
	byMemory := map[string][]SourceLink{}
	for _, l := range links {
		byMemory[l.memoryID] = append(byMemory[l.memoryID], l.link)
	}
	for i := range rows {
		rows[i].sources = byMemory[rows[i].id]
		if rows[i].sources == nil {
			rows[i].sources = []SourceLink{}
		}
	}
	return nil
}
