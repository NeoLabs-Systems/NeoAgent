package memory

import (
	"context"
	"database/sql"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/memory/jsx"
)

// This file keeps the derived rows of a memory in step with its text: its
// entities and their mentions, its facts with their supersession chain and
// relations, and its full-text index entry.

func normalizeFactSlot(value string) string {
	s := jsx.Lower(value)
	s = strings.NewReplacer("_", " ", "-", " ").Replace(s)
	return jsx.Collapse(s)
}

// activeFact is an active fact found for a slot or a memory.
type activeFact struct {
	id           string
	memoryID     string
	object       string
	confidence   float64
	metadataJSON string
}

func scanActiveFact(r rowScanner) (activeFact, error) {
	var f activeFact
	var confidence sql.NullFloat64
	var meta sql.NullString
	err := r.Scan(&f.id, &f.memoryID, &f.object, &confidence, &meta)
	f.confidence = confidence.Float64
	f.metadataJSON = meta.String
	return f, err
}

// activeFactsForSlot lists active facts holding the same subject and
// predicate, newest first, within the same scope: a shared room's fact must
// not replace the owner's. Locally built facts never count.
func (m *Manager) activeFactsForSlot(ctx context.Context, q queryer, userID int64, agentID string, scope *MemoryScope, subject, predicate string) ([]activeFact, error) {
	var scopeType, scopeID any
	if scope != nil {
		if scope.Type != "" {
			scopeType = scope.Type
		}
		if scope.ID != nil && *scope.ID != "" {
			scopeID = *scope.ID
		}
	}
	rows, err := collect(ctx, q, scanActiveFact,
		`SELECT f.id, f.memory_id, f.object, f.confidence, f.metadata_json
       FROM memory_facts f
       JOIN memories m ON m.id = f.memory_id
       WHERE f.user_id = ? AND f.agent_id = ?
         AND lower(f.subject) = lower(?)
         AND replace(replace(lower(f.predicate), '_', ' '), '-', ' ') = ?
         AND f.status = 'active'
         AND COALESCE(m.scope_type, 'agent') = COALESCE(?, 'agent')
         AND COALESCE(m.scope_id, '') = COALESCE(?, '')
       ORDER BY f.learned_at DESC, f.created_at DESC`,
		userID, agentID, subject, normalizeFactSlot(predicate), scopeType, scopeID)
	if err != nil {
		return nil, err
	}
	var kept []activeFact
	for _, row := range rows {
		if jsx.ParseObject(row.metadataJSON).Value("extractedBy") != "local_memory_intelligence" {
			kept = append(kept, row)
		}
	}
	return kept, nil
}

func (m *Manager) activeFactsOfMemories(ctx context.Context, q queryer, memoryIDs []string) ([]activeFact, error) {
	if len(memoryIDs) == 0 {
		return nil, nil
	}
	return collect(ctx, q, scanActiveFact,
		`SELECT id, memory_id, object, confidence, metadata_json
       FROM memory_facts
       WHERE memory_id IN (`+placeholders(len(memoryIDs))+`) AND status = 'active'
       ORDER BY learned_at DESC, created_at DESC`, anySlice(memoryIDs)...)
}

func (m *Manager) deleteMemoryIndex(ctx context.Context, q queryer, memoryID string, keepFacts bool) error {
	// FTS is optional: a failure here is not an error.
	_, _ = q.ExecContext(ctx, `DELETE FROM memories_fts WHERE memory_id = ?`, memoryID)
	if _, err := q.ExecContext(ctx, `DELETE FROM memory_entity_mentions WHERE memory_id = ?`, memoryID); err != nil {
		return err
	}
	if !keepFacts {
		if _, err := q.ExecContext(ctx, `DELETE FROM memory_facts WHERE memory_id = ?`, memoryID); err != nil {
			return err
		}
	}
	_, err := q.ExecContext(ctx, `DELETE FROM memory_embedding_bands WHERE memory_id = ?`, memoryID)
	return err
}

// pruneOrphanEntities recounts the given entities and drops the ones no memory
// mentions anymore. Callers collect ids before deleting or re-indexing
// mentions and call this afterwards.
func (m *Manager) pruneOrphanEntities(ctx context.Context, q queryer, entityIDs []string) error {
	for _, id := range uniqueStrings(entityIDs) {
		var count int64
		if err := q.QueryRowContext(ctx, `SELECT COUNT(*) AS count FROM memory_entity_mentions WHERE entity_id = ?`, id).Scan(&count); err != nil {
			return err
		}
		var err error
		if count > 0 {
			_, err = q.ExecContext(ctx, `UPDATE memory_entities SET mention_count = ? WHERE id = ?`, count, id)
		} else {
			_, err = q.ExecContext(ctx, `DELETE FROM memory_entities WHERE id = ?`, id)
		}
		if err != nil {
			return err
		}
	}
	return nil
}

