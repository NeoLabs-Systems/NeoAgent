// Package agentimport brings OpenClaw or Hermes Agent over to NeoAgent: it
// finds their installations on this computer, reads keys, agents, memories,
// skills, model choice, MCP servers, automations and chat channels, and writes
// what NeoAgent can use into the signed-in admin's account. It serves
// /api/admin/import and ports lib/importers and services/admin/agent_import.js
// of the Node server.
package agentimport

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/apperr"
	"github.com/NeoLabs-Systems/neolabs-go/httpx"
	"github.com/NeoLabs-Systems/neolabs-go/publicerr"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
)

const (
	attentionLimit = 50
	bodyLimit      = 1 << 20
)

// Config wires the import routes.
type Config struct {
	Env     Env
	Scanner Scanner
	Log     *slog.Logger
	// Now is the clock; nil is the system clock.
	Now func() time.Time
}

// API serves the import routes.
type API struct {
	cfg Config
	// running allows one import at a time: a second run while the first writes
	// would find nothing "already there" yet and add everything twice.
	mu      sync.Mutex
	running bool
}

// New builds the API.
func New(cfg Config) *API { return &API{cfg: cfg} }

func (a *API) now() time.Time {
	if a.cfg.Now != nil {
		return a.cfg.Now()
	}
	return time.Now()
}

// Routes registers GET /api/admin/import/sources and POST /api/admin/import.
func (a *API) Routes(mux *http.ServeMux) {
	mux.Handle("GET /api/admin/import/sources", a.guard(http.HandlerFunc(a.sources)))
	mux.Handle("POST /api/admin/import/{$}", a.guard(http.HandlerFunc(a.run)))
	mux.Handle("POST /api/admin/import", a.guard(http.HandlerFunc(a.run)))
}

// guard answers 401 without a signed-in account and 403 unless it holds the
// admin flag, which is read from the account row on every request.
func (a *API) guard(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		id, ok := sessionUser(r)
		if !ok {
			httpx.Error(w, http.StatusUnauthorized, "Unauthorized")
			return
		}
		var admin int64
		_ = a.cfg.Env.DB.R.QueryRowContext(r.Context(), `SELECT is_admin FROM users WHERE id = ?`, id).Scan(&admin)
		if admin != 1 {
			httpx.WriteJSON(w, http.StatusForbidden, errorBody{Error: "Admin access required", Code: "ADMIN_REQUIRED"})
			return
		}
		next.ServeHTTP(w, r)
	})
}

func sessionUser(r *http.Request) (int64, bool) {
	sess := sessionx.FromContext(r.Context())
	if sess == nil {
		return 0, false
	}
	return sess.Int64("userId")
}

func (a *API) fail(w http.ResponseWriter, err error) {
	var he *apperr.Error
	if errors.As(err, &he) && he.Status < 500 {
		httpx.WriteJSON(w, he.Status, errorBody{Error: he.Message, Code: he.Code})
		return
	}
	if a.cfg.Log != nil {
		a.cfg.Log.Error("import route failed", "error", err)
	}
	httpx.WriteJSON(w, http.StatusInternalServerError, errorBody{Error: publicerr.Sanitize(err.Error(), "", "")})
}

// errorBody is the error envelope; the member order is the one Node writes.
type errorBody struct {
	Error string `json:"error"`
	Code  string `json:"code,omitempty"`
}

func invalidRequest(message string) error {
	return apperr.New(http.StatusBadRequest, message, "INVALID_IMPORT_REQUEST")
}

// ---- sources ------------------------------------------------------------------

// SourceView is one installation as the import screen lists it.
type SourceView struct {
	ID        string    `json:"id"`
	Source    string    `json:"source"`
	Label     string    `json:"label"`
	Path      string    `json:"path"`
	Contents  []Content `json:"contents"`
	NeedsHand int       `json:"needsHand"`
}

func (a *API) sourceViews() []SourceView {
	views := []SourceView{}
	for _, b := range a.cfg.Scanner.Scan() {
		contents := bundleContents(b, a.cfg.Env.AIProviders)
		if contents == nil {
			contents = []Content{}
		}
		views = append(views, SourceView{ID: b.Home, Source: b.Source, Label: b.Label, Path: b.Path, Contents: contents, NeedsHand: len(b.Skipped)})
	}
	return views
}

// hasUsableAI says whether any AI provider has what it needs to answer. Ollama
// counts only when pointed somewhere other than the default every install
// starts with.
// Sources lists the installations found and whether an AI is connected (the
// agent-assisted finish needs one).
func (a *API) Sources() ([]SourceView, bool) { return a.sourceViews(), a.hasUsableAI() }

func (a *API) hasUsableAI() bool {
	values := envFileValues(a.cfg.Env.EnvFile)
	for _, p := range a.cfg.Env.AIProviders {
		if p.EnvKey != "" {
			if trim(values[p.EnvKey]) != "" {
				return true
			}
			continue
		}
		if url := trim(values["OLLAMA_URL"]); url != "" && url != defaultOllamaURL {
			return true
		}
	}
	return false
}

func (a *API) sources(w http.ResponseWriter, r *http.Request) {
	httpx.WriteJSON(w, http.StatusOK, map[string]any{
		"sources": a.sourceViews(),
		"parts":   Parts,
		"aiReady": a.hasUsableAI(),
	})
}

// ---- run ----------------------------------------------------------------------

type request struct {
	sourceIDs []string
	parts     []string
	finish    bool
}

// stringList reads a JSON list of strings; a missing or mixed list is refused.
func stringList(v any, ok bool, field string) ([]string, error) {
	list, isList := v.([]any)
	if !ok || !isList {
		return nil, invalidRequest(field + " must be a list of strings")
	}
	out := make([]string, 0, len(list))
	for _, item := range list {
		s, isString := item.(string)
		if !isString {
			return nil, invalidRequest(field + " must be a list of strings")
		}
		out = append(out, s)
	}
	return out, nil
}

