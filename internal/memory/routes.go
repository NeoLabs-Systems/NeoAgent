package memory

import (
	"bytes"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"math"
	"net/http"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/agentscope"
	"github.com/NeoLabs-Systems/neoagent/internal/memory/jsx"
	"github.com/NeoLabs-Systems/neolabs-go/httpx"
	"github.com/NeoLabs-Systems/neolabs-go/ratelimit"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
)

const (
	bodyLimit            = 10 << 20
	maxTransferTextBytes = 60 * 1024
)

// APIConfig wires the /api/memory routes.
type APIConfig struct {
	Memory *Manager
	// Ingestion is nil when the ingestion service is unavailable.
	Ingestion  *IngestionService
	Log        *slog.Logger
	TrustProxy bool
	// UserID returns the signed-in account of a request. Nil reads "userId"
	// from the session.
	UserID func(*http.Request) (int64, bool)
}

// API serves the /api/memory routes.
type API struct {
	mm        *Manager
	ingestion *IngestionService
	log       *slog.Logger
	userID    func(*http.Request) (int64, bool)

	apiKeyLimit *ratelimit.Limiter
	importLimit *ratelimit.Limiter
	searchLimit *ratelimit.Limiter
}

// NewAPI builds the routes.
func NewAPI(cfg APIConfig) *API {
	userID := cfg.UserID
	if userID == nil {
		userID = sessionUserID
	}
	log := cfg.Log
	if log == nil {
		log = slog.New(slog.DiscardHandler)
	}
	limiter := func(window time.Duration, max int, message string) *ratelimit.Limiter {
		return ratelimit.New(ratelimit.Config{
			Window: window, Max: max, Message: map[string]string{"error": message},
			Key: func(r *http.Request) string { return httpx.ClientIP(r, cfg.TrustProxy) },
		})
	}
	return &API{
		mm: cfg.Memory, ingestion: cfg.Ingestion, log: log, userID: userID,
		apiKeyLimit: limiter(15*time.Minute, 60, "Too many API key update attempts, try again later"),
		importLimit: limiter(10*time.Minute, 20, "Too many memory imports, try again later"),
		searchLimit: limiter(time.Minute, 60, "Too many memory search requests, try again later"),
	}
}

func sessionUserID(r *http.Request) (int64, bool) {
	sess := sessionx.FromContext(r.Context())
	if sess == nil {
		return 0, false
	}
	return sess.Int64("userId")
}

// request is what a route needs: the account, the agent the request is about
// and the JSON body. body is nil when the request carried none, as req.body is
// undefined in Express then.
type request struct {
	userID  int64
	agentID string
	body    *jsx.Obj
	r       *http.Request
}

type handler func(w http.ResponseWriter, req request)

// Routes registers the memory routes on mux.
func (a *API) Routes(mux *http.ServeMux) {
	route := func(pattern string, fn handler, limiter *ratelimit.Limiter) {
		var h http.Handler = a.scoped(fn)
		if limiter != nil {
			h = limiter.Middleware(h)
		}
		mux.Handle(pattern, a.guard(h))
	}
	route("GET /api/memory/{$}", a.overview, nil)
	route("GET /api/memory", a.overview, nil)
	route("GET /api/memory/memories", a.listMemories, nil)
	route("GET /api/memory/ingestion/status", a.ingestionStatus, nil)
	route("POST /api/memory/ingestion/sweep", a.ingestionSweep, nil)
	route("POST /api/memory/ingestion/documents", a.ingestionDocuments, nil)
	route("GET /api/memory/knowledge-views", a.knowledgeViews, nil)
	route("GET /api/memory/entities", a.entities, nil)
	route("GET /api/memory/graph", a.graph, nil)
	route("GET /api/memory/entities/{id}/memories", a.entityMemories, nil)
	route("GET /api/memory/facts", a.facts, nil)
	route("POST /api/memory/facts/reconcile", a.reconcileFacts, nil)
	route("POST /api/memory/knowledge-views/materialize", a.materialize, nil)
	route("POST /api/memory/memories", a.saveMemory, nil)
	route("PUT /api/memory/memories/{id}", a.updateMemory, nil)
	route("DELETE /api/memory/memories/{id}", a.deleteMemory, nil)
	route("POST /api/memory/memories/bulk-delete", a.bulkDelete, nil)
	route("POST /api/memory/memories/bulk-archive", a.bulkArchive, nil)
	route("POST /api/memory/memories/recall", a.recall, a.searchLimit)
	route("GET /api/memory/core", a.core, nil)
	route("GET /api/memory/transfer-prompt", a.transferPrompt, nil)
	route("POST /api/memory/transfer-import", a.transferImport, a.importLimit)
	route("PUT /api/memory/core/{key}", a.putCore, nil)
	route("DELETE /api/memory/core/{key}", a.deleteCore, nil)
	route("GET /api/memory/daily", a.dailyLogs, nil)
	route("GET /api/memory/daily/{date}", a.dailyLog, nil)
	route("GET /api/memory/api-keys", a.apiKeys, nil)
	route("PUT /api/memory/api-keys/{service}", a.putAPIKey, a.apiKeyLimit)
	route("DELETE /api/memory/api-keys/{service}", a.deleteAPIKey, a.apiKeyLimit)
	route("GET /api/memory/conversations", a.conversations, nil)
	route("POST /api/memory/conversations/search", a.searchConversations, nil)
}