func (m *Manager) entityIDsForMemories(ctx context.Context, q queryer, memoryIDs []string) ([]string, error) {
	ids := uniqueStrings(memoryIDs)
	if len(ids) == 0 {
		return nil, nil
	}
	return collect(ctx, q, scanString,
		`SELECT DISTINCT entity_id FROM memory_entity_mentions
       WHERE memory_id IN (`+placeholders(len(ids))+`)`, anySlice(ids)...)
}

// intelligenceInput is what the derived rows of a memory are built from.
type intelligenceInput struct {
	content   string
	category  string
	sourceRef SourceRef
	metadata  *jsx.Obj
	facts     []Candidate
	replaces  []string
	keepFacts bool
}

func jsString(v any) string {
	if !jsx.Truthy(v) {
		return ""
	}
	return jsx.ToString(v)
}

func (in intelligenceInput) sourceType() string {
	return jsString(jsx.Or(strPtrAny(in.sourceRef.Type), in.metadata.Lookup("sourceType")))
}

func strPtrAny(p *string) any {
	if p == nil {
		return nil
	}
	return *p
}

func (in intelligenceInput) draftFacts() []Fact {
	if len(in.facts) > 0 {
		facts := make([]Fact, len(in.facts))
		for i, f := range in.facts {
			var evidence, forgetAfter any
			if f.Evidence != "" {
				evidence = f.Evidence
			}
			if f.ForgetAfter != "" {
				forgetAfter = f.ForgetAfter
			}
			var sourceType any
			if st := in.sourceType(); st != "" {
				sourceType = st
			}
			validTo := f.ValidTo
			if validTo == "" {
				validTo = f.ForgetAfter
			}
			facts[i] = Fact{
				Subject: f.Subject, Predicate: f.Predicate, Object: f.Object, Category: f.Category,
				Confidence: f.Confidence, EventTime: f.ValidFrom, ValidFrom: f.ValidFrom, ValidTo: validTo,
				Relation: f.Relation,
				Metadata: jsx.O("sourceType", sourceType, "extractedBy", "llm_memory_consolidation",
					"relation", f.Relation, "isStatic", f.IsStatic, "evidence", evidence, "forgetAfter", forgetAfter),
			}
		}
		return facts
	}
	// Raw ingested source chunks stay searchable as memories, but copying their
	// sentences into the fact index only floods it with non-facts.
	if in.sourceRef.typeValue() == "memory_ingestion" {
		return nil
	}
	return BuildFacts(in.content, in.category, in.sourceType())
}

func firstTruthyString(values ...any) string {
	return jsString(jsx.Or(append(values, nil)...))
}

// upsertMemoryIntelligence rebuilds the entities, facts, relations and
// full-text entry of one memory.
func (m *Manager) upsertMemoryIntelligence(ctx context.Context, userID int64, agentID, memoryID string, in intelligenceInput) ([]EntityCandidate, error) {
	if in.metadata == nil {
		in.metadata = jsx.NewObj()
	}
	entities := ExtractEntities(in.content, DefaultMaxEntities)
	facts := in.draftFacts()
	now := m.nowISO()

	var scope *MemoryScope
	var scopeType, scopeID sql.NullString
	found, err := one(ctx, m.db.W, []any{&scopeType, &scopeID}, `SELECT scope_type, scope_id FROM memories WHERE id = ?`, memoryID)
	if err != nil {
		return nil, err
	}
	if found {
		s := MemoryScope{Type: scopeType.String}
		if scopeID.Valid {
			s.ID = &scopeID.String
		}
		scope = &s
	}

	err = atomically(ctx, m.db.W, func(q queryer) error {
		touched, err := m.entityIDsForMemories(ctx, q, []string{memoryID})
		if err != nil {
			return err
		}
		if err := m.deleteMemoryIndex(ctx, q, memoryID, in.keepFacts); err != nil {
			return err
		}

		if !in.keepFacts {
			for _, fact := range facts {
				if err := m.storeFact(ctx, q, userID, agentID, memoryID, in, fact, scope, now); err != nil {
					return err
				}
			}
		}

		for _, entity := range entities {
			id, err := m.storeEntity(ctx, q, userID, agentID, memoryID, entity, now)
			if err != nil {
				return err
			}
			touched = append(touched, id)
		}
		if err := m.pruneOrphanEntities(ctx, q, touched); err != nil {
			return err
		}

		names := make([]string, len(entities))
		for i, e := range entities {
			names[i] = e.Name + " " + e.Kind
		}
		// FTS is optional.
		_, _ = q.ExecContext(ctx,
			`INSERT INTO memories_fts (memory_id, user_id, agent_id, content, category, entities)
           VALUES (?, ?, ?, ?, ?, ?)`,
			memoryID, userID, agentID, in.content, in.category, strings.Join(names, " "))
		return nil
	})
	return entities, err
}

