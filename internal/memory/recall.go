package memory

import (
	"context"
	"database/sql"
	"sort"

	"github.com/NeoLabs-Systems/neoagent/internal/memory/jsx"
)

const (
	relationSignalShare = 0.6
	// Below this a memory has too little evidence to hand to anyone, including
	// a caller that does no filtering of its own.
	minRecallScore = 0.25
	entitySignal   = 0.6
)

// ScoreBreakdown shows where a recall score came from.
type ScoreBreakdown struct {
	Semantic            float64 `json:"semantic"`
	Cosine              float64 `json:"cosine"`
	Lexical             float64 `json:"lexical"`
	Entity              float64 `json:"entity"`
	Relation            float64 `json:"relation"`
	Route               float64 `json:"route"`
	RouteIntent         string  `json:"routeIntent"`
	VectorCandidateRank int     `json:"vectorCandidateRank"`
	CandidateCount      int     `json:"candidateCount"`
}

// RecallResult is a recalled memory with its evidence.
type RecallResult struct {
	MemoryView
	Score          float64        `json:"score"`
	ScoreBreakdown ScoreBreakdown `json:"scoreBreakdown"`
	FactContext    []FactContext  `json:"factContext"`
	Provenance     string         `json:"provenance"`
	Current        bool           `json:"current"`
}

// RecallOptions tune RecallMemory.
type RecallOptions struct {
	AgentID string
	Scope   *ScopeInput
	// QueryEmbedding replaces embedding the query, with the model that made it.
	QueryEmbedding         []float32
	QueryEmbeddingProvider string
	QueryEmbeddingModel    string
	// ValidAt and KnownAt ask for what was true, or known, at a point in time.
	ValidAt        string
	KnownAt        string
	IncludeHistory bool
	// NoReinforce keeps the recall from strengthening the memories it returns.
	NoReinforce bool
}

const recallColumns = `rowid AS row_order, id, category, content, summary, importance, confidence, embedding, access_count,
              memory_strength, last_accessed_at, pinned, created_at, updated_at,
              scope_type, scope_id, source_type, source_id, source_label, stale_after_days,
              embedding_provider, embedding_model, metadata_json`

func scanRecallRow(r rowScanner) (memoryRow, error) {
	var x memoryRow
	err := r.Scan(&x.rowOrder, &x.id, &x.category, &x.content, &x.summary, &x.importance, &x.confidence, &x.embedding,
		&x.accessCount, &x.strength, &x.lastAccessedAt, &x.pinned, &x.createdAt, &x.updatedAt,
		&x.scopeType, &x.scopeID, &x.sourceType, &x.sourceID, &x.sourceLabel, &x.staleAfterDays,
		&x.embedProvider, &x.embedModel, &x.metadataJSON)
	return x, err
}

const scopeFilter = `(
           (COALESCE(scope_type, 'agent') = ? AND COALESCE(scope_id, '') = COALESCE(?, ''))
           OR COALESCE(scope_type, 'agent') = 'shared'
         )`

