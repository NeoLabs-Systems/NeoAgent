package memory

import (
	"context"
	"database/sql"
	"errors"
	"log/slog"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/memory/jsx"
)

// Integrations is what ingestion needs from the integrations domain. Both
// methods may answer "nothing" when no integration is wired.
type Integrations interface {
	// SweepProvider returns the collector that reads a provider's past mail, or
	// false when the provider has none.
	SweepProvider(providerKey string) (SweepProvider, bool)
	// SaveRefreshedCredentials stores credentials a collector refreshed.
	SaveRefreshedCredentials(conn Connection, credentials any)
}

// SweepProvider reads the past mail of a connected account.
type SweepProvider interface {
	CollectMemorySweep(ctx context.Context, req SweepRequest) (SweepResult, error)
}

// Connection is a row of integration_connections as ingestion reads it.
type Connection struct {
	ID           int64
	UserID       int64
	AgentID      string
	ProviderKey  string
	AppKey       string
	Status       string
	AccountEmail string
	MetadataJSON string
}

// SweepRequest asks a provider for the documents of a connection.
type SweepRequest struct {
	Connection    Connection
	SourceTypes   []string
	SkipObjectIDs map[string]bool
	// OnProgress reports how many documents were read; total is nil while unknown.
	OnProgress func(done int, total *int)
}

// SweepResult is what a collector read: raw documents (JSON values), refreshed
// credentials and a cursor.
type SweepResult struct {
	Documents   []any
	Credentials any
	Cursor      any
}

// Owner is the account owner a source belongs to.
type Owner struct {
	Name  string
	Email string
}

// ExtractRequest asks the model for the facts in documents.
type ExtractRequest struct {
	Documents  []Document
	Owner      Owner
	Metadata   *jsx.Obj
	OnProgress func(done, total int)
}

// ExtractFunc reads documents and saves the durable facts it finds as memories
// (agent_engine.extractDocumentFacts), returning the ids of the memories.
type ExtractFunc func(ctx context.Context, userID int64, agentID string, req ExtractRequest) (memoryIDs []string, err error)

// Emitter sends a realtime event to one user.
type Emitter interface {
	EmitToUser(userID int64, event string, payload any)
}

// IngestionConfig wires an IngestionService.
type IngestionConfig struct {
	Memory       *Manager
	Integrations Integrations
	// Extract learns facts from documents; nil stores the documents only.
	Extract ExtractFunc
	Emitter Emitter
	Log     *slog.Logger
}

const sweepProgressInterval = 400 * time.Millisecond

// IngestionService stores source documents and learns durable facts from them.
// Integrations reach memory once: a sweep of past mail when an account is
// connected. Nothing polls connected accounts afterwards.
type IngestionService struct {
	mm      *Manager
	integ   Integrations
	extract ExtractFunc
	emitter Emitter
	log     *slog.Logger
	rootCtx context.Context
	cancel  context.CancelFunc

	mu        sync.Mutex
	progress  map[int64]*jsx.Obj
	emittedAt map[int64]time.Time
	active    map[string]*sweepCall
	state     string
	lastError *string
}

type sweepCall struct {
	done   chan struct{}
	result SweepOutcome
}

// SweepOutcome is how a sweep ended.
type SweepOutcome struct {
	ConnectionID int64
	Status       string
	Error        string
	Result       *IngestResult
}

// NewIngestionService builds the service.
func NewIngestionService(cfg IngestionConfig) *IngestionService {
	ctx, cancel := context.WithCancel(context.Background())
	s := &IngestionService{
		mm: cfg.Memory, integ: cfg.Integrations, extract: cfg.Extract, emitter: cfg.Emitter, log: cfg.Log,
		rootCtx: ctx, cancel: cancel,
		progress: map[int64]*jsx.Obj{}, emittedAt: map[int64]time.Time{}, active: map[string]*sweepCall{},
		state: "running",
	}
	if s.log == nil {
		s.log = slog.New(slog.DiscardHandler)
	}
	return s
}

// SetExtractor sets the fact extraction once the AI engine exists.
func (s *IngestionService) SetExtractor(f ExtractFunc) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.extract = f
}

// ServiceStatus is the state of the service for the status endpoint.
type ServiceStatus struct {
	State            string  `json:"state"`
	ActiveSweepCount int     `json:"activeSweepCount"`
	LastError        *string `json:"lastError"`
}

// Status reports whether the service runs and how many sweeps are active.
func (s *IngestionService) Status() ServiceStatus {
	s.mu.Lock()
	defer s.mu.Unlock()
	return ServiceStatus{State: s.state, ActiveSweepCount: len(s.active), LastError: s.lastError}
}

