package socialreach

import (
	"bytes"
	"context"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"os"
	"strings"

	"github.com/NeoLabs-Systems/neolabs-go/httpx"
	"github.com/NeoLabs-Systems/neolabs-go/publicerr"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
)

const bodyLimit = 1 << 20

// Backend is what the routes need from the service; Service satisfies it.
type Backend interface {
	Status(ctx context.Context, userID int64) (any, error)
	Read(ctx context.Context, userID int64, body map[string]any) (any, error)
	Search(ctx context.Context, userID int64, body map[string]any) (any, error)
	ImportCookies(ctx context.Context, userID int64, platform string) (any, error)
	ClearCookies(ctx context.Context, userID int64, platform string) (any, error)
}

// APIConfig wires the /api/social-reach routes.
type APIConfig struct {
	// Backend answers the routes; nil answers 503 like a missing service.
	Backend Backend
	Log     *slog.Logger
	// UserID returns the signed-in account. Nil reads "userId" from the session.
	UserID func(*http.Request) (int64, bool)
	// AppRoot is hidden in error texts as "[app]" (the home directory is always
	// hidden as "~").
	AppRoot string
}

// API serves the routes.
type API struct {
	cfg  APIConfig
	home string
}

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
	home, _ := os.UserHomeDir()
	return &API{cfg: cfg, home: home}
}

// Routes registers the routes on mux.
func (a *API) Routes(mux *http.ServeMux) {
	mux.Handle("GET /api/social-reach/status", a.guard(func(w http.ResponseWriter, r *http.Request, id int64) (any, error) {
		return a.cfg.Backend.Status(r.Context(), id)
	}))
	mux.Handle("POST /api/social-reach/read", a.guard(func(w http.ResponseWriter, r *http.Request, id int64) (any, error) {
		body, err := readBody(r)
		if err != nil {
			return nil, err
		}
		return a.cfg.Backend.Read(r.Context(), id, body)
	}))
	mux.Handle("POST /api/social-reach/search", a.guard(func(w http.ResponseWriter, r *http.Request, id int64) (any, error) {
		body, err := readBody(r)
		if err != nil {
			return nil, err
		}
		return a.cfg.Backend.Search(r.Context(), id, body)
	}))
	mux.Handle("POST /api/social-reach/cookies/import", a.guard(func(w http.ResponseWriter, r *http.Request, id int64) (any, error) {
		body, err := readBody(r)
		if err != nil {
			return nil, err
		}
		platform := jsTrim(str(body["platform"]))
		if platform == "" {
			return nil, badRequest("platform is required.")
		}
		return a.cfg.Backend.ImportCookies(r.Context(), id, platform)
	}))
	mux.Handle("DELETE /api/social-reach/cookies/{platform}", a.guard(func(w http.ResponseWriter, r *http.Request, id int64) (any, error) {
		return a.cfg.Backend.ClearCookies(r.Context(), id, r.PathValue("platform"))
	}))
}

// guard checks the session and the service, then answers with the result or
// the failure's status.
func (a *API) guard(fn func(http.ResponseWriter, *http.Request, int64) (any, error)) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		id, ok := a.cfg.UserID(r)
		if !ok {
			httpx.Error(w, 401, "Unauthorized")
			return
		}
		if a.cfg.Backend == nil {
			httpx.Error(w, 503, "Social reach service is unavailable.")
			return
		}
		result, err := fn(w, r, id)
		if err != nil {
			a.fail(w, err)
			return
		}
		httpx.WriteJSON(w, 200, result)
	})
}

func (a *API) fail(w http.ResponseWriter, err error) {
	status := 500
	var re *reachError
	if errors.As(err, &re) && re.Status >= 400 && re.Status < 600 {
		status = re.Status
	}
	if a.cfg.Log != nil && status >= 500 {
		a.cfg.Log.Error("social reach route failed", "error", err)
	}
	httpx.Error(w, status, publicerr.Sanitize(err.Error(), a.home, a.cfg.AppRoot))
}

// readBody reads the JSON object a request carries; none means empty.
func readBody(r *http.Request) (map[string]any, error) {
	if !strings.Contains(strings.ToLower(r.Header.Get("Content-Type")), "json") {
		return map[string]any{}, nil
	}
	raw, err := io.ReadAll(http.MaxBytesReader(nil, r.Body, bodyLimit))
	if err != nil {
		return nil, badRequest("Request body too large")
	}
	raw = bytes.TrimSpace(raw)
	if len(raw) == 0 {
		return map[string]any{}, nil
	}
	v, err := decode(raw)
	if err != nil {
		return nil, badRequest("Invalid JSON body")
	}
	body, _ := v.(map[string]any)
	if body == nil {
		return map[string]any{}, nil
	}
	return body, nil
}
