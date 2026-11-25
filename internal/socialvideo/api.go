package socialvideo

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"

	"github.com/NeoLabs-Systems/neolabs-go/httpx"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
)

const bodyLimit = 1 << 20

// Extractor is what the routes need from the extraction service.
type Extractor interface {
	HealthStatus(ctx context.Context, forceRefresh bool) (Health, error)
	Extract(ctx context.Context, userID int64, sourceURL string, opts Options) (Result, error)
}

// APIConfig wires the /api/social-video routes.
type APIConfig struct {
	// Extractor answers the routes; nil answers 503 like a missing service.
	Extractor Extractor
	Log       *slog.Logger
	// UserID returns the signed-in account. Nil reads "userId" from the session.
	UserID func(*http.Request) (int64, bool)
	// AgentID picks the agent a request is about: the request's own choice
	// (body agentId / agent_id / options.*, query, X-Agent-Id) or the account's
	// default. The lead wires agentscope.Resolver here.
	AgentID func(r *http.Request, userID int64, body map[string]json.RawMessage) (string, error)
}

// API serves the routes.
type API struct{ cfg APIConfig }

// NewAPI builds the routes.
func NewAPI(cfg APIConfig) *API {
	if cfg.UserID == nil {
		cfg.UserID = func(r *http.Request) (int64, bool) {
			sess := sessionx.FromContext(r.Context())
			if sess == nil {
				return 0, false
			}
			return sess.Int64("userId")
		}
	}
	return &API{cfg: cfg}
}

// Routes registers the routes on mux.
func (a *API) Routes(mux *http.ServeMux) {
	mux.Handle("GET /api/social-video/health", a.guard(a.health))
	mux.Handle("POST /api/social-video/extract", a.guard(a.extract))
}

func (a *API) guard(fn func(http.ResponseWriter, *http.Request, int64)) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		id, ok := a.cfg.UserID(r)
		if !ok {
			httpx.Error(w, 401, "Unauthorized")
			return
		}
		fn(w, r, id)
	})
}

func (a *API) fail(w http.ResponseWriter, err error) {
	if a.cfg.Log != nil {
		a.cfg.Log.Error("social video route failed", "error", err)
	}
	httpx.Error(w, 500, err.Error())
}

func (a *API) health(w http.ResponseWriter, r *http.Request, _ int64) {
	if a.cfg.Extractor == nil {
		httpx.WriteJSON(w, 503, map[string]any{"ready": false, "error": "Social video service is unavailable."})
		return
	}
	refresh := r.URL.Query().Get("refresh")
	h, err := a.cfg.Extractor.HealthStatus(r.Context(), refresh == "1" || refresh == "true")
	if err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, 200, h)
}

func readBody(r *http.Request) (map[string]json.RawMessage, error) {
	body := map[string]json.RawMessage{}
	if !bytes.Contains(bytes.ToLower([]byte(r.Header.Get("Content-Type"))), []byte("json")) {
		return body, nil
	}
	raw, err := io.ReadAll(http.MaxBytesReader(nil, r.Body, bodyLimit))
	if err != nil {
		return nil, errors.New("Request body too large")
	}
	raw = bytes.TrimSpace(raw)
	if len(raw) == 0 || raw[0] == '[' {
		return body, nil
	}
	if json.Unmarshal(raw, &body) != nil || body == nil {
		return nil, errors.New("Invalid JSON body")
	}
	return body, nil
}

func (a *API) extract(w http.ResponseWriter, r *http.Request, userID int64) {
	if a.cfg.Extractor == nil {
		httpx.Error(w, 503, "Social video service is unavailable.")
		return
	}
	body, err := readBody(r)
	if err != nil {
		httpx.Error(w, 400, err.Error())
		return
	}
	var raw any
	if v, ok := body["url"]; ok {
		_ = json.Unmarshal(v, &raw)
	}
	source := jsTrim(jsText(raw))
	if source == "" {
		httpx.Error(w, 400, "url is required.")
		return
	}
	agentID, err := a.cfg.AgentID(r, userID, body)
	if err != nil {
		a.fail(w, err)
		return
	}
	res, err := a.cfg.Extractor.Extract(r.Context(), userID, source, Options{
		IncludeFrame: string(body["include_frame"]) != "false",
		ForceSTT:     string(body["force_stt"]) == "true",
		AgentID:      agentID,
	})
	switch {
	case err != nil:
		a.fail(w, err)
	case res.Setup != nil && !res.Setup.Ready:
		httpx.WriteJSON(w, 503, res)
	case len(res.Errors) > 0:
		failed := res.Title == "" && res.Description == "" && res.Transcript == "" && res.FrameImage == nil
		status := 200
		if failed {
			status = 422
		}
		httpx.WriteJSON(w, status, res)
	default:
		httpx.WriteJSON(w, 200, res)
	}
}
