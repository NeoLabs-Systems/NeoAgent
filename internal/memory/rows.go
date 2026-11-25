package memory

import (
	"database/sql"

	"github.com/NeoLabs-Systems/neoagent/internal/memory/jsx"
)

// EntityRef is an entity attached to a memory.
type EntityRef struct {
	ID           string `json:"id"`
	Key          string `json:"key"`
	Name         string `json:"name"`
	Kind         string `json:"kind"`
	MentionCount int64  `json:"mentionCount"`
}

// SourceLink points from a memory to the document chunk it was learned from.
type SourceLink struct {
	DocumentID       string  `json:"documentId"`
	ChunkID          string  `json:"chunkId"`
	ExternalObjectID string  `json:"externalObjectId"`
	SourceType       string  `json:"sourceType"`
	Title            *string `json:"title"`
	ChunkIndex       int64   `json:"chunkIndex"`
	CharStart        int64   `json:"charStart"`
	CharEnd          int64   `json:"charEnd"`
	SourceTimestamp  *string `json:"sourceTimestamp"`
	RelevanceScore   float64 `json:"relevanceScore"`
	ExtractionMethod string  `json:"extractionMethod"`
}

// ScopeView is a memory's scope as the API shows it.
type ScopeView struct {
	ScopeType string  `json:"scopeType"`
	ScopeID   *string `json:"scopeId"`
}

// MemoryView is a memory as the API shows it (serializeMemoryRow).
type MemoryView struct {
	ID             string       `json:"id"`
	Category       string       `json:"category"`
	Content        string       `json:"content"`
	Summary        string       `json:"summary"`
	Importance     float64      `json:"importance"`
	Confidence     float64      `json:"confidence"`
	AccessCount    float64      `json:"access_count"`
	MemoryStrength float64      `json:"memoryStrength"`
	LastAccessedAt *string      `json:"lastAccessedAt"`
	Pinned         bool         `json:"pinned"`
	Archived       float64      `json:"archived"`
	CreatedAt      string       `json:"created_at"`
	UpdatedAt      string       `json:"updated_at"`
	SourceRef      SourceRef    `json:"sourceRef"`
	Scope          ScopeView    `json:"scope"`
	StaleAfterDays *float64     `json:"staleAfterDays"`
	Metadata       *jsx.Obj     `json:"metadata"`
	Entities       []EntityRef  `json:"entities"`
	Sources        []SourceLink `json:"sources"`
}

// memoryRow is a memories row with the columns the list and recall queries read.
type memoryRow struct {
	rowOrder       int64
	id             string
	category       sql.NullString
	content        string
	summary        sql.NullString
	importance     sql.NullFloat64
	confidence     sql.NullFloat64
	embedding      sql.NullString
	accessCount    sql.NullFloat64
	strength       sql.NullFloat64
	lastAccessedAt sql.NullString
	pinned         sql.NullFloat64
	archived       sql.NullFloat64
	createdAt      sql.NullString
	updatedAt      sql.NullString
	scopeType      sql.NullString
	scopeID        sql.NullString
	sourceType     sql.NullString
	sourceID       sql.NullString
	sourceLabel    sql.NullString
	staleAfterDays sql.NullFloat64
	embedProvider  sql.NullString
	embedModel     sql.NullString
	metadataJSON   sql.NullString

	entities []EntityRef
	sources  []SourceLink
	facts    []FactContext
}

// listColumns are the memories columns of the list endpoints.
const listColumns = `id, category, content, summary, importance, confidence, access_count,
       memory_strength, last_accessed_at, pinned, archived, created_at, updated_at,
       scope_type, scope_id, source_type, source_id, source_label, stale_after_days, metadata_json`

func scanListRow(r rowScanner) (memoryRow, error) {
	var x memoryRow
	err := r.Scan(&x.id, &x.category, &x.content, &x.summary, &x.importance, &x.confidence, &x.accessCount,
		&x.strength, &x.lastAccessedAt, &x.pinned, &x.archived, &x.createdAt, &x.updatedAt,
		&x.scopeType, &x.scopeID, &x.sourceType, &x.sourceID, &x.sourceLabel, &x.staleAfterDays, &x.metadataJSON)
	return x, err
}

func (r memoryRow) retention() Retention {
	return Retention{
		Pinned: r.pinned.Float64, Category: r.category.String, Importance: r.importance.Float64,
		Archived: r.archived.Float64, Strength: r.strength.Float64, StaleAfterDays: r.staleAfterDays.Float64,
		LastAccessedAt: r.lastAccessedAt.String, UpdatedAt: r.updatedAt.String, CreatedAt: r.createdAt.String,
	}
}

func (r memoryRow) metadata() *jsx.Obj { return jsx.ParseObject(r.metadataJSON.String) }

func (r memoryRow) view() MemoryView {
	scopeType := r.scopeType.String
	if scopeType == "" {
		scopeType = "agent"
	}
	confidence, strength := 0.7, 1.0
	if r.confidence.Valid {
		confidence = r.confidence.Float64
	}
	if r.strength.Valid {
		strength = r.strength.Float64
	}
	var stale *float64
	if r.staleAfterDays.Valid {
		stale = &r.staleAfterDays.Float64
	}
	entities, sources := r.entities, r.sources
	if entities == nil {
		entities = []EntityRef{}
	}
	if sources == nil {
		sources = []SourceLink{}
	}
	return MemoryView{
		ID:             r.id,
		Category:       NormalizeMemoryCategory(r.category.String),
		Content:        r.content,
		Summary:        r.summary.String,
		Importance:     r.importance.Float64,
		Confidence:     confidence,
		AccessCount:    r.accessCount.Float64,
		MemoryStrength: strength,
		LastAccessedAt: nonEmptyPtr(r.lastAccessedAt.String),
		Pinned:         r.pinned.Float64 == 1,
		Archived:       r.archived.Float64,
		CreatedAt:      r.createdAt.String,
		UpdatedAt:      r.updatedAt.String,
		SourceRef:      SourceRef{Type: nonEmptyPtr(r.sourceType.String), ID: nonEmptyPtr(r.sourceID.String), Label: nonEmptyPtr(r.sourceLabel.String)},
		Scope:          ScopeView{ScopeType: scopeType, ScopeID: nonEmptyPtr(r.scopeID.String)},
		StaleAfterDays: stale,
		Metadata:       r.metadata(),
		Entities:       entities,
		Sources:        sources,
	}
}