// guard answers 401 JSON unless the session belongs to an account.
func (a *API) guard(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if _, ok := a.userID(r); !ok {
			httpx.Error(w, 401, "Unauthorized")
			return
		}
		next.ServeHTTP(w, r)
	})
}

// scoped reads the body and resolves the agent before calling fn.
func (a *API) scoped(fn handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		userID, _ := a.userID(r)
		body, top, err := readBody(r)
		if err != nil {
			httpx.Error(w, 400, err.Error())
			return
		}
		agentID, err := a.mm.agentID(r.Context(), userID, agentscope.Candidate(r, top))
		if err != nil {
			a.fail(w, err)
			return
		}
		fn(w, request{userID: userID, agentID: agentID, body: body, r: r})
	})
}

// readBody reads the JSON body of a request like express.json() does: nothing
// unless the request is JSON, and only an object or a list. A list reads as an
// object without members.
func readBody(r *http.Request) (*jsx.Obj, map[string]json.RawMessage, error) {
	if !strings.Contains(strings.ToLower(r.Header.Get("Content-Type")), "json") {
		return nil, nil, nil
	}
	raw, err := io.ReadAll(http.MaxBytesReader(nil, r.Body, bodyLimit))
	if err != nil {
		return nil, nil, errors.New("Request body too large")
	}
	raw = bytes.TrimSpace(raw)
	if len(raw) == 0 {
		return nil, nil, nil
	}
	if raw[0] != '{' && raw[0] != '[' {
		return nil, nil, errors.New("Invalid JSON body")
	}
	value, err := jsx.Parse(string(raw))
	if err != nil {
		return nil, nil, errors.New("Invalid JSON body")
	}
	var top map[string]json.RawMessage
	if raw[0] == '{' {
		_ = json.Unmarshal(raw, &top)
	}
	if obj, ok := value.(*jsx.Obj); ok {
		return obj, top, nil
	}
	return jsx.NewObj(), nil, nil
}

// fail answers an error as the Node error handler does.
func (a *API) fail(w http.ResponseWriter, err error) {
	a.log.Error("memory route failed", "error", err)
	httpx.Error(w, 500, sanitizeError(err))
}

// bodyValue is req.body?.key.
func (r request) bodyValue(key string) any {
	if r.body == nil {
		return jsx.Undefined
	}
	return r.body.Lookup(key)
}

// requireBody is the destructuring of req.body, which throws when it is undefined.
func (a *API) requireBody(w http.ResponseWriter, req request, firstProperty string) bool {
	if req.body != nil {
		return true
	}
	httpx.Error(w, 500, "Cannot destructure property '"+firstProperty+"' of 'req.body' as it is undefined.")
	return false
}

var leadingInt = regexp.MustCompile(`^[\t\n\v\f\r \x{a0}\x{feff}]*([+-]?\d+)`)

// parseInt is parseInt(text, 10); ok is false for NaN.
func parseInt(text string) (int, bool) {
	m := leadingInt.FindStringSubmatch(text)
	if m == nil {
		return 0, false
	}
	n, err := strconv.ParseInt(m[1], 10, 64)
	if err != nil {
		return int(math.MaxInt32), true
	}
	return int(n), true
}

// intOr is `parseInt(text) || fallback`.
func intOr(text string, fallback int) int {
	if n, ok := parseInt(text); ok && n != 0 {
		return n
	}
	return fallback
}