// Stop cancels the running sweeps and waits for them to end.
func (s *IngestionService) Stop() ServiceStatus {
	s.mu.Lock()
	s.state = "stopping"
	var calls []*sweepCall
	for _, c := range s.active {
		calls = append(calls, c)
	}
	s.mu.Unlock()
	s.cancel()
	for _, c := range calls {
		<-c.done
	}
	s.mu.Lock()
	s.state = "stopped"
	s.mu.Unlock()
	return s.Status()
}

func (s *IngestionService) stopping() bool { return s.rootCtx.Err() != nil }

// IngestResult is the outcome of ingesting documents.
type IngestResult struct {
	JobID          string          `json:"jobId"`
	Status         string          `json:"status"`
	DocumentIDs    []string        `json:"documentIds"`
	MemoryIDs      []string        `json:"memoryIds"`
	KnowledgeViews []KnowledgeView `json:"knowledgeViews"`
}

// IngestOptions describe a batch of documents.
type IngestOptions struct {
	AgentID       string
	SourceType    string
	ProviderKey   string
	ConnectionID  any
	SourceAccount string
	Owner         *Owner
	Metadata      *jsx.Obj
	OnProgress    func(done, total int)
}

func isAborted(err error, ctx context.Context) bool {
	return errors.Is(err, context.Canceled) || ctx.Err() != nil
}

// IngestDocuments stores documents as source material and learns durable facts
// from them. The documents themselves never become memories. Each document is
// a decoded JSON value.
func (s *IngestionService) IngestDocuments(ctx context.Context, userID int64, documents []any, o IngestOptions) (IngestResult, error) {
	ctx, stop := linkedContext(ctx, s.rootCtx)
	defer stop()
	if err := ctx.Err(); err != nil {
		return IngestResult{}, errors.New("Memory ingestion aborted.")
	}
	agentID, err := s.mm.agentID(ctx, userID, o.AgentID)
	if err != nil {
		return IngestResult{}, err
	}
	defaults := DocumentDefaults{SourceType: o.SourceType, ProviderKey: o.ProviderKey, ConnectionID: o.ConnectionID, SourceAccount: o.SourceAccount}
	normalized := make([]Document, 0, len(documents))
	for _, raw := range documents {
		doc, err := NormalizeDocument(raw, defaults)
		if err != nil {
			return IngestResult{}, err
		}
		normalized = append(normalized, doc)
	}
	first := ""
	if len(normalized) > 0 {
		first = normalized[0].SourceType
	}
	sourceType := NormalizeSourceType(orLabel(o.SourceType, first))
	connectionID := int64(0)
	if n := jsx.ToNumber(o.ConnectionID); isInteger(n) {
		connectionID = int64(n)
	}
	providerKey := safeTrim(o.ProviderKey, 80)
	metadata := objOrEmpty(o.Metadata)

	jobID, err := s.mm.RecordIngestionJob(ctx, userID, agentID, JobRecord{
		SourceType: sourceType, ProviderKey: providerKey, ConnectionID: connectionID,
		Status: "running", Metadata: metadata,
	})
	if err != nil {
		return IngestResult{}, err
	}

	documentIDs := []string{}
	record := func(status string, summary *jsx.Obj, count int, errText string) error {
		_, err := s.mm.RecordIngestionJob(context.WithoutCancel(ctx), userID, agentID, JobRecord{
			ID: jobID, SourceType: sourceType, ProviderKey: providerKey, ConnectionID: connectionID, Status: status,
			Summary: summary, Metadata: metadata, DocumentCount: count, Error: errText,
			CompletedAt: jsx.ISO(s.mm.clock()),
		})
		return err
	}
	fail := func(err error) (IngestResult, error) {
		if isAborted(err, ctx) {
			_ = record("cancelled", nil, len(documentIDs), "")
		} else {
			_ = record("failed", nil, len(documentIDs), err.Error())
		}
		return IngestResult{}, err
	}

	for _, doc := range normalized {
		if err := ctx.Err(); err != nil {
			return fail(errors.New("Memory ingestion aborted."))
		}
		id, err := s.mm.UpsertIngestionDocument(ctx, userID, agentID, doc)
		if err != nil {
			return fail(err)
		}
		documentIDs = append(documentIDs, id)
	}

	memoryIDs := []string{}
	s.mu.Lock()
	extract := s.extract
	s.mu.Unlock()
	if extract != nil {
		owner := Owner{Email: o.SourceAccount}
		if o.Owner != nil {
			owner = *o.Owner
		}
		ids, err := extract(ctx, userID, agentID, ExtractRequest{
			Documents: normalized, Owner: owner, Metadata: jsx.O("ingestionJobId", jobID), OnProgress: o.OnProgress,
		})
		if err != nil {
			return fail(err)
		}
		if ids != nil {
			memoryIDs = ids
		}
	}

	if err := ctx.Err(); err != nil {
		return fail(errors.New("Memory ingestion aborted."))
	}
	if err := record("completed", jsx.O("documentIds", documentIDs, "memoryIds", memoryIDs), len(documentIDs), ""); err != nil {
		return fail(err)
	}
	views, err := s.mm.MaterializeKnowledgeViews(ctx, userID, agentID)
	if err != nil {
		return fail(err)
	}
	return IngestResult{JobID: jobID, Status: "completed", DocumentIDs: documentIDs, MemoryIDs: memoryIDs, KnowledgeViews: views}, nil
}

