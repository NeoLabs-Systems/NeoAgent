package memory

import (
	"context"
	"database/sql"
	"errors"
	"fmt"

	"github.com/NeoLabs-Systems/neoagent/internal/memory/jsx"
)

// SaveOptions are the optional parts of SaveMemory.
type SaveOptions struct {
	AgentID   string
	Scope     *ScopeInput
	SourceRef SourceRef
	// StaleAfterDays is nil when the caller gave none.
	StaleAfterDays *float64
	Metadata       *jsx.Obj
	// Facts are model-extracted candidates for this memory.
	Facts []Candidate
	// Confidence is 0 when the caller gave none.
	Confidence float64
	// Replaces are the ids of memories this one replaces.
	Replaces []string
}

type similarMemory struct {
	id            string
	content       string
	embedding     string
	embedProvider string
	embedModel    string
	metadataJSON  string
}

func (m *Manager) findExactMemory(ctx context.Context, q queryer, userID int64, agentID, memoryHash string, scope MemoryScope) (string, error) {
	var id string
	found, err := one(ctx, q, []any{&id},
		`SELECT id FROM memories
       WHERE user_id = ? AND agent_id = ? AND archived = 0
         AND memory_hash = ?
         AND COALESCE(scope_type, 'agent') = ?
         AND COALESCE(scope_id, '') = COALESCE(?, '')
       LIMIT 1`, userID, agentID, memoryHash, scope.Type, strPtr(scope.ID))
	if !found {
		return "", err
	}
	return id, err
}

func (m *Manager) reinforceExactMemory(ctx context.Context, memoryID string, importance float64, metadata *jsx.Obj) (string, error) {
	var metaJSON sql.NullString
	if _, err := one(ctx, m.db.W, []any{&metaJSON}, `SELECT metadata_json FROM memories WHERE id = ?`, memoryID); err != nil {
		return "", err
	}
	merged := MergeMemoryMetadata(jsx.ParseObject(metaJSON.String), metadata)
	err := atomically(ctx, m.db.W, func(q queryer) error {
		if _, err := q.ExecContext(ctx,
			`UPDATE memories
       SET importance = MAX(importance, ?),
           confidence = MIN(1, confidence + 0.03),
           metadata_json = ?,
           updated_at = datetime('now')
       WHERE id = ?`, importance, jsx.Marshal(merged), memoryID); err != nil {
			return err
		}
		_, err := q.ExecContext(ctx,
			`UPDATE memory_facts
       SET confidence = MIN(1, confidence + 0.03),
           updated_at = datetime('now')
       WHERE memory_id = ? AND status = 'active'`, memoryID)
		return err
	})
	return memoryID, err
}

// currentMemoryIDs are the memories still current: an active fact in its
// window, or no facts at all.
func (m *Manager) currentMemoryIDs(ctx context.Context, q queryer, memoryIDs []string) (map[string]bool, error) {
	current := map[string]bool{}
	if len(memoryIDs) == 0 {
		return current, nil
	}
	type status struct {
		id        string
		hasActive int64
	}
	rows, err := collect(ctx, q, func(r rowScanner) (status, error) {
		var s status
		var active sql.NullInt64
		err := r.Scan(&s.id, &active)
		s.hasActive = active.Int64
		return s, err
	}, `SELECT memory_id,
              MAX(CASE WHEN status = 'active' AND (valid_to IS NULL OR datetime(valid_to) > datetime('now')) THEN 1 ELSE 0 END) AS has_active
       FROM memory_facts
       WHERE memory_id IN (`+placeholders(len(memoryIDs))+`)
       GROUP BY memory_id`, anySlice(memoryIDs)...)
	if err != nil {
		return nil, err
	}
	hasActive := map[string]int64{}
	for _, r := range rows {
		hasActive[r.id] = r.hasActive
	}
	for _, id := range memoryIDs {
		if v, ok := hasActive[id]; !ok || v == 1 {
			current[id] = true
		}
	}
	return current, nil
}

