package memory

import (
	"context"
	"crypto/rand"
	"database/sql"
	"errors"
	"fmt"
	"log/slog"
	"os"
	"path/filepath"
	"strconv"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/agentscope"
	"github.com/NeoLabs-Systems/neoagent/internal/memory/jsx"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/secretbox"
)

// Config wires a Manager.
type Config struct {
	DB *dbx.DB
	// Embedder makes embeddings. Nil keeps memory on keyword search.
	Embedder Embedder
	// AgentDataDir is where per-user daily logs and API_KEYS.json live
	// (NEOAGENT_AGENT_DATA_DIR, default ~/.neoagent/agent-data).
	AgentDataDir string
	// LocalBox seals API_KEYS.json values (prefix "enc:local:v1:", key material
	// NEOAGENT_DATA_ENCRYPTION_KEY or else SESSION_SECRET).
	LocalBox *secretbox.Box
	Log      *slog.Logger
	// StyleNotes turns assistant_self facts into voice notes; optional.
	StyleNotes StyleNotes
	// Clock and NewID are test seams; they default to the real time and UUID v4.
	Clock func() time.Time
	NewID func() string
}

// StyleNotes is the voice-profile logic that learns writing style from
// assistant_self facts (services/behavior/modules/voice_profile.js).
type StyleNotes interface {
	// StyleNoteFromFact returns the note a fact teaches, or "" for none.
	StyleNoteFromFact(predicate, object, memory string) string
	// MergeStyleNotes merges new notes into the stored ones.
	MergeStyleNotes(existing []any, added []string) []any
}

// Manager keeps memories, core memory, source documents and conversation
// state. It is safe for concurrent use.
type Manager struct {
	db       *dbx.DB
	embedder Embedder
	agents   agentscope.Resolver
	dataDir  string
	localBox *secretbox.Box
	log      *slog.Logger
	styles   StyleNotes
	clock    func() time.Time
	newID    func() string

	lowercaseMu    sync.Mutex
	lowercaseCache struct {
		key   string
		words map[string]bool
	}
	refresher *refresher
	stop      context.CancelFunc
	wg        sync.WaitGroup
}

// New builds the manager, makes sure the data directories exist and fills in
// the facts and entities of memories saved before they existed.
func New(ctx context.Context, cfg Config) (*Manager, error) {
	if cfg.AgentDataDir != "" && cfg.LocalBox == nil {
		return nil, errors.New("memory: LocalBox is required to keep API keys")
	}
	m := &Manager{
		db:       cfg.DB,
		embedder: cfg.Embedder,
		agents:   agentscope.Resolver{DB: cfg.DB},
		dataDir:  cfg.AgentDataDir,
		localBox: cfg.LocalBox,
		log:      cfg.Log,
		styles:   cfg.StyleNotes,
		clock:    cfg.Clock,
		newID:    cfg.NewID,
	}
	if m.log == nil {
		m.log = slog.New(slog.DiscardHandler)
	}
	if m.clock == nil {
		m.clock = time.Now
	}
	if m.newID == nil {
		m.newID = uuidV4
	}
	m.refresher = newRefresher(m)
	if err := m.ensureDirs(); err != nil {
		return nil, err
	}
	m.backfillMemoryIntelligence(ctx, 1000)
	return m, nil
}

func uuidV4() string {
	var b [16]byte
	if _, err := rand.Read(b[:]); err != nil {
		panic(err)
	}
	b[6] = b[6]&0x0f | 0x40
	b[8] = b[8]&0x3f | 0x80
	return fmt.Sprintf("%x-%x-%x-%x-%x", b[0:4], b[4:6], b[6:8], b[8:10], b[10:])
}

func (m *Manager) ensureDirs() error {
	if m.dataDir == "" {
		return nil
	}
	for _, dir := range []string{m.dataDir, filepath.Join(m.dataDir, "users"), filepath.Join(m.dataDir, "daily"), filepath.Join(m.dataDir, "memory"), filepath.Join(m.dataDir, "skills")} {
		if err := os.MkdirAll(dir, 0o700); err != nil {
			return err
		}
	}
	shared := filepath.Join(m.dataDir, "API_KEYS.json")
	if _, err := os.Stat(shared); os.IsNotExist(err) {
		return os.WriteFile(shared, []byte("{}"), 0o600)
	}
	return nil
}

// agentID resolves the agent a call is about: an id or slug of one of the
// user's agents, or else the user's default agent.
func (m *Manager) agentID(ctx context.Context, userID int64, candidate string) (string, error) {
	return m.agents.Resolve(ctx, userID, candidate)
}