// linkedContext is cancelled when either context is.
func linkedContext(a, b context.Context) (context.Context, func()) {
	ctx, cancel := context.WithCancelCause(a)
	stop := context.AfterFunc(b, func() { cancel(context.Cause(b)) })
	return ctx, func() { stop(); cancel(nil) }
}

// SweepProgress is the live or last sweep state of a connection, or nil.
func (s *IngestionService) SweepProgress(connectionID int64) *jsx.Obj {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.progress[connectionID]
}

func (s *IngestionService) reportSweep(conn Connection, patch *jsx.Obj, force bool) {
	s.mu.Lock()
	progress := s.progress[conn.ID].Clone().Assign(patch)
	progress.Set("updatedAt", jsx.ISO(time.Now()))
	s.progress[conn.ID] = progress
	now := time.Now()
	if !force && now.Sub(s.emittedAt[conn.ID]) < sweepProgressInterval {
		s.mu.Unlock()
		return
	}
	s.emittedAt[conn.ID] = now
	payload := jsx.O("connectionId", conn.ID, "providerKey", conn.ProviderKey, "appKey", conn.AppKey).Assign(progress)
	s.mu.Unlock()
	if s.emitter != nil {
		s.emitter.EmitToUser(conn.UserID, "memory:sweep_progress", payload)
	}
}

// HandleConnected runs the one-time sweep of past mail when the user left it
// switched on.
func (s *IngestionService) HandleConnected(conn Connection, memorySweep bool) {
	if !memorySweep || s.stopping() {
		return
	}
	s.SweepConnection(conn, false)
}

// SweepApp sweeps every connected account of one app again on request,
// importing only threads that are not in memory yet. The sweeps run in the
// background; it returns the ids of the connections it started.
func (s *IngestionService) SweepApp(ctx context.Context, userID int64, agentID, providerKey, appKey string) ([]int64, error) {
	if s.stopping() {
		return []int64{}, nil
	}
	connections, err := s.connections(ctx, `SELECT id, user_id, agent_id, provider_key, app_key, status, account_email, metadata_json
       FROM integration_connections
       WHERE user_id = ? AND agent_id = ? AND provider_key = ? AND app_key = ? AND status = 'connected'`,
		userID, agentID, providerKey, appKey)
	if err != nil {
		return nil, err
	}
	ids := make([]int64, len(connections))
	for i, c := range connections {
		ids[i] = c.ID
		go s.SweepConnection(c, true)
	}
	return ids, nil
}

func (s *IngestionService) connections(ctx context.Context, query string, args ...any) ([]Connection, error) {
	return collect(ctx, s.mm.db.R, func(r rowScanner) (Connection, error) {
		var c Connection
		var agent, status, email, meta sql.NullString
		err := r.Scan(&c.ID, &c.UserID, &agent, &c.ProviderKey, &c.AppKey, &status, &email, &meta)
		c.AgentID, c.Status, c.AccountEmail, c.MetadataJSON = agent.String, status.String, email.String, meta.String
		return c, err
	}, query, args...)
}

// SweepConnection reads the past mail of one connection into memory and waits
// for it. A sweep already running for the connection is joined, not repeated.
func (s *IngestionService) SweepConnection(conn Connection, repeat bool) SweepOutcome {
	key := "sweep:" + itoa(conn.UserID) + ":" + itoa(conn.ID)
	s.mu.Lock()
	if active, ok := s.active[key]; ok {
		s.mu.Unlock()
		<-active.done
		return active.result
	}
	call := &sweepCall{done: make(chan struct{})}
	s.active[key] = call
	s.mu.Unlock()

	call.result = s.sweep(conn, repeat)
	s.mu.Lock()
	delete(s.active, key)
	s.mu.Unlock()
	close(call.done)
	return call.result
}