// currentSimilarMemories lists current memories in this scope worded close
// enough to compare with content.
func (m *Manager) currentSimilarMemories(ctx context.Context, q queryer, userID int64, agentID string, scope MemoryScope, content string, extraIDs []string) ([]similarMemory, error) {
	hits := m.searchMemoryFts(ctx, q, userID, agentID, content, 120)
	ids := newOrderedSet()
	ids.add(extraIDs...)
	for _, h := range hits {
		ids.add(h.memoryID)
	}
	if len(ids.items) == 0 {
		return nil, nil
	}
	args := anySlice(ids.items)
	args = append(args, userID, agentID, scope.Type, strPtr(scope.ID))
	rows, err := collect(ctx, q, func(r rowScanner) (similarMemory, error) {
		var s similarMemory
		var emb, prov, model, meta sql.NullString
		err := r.Scan(&s.id, &s.content, &emb, &prov, &model, &meta)
		s.embedding, s.embedProvider, s.embedModel, s.metadataJSON = emb.String, prov.String, model.String, meta.String
		return s, err
	}, `SELECT id, content, embedding, embedding_provider, embedding_model, metadata_json
       FROM memories
       WHERE id IN (`+placeholders(len(ids.items))+`)
         AND user_id = ? AND agent_id = ? AND archived = 0
         AND COALESCE(scope_type, 'agent') = ?
         AND COALESCE(scope_id, '') = COALESCE(?, '')`, args...)
	if err != nil {
		return nil, err
	}
	rowIDs := make([]string, len(rows))
	for i, r := range rows {
		rowIDs[i] = r.id
	}
	current, err := m.currentMemoryIDs(ctx, q, rowIDs)
	if err != nil {
		return nil, err
	}
	var out []similarMemory
	for _, r := range rows {
		if current[r.id] {
			out = append(out, r)
		}
	}
	return out, nil
}

// restateMemory handles a memory said again after it was replaced or expired:
// it is the current value again.
func (m *Manager) restateMemory(ctx context.Context, userID int64, agentID, memoryID string, in intelligenceInput, importance float64) (string, error) {
	var embedding, metaJSON sql.NullString
	if _, err := one(ctx, m.db.W, []any{&embedding, &metaJSON}, `SELECT embedding, metadata_json FROM memories WHERE id = ?`, memoryID); err != nil {
		return "", err
	}
	merged := MergeMemoryMetadata(jsx.ParseObject(metaJSON.String), in.metadata)
	if _, err := m.db.W.ExecContext(ctx,
		`UPDATE memories
       SET importance = MAX(importance, ?), metadata_json = ?, updated_at = datetime('now')
       WHERE id = ?`, importance, jsx.Marshal(merged), memoryID); err != nil {
		return "", err
	}
	in.metadata = merged
	if _, err := m.upsertMemoryIntelligence(ctx, userID, agentID, memoryID, in); err != nil {
		return "", err
	}
	return memoryID, replaceEmbeddingIndex(ctx, m.db.W, memoryID, userID, agentID, DeserializeEmbedding(embedding.String))
}

func (m *Manager) embed(ctx context.Context, text, inputType string, userID int64, agentID string) (*Embedding, error) {
	if m.embedder == nil {
		return nil, nil
	}
	return m.embedder.Embed(ctx, EmbedRequest{Text: text, InputType: inputType, UserID: userID, AgentID: agentID})
}

func sameSpaceAsEmbedding(row similarMemory, vec []float32, e *Embedding) bool {
	return SameEmbeddingSpace(row.embedProvider, row.embedModel, len(vec), e.Provider, e.Model, len(e.Vector))
}