func (m *Manager) storeEntity(ctx context.Context, q queryer, userID int64, agentID, memoryID string, entity EntityCandidate, now string) (string, error) {
	var existingID, aliasesJSON sql.NullString
	var mentions sql.NullInt64
	found, err := one(ctx, q, []any{&existingID, &aliasesJSON, &mentions},
		`SELECT id, aliases_json, mention_count
           FROM memory_entities
           WHERE user_id = ? AND agent_id = ? AND entity_key = ?`, userID, agentID, entity.Key)
	if err != nil {
		return "", err
	}
	aliases := parseStringList(aliasesJSON.String, 16, 160)
	if !contains(aliases, entity.Name) {
		aliases = append(aliases, entity.Name)
	}
	entityID := existingID.String
	if !found || entityID == "" {
		entityID = m.newID()
	}
	if len(aliases) > 16 {
		aliases = aliases[:16]
	}
	if _, err := q.ExecContext(ctx,
		`INSERT INTO memory_entities (
            id, user_id, agent_id, entity_key, name, kind, aliases_json,
            mention_count, first_seen_at, last_seen_at, metadata_json
          ) VALUES (?, ?, ?, ?, ?, ?, ?, 1, datetime('now'), ?, '{}')
          ON CONFLICT(user_id, agent_id, entity_key) DO UPDATE SET
            name = CASE WHEN length(excluded.name) > length(memory_entities.name) THEN excluded.name ELSE memory_entities.name END,
            kind = CASE WHEN memory_entities.kind = 'concept' THEN excluded.kind ELSE memory_entities.kind END,
            aliases_json = excluded.aliases_json,
            last_seen_at = excluded.last_seen_at`,
		entityID, userID, agentID, entity.Key, entity.Name, entity.Kind, jsx.Marshal(aliases), now); err != nil {
		return "", err
	}
	inSentence := 0
	if entity.InSentence {
		inSentence = 1
	}
	_, err = q.ExecContext(ctx,
		`INSERT OR IGNORE INTO memory_entity_mentions (entity_id, memory_id, user_id, agent_id, in_sentence)
           VALUES (?, ?, ?, ?, ?)`, entityID, memoryID, userID, agentID, inSentence)
	return entityID, err
}

func contains(items []string, item string) bool {
	for _, i := range items {
		if i == item {
			return true
		}
	}
	return false
}

func lowerTrim(s string) string { return jsx.Lower(jsx.Trim(s)) }