func (s *IngestionService) sweep(conn Connection, repeat bool) SweepOutcome {
	outcome, err := s.sweepConnection(conn, repeat)
	if err == nil {
		return outcome
	}
	if isAborted(err, s.rootCtx) && s.stopping() {
		s.mu.Lock()
		delete(s.progress, conn.ID)
		s.mu.Unlock()
		return SweepOutcome{ConnectionID: conn.ID, Status: "cancelled"}
	}
	message := err.Error()
	s.mu.Lock()
	s.lastError = &message
	s.mu.Unlock()
	s.reportSweep(conn, jsx.O("state", "failed", "error", message, "finishedAt", jsx.ISO(time.Now())), true)
	s.log.Warn("memory ingestion: sweep failed", "connection", conn.ID, "error", message)
	return SweepOutcome{ConnectionID: conn.ID, Status: "failed", Error: message}
}

func (s *IngestionService) sweepConnection(conn Connection, repeat bool) (SweepOutcome, error) {
	ctx := s.rootCtx
	sourceTypes := SourceTypesForConnection(conn.ProviderKey, conn.AppKey)
	var provider SweepProvider
	if s.integ != nil {
		provider, _ = s.integ.SweepProvider(conn.ProviderKey)
	}
	if !contains(sourceTypes, "email") || provider == nil {
		return SweepOutcome{ConnectionID: conn.ID, Status: "not_supported"}, nil
	}
	agentID := conn.AgentID
	if agentID == "" {
		var err error
		if agentID, err = s.mm.agentID(ctx, conn.UserID, ""); err != nil {
			return SweepOutcome{}, err
		}
	}
	if !repeat {
		jobs, err := s.mm.ListIngestionJobs(ctx, conn.UserID, JobFilter{AgentID: agentID, ProviderKey: conn.ProviderKey, Limit: 100})
		if err != nil {
			return SweepOutcome{}, err
		}
		for _, job := range jobs {
			if job.ConnectionID != nil && *job.ConnectionID == conn.ID && job.Status == "completed" && job.Metadata.Value("mode") == "sweep" {
				return SweepOutcome{ConnectionID: conn.ID, Status: "already_swept"}, nil
			}
		}
	}

	startedAt := jsx.ISO(s.mm.clock())
	s.mu.Lock()
	delete(s.progress, conn.ID)
	s.mu.Unlock()
	s.reportSweep(conn, jsx.O("state", "running", "phase", "reading", "done", 0, "total", nil, "imported", 0,
		"learned", 0, "startedAt", startedAt, "finishedAt", nil, "error", nil), true)
	skip, err := s.mm.ListIngestedObjectIDs(ctx, conn.UserID, conn.ID, agentID)
	if err != nil {
		return SweepOutcome{}, err
	}
	collected, err := provider.CollectMemorySweep(ctx, SweepRequest{
		Connection: conn, SourceTypes: sourceTypes, SkipObjectIDs: skip,
		OnProgress: func(done int, total *int) {
			var t any
			if total != nil {
				t = *total
			}
			s.reportSweep(conn, jsx.O("done", done, "total", t), false)
		},
	})
	if err != nil {
		return SweepOutcome{}, err
	}
	if collected.Credentials != nil && s.integ != nil {
		s.integ.SaveRefreshedCredentials(conn, collected.Credentials)
	}
	s.reportSweep(conn, jsx.O("phase", "learning", "done", 0, "total", len(collected.Documents)), true)
	connectionMeta := jsx.ParseObject(conn.MetadataJSON)
	var cursor any
	if jsx.Truthy(collected.Cursor) {
		cursor = collected.Cursor
	}
	owner := Owner{Email: conn.AccountEmail, Name: jsString(connectionMeta.Value("displayName"))}
	result, err := s.IngestDocuments(ctx, conn.UserID, collected.Documents, IngestOptions{
		AgentID: agentID, SourceType: "email", ProviderKey: conn.ProviderKey, ConnectionID: conn.ID,
		SourceAccount: conn.AccountEmail, Owner: &owner,
		Metadata:   jsx.O("appKey", conn.AppKey, "sourceTypes", sourceTypes, "mode", "sweep", "cursor", cursor),
		OnProgress: func(done, total int) { s.reportSweep(conn, jsx.O("done", done, "total", total), false) },
	})
	if err != nil {
		return SweepOutcome{}, err
	}
	learned, err := s.mm.CountMemoriesCreatedSince(ctx, result.MemoryIDs, startedAt)
	if err != nil {
		return SweepOutcome{}, err
	}
	s.reportSweep(conn, jsx.O("state", "completed", "imported", len(collected.Documents), "learned", learned,
		"finishedAt", jsx.ISO(time.Now())), true)
	return SweepOutcome{ConnectionID: conn.ID, Status: "completed", Result: &result}, nil
}