// numberOr is `Number(text) || fallback`, as an integer.
func numberOr(text string, fallback int) int {
	n := jsx.ToNumber(text)
	if !jsx.IsFinite(n) || n == 0 {
		return fallback
	}
	return int(n)
}

func (r request) query(key string) string { return r.r.URL.Query().Get(key) }

// queryLimit is `Number(req.query.limit) || fallback`.
func (r request) queryLimit(fallback int) int { return numberOr(r.query("limit"), fallback) }

func withoutActiveContext(core *jsx.Obj) *jsx.Obj {
	core.Delete("active_context")
	return core
}

func (a *API) overview(w http.ResponseWriter, req request) {
	ctx := req.r.Context()
	mm, uid, agent := a.mm, req.userID, req.agentID
	core, err := mm.CoreMemory(ctx, uid, agent)
	if err != nil {
		a.fail(w, err)
		return
	}
	withoutActiveContext(core)
	views, err := mm.ListKnowledgeViews(ctx, uid, ViewFilter{AgentID: agent, Limit: 12})
	if err != nil {
		a.fail(w, err)
		return
	}
	notes, err := mm.AssistantBehaviorNotes(ctx, uid, agent)
	if err != nil {
		a.fail(w, err)
		return
	}
	self, err := mm.AssistantSelfState(ctx, uid, agent)
	if err != nil {
		a.fail(w, err)
		return
	}
	logs, err := mm.ListDailyLogs(7, uid)
	if err != nil {
		a.fail(w, err)
		return
	}
	keys, err := mm.ReadAPIKeys(uid)
	if err != nil {
		a.fail(w, err)
		return
	}
	stats, err := mm.MemoryStats(ctx, uid, agent)
	if err != nil {
		a.fail(w, err)
		return
	}
	entities, err := mm.ListEntities(ctx, uid, EntityFilter{AgentID: agent, Limit: 12})
	if err != nil {
		a.fail(w, err)
		return
	}
	overview, err := mm.IngestionOverview(ctx, uid, agent, 0)
	if err != nil {
		a.fail(w, err)
		return
	}
	changes, err := mm.ListRecentKnowledgeChanges(ctx, uid, agent, 8)
	if err != nil {
		a.fail(w, err)
		return
	}
	keyNames := append([]string{}, keys.Keys()...)
	httpx.WriteJSON(w, 200, jsx.O(
		"agentId", agent, "assistantBehaviorNotes", notes, "assistantSelfState", self, "dailyLogs", logs,
		"apiKeys", keyNames, "coreMemory", core, "stats", stats, "entities", entities, "knowledgeViews", nonNilSlice(views),
		"ingestionOverview", overview, "recentKnowledgeChanges", changes))
}

func (a *API) listMemories(w http.ResponseWriter, req request) {
	limit, limitOK := 50, true
	if q := req.r.URL.Query(); q.Has("limit") {
		limit, limitOK = parseInt(q.Get("limit"))
	}
	offset, offsetOK := 0, true
	if q := req.r.URL.Query(); q.Has("offset") {
		offset, offsetOK = parseInt(q.Get("offset"))
	}
	if !limitOK || !offsetOK {
		httpx.Error(w, 500, "datatype mismatch")
		return
	}
	memories, err := a.mm.ListMemories(req.r.Context(), req.userID, ListOptions{
		AgentID: req.agentID, Category: req.query("category"), Limit: limit, Offset: offset,
		IncludeArchived: req.query("archived") == "true",
	})
	if err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, 200, nonNilSlice(memories))
}

func nonNilSlice[T any](s []T) []T {
	if s == nil {
		return []T{}
	}
	return s
}

func (a *API) ingestionStatus(w http.ResponseWriter, req request) {
	ctx, uid, agent := req.r.Context(), req.userID, req.agentID
	overview, err := a.mm.IngestionOverview(ctx, uid, agent, 0)
	if err != nil {
		a.fail(w, err)
		return
	}
	jobs, err := a.mm.ListIngestionJobs(ctx, uid, JobFilter{AgentID: agent})
	if err != nil {
		a.fail(w, err)
		return
	}
	changes, err := a.mm.ListRecentKnowledgeChanges(ctx, uid, agent, 0)
	if err != nil {
		a.fail(w, err)
		return
	}
	connections := []ConnectionStatus{}
	var service any = jsx.O("state", "unavailable")
	if a.ingestion != nil {
		if connections, err = a.ingestion.ListConnectionStatuses(ctx, uid, agent); err != nil {
			a.fail(w, err)
			return
		}
		service = a.ingestion.Status()
	}
	httpx.WriteJSON(w, 200, jsx.O("agentId", agent, "overview", overview, "jobs", nonNilSlice(jobs),
		"recentChanges", changes, "connections", nonNilSlice(connections), "service", service))
}