// SaveMemory stores a memory, or reinforces the known one it duplicates. It
// returns the id of the new or existing memory, or "" when the text may not be
// stored as a memory (empty or longer than MaxMemoryChars).
func (m *Manager) SaveMemory(ctx context.Context, userID int64, content, category string, importance float64, opts SaveOptions) (string, error) {
	agentID, err := m.agentID(ctx, userID, opts.AgentID)
	if err != nil {
		return "", err
	}
	decision := MemoryStorageDecision(content)
	if !decision.Allow {
		return "", nil
	}
	content = decision.Normalized
	category = NormalizeMemoryCategory(category)
	if !jsx.IsFinite(importance) || importance == 0 {
		importance = 5
	}
	importance = max(1, min(10, importance))
	scope := normalizeScope(opts.Scope, agentID)
	sourceRef := opts.SourceRef
	var staleAfterDays any
	if opts.StaleAfterDays != nil && jsx.IsFinite(*opts.StaleAfterDays) {
		staleAfterDays = max(1, *opts.StaleAfterDays)
	}
	metadata := opts.Metadata
	if metadata == nil {
		metadata = jsx.NewObj()
	}
	structuredFacts := opts.Facts
	confidence := opts.Confidence
	if !jsx.IsFinite(confidence) || confidence == 0 {
		confidence = 0.7
	}
	confidence = max(0, min(1, confidence))
	memoryHash := StableHash(category + ":" + content)
	summary := SummarizeForPrompt(content, entityNames(ExtractEntities(content, DefaultMaxEntities)))
	namedReplacements := normalizeStringArray(opts.Replaces, 24, 80)
	relation := ""
	if len(structuredFacts) > 0 {
		relation = structuredFacts[0].Relation
	}
	// An inference may sit next to a known fact but must never replace one.
	addsToKnown := relation == "extends" || relation == "derives" || metadata.Value("relation") == "derives"
	valueChanges := func(rows []similarMemory, selfID string) []string {
		if addsToKnown {
			return nil
		}
		var ids []string
		for _, r := range rows {
			if r.id != selfID && IsValueChange(content, r.content) {
				ids = append(ids, r.id)
			}
		}
		return ids
	}
	intel := func(replaces []string, keepFacts bool, meta *jsx.Obj) intelligenceInput {
		return intelligenceInput{content: content, category: category, sourceRef: sourceRef, metadata: meta,
			facts: structuredFacts, replaces: replaces, keepFacts: keepFacts}
	}

	exact, err := m.findExactMemory(ctx, m.db.W, userID, agentID, memoryHash, scope)
	if err != nil {
		return "", err
	}
	if exact != "" {
		current, err := m.currentMemoryIDs(ctx, m.db.W, []string{exact})
		if err != nil {
			return "", err
		}
		if current[exact] && len(namedReplacements) == 0 {
			return m.reinforceExactMemory(ctx, exact, importance, metadata)
		}
		similar, err := m.currentSimilarMemories(ctx, m.db.W, userID, agentID, scope, content, nil)
		if err != nil {
			return "", err
		}
		var replaces []string
		for _, id := range uniqueStrings(append(append([]string{}, namedReplacements...), valueChanges(similar, exact)...)) {
			if id != exact {
				replaces = append(replaces, id)
			}
		}
		return m.restateMemory(ctx, userID, agentID, exact, intel(replaces, false, metadata), importance)
	}

	// The same subject, predicate and value is the same fact, however it is worded.
	var slotFacts []activeFact
	sameSlotMemoryIDs := map[string]bool{}
	if len(structuredFacts) > 0 {
		slot := structuredFacts[0]
		scopeRow := scope
		if slotFacts, err = m.activeFactsForSlot(ctx, m.db.W, userID, agentID, &scopeRow, slot.Subject, slot.Predicate); err != nil {
			return "", err
		}
		for _, other := range slotFacts {
			sameSlotMemoryIDs[other.memoryID] = true
			if lowerTrim(other.object) == lowerTrim(slot.Object) && len(namedReplacements) == 0 {
				return m.reinforceExactMemory(ctx, other.memoryID, importance, metadata)
			}
		}
	}

	emb, err := m.embed(ctx, content, "document", userID, agentID)
	if err != nil {
		return "", err
	}
	var vector []float32
	if emb != nil {
		vector = emb.Vector
	}

	var candidateIDs []string
	if vector != nil {
		cands, err := findEmbeddingCandidates(ctx, m.db.W, CandidateSearch{
			UserID: userID, AgentID: agentID, Vector: vector, Provider: emb.Provider, Model: emb.Model, Limit: 120})
		if err != nil {
			return "", err
		}
		for _, c := range cands {
			candidateIDs = append(candidateIDs, c.MemoryID)
		}
	}
	existing, err := m.currentSimilarMemories(ctx, m.db.W, userID, agentID, scope, content, candidateIDs)
	if err != nil {
		return "", err
	}

	replaced := newOrderedSet()
	replaced.add(namedReplacements...)
	replaced.add(valueChanges(existing, "")...)
	similarity := func(row similarMemory) float64 {
		if vector != nil && row.embedding != "" {
			if memVec := DeserializeEmbedding(row.embedding); memVec != nil && sameSpaceAsEmbedding(row, memVec, emb) {
				return Cosine(vector, memVec)
			}
		}
		return KeywordSimilarity(content, row.content)
	}

	// A reworded copy of a known fact is a duplicate. A fact replacing an older
	// value reads similar to it on purpose, so it goes through supersession.
	for _, mem := range existing {
		if replaced.has(mem.id) || len(namedReplacements) > 0 {
			continue
		}
		if sameSlotMemoryIDs[mem.id] || IsOneWordSwap(content, mem.content) || ValuesDiffer(content, mem.content) {
			continue
		}
		if !SharesContentWord(content, mem.content) {
			continue
		}
		sim := similarity(mem)
		if relation == "updates" {
			if sim > 0.85 {
				replaced.add(mem.id)
			}
			continue
		}
		if sim > 0.85 {
			// Similarity cannot transfer verification to different, weaker content.
			if (addsToKnown || isVerifiedTrust(jsx.ParseObject(mem.metadataJSON).Value("trustLevel"))) && !isVerifiedTrust(metadata.Value("trustLevel")) {
				continue
			}
			// Very similar: update in place if the new content is longer, otherwise skip.
			if jsx.Len(content) > jsx.Len(mem.content) {
				return m.rewriteSimilar(ctx, userID, agentID, mem, content, summary, importance, confidence, staleAfterDays,
					memoryHash, emb, vector, intel(nil, len(structuredFacts) == 0, MergeMemoryMetadata(jsx.ParseObject(mem.metadataJSON), metadata)))
			}
			return m.reinforceExactMemory(ctx, mem.id, importance, metadata)
		}
	}

	id := m.newID()
	var embeddingText, embedProvider, embedModel, embedDims, embeddedAt any
	if vector != nil {
		embeddingText = SerializeEmbedding(vector)
		embeddedAt = m.nowISO()
	}
	if emb != nil {
		embedProvider, embedModel, embedDims = nilIfEmptyStr(emb.Provider), nilIfEmptyStr(emb.Model), nilIfZero(emb.Dimensions)
	}
	sourceType, sourceID, sourceLabel := sourceRef.args()
	res, err := m.db.W.ExecContext(ctx,
		`INSERT OR IGNORE INTO memories (
        id, user_id, agent_id, category, scope_type, scope_id, source_type, source_id, source_label,
        stale_after_days, metadata_json, content, summary, importance, confidence, memory_hash, embedding,
        memory_strength, pinned, embedding_provider, embedding_model, embedding_dimensions, embedded_at
      )
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		id, userID, agentID, category, scope.Type, strPtr(scope.ID), sourceType, sourceID, sourceLabel,
		staleAfterDays, jsx.Marshal(metadata), content, summary, importance, confidence, memoryHash, embeddingText,
		1, 0, embedProvider, embedModel, embedDims, embeddedAt)
	if err != nil {
		return "", err
	}
	if n, _ := res.RowsAffected(); n == 0 {
		existingExact, err := m.findExactMemory(ctx, m.db.W, userID, agentID, memoryHash, scope)
		if err != nil {
			return "", err
		}
		if existingExact != "" {
			return m.reinforceExactMemory(ctx, existingExact, importance, metadata)
		}
		return "", errors.New("Memory insert was ignored but no matching memory row was found")
	}

	if _, err := m.upsertMemoryIntelligence(ctx, userID, agentID, id, intel(replaced.items, false, metadata)); err != nil {
		return "", err
	}
	return id, replaceEmbeddingIndex(ctx, m.db.W, id, userID, agentID, vector)
}

func nilIfZero(n int) any {
	if n == 0 {
		return nil
	}
	return n
}

func entityNames(entities []EntityCandidate) []string {
	names := make([]string, len(entities))
	for i, e := range entities {
		names[i] = e.Name
	}
	return names
}

// rewriteSimilar replaces the text of a near-duplicate with the longer wording.
func (m *Manager) rewriteSimilar(ctx context.Context, userID int64, agentID string, mem similarMemory, content, summary string,
	importance, confidence float64, staleAfterDays any, memoryHash string, emb *Embedding, vector []float32, in intelligenceInput) (string, error) {
	embedding := nilIfEmptyStr(mem.embedding)
	var provider, model, dims any
	if vector != nil {
		embedding = SerializeEmbedding(vector)
	}
	if emb != nil {
		provider, model, dims = nilIfEmptyStr(emb.Provider), nilIfEmptyStr(emb.Model), nilIfZero(emb.Dimensions)
	}
	sourceType, sourceID, sourceLabel := in.sourceRef.args()
	if _, err := m.db.W.ExecContext(ctx,
		`UPDATE memories SET content = ?, summary = ?, importance = MAX(importance, ?), confidence = MAX(confidence, ?), embedding = ?,
             embedding_provider = COALESCE(?, embedding_provider),
             embedding_model = COALESCE(?, embedding_model),
             embedding_dimensions = COALESCE(?, embedding_dimensions),
             embedded_at = CASE WHEN ? IS NULL THEN embedded_at ELSE datetime('now') END,
             source_type = COALESCE(?, source_type), source_id = COALESCE(?, source_id),
             source_label = COALESCE(?, source_label), stale_after_days = COALESCE(?, stale_after_days),
             metadata_json = ?, memory_hash = ?,
             updated_at = datetime('now') WHERE id = ?`,
		content, summary, importance, confidence, embedding, provider, model, dims, provider,
		sourceType, sourceID, sourceLabel, staleAfterDays, jsx.Marshal(in.metadata), memoryHash, mem.id); err != nil {
		return "", err
	}
	// A reworded copy without its own fact leaves the known one in place.
	if _, err := m.upsertMemoryIntelligence(ctx, userID, agentID, mem.id, in); err != nil {
		return "", err
	}
	indexed := DeserializeEmbedding(mem.embedding)
	if vector != nil {
		indexed = vector
	}
	return mem.id, replaceEmbeddingIndex(ctx, m.db.W, mem.id, userID, agentID, indexed)
}

// ConsolidateOptions describe where a batch of extracted candidates came from.
type ConsolidateOptions struct {
	AgentID        string
	Scope          *ScopeInput
	SourceRef      *SourceRef
	Metadata       *jsx.Obj
	RunID          string
	ConversationID string
}

// ConsolidateMemoryCandidates saves the model-extracted candidates of a
// thread as memories and returns their ids.
func (m *Manager) ConsolidateMemoryCandidates(ctx context.Context, userID int64, candidates []Candidate, opts ConsolidateOptions) ([]string, error) {
	agentID, err := m.agentID(ctx, userID, opts.AgentID)
	if err != nil {
		return nil, err
	}
	scope := normalizeScope(opts.Scope, agentID)
	var sourceRef SourceRef
	if opts.SourceRef != nil {
		sourceRef = *opts.SourceRef
	} else {
		label := "Agent memory"
		if opts.ConversationID != "" {
			label = "Conversation memory"
		}
		id := opts.RunID
		if id == "" {
			id = opts.ConversationID
		}
		sourceRef = NewSourceRef("conversation_consolidation", id, label)
	}
	extra := opts.Metadata
	if extra == nil {
		extra = jsx.NewObj()
	}
	memoryIDs := []string{}
	var styleNotes []string

	for _, c := range candidates {
		meta := jsx.O("relation", c.Relation, "isStatic", c.IsStatic,
			"evidence", nilIfFalsy(c.Evidence), "conversationId", nilIfEmptyStr(opts.ConversationID), "runId", nilIfEmptyStr(opts.RunID))
		meta.Assign(extra)
		scopeInput := ScopeInput{Type: scope.Type}
		if scope.ID != nil {
			scopeInput.ID = *scope.ID
		}
		id, err := m.SaveMemory(ctx, userID, c.Memory, c.Category, c.Importance, SaveOptions{
			AgentID: agentID, Confidence: c.Confidence, Facts: []Candidate{c}, SourceRef: sourceRef,
			Scope: &scopeInput, Metadata: meta,
		})
		if err != nil {
			return memoryIDs, err
		}
		if id != "" {
			memoryIDs = append(memoryIDs, id)
		}
		// Freeform style evolution: no enum knobs, just durable notes.
		if c.Category == "assistant_self" && scope.Type == "agent" && c.Confidence >= 0.55 && m.styles != nil {
			if note := m.styles.StyleNoteFromFact(c.Predicate, c.Object, c.Memory); note != "" {
				styleNotes = append(styleNotes, note)
			}
		}
	}
	if len(styleNotes) > 0 && m.styles != nil {
		if err := m.mergeStyleNotes(ctx, userID, agentID, styleNotes); err != nil {
			m.log.Warn("memory: style note update failed", "error", err)
		}
	}
	return memoryIDs, nil
}

func (m *Manager) mergeStyleNotes(ctx context.Context, userID int64, agentID string, notes []string) error {
	current, err := m.AssistantSelfState(ctx, userID, agentID)
	if err != nil {
		return err
	}
	var existing []any
	if voice, ok := current.Identity.Value("voice").(*jsx.Obj); ok {
		existing, _ = voice.Value("notes").([]any)
	}
	if existing == nil {
		if profile, ok := current.Identity.Value("voice_profile").(*jsx.Obj); ok {
			existing, _ = profile.Value("notes").([]any)
		}
	}
	merged := m.styles.MergeStyleNotes(existing, notes)
	identity := current.Identity.Clone()
	identity.Set("voice", jsx.O("notes", merged))
	_, err = m.UpdateAssistantSelfState(ctx, userID, agentID, identity, nil)
	return err
}

// ListOptions filter ListMemories.
type ListOptions struct {
	AgentID         string
	Category        string
	Limit           int
	Offset          int
	IncludeArchived bool
}

// ListMemories pages through the memories of an agent for the app.
func (m *Manager) ListMemories(ctx context.Context, userID int64, o ListOptions) ([]MemoryView, error) {
	agentID, err := m.agentID(ctx, userID, o.AgentID)
	if err != nil {
		return nil, err
	}
	archived := 0
	if o.IncludeArchived {
		archived = 1
	}
	query := `SELECT ` + listColumns + `
               FROM memories WHERE user_id = ? AND agent_id = ? AND archived = ?`
	args := []any{userID, agentID, archived}
	category := o.Category
	if category != "" && !isCategory(category) {
		category = "episodic"
	}
	if category != "" {
		query += ` AND category = ?`
		args = append(args, NormalizeMemoryCategory(category))
	}
	query += ` ORDER BY importance DESC, updated_at DESC LIMIT ? OFFSET ?`
	args = append(args, o.Limit, o.Offset)
	rows, err := collect(ctx, m.db.R, scanListRow, query, args...)
	if err != nil {
		return nil, err
	}
	return m.viewsWithEntities(ctx, rows)
}

func (m *Manager) viewsWithEntities(ctx context.Context, rows []memoryRow) ([]MemoryView, error) {
	if err := m.attachEntities(ctx, rows); err != nil {
		return nil, err
	}
	views := make([]MemoryView, len(rows))
	for i, r := range rows {
		views[i] = r.view()
	}
	return views, nil
}

// OwnedMemoryIDs keeps the ids that belong to the user's agent.
func (m *Manager) OwnedMemoryIDs(ctx context.Context, userID int64, agentID string, ids []string) ([]string, error) {
	var unique []string
	seen := map[string]bool{}
	for _, id := range ids {
		if id = jsx.Trim(id); id != "" && !seen[id] {
			seen[id] = true
			unique = append(unique, id)
		}
	}
	if len(unique) == 0 {
		return nil, nil
	}
	scoped, err := m.agentID(ctx, userID, agentID)
	if err != nil {
		return nil, err
	}
	return collect(ctx, m.db.R, scanString,
		`SELECT id FROM memories WHERE user_id = ? AND agent_id = ? AND id IN (`+placeholders(len(unique))+`)`,
		append([]any{userID, scoped}, anySlice(unique)...)...)
}

// UpdateFields are the parts of a memory the app can change; nil keeps it.
type UpdateFields struct {
	Content    *string
	Importance *float64
	Category   *string
}

// UpdateMemory changes a memory's content, importance or category. It returns
// nil when the memory does not exist.
func (m *Manager) UpdateMemory(ctx context.Context, id string, f UpdateFields) (*MemoryView, error) {
	var userID int64
	var agentID, category, metaJSON, embedding, hash, sourceType, sourceID, sourceLabel, content sql.NullString
	var importance sql.NullFloat64
	found, err := one(ctx, m.db.W, []any{&userID, &agentID, &category, &content, &importance, &metaJSON, &embedding, &sourceType, &sourceID, &sourceLabel, &hash},
		`SELECT user_id, agent_id, category, content, importance, metadata_json, embedding, source_type, source_id, source_label, memory_hash
		 FROM memories WHERE id = ?`, id)
	if err != nil || !found {
		return nil, err
	}

	newContent := content.String
	contentChanged := false
	if f.Content != nil {
		newContent = *f.Content
		contentChanged = newContent != "" && newContent != content.String
	}
	newImportance := importance.Float64
	if f.Importance != nil && jsx.IsFinite(*f.Importance) {
		newImportance = max(1, min(10, *f.Importance))
	}
	newCategory := category.String
	if f.Category != nil && *f.Category != "" {
		newCategory = NormalizeMemoryCategory(*f.Category)
	}
	newSummary := SummarizeForPrompt(newContent, entityNames(ExtractEntities(newContent, DefaultMaxEntities)))
	newHash := StableHash(newCategory + ":" + newContent)
	// Only the app edits memories this way: the owner just wrote or checked it.
	incoming := jsx.NewObj()
	if contentChanged {
		incoming.Set("trustLevel", "user_stated").Set("verification", OwnerVerification(newContent))
	}
	newMetadata := MergeMemoryMetadata(jsx.ParseObject(metaJSON.String), incoming)

	newEmbed := nilIfEmptyStr(embedding.String)
	var emb *Embedding
	if contentChanged {
		if emb, err = m.embed(ctx, newContent, "document", userID, agentID.String); err != nil {
			return nil, err
		}
		if emb != nil && emb.Vector != nil {
			newEmbed = SerializeEmbedding(emb.Vector)
		}
	}
	var provider, model, dims any
	if emb != nil {
		provider, model, dims = nilIfEmptyStr(emb.Provider), nilIfEmptyStr(emb.Model), nilIfZero(emb.Dimensions)
	}
	if _, err := m.db.W.ExecContext(ctx,
		`UPDATE memories SET content = ?, summary = ?, importance = ?, category = ?, memory_hash = ?, embedding = ?,
       metadata_json = ?,
       embedding_provider = COALESCE(?, embedding_provider),
       embedding_model = COALESCE(?, embedding_model),
       embedding_dimensions = COALESCE(?, embedding_dimensions),
       embedded_at = CASE WHEN ? IS NULL THEN embedded_at ELSE datetime('now') END,
       updated_at = datetime('now') WHERE id = ?`,
		newContent, newSummary, newImportance, newCategory, newHash, newEmbed, jsx.Marshal(newMetadata),
		provider, model, dims, provider, id); err != nil {
		return nil, err
	}

	in := intelligenceInput{
		content: newContent, category: newCategory, metadata: newMetadata,
		sourceRef: NewSourceRef(sourceType.String, sourceID.String, sourceLabel.String),
	}
	if _, err := m.upsertMemoryIntelligence(ctx, userID, agentID.String, id, in); err != nil {
		return nil, err
	}
	indexed := DeserializeEmbedding(jsString(newEmbed))
	if err := replaceEmbeddingIndex(ctx, m.db.W, id, userID, agentID.String, indexed); err != nil {
		return nil, err
	}
	rows, err := collect(ctx, m.db.W, scanListRow, `SELECT `+listColumns+` FROM memories WHERE id = ?`, id)
	if err != nil || len(rows) == 0 {
		return nil, err
	}
	view := rows[0].view()
	return &view, nil
}

// DeleteMemories removes memories with everything derived from them and
// returns how many were deleted. A non-zero userID restricts the delete to
// that user's memories.
func (m *Manager) DeleteMemories(ctx context.Context, ids []string, userID int64) (int64, error) {
	unique := normalizeIDs(ids)
	if len(unique) == 0 {
		return 0, nil
	}
	owned := unique
	if userID != 0 {
		var err error
		owned, err = collect(ctx, m.db.W, scanString,
			`SELECT id FROM memories WHERE id IN (`+placeholders(len(unique))+`) AND user_id = ?`,
			append(anySlice(unique), userID)...)
		if err != nil {
			return 0, err
		}
	}
	if len(owned) == 0 {
		return 0, nil
	}
	var deleted int64
	err := atomically(ctx, m.db.W, func(q queryer) error {
		entityIDs, err := m.entityIDsForMemories(ctx, q, owned)
		if err != nil {
			return err
		}
		for _, id := range owned {
			if err := m.deleteMemoryIndex(ctx, q, id, false); err != nil {
				return err
			}
		}
		res, err := q.ExecContext(ctx, `DELETE FROM memories WHERE id IN (`+placeholders(len(owned))+`)`, anySlice(owned)...)
		if err != nil {
			return err
		}
		deleted, _ = res.RowsAffected()
		return m.pruneOrphanEntities(ctx, q, entityIDs)
	})
	return deleted, err
}

func normalizeIDs(ids []string) []string {
	var out []string
	seen := map[string]bool{}
	for _, id := range ids {
		if id = jsx.Trim(id); id != "" && !seen[id] {
			seen[id] = true
			out = append(out, id)
		}
	}
	return out
}

// ArchiveMemories archives or restores memories and returns how many changed.
// A non-zero userID restricts it to that user's memories.
func (m *Manager) ArchiveMemories(ctx context.Context, ids []string, archived bool, userID int64) (int64, error) {
	unique := normalizeIDs(ids)
	if len(unique) == 0 {
		return 0, nil
	}
	if archived {
		for _, id := range unique {
			_, _ = m.db.W.ExecContext(ctx, `DELETE FROM memories_fts WHERE memory_id = ?`, id)
		}
	}
	flag := 0
	if archived {
		flag = 1
	}
	query := fmt.Sprintf(`UPDATE memories SET archived = ? WHERE id IN (%s)`, placeholders(len(unique)))
	args := append([]any{flag}, anySlice(unique)...)
	if userID != 0 {
		query += ` AND user_id = ?`
		args = append(args, userID)
	}
	res, err := m.db.W.ExecContext(ctx, query, args...)
	if err != nil {
		return 0, err
	}
	n, _ := res.RowsAffected()
	return n, nil
}

// ArchiveWeakOptions tune ArchiveWeakMemories.
type ArchiveWeakOptions struct {
	AgentID string
	Limit   int
	ArchiveOptions
}

// ArchiveWeakResult is what ArchiveWeakMemories did.
type ArchiveWeakResult struct {
	Scanned   int
	Archived  int64
	MemoryIDs []string
}

// ArchiveWeakMemories archives old, faded, unpinned memories.
func (m *Manager) ArchiveWeakMemories(ctx context.Context, userID int64, o ArchiveWeakOptions) (ArchiveWeakResult, error) {
	agentID, err := m.agentID(ctx, userID, o.AgentID)
	if err != nil {
		return ArchiveWeakResult{}, err
	}
	limit := o.Limit
	if limit == 0 {
		limit = 100
	}
	limit = max(1, min(limit, 500))
	type weak struct {
		id string
		r  Retention
	}
	rows, err := collect(ctx, m.db.W, func(r rowScanner) (weak, error) {
		var w weak
		var cat, last, created, updated sql.NullString
		var imp, archived, strength, pinned, stale sql.NullFloat64
		err := r.Scan(&w.id, &cat, &imp, &archived, &strength, &last, &pinned, &stale, &created, &updated)
		w.r = Retention{Pinned: pinned.Float64, Category: cat.String, Importance: imp.Float64, Archived: archived.Float64,
			Strength: strength.Float64, StaleAfterDays: stale.Float64, LastAccessedAt: last.String,
			UpdatedAt: updated.String, CreatedAt: created.String}
		return w, err
	}, `SELECT id, category, importance, archived, memory_strength, last_accessed_at,
              pinned, stale_after_days, created_at, updated_at
       FROM memories
       WHERE user_id = ? AND agent_id = ? AND archived = 0
       ORDER BY updated_at ASC
       LIMIT ?`, userID, agentID, limit)
	if err != nil {
		return ArchiveWeakResult{}, err
	}
	opts := o.ArchiveOptions
	if opts.NowMs == 0 {
		opts.NowMs = m.nowMS()
	}
	var ids []string
	for _, w := range rows {
		if w.r.IsArchiveEligible(opts) {
			ids = append(ids, w.id)
		}
	}
	archived, err := m.ArchiveMemories(ctx, ids, true, userID)
	return ArchiveWeakResult{Scanned: len(rows), Archived: archived, MemoryIDs: ids}, err
}