// RecallMemory finds the memories that best answer a query: by meaning when an
// embedder is available, always by words, entities and links between memories.
func (m *Manager) RecallMemory(ctx context.Context, userID int64, query string, topK int, opts RecallOptions) ([]RecallResult, error) {
	if jsx.Trim(query) == "" {
		return []RecallResult{}, nil
	}
	startedAt := m.nowMS()
	agentID, err := m.agentID(ctx, userID, opts.AgentID)
	if err != nil {
		return nil, err
	}
	scope := normalizeScope(opts.Scope, agentID)
	if topK == 0 {
		topK = 6
	}
	limit := max(1, min(topK, 50))
	route := RouteMemoryQuery(query)
	rd := m.db.R

	var queryVec []float32
	var queryProvider, queryModel string
	if opts.QueryEmbedding != nil {
		queryVec, queryProvider, queryModel = opts.QueryEmbedding, opts.QueryEmbeddingProvider, opts.QueryEmbeddingModel
	} else {
		emb, err := m.embed(ctx, query, "query", userID, agentID)
		if err != nil {
			return nil, err
		}
		if emb != nil {
			queryVec, queryProvider, queryModel = emb.Vector, emb.Provider, emb.Model
		}
	}

	lexicalHits := m.searchMemoryFts(ctx, rd, userID, agentID, query, max(80, limit*12))
	entityHits, err := m.searchEntityMemoryIds(ctx, rd, userID, agentID, query, max(80, limit*12))
	if err != nil {
		return nil, err
	}
	var vectorHits []EmbeddingCandidate
	if queryVec != nil {
		vectorHits, err = findEmbeddingCandidates(ctx, rd, CandidateSearch{
			UserID: userID, AgentID: agentID, Vector: queryVec, Provider: queryProvider, Model: queryModel,
			Limit: min(500, max(300, limit*20)),
		})
		if err != nil {
			return nil, err
		}
	}

	candidates := newOrderedSet()
	for _, h := range vectorHits {
		candidates.add(h.MemoryID)
	}
	for _, h := range lexicalHits {
		candidates.add(h.memoryID)
	}
	for _, h := range entityHits {
		candidates.add(h.memoryID)
	}
	// Links spread from what the query found, not from every vector neighbour.
	var seeds []string
	for _, h := range lexicalHits {
		seeds = append(seeds, h.memoryID)
	}
	for _, h := range entityHits {
		seeds = append(seeds, h.memoryID)
	}
	for _, h := range vectorHits[:min(40, len(vectorHits))] {
		seeds = append(seeds, h.MemoryID)
	}
	relationLinks, err := m.relatedMemoryLinks(ctx, rd, seeds, max(80, limit*16))
	if err != nil {
		return nil, err
	}
	relationSet := newOrderedSet()
	for _, l := range relationLinks {
		relationSet.add(l.from, l.to)
	}
	candidates.add(relationSet.items...)

	baseline, err := collect(ctx, rd, scanString,
		`SELECT id
       FROM memories
       WHERE user_id = ? AND agent_id = ? AND archived = 0
         AND `+scopeFilter+`
       ORDER BY importance DESC, updated_at DESC
       LIMIT 160`, userID, agentID, scope.Type, strPtr(scope.ID))
	if err != nil {
		return nil, err
	}
	candidates.add(baseline...)

	record := func(candidateCount int, results []RecallResult) {
		m.recordRetrievalEvent(ctx, userID, agentID, query, scope, limit, candidateCount,
			len(vectorHits), len(lexicalHits), len(entityHits), len(relationSet.items), results, startedAt)
	}
	if len(candidates.items) == 0 {
		record(0, nil)
		return []RecallResult{}, nil
	}

	candidateIDs := candidates.items
	all, err := collect(ctx, rd, scanRecallRow,
		`SELECT `+recallColumns+`
       FROM memories
       WHERE id IN (`+placeholders(len(candidateIDs))+`)
         AND user_id = ? AND agent_id = ? AND archived = 0
         AND `+scopeFilter,
		append(append(anySlice(candidateIDs), userID, agentID), scope.Type, strPtr(scope.ID))...)
	if err != nil {
		return nil, err
	}

	validAt, knownAt := jsx.Trim(opts.ValidAt), jsx.Trim(opts.KnownAt)
	if validAt != "" || knownAt != "" {
		// datetime() because the columns mix ISO timestamps and SQLite's own
		// format. Facts held for review or marked as copies were never true at
		// any point.
		eligible, err := collect(ctx, rd, scanString,
			`SELECT DISTINCT memory_id
         FROM memory_facts
         WHERE user_id = ? AND agent_id = ?
           AND status IN ('active', 'superseded', 'expired')
           AND (? = '' OR datetime(COALESCE(valid_from, event_time, created_at)) <= datetime(?))
           AND (? = '' OR valid_to IS NULL OR datetime(valid_to) > datetime(?))
           AND (? = '' OR datetime(COALESCE(learned_at, created_at)) <= datetime(?))`,
			userID, agentID, validAt, validAt, validAt, validAt, knownAt, knownAt)
		if err != nil {
			return nil, err
		}
		eligibleIDs := map[string]bool{}
		for _, id := range eligible {
			eligibleIDs[id] = true
		}
		all = filterRows(all, func(r memoryRow) bool { return eligibleIDs[r.id] })
	}

	currentIDs, err := m.currentMemoryIDs(ctx, rd, candidateIDs)
	if err != nil {
		return nil, err
	}
	pointInTime := opts.IncludeHistory || validAt != "" || knownAt != ""
	if !pointInTime {
		all = filterRows(all, func(r memoryRow) bool { return currentIDs[r.id] })
	}
	if len(all) == 0 {
		record(len(candidateIDs), nil)
		return []RecallResult{}, nil
	}

	vectorRanks := map[string]int{}
	for i, h := range vectorHits {
		vectorRanks[h.MemoryID] = i
	}
	totalDocuments, terms := m.weighQueryTerms(ctx, rd, userID, agentID, query, all)
	// A name most memories mention does not single any of them out.
	entityStrength := map[string]float64{}
	for _, h := range entityHits {
		entityStrength[h.memoryID] = entitySignal * max(0, 1-h.mentionCount/max(1, totalDocuments))
	}

	cosines := make([]float64, len(all))
	for i, mem := range all {
		if queryVec != nil && mem.embedding.String != "" {
			if memVec := DeserializeEmbedding(mem.embedding.String); memVec != nil &&
				SameEmbeddingSpace(mem.embedProvider.String, mem.embedModel.String, len(memVec), queryProvider, queryModel, len(queryVec)) {
				cosines[i] = Cosine(queryVec, memVec)
			}
		}
	}
	noiseFloor := SemanticNoiseFloor(cosines)

	type signal struct {
		semantic, lexical, entity, direct float64
	}
	signals := make([]signal, len(all))
	directByID := map[string]float64{}
	for i, mem := range all {
		s := signal{
			semantic: CalibrateSemantic(cosines[i], noiseFloor),
			lexical:  LexicalSignal(terms, mem.content),
			entity:   entityStrength[mem.id],
		}
		s.direct = max(s.semantic, s.lexical, s.entity)
		signals[i] = s
		directByID[mem.id] = s.direct
	}
	relationScores := map[string]float64{}
	passRelation := func(from, to string) {
		inherited := directByID[from] * relationSignalShare
		if inherited > relationScores[to] {
			relationScores[to] = inherited
		}
	}
	for _, l := range relationLinks {
		passRelation(l.from, l.to)
		passRelation(l.to, l.from)
	}

	type scoredRow struct {
		row       memoryRow
		score     float64
		breakdown ScoreBreakdown
	}
	scored := make([]scoredRow, 0, len(all))
	nowMs := m.nowMS()
	for i, mem := range all {
		s := signals[i]
		relation := relationScores[mem.id]
		ordered := []float64{s.semantic, s.lexical, s.entity, relation}
		sort.Slice(ordered, func(a, b int) bool { return ordered[a] > ordered[b] })
		routeBoost := 0.0
		if s.direct > 0.08 {
			routeBoost = RouteCategoryBoost(route, NormalizeMemoryCategory(mem.category.String))
		}
		score := ScoreMemoryCandidate(Signals{
			Signal: ordered[0], SecondarySignal: ordered[1], RouteBoost: routeBoost,
			Importance: mem.importance.Float64, Confidence: mem.confidence.Float64, AccessCount: mem.accessCount.Float64,
			Retention: mem.retention().RetentionScoreMultiplier(nowMs),
		})
		rank, ok := vectorRanks[mem.id]
		if !ok {
			rank = -1
		}
		scored = append(scored, scoredRow{mem, score, ScoreBreakdown{
			Semantic: s.semantic, Cosine: cosines[i], Lexical: s.lexical, Entity: s.entity, Relation: relation,
			Route: routeBoost, RouteIntent: route.Intent, VectorCandidateRank: rank, CandidateCount: len(all),
		}})
	}

	var ranked []scoredRow
	for _, s := range scored {
		if s.score > minRecallScore {
			ranked = append(ranked, s)
		}
	}
	sort.SliceStable(ranked, func(a, b int) bool { return ranked[a].score > ranked[b].score })

	// Rows written before value changes were caught can both still be active.
	// The older one must not read as current, and this needs no re-embedding.
	newer := func(a, b memoryRow) bool {
		return a.updatedAt.String > b.updatedAt.String || (a.updatedAt.String == b.updatedAt.String && a.rowOrder > b.rowOrder)
	}
	var kept []scoredRow
	for i, mem := range ranked {
		superseded := false
		if !pointInTime {
			for j, other := range ranked {
				if j != i && newer(other.row, mem.row) && IsValueChange(other.row.content, mem.row.content) {
					superseded = true
					break
				}
			}
		}
		if !superseded {
			kept = append(kept, mem)
		}
	}
	if len(kept) > limit {
		kept = kept[:limit]
	}

	resultRows := make([]memoryRow, len(kept))
	for i, k := range kept {
		resultRows[i] = k.row
	}
	if !opts.NoReinforce {
		if err := m.reinforceRecalled(ctx, memoryRowIDs(resultRows)); err != nil {
			return nil, err
		}
	}
	if err := m.attachEntities(ctx, resultRows); err != nil {
		return nil, err
	}
	if err := m.attachFactContext(ctx, resultRows); err != nil {
		return nil, err
	}
	if err := m.attachSourceContext(ctx, resultRows); err != nil {
		return nil, err
	}

	results := make([]RecallResult, len(kept))
	for i, k := range kept {
		row := resultRows[i]
		results[i] = RecallResult{
			MemoryView:     row.view(),
			Score:          k.score,
			ScoreBreakdown: k.breakdown,
			FactContext:    row.facts,
			Provenance:     Provenance(row.content, nullableFloat(row.confidence), row.metadata()),
			Current:        currentIDs[row.id],
		}
	}
	record(len(all), results)
	return results, nil
}