func (a *API) ingestionSweep(w http.ResponseWriter, req request) {
	if a.ingestion == nil {
		httpx.Error(w, 503, "Memory ingestion service is unavailable.")
		return
	}
	providerKey := jsx.Trim(jsx.StrOr(req.bodyValue("providerKey")))
	appKey := jsx.Trim(jsx.StrOr(req.bodyValue("appId")))
	if providerKey == "" || appKey == "" {
		httpx.Error(w, 400, "providerKey and appId are required.")
		return
	}
	ids, err := a.ingestion.SweepApp(req.r.Context(), req.userID, req.agentID, providerKey, appKey)
	if err != nil {
		a.fail(w, err)
		return
	}
	if len(ids) == 0 {
		httpx.Error(w, 404, "No connected account to import from.")
		return
	}
	httpx.WriteJSON(w, 202, jsx.O("started", true, "connectionIds", ids))
}

func (a *API) ingestionDocuments(w http.ResponseWriter, req request) {
	if a.ingestion == nil {
		httpx.Error(w, 503, "Memory ingestion service is unavailable.")
		return
	}
	documents, _ := req.bodyValue("documents").([]any)
	if len(documents) == 0 {
		httpx.Error(w, 400, "documents must contain at least one item.")
		return
	}
	metadata, err := normalizeMetadata(req.bodyValue("metadata"))
	if err != nil {
		httpx.Error(w, 400, sanitizeError(err))
		return
	}
	result, err := a.ingestion.IngestDocuments(req.r.Context(), req.userID, documents, IngestOptions{
		AgentID:       req.agentID,
		SourceType:    jsx.StrOr(req.bodyValue("sourceType")),
		ProviderKey:   jsx.StrOr(req.bodyValue("providerKey")),
		ConnectionID:  req.bodyValue("connectionId"),
		SourceAccount: jsx.StrOr(req.bodyValue("sourceAccount")),
		Metadata:      metadata,
	})
	if err != nil {
		httpx.Error(w, 400, sanitizeError(err))
		return
	}
	httpx.WriteJSON(w, 200, result)
}

func (a *API) knowledgeViews(w http.ResponseWriter, req request) {
	views, err := a.mm.ListKnowledgeViews(req.r.Context(), req.userID, ViewFilter{
		AgentID: req.agentID, ViewType: req.query("viewType"), Limit: req.queryLimit(40)})
	if err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, 200, nonNilSlice(views))
}

func (a *API) entities(w http.ResponseWriter, req request) {
	entities, err := a.mm.ListEntities(req.r.Context(), req.userID, EntityFilter{
		AgentID: req.agentID, Query: req.query("query"), Limit: req.queryLimit(24)})
	if err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, 200, nonNilSlice(entities))
}

func (a *API) graph(w http.ResponseWriter, req request) {
	// The graph asks for 60 nodes unless the client names a limit, even a
	// malformed one, which the entity list then reads as its own default.
	limit := 60
	if req.r.URL.Query().Has("limit") {
		limit = req.queryLimit(24)
	}
	graph, err := a.mm.EntityGraphOf(req.r.Context(), req.userID, req.agentID, limit)
	if err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, 200, graph)
}

func (a *API) entityMemories(w http.ResponseWriter, req request) {
	memories, err := a.mm.ListEntityMemories(req.r.Context(), req.userID, req.r.PathValue("id"), req.agentID, req.queryLimit(40))
	if err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, 200, nonNilSlice(memories))
}

func (a *API) facts(w http.ResponseWriter, req request) {
	facts, err := a.mm.ListFacts(req.r.Context(), req.userID, FactFilter{
		AgentID: req.agentID, Status: req.query("status"), Subject: req.query("subject"),
		Predicate: req.query("predicate"), ValidAt: req.query("validAt"), KnownAt: req.query("knownAt"),
		Limit: req.queryLimit(100)})
	if err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, 200, nonNilSlice(facts))
}

