// Package httpserver assembles NeoAgent's HTTP surface: the hardening
// middleware stack, the session layer, health, and the static clients.
package httpserver

import (
	"log/slog"
	"net/http"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/config"
	"github.com/NeoLabs-Systems/neolabs-go/httpx"
	"github.com/NeoLabs-Systems/neolabs-go/secheaders"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
)

const jsonBodyLimit = 10 << 20 // 10 MiB, same as the Node server

// Deps are the collaborators the server needs.
type Deps struct {
	Config   config.Config
	Sessions *sessionx.Manager
	Log      *slog.Logger
	Now      func() time.Time
}

// New returns the root handler.
func New(d Deps) http.Handler {
	if d.Now == nil {
		d.Now = time.Now
	}
	mux := http.NewServeMux()
	mux.HandleFunc("GET /api/health", healthHandler(d))
	mux.HandleFunc("GET /app-build.json", buildIDHandler(d.Config.WebDir))
	mux.Handle("/app/", flutterApp(d.Config.WebDir))
	mux.Handle("/app", http.RedirectHandler("/app/", http.StatusMovedPermanently))
	mux.HandleFunc("/api/", func(w http.ResponseWriter, r *http.Request) {
		httpx.Error(w, http.StatusNotFound, "Not found")
	})
	mux.Handle("/", landing(d.Config.Landing))

	var app http.Handler = mux
	if d.Sessions != nil {
		app = d.Sessions.Middleware(app)
	}
	return httpx.Chain(app,
		httpx.Recover(d.Log),
		secheaders.Middleware(SecurityHeaders(d.Config, "")),
		httpx.APICaseGuard(),
		httpx.CORS(d.Config.Origins),
		httpx.NoStoreAPI(),
		httpx.OriginGuard(d.Config.Origins),
		httpx.MaxBody(jsonBodyLimit),
	)
}

func healthHandler(d Deps) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// Runtime (VM) validation is not ported yet; report the same
		// "unavailable" state the Node server reports when the probe fails.
		httpx.WriteJSON(w, http.StatusOK, map[string]any{
			"status":    "degraded",
			"timestamp": d.Now().UTC().Format("2006-01-02T15:04:05.000Z"),
			"runtime": map[string]any{
				"ready":      false,
				"issueCount": 1,
				"summary":    "Runtime validation is unavailable.",
			},
		})
	}
}

func buildIDHandler(webDir string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		setNoStore(w.Header())
		var id any
		if raw, err := readSmall(webDir, ".last_build_id"); err == nil && raw != "" {
			id = raw
		}
		httpx.WriteJSON(w, http.StatusOK, map[string]any{"buildId": id})
	}
}

func readSmall(dir, rel string) (string, error) {
	f, _, err := openRooted(dir, rel)
	if err != nil {
		return "", err
	}
	defer f.Close()
	buf := make([]byte, 256)
	n, _ := f.Read(buf)
	out := string(buf[:n])
	for len(out) > 0 && (out[len(out)-1] == '\n' || out[len(out)-1] == '\r' || out[len(out)-1] == ' ') {
		out = out[:len(out)-1]
	}
	return out, nil
}

// NewHTTPServer wraps the handler with timeouts that defend against slow
// clients. There is deliberately no write timeout: agent runs stream for
// minutes (SSE, WebSockets).
func NewHTTPServer(addr string, h http.Handler, log *slog.Logger) *http.Server {
	return &http.Server{
		Addr:              addr,
		Handler:           h,
		ReadHeaderTimeout: 10 * time.Second,
		IdleTimeout:       120 * time.Second,
		MaxHeaderBytes:    1 << 20,
		ErrorLog:          slog.NewLogLogger(log.Handler(), slog.LevelWarn),
	}
}