func nullableFloat(n sql.NullFloat64) *float64 {
	if !n.Valid {
		return nil
	}
	return &n.Float64
}

func filterRows(rows []memoryRow, keep func(memoryRow) bool) []memoryRow {
	var out []memoryRow
	for _, r := range rows {
		if keep(r) {
			out = append(out, r)
		}
	}
	return out
}

// reinforceRecalled strengthens what reached the model: being used is what
// keeps a memory from fading. Candidates a filter threw away earned nothing.
func (m *Manager) reinforceRecalled(ctx context.Context, ids []string) error {
	if len(ids) == 0 {
		return nil
	}
	return atomically(ctx, m.db.W, func(q queryer) error {
		for _, id := range ids {
			var strength, importance sql.NullFloat64
			found, err := one(ctx, q, []any{&strength, &importance}, `SELECT memory_strength, importance FROM memories WHERE id = ?`, id)
			if err != nil {
				return err
			}
			if !found {
				continue
			}
			next := Retention{Strength: strength.Float64, Importance: importance.Float64}.ReinforcedStrength()
			if _, err := q.ExecContext(ctx,
				`UPDATE memories
       SET access_count = access_count + 1,
           memory_strength = ?,
           last_accessed_at = datetime('now')
       WHERE id = ?`, next, id); err != nil {
				return err
			}
		}
		return nil
	})
}