func (a *API) reconcileFacts(w http.ResponseWriter, req request) {
	minimum := jsx.ToNumber(jsx.Coalesce(req.bodyValue("minimumConfidence"), defaultMinimumFactConfidence))
	result, err := a.mm.ReconcileFacts(req.r.Context(), req.userID, req.agentID, minimum)
	if err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, 200, result)
}

func (a *API) materialize(w http.ResponseWriter, req request) {
	views, err := a.mm.MaterializeKnowledgeViews(req.r.Context(), req.userID, req.agentID)
	if err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, 200, jsx.O("agentId", req.agentID, "views", nonNilSlice(views)))
}

// plainObject is parsePlainObject: nil for null, a parsed JSON object for text.
func plainObject(input any, field string) (*jsx.Obj, error) {
	if jsx.Nullish(input) {
		return nil, nil
	}
	if text, ok := input.(string); ok {
		v, err := jsx.Parse(text)
		if err != nil {
			return nil, errors.New(field + " must be valid JSON.")
		}
		input = v
	}
	obj, ok := input.(*jsx.Obj)
	if !ok || obj == nil {
		return nil, errors.New(field + " must be an object.")
	}
	return obj, nil
}

func normalizeMetadata(input any) (*jsx.Obj, error) { return plainObject(input, "metadata") }

var (
	sourceTypePattern = regexp.MustCompile(`(?i)^[a-z0-9_:-]+$`)
	scopeTypePattern  = regexp.MustCompile(`(?i)^(agent|conversation|task|channel|shared)$`)
)

// optionalStringField is normalizeOptionalStringField: "" for none.
func optionalStringField(value any, field string, maxLength int, pattern *regexp.Regexp) (string, error) {
	if jsx.Nullish(value) || value == "" {
		return "", nil
	}
	s, ok := value.(string)
	if !ok {
		return "", errors.New(field + " must be a string.")
	}
	normalized := jsx.Head(jsx.Trim(s), maxLength)
	if normalized == "" {
		return "", nil
	}
	if pattern != nil && !pattern.MatchString(normalized) {
		return "", errors.New(field + " has an invalid format.")
	}
	return normalized, nil
}

func normalizeSourceRefInput(input any) (SourceRef, error) {
	raw, err := plainObject(input, "sourceRef")
	if err != nil || raw == nil {
		return SourceRef{}, err
	}
	sourceType, err := optionalStringField(jsx.Coalesce(raw.Lookup("sourceType"), raw.Lookup("type")), "sourceRef.sourceType", 48, sourceTypePattern)
	if err != nil {
		return SourceRef{}, err
	}
	sourceID, err := optionalStringField(jsx.Coalesce(raw.Lookup("sourceId"), raw.Lookup("id")), "sourceRef.sourceId", 128, nil)
	if err != nil {
		return SourceRef{}, err
	}
	label, err := optionalStringField(jsx.Coalesce(raw.Lookup("sourceLabel"), raw.Lookup("label")), "sourceRef.sourceLabel", 160, nil)
	if err != nil {
		return SourceRef{}, err
	}
	return NewSourceRef(sourceType, sourceID, label), nil
}

func normalizeScopeInput(input any) (*ScopeInput, error) {
	raw, err := plainObject(input, "scope")
	if err != nil || raw == nil {
		return nil, err
	}
	scopeType, err := optionalStringField(jsx.Coalesce(raw.Lookup("scopeType"), raw.Lookup("type")), "scope.scopeType", 32, scopeTypePattern)
	if err != nil {
		return nil, err
	}
	scopeID, err := optionalStringField(jsx.Coalesce(raw.Lookup("scopeId"), raw.Lookup("id")), "scope.scopeId", 128, nil)
	if err != nil {
		return nil, err
	}
	return &ScopeInput{Type: jsx.Lower(scopeType), ID: scopeID}, nil
}

var inputError = regexp.MustCompile(`(?i)must be valid JSON|must be an object|must be a string|has an invalid format`)

func memoryTooLong() string {
	return "A memory can be at most " + strconv.Itoa(MaxMemoryChars) + " characters."
}