// storeFact inserts one fact of a memory, superseding the facts it replaces.
func (m *Manager) storeFact(ctx context.Context, q queryer, userID int64, agentID, memoryID string, in intelligenceInput, fact Fact, scope *MemoryScope, now string) error {
	factID := m.newID()
	validFrom := firstTruthyString(fact.ValidFrom, fact.EventTime, in.metadata.Lookup("validFrom"), in.metadata.Lookup("eventTime"))
	validTo := fact.ValidTo
	relation := jsx.Lower(jsString(jsx.Or(fact.Relation, fact.Metadata.Lookup("relation"), "new")))

	// A locally built fact has a category for a predicate and any capitalized
	// word for a subject, so sharing them says nothing about sharing a value.
	hasSlot := fact.Predicate != "detail" && fact.Metadata.Value("extractedBy") != "local_memory_intelligence"
	var slotFacts []activeFact
	if hasSlot {
		var err error
		if slotFacts, err = m.activeFactsForSlot(ctx, q, userID, agentID, scope, fact.Subject, fact.Predicate); err != nil {
			return err
		}
	}
	replacedFacts, err := m.activeFactsOfMemories(ctx, q, in.replaces)
	if err != nil {
		return err
	}
	var conflict *activeFact
	switch {
	case len(slotFacts) > 0:
		conflict = &slotFacts[0]
	case len(replacedFacts) > 0:
		conflict = &replacedFacts[0]
	}
	differs := func(other activeFact) bool { return lowerTrim(other.object) != lowerTrim(fact.Object) }

	var replacing []activeFact
	if relation == "updates" || len(replacedFacts) > 0 {
		seen := map[string]bool{}
		for _, other := range append(append([]activeFact{}, slotFacts...), replacedFacts...) {
			if seen[other.id] {
				continue
			}
			seen[other.id] = true
			if differs(other) {
				replacing = append(replacing, other)
			}
		}
	} else if conflict != nil && differs(*conflict) {
		replacing = []activeFact{*conflict}
	}

	var superseded []activeFact
	requiresReview := false
	if len(replacing) > 0 && relation != "extends" && relation != "derives" {
		trust := in.metadata.Value("trustLevel")
		isExternalNew := trust == "external_source" || fact.Metadata.Value("sourceType") == "external"
		// Outside content can only name a value; what it would replace by
		// matching wording, or what is known firmly, waits for someone to confirm.
		isProtected := func(other activeFact) bool {
			for _, r := range replacedFacts {
				if r.id == other.id {
					return true
				}
			}
			return jsx.ParseObject(other.metadataJSON).Truthy("isStatic") || other.confidence >= 0.8
		}
		protected := false
		for _, other := range replacing {
			if isProtected(other) {
				protected = true
				break
			}
		}
		if isExternalNew && protected {
			requiresReview = true
		} else {
			superseded = replacing
		}
	}
	var supersedesID any
	if len(superseded) > 0 {
		supersedesID = superseded[0].id
	}
	for _, s := range superseded {
		if _, err := q.ExecContext(ctx,
			`UPDATE memory_facts
             SET status = 'superseded',
                 valid_to = COALESCE(?, datetime('now')),
                 invalidated_at = datetime('now'),
                 updated_at = datetime('now')
             WHERE id = ?`, nilIfEmptyStr(validFrom), s.id); err != nil {
			return err
		}
	}

	status := "active"
	finalMetadata := fact.Metadata.Clone()
	if requiresReview {
		status = "needs_review"
		finalMetadata.Set("reviewReason", "conflict_with_high_confidence_or_core_memory")
		finalMetadata.Set("conflictingFactId", replacing[0].id)
	}
	// Reconciliation restores old accidental supersessions; this one was meant.
	if len(replacedFacts) > 0 && len(superseded) > 0 {
		finalMetadata.Set("replacedMemory", true)
	}

	confidence := fact.Confidence
	if confidence == 0 {
		confidence = 0.7
	}
	confidence = max(0, min(1, confidence))
	if _, err := q.ExecContext(ctx,
		`INSERT INTO memory_facts (
            id, memory_id, user_id, agent_id, subject, predicate, object, category,
            confidence, event_time, valid_from, valid_to, learned_at, status, supersedes_fact_id,
            metadata_json, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'), datetime('now'))`,
		factID, memoryID, userID, agentID, fact.Subject, fact.Predicate, fact.Object,
		NormalizeMemoryCategory(fact.Category), confidence, nilIfEmptyStr(fact.EventTime), nilIfEmptyStr(validFrom),
		nilIfEmptyStr(validTo), now, status, supersedesID, jsx.Marshal(finalMetadata)); err != nil {
		return err
	}

	type link struct {
		target       activeFact
		relationType string
	}
	var links []link
	for _, t := range superseded {
		links = append(links, link{t, "updates"})
	}
	if len(links) == 0 && conflict != nil && (relation == "extends" || relation == "derives") {
		links = append(links, link{*conflict, relation})
	}
	for _, l := range links {
		var evidence, evidenceSource any
		if fact.Metadata != nil {
			evidence = nilIfFalsy(fact.Metadata.Value("evidence"))
		}
		if in.sourceRef.ID != nil {
			evidenceSource = *in.sourceRef.ID
		}
		if _, err := q.ExecContext(ctx,
			`INSERT OR REPLACE INTO memory_relations (
               id, user_id, agent_id, from_memory_id, to_memory_id, relation_type,
               confidence, metadata_json
             ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
			m.newID(), userID, agentID, memoryID, l.target.memoryID, l.relationType, confidence,
			jsx.Marshal(jsx.O("evidence", evidence, "sourceFactId", factID, "targetFactId", l.target.id, "evidenceSourceId", evidenceSource))); err != nil {
			return err
		}
	}
	return nil
}

func nilIfEmptyStr(s string) any {
	if s == "" {
		return nil
	}
	return s
}

func nilIfFalsy(v any) any {
	if !jsx.Truthy(v) {
		return nil
	}
	return v
}