func (m *Manager) nowISO() string { return jsx.ISO(m.clock()) }

func (m *Manager) nowMS() int64 { return m.clock().UnixMilli() }

// Categories are the memory categories, including the legacy names.
var Categories = []string{
	"identity", "preferences", "projects", "contacts", "events", "tasks", "episodic",
	"procedural", "assistant_self", "user_fact", "preference", "personality",
}

var categoryAliases = map[string]string{
	"user_fact": "identity", "preference": "preferences", "personality": "assistant_self",
}

func isCategory(value string) bool {
	for _, c := range Categories {
		if c == value {
			return true
		}
	}
	return false
}

// NormalizeMemoryCategory maps a category or legacy alias onto a current
// category; anything unknown is episodic.
func NormalizeMemoryCategory(value string) string {
	normalized := jsx.Lower(jsx.Trim(value))
	if alias, ok := categoryAliases[normalized]; ok {
		return alias
	}
	if isCategory(normalized) {
		return normalized
	}
	return "episodic"
}

// ScopeInput is a scope as a caller wrote it.
type ScopeInput struct {
	Type string
	ID   string
}

// MemoryScope is where a memory applies.
type MemoryScope struct {
	Type string
	ID   *string
}

func normalizeScope(input *ScopeInput, fallbackAgentID string) MemoryScope {
	if input != nil {
		scopeType := jsx.Lower(jsx.Trim(input.Type))
		if scopeType == "" {
			scopeType = "agent"
		}
		id := jsx.Trim(input.ID)
		switch scopeType {
		case "conversation", "task", "channel", "shared":
			s := MemoryScope{Type: scopeType}
			if id != "" {
				s.ID = &id
			}
			return s
		}
	}
	s := MemoryScope{Type: "agent"}
	if fallbackAgentID != "" {
		s.ID = &fallbackAgentID
	}
	return s
}

// SourceRef says where a memory came from.
type SourceRef struct {
	Type  *string `json:"sourceType"`
	ID    *string `json:"sourceId"`
	Label *string `json:"sourceLabel"`
}

// NewSourceRef is normalizeSourceRef: values are trimmed, cut and nulled when empty.
func NewSourceRef(sourceType, sourceID, sourceLabel string) SourceRef {
	cut := func(s string, n int) *string {
		s = jsx.Head(jsx.Trim(s), n)
		if s == "" {
			return nil
		}
		return &s
	}
	return SourceRef{Type: cut(sourceType, 48), ID: cut(sourceID, 128), Label: cut(sourceLabel, 160)}
}

func (s SourceRef) typeValue() string {
	if s.Type == nil {
		return ""
	}
	return *s.Type
}

func (s SourceRef) args() (any, any, any) { return strPtr(s.Type), strPtr(s.ID), strPtr(s.Label) }

func strPtr(p *string) any {
	if p == nil {
		return nil
	}
	return *p
}

func nullableString(n sql.NullString) *string {
	if !n.Valid {
		return nil
	}
	return &n.String
}

func nonEmptyPtr(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

// normalizeStringArray trims, cuts and de-duplicates strings, keeping order.
func normalizeStringArray(items []string, maxItems, maxLength int) []string {
	seen := map[string]bool{}
	out := []string{}
	for _, item := range items {
		item = jsx.Head(jsx.Trim(item), maxLength)
		if item == "" || seen[item] {
			continue
		}
		seen[item] = true
		out = append(out, item)
	}
	if len(out) > maxItems {
		out = out[:maxItems]
	}
	return out
}

func anyStrings(items []any) []string {
	out := make([]string, len(items))
	for i, item := range items {
		out[i] = jsx.StrOr(item)
	}
	return out
}

func parseStringList(text string, maxItems, maxLength int) []string {
	return normalizeStringArray(anyStrings(jsx.ParseArray(text)), maxItems, maxLength)
}

// orderedSet is a set that remembers insertion order, like a JavaScript Set.
type orderedSet struct {
	items []string
	seen  map[string]bool
}

func newOrderedSet() *orderedSet { return &orderedSet{seen: map[string]bool{}} }

func (s *orderedSet) add(items ...string) {
	for _, item := range items {
		if !s.seen[item] {
			s.seen[item] = true
			s.items = append(s.items, item)
		}
	}
}

func (s *orderedSet) has(item string) bool { return s.seen[item] }

func uniqueStrings(items []string) []string {
	s := newOrderedSet()
	s.add(items...)
	return s.items
}

func itoa(n int64) string { return strconv.FormatInt(n, 10) }