func (a *API) saveMemory(w http.ResponseWriter, req request) {
	if !a.requireBody(w, req, "content") {
		return
	}
	content := req.bodyValue("content")
	if !jsx.Truthy(content) {
		httpx.Error(w, 400, "content is required")
		return
	}
	text, isString := content.(string)
	if !isString {
		httpx.Error(w, 500, "content.trim is not a function")
		return
	}
	if jsx.Trim(text) == "" {
		httpx.Error(w, 400, "content is required")
		return
	}
	if jsx.Len(jsx.Trim(text)) > MaxMemoryChars {
		httpx.Error(w, 400, memoryTooLong())
		return
	}

	category := req.bodyValue("category")
	if category == jsx.Undefined {
		category = "episodic"
	}
	importance := req.bodyValue("importance")
	if importance == jsx.Undefined {
		importance = float64(5)
	}

	fail := func(err error) {
		message := sanitizeError(err)
		if inputError.MatchString(message) {
			httpx.Error(w, 400, message)
			return
		}
		httpx.Error(w, 500, message)
	}
	var staleAfterDays *float64
	if stale := req.bodyValue("staleAfterDays"); !jsx.Nullish(stale) && stale != "" {
		n, ok := parseInt(jsx.ToString(stale))
		if !ok || n <= 0 {
			httpx.Error(w, 400, "staleAfterDays must be a positive integer.")
			return
		}
		f := float64(n)
		staleAfterDays = &f
	}
	sourceRef, err := normalizeSourceRefInput(req.bodyValue("sourceRef"))
	if err != nil {
		fail(err)
		return
	}
	scope, err := normalizeScopeInput(req.bodyValue("scope"))
	if err != nil {
		fail(err)
		return
	}
	metadata, err := normalizeMetadata(req.bodyValue("metadata"))
	if err != nil {
		fail(err)
		return
	}
	// The owner typed or explicitly imported this complete content.
	merged := objOrEmpty(metadata).Clone()
	merged.Set("trustLevel", "user_stated").Set("verification", OwnerVerification(text))

	id, err := a.mm.SaveMemory(req.r.Context(), req.userID, text, jsx.StrOr(category), importanceValue(importance), SaveOptions{
		AgentID: req.agentID, SourceRef: sourceRef, Scope: scope, StaleAfterDays: staleAfterDays, Metadata: merged,
	})
	if err != nil {
		fail(err)
		return
	}
	var out any
	if id != "" {
		out = id
	}
	httpx.WriteJSON(w, 200, jsx.O("success", true, "id", out))
}

// importanceValue is Number(importance); SaveMemory turns 0 and NaN into the default.
func importanceValue(v any) float64 { return jsx.ToNumber(v) }

func (a *API) ownsMemory(w http.ResponseWriter, req request) bool {
	var id string
	found, err := one(req.r.Context(), a.mm.db.R, []any{&id},
		`SELECT id FROM memories WHERE id = ? AND user_id = ? AND agent_id = ?`, req.r.PathValue("id"), req.userID, req.agentID)
	if err != nil {
		a.fail(w, err)
		return false
	}
	if !found {
		httpx.Error(w, 404, "Memory not found")
		return false
	}
	return true
}

func (a *API) updateMemory(w http.ResponseWriter, req request) {
	// Verify ownership before updating.
	if !a.ownsMemory(w, req) || !a.requireBody(w, req, "content") {
		return
	}
	var fields UpdateFields
	if content, ok := req.bodyValue("content").(string); ok {
		if jsx.Len(jsx.Trim(content)) > MaxMemoryChars {
			httpx.Error(w, 400, memoryTooLong())
			return
		}
		fields.Content = &content
	}
	if v := req.bodyValue("importance"); !jsx.Nullish(v) {
		n := jsx.ToNumber(v)
		fields.Importance = &n
	}
	if category, ok := req.bodyValue("category").(string); ok {
		fields.Category = &category
	}
	updated, err := a.mm.UpdateMemory(req.r.Context(), req.r.PathValue("id"), fields)
	if err != nil {
		a.fail(w, err)
		return
	}
	if updated == nil {
		httpx.Error(w, 404, "Memory not found")
		return
	}
	httpx.WriteJSON(w, 200, updated)
}

func (a *API) deleteMemory(w http.ResponseWriter, req request) {
	// Verify ownership before deleting.
	if !a.ownsMemory(w, req) {
		return
	}
	if _, err := a.mm.DeleteMemories(req.r.Context(), []string{req.r.PathValue("id")}, req.userID); err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, 200, map[string]any{"success": true})
}