func readBody(r *http.Request) (map[string]any, error) {
	if !strings.Contains(strings.ToLower(r.Header.Get("Content-Type")), "json") {
		return map[string]any{}, nil
	}
	raw, err := io.ReadAll(http.MaxBytesReader(nil, r.Body, bodyLimit))
	if err != nil {
		return nil, apperr.New(http.StatusRequestEntityTooLarge, "Request body too large", "")
	}
	if len(bytes.TrimSpace(raw)) == 0 {
		return map[string]any{}, nil
	}
	var v any
	if err := json.Unmarshal(raw, &v); err != nil {
		return nil, apperr.New(http.StatusBadRequest, "Invalid JSON body", "")
	}
	m, _ := v.(map[string]any)
	if m == nil {
		m = map[string]any{}
	}
	return m, nil
}

func parseRequest(body map[string]any) (request, error) {
	sources, ok := body["sources"]
	ids, err := stringList(sources, ok, "sources")
	if err != nil {
		return request{}, err
	}
	if len(ids) == 0 {
		return request{}, invalidRequest("Choose at least one agent to bring over")
	}
	parts := Parts
	if v, present := body["parts"]; present && v != nil {
		if parts, err = stringList(v, true, "parts"); err != nil {
			return request{}, err
		}
	}
	var unknown []string
	for _, p := range parts {
		if !contains(Parts, p) {
			unknown = append(unknown, p)
		}
	}
	if len(unknown) > 0 {
		return request{}, invalidRequest("Unknown parts: " + strings.Join(unknown, ", "))
	}
	finish, isBool := false, true
	if v, present := body["finish"]; present {
		finish, isBool = v.(bool)
		if !isBool {
			return request{}, invalidRequest("finish must be true or false")
		}
	}
	return request{sourceIDs: ids, parts: parts, finish: finish}, nil
}

func (a *API) run(w http.ResponseWriter, r *http.Request) {
	body, err := readBody(r)
	if err != nil {
		a.fail(w, err)
		return
	}
	req, err := parseRequest(body)
	if err != nil {
		a.fail(w, err)
		return
	}
	userID, _ := sessionUser(r)
	out, err := a.RunImport(r.Context(), userID, req.sourceIDs, req.parts, req.finish)
	if err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, out)
}

type attentionItem struct {
	Kind   string `json:"kind"`
	Status string `json:"status"`
	Name   string `json:"name"`
	Detail string `json:"detail"`
}

// Summary is the answer of an import.
type Summary struct {
	BroughtOver     []string        `json:"broughtOver"`
	AlreadyThere    int             `json:"alreadyThere"`
	Attention       []attentionItem `json:"attention"`
	AttentionTotal  int             `json:"attentionTotal"`
	ReportFile      string          `json:"reportFile"`
	FinishTask      *string         `json:"finishTask"`
	RestartRequired bool            `json:"restartRequired"`
}

// RunImport brings the chosen installations (ids from the sources list) over
// into the account. parts is a subset of Parts; finish queues the one-time
// automation that rebuilds what the script could not translate.
func (a *API) RunImport(ctx context.Context, userID int64, sourceIDs, parts []string, finish bool) (Summary, error) {
	a.mu.Lock()
	if a.running {
		a.mu.Unlock()
		return Summary{}, apperr.New(http.StatusConflict, "An import is already running", "IMPORT_RUNNING")
	}
	a.running = true
	a.mu.Unlock()
	defer func() {
		a.mu.Lock()
		a.running = false
		a.mu.Unlock()
	}()

	var bundles []Bundle
	for _, b := range a.cfg.Scanner.Scan() {
		if contains(sourceIDs, b.Home) {
			bundles = append(bundles, selectParts(b, parts))
		}
	}
	if len(bundles) == 0 {
		return Summary{}, apperr.New(http.StatusNotFound, "The chosen agent was not found on this computer", "IMPORT_SOURCE_NOT_FOUND")
	}

	session := NewSession(a.cfg.Env, userID)
	for _, b := range bundles {
		session.ApplyBundle(ctx, b)
	}
	now := a.now()
	reportFile, err := session.writeReport(bundles, now)
	if err != nil {
		return Summary{}, err
	}
	var finishTask *string
	if finish && session.hasLeftovers() && a.hasUsableAI() {
		name, err := session.queueFinishTask(ctx, bundles, now)
		if err != nil {
			return Summary{}, err
		}
		finishTask = &name
	}
	return summarize(session, reportFile, finishTask), nil
}

func summarize(s *Session, reportFile string, finishTask *string) Summary {
	var imported, attention []Entry
	already := 0
	for _, e := range s.Entries {
		switch e.Status {
		case "imported":
			imported = append(imported, e)
		case "failed", "skipped":
			attention = append(attention, e)
		case "exists":
			already += e.Count
		}
	}
	items := []attentionItem{}
	for i, e := range attention {
		if i >= attentionLimit {
			break
		}
		items = append(items, attentionItem{e.Kind, e.Status, e.Name, e.Detail})
	}
	return Summary{
		BroughtOver:     totals(imported),
		AlreadyThere:    already,
		Attention:       items,
		AttentionTotal:  len(attention),
		ReportFile:      reportFile,
		FinishTask:      finishTask,
		RestartRequired: len(imported) > 0 || finishTask != nil,
	}
}

// WithScanner is the same import writing into the same installation, but
// reading the installations Scanner finds (`neoagent migrate --from`).
func (a *API) WithScanner(s Scanner) *API {
	cfg := a.cfg
	cfg.Scanner = s
	return New(cfg)
}