func (r request) ids() []string {
	list, _ := r.bodyValue("ids").([]any)
	ids := make([]string, len(list))
	for i, item := range list {
		ids[i] = jsx.StrOr(item)
	}
	return ids
}

func (a *API) bulkDelete(w http.ResponseWriter, req request) {
	ids := req.ids()
	if len(ids) == 0 {
		httpx.Error(w, 400, "ids is required")
		return
	}
	owned, err := a.mm.OwnedMemoryIDs(req.r.Context(), req.userID, req.agentID, ids)
	if err != nil {
		a.fail(w, err)
		return
	}
	if len(owned) == 0 {
		httpx.Error(w, 404, "Memory not found")
		return
	}
	deleted, err := a.mm.DeleteMemories(req.r.Context(), owned, req.userID)
	if err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, 200, jsx.O("success", true, "deletedCount", deleted))
}

func (a *API) bulkArchive(w http.ResponseWriter, req request) {
	ids := req.ids()
	archived := req.bodyValue("archived") != false
	if len(ids) == 0 {
		httpx.Error(w, 400, "ids is required")
		return
	}
	owned, err := a.mm.OwnedMemoryIDs(req.r.Context(), req.userID, req.agentID, ids)
	if err != nil {
		a.fail(w, err)
		return
	}
	if len(owned) == 0 {
		httpx.Error(w, 404, "Memory not found")
		return
	}
	count, err := a.mm.ArchiveMemories(req.r.Context(), owned, archived, req.userID)
	if err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, 200, jsx.O("success", true, "archivedCount", count))
}

func (a *API) recall(w http.ResponseWriter, req request) {
	if !a.requireBody(w, req, "query") {
		return
	}
	query := req.bodyValue("query")
	if !jsx.Truthy(query) {
		httpx.Error(w, 400, "query is required")
		return
	}
	limit := req.bodyValue("limit")
	if limit == jsx.Undefined {
		limit = float64(8)
	}
	parsed, ok := parseInt(jsx.ToString(limit))
	if !ok {
		httpx.Error(w, 400, "limit must be an integer between 1 and 100")
		return
	}
	parsed = max(1, min(100, parsed))
	text, isString := query.(string)
	if !isString {
		httpx.Error(w, 500, "query.trim is not a function")
		return
	}
	results, err := a.mm.RecallMemory(req.r.Context(), req.userID, text, parsed, RecallOptions{AgentID: req.agentID})
	if err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, 200, nonNilSlice(results))
}

func (a *API) core(w http.ResponseWriter, req request) {
	core, err := a.mm.CoreMemory(req.r.Context(), req.userID, req.agentID)
	if err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, 200, withoutActiveContext(core))
}

func (a *API) transferPrompt(w http.ResponseWriter, _ request) {
	httpx.WriteJSON(w, 200, map[string]string{"prompt": LLMTransferPrompt("NeoAgent")})
}

func (a *API) transferImport(w http.ResponseWriter, req request) {
	ctx := req.r.Context()
	text := jsx.Trim(jsx.StrOr(req.bodyValue("text")))
	if text == "" {
		httpx.Error(w, 400, "text is required")
		return
	}
	if len(text) > maxTransferTextBytes {
		httpx.Error(w, 413, "text exceeds 60KB limit")
		return
	}
	applyBehaviorNotes := req.bodyValue("applyBehaviorNotes") != false
	applyCoreMemory := req.bodyValue("applyCoreMemory") != false

	parsed := ParseLLMTransferText(text)
	imported, skipped, coreUpdated := 0, 0, 0
	for _, memory := range parsed.Memories {
		content := jsx.Trim(memory.Content)
		if content == "" {
			skipped++
			continue
		}
		// Lines over the memory length limit are skipped, never cut off.
		id, err := a.mm.SaveMemory(ctx, req.userID, content, memory.Category, float64(ImportanceForCategory(memory.Category)), SaveOptions{
			AgentID:   req.agentID,
			SourceRef: NewSourceRef("llm_import", "", "LLM memory transfer"),
			Metadata:  jsx.O("importedFrom", "llm_transfer"),
		})
		if err != nil {
			a.fail(w, err)
			return
		}
		if id != "" {
			imported++
		} else {
			skipped++
		}
	}
	if applyCoreMemory {
		for _, key := range parsed.CoreEntries.Keys() {
			if key == "" || key == "active_context" {
				continue
			}
			if err := a.mm.UpdateCore(ctx, req.userID, req.agentID, key, parsed.CoreEntries.Value(key)); err != nil {
				a.fail(w, err)
				return
			}
			coreUpdated++
		}
	}
	behaviorNotesUpdated := false
	if applyBehaviorNotes && parsed.BehaviorNotes != "" {
		if err := a.mm.SetAssistantBehaviorNotes(ctx, req.userID, req.agentID, parsed.BehaviorNotes); err != nil {
			a.fail(w, err)
			return
		}
		behaviorNotesUpdated = true
	}
	httpx.WriteJSON(w, 200, jsx.O(
		"importedCount", imported, "skippedCount", skipped, "coreUpdatedCount", coreUpdated,
		"behaviorNotesUpdated", behaviorNotesUpdated, "warnings", nonNilSlice(parsed.Warnings)))
}

const activeContextRetired = "active_context is no longer a supported core memory key"

func (a *API) putCore(w http.ResponseWriter, req request) {
	if !a.requireBody(w, req, "value") {
		return
	}
	value := req.bodyValue("value")
	if value == jsx.Undefined {
		httpx.Error(w, 400, "value is required")
		return
	}
	key := req.r.PathValue("key")
	if key == "active_context" {
		httpx.Error(w, 400, activeContextRetired)
		return
	}
	if err := a.mm.UpdateCore(req.r.Context(), req.userID, req.agentID, key, value); err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, 200, map[string]any{"success": true})
}

func (a *API) deleteCore(w http.ResponseWriter, req request) {
	key := req.r.PathValue("key")
	if key == "active_context" {
		httpx.Error(w, 400, activeContextRetired)
		return
	}
	if err := a.mm.DeleteCore(req.r.Context(), req.userID, req.agentID, key); err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, 200, map[string]any{"success": true})
}

func (a *API) dailyLogs(w http.ResponseWriter, req request) {
	logs, err := a.mm.ListDailyLogs(intOr(req.query("limit"), 7), req.userID)
	if err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, 200, logs)
}

func (a *API) dailyLog(w http.ResponseWriter, req request) {
	param := req.r.PathValue("date")
	date, ok := ParseLogDate(param)
	if !ok {
		httpx.Error(w, 500, "Invalid time value")
		return
	}
	content, err := a.mm.ReadDailyLog(date, req.userID)
	if err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, 200, jsx.O("date", param, "content", content))
}

func (a *API) apiKeys(w http.ResponseWriter, req request) {
	keys, err := a.mm.ReadAPIKeys(req.userID)
	if err != nil {
		a.fail(w, err)
		return
	}
	masked := jsx.NewObj()
	for _, service := range keys.Keys() {
		value := jsx.StrOr(keys.Value(service))
		if value == "" {
			masked.Set(service, nil)
			continue
		}
		n := jsx.Len(value)
		masked.Set(service, jsx.Head(value, 4)+"..."+jsx.Slice(value, max(0, n-4), n))
	}
	httpx.WriteJSON(w, 200, masked)
}

func (a *API) putAPIKey(w http.ResponseWriter, req request) {
	if req.body == nil {
		httpx.Error(w, 500, "Cannot read properties of undefined (reading 'key')")
		return
	}
	if err := a.mm.SetAPIKey(req.userID, req.r.PathValue("service"), jsx.StrOr(req.body.Lookup("key"))); err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, 200, map[string]any{"success": true})
}

func (a *API) deleteAPIKey(w http.ResponseWriter, req request) {
	if err := a.mm.DeleteAPIKey(req.userID, req.r.PathValue("service")); err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, 200, map[string]any{"success": true})
}

func (a *API) conversations(w http.ResponseWriter, req request) {
	conversations, err := a.mm.RecentConversations(req.r.Context(), req.userID, req.agentID, intOr(req.query("limit"), 20))
	if err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, 200, nonNilSlice(conversations))
}

func (a *API) searchConversations(w http.ResponseWriter, req request) {
	if req.body == nil {
		httpx.Error(w, 500, "Cannot read properties of undefined (reading 'query')")
		return
	}
	results, err := a.mm.SearchConversations(req.r.Context(), req.userID, jsx.StrOr(req.body.Lookup("query")), SearchConversationsOptions{
		AgentID: req.agentID, Sessions: intOr(jsx.StrOr(req.body.Lookup("limit")), 8),
	})
	if err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, 200, nonNilSlice(results))
}
