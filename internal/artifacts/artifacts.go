package artifacts

import (
	"database/sql"
	"errors"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/httpx"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
)

// Config configures the artifacts API.
type Config struct {
	DB     *dbx.DB
	Root   string
	UserID func(*http.Request) (int64, bool)
}

// API serves /api/artifacts/*.
type API struct {
	cfg Config
}

// New creates an artifacts API.
func New(cfg Config) *API {
	return &API{cfg: cfg}
}

// Routes registers /api/artifacts/{id}/content on mux.
func (a *API) Routes(mux *http.ServeMux) {
	mux.HandleFunc("GET /api/artifacts/{id}/content", a.handleContent)
}

func (a *API) handleContent(w http.ResponseWriter, r *http.Request) {
	var uid int64
	var ok bool
	if a.cfg.UserID != nil {
		uid, ok = a.cfg.UserID(r)
	} else if sess := sessionx.FromContext(r.Context()); sess != nil {
		uid, ok = sess.Int64("userId")
	}
	if !ok || uid <= 0 {
		httpx.WriteJSON(w, http.StatusUnauthorized, map[string]any{"error": "Unauthorized"})
		return
	}
	if a.cfg.DB == nil || a.cfg.Root == "" {
		httpx.WriteJSON(w, http.StatusServiceUnavailable, map[string]any{"error": "Artifact store not available"})
		return
	}

	var contentType sql.NullString
	var storagePath string
	err := a.cfg.DB.R.QueryRowContext(r.Context(), `SELECT content_type, storage_path FROM artifacts WHERE id = ? AND user_id = ?`, r.PathValue("id"), uid).
		Scan(&contentType, &storagePath)
	if errors.Is(err, sql.ErrNoRows) {
		httpx.WriteJSON(w, http.StatusNotFound, map[string]any{"error": "Artifact not found"})
		return
	}
	if err != nil {
		httpx.WriteJSON(w, http.StatusInternalServerError, map[string]any{"error": "Failed to load artifact"})
		return
	}

	baseDir := filepath.Clean(a.cfg.Root)
	absPath := filepath.Clean(storagePath)
	rel, err := filepath.Rel(baseDir, absPath)
	if err != nil || rel == "." || strings.HasPrefix(rel, "..") || filepath.IsAbs(rel) {
		httpx.WriteJSON(w, http.StatusNotFound, map[string]any{"error": "Artifact not found"})
		return
	}

	root, err := os.OpenRoot(baseDir)
	if err != nil {
		httpx.WriteJSON(w, http.StatusNotFound, map[string]any{"error": "File not found"})
		return
	}
	defer root.Close()

	f, err := root.Open(rel)
	if err != nil {
		httpx.WriteJSON(w, http.StatusNotFound, map[string]any{"error": "File not found"})
		return
	}
	defer f.Close()

	info, err := f.Stat()
	if err != nil || info.IsDir() {
		httpx.WriteJSON(w, http.StatusNotFound, map[string]any{"error": "File not found"})
		return
	}
	if contentType.Valid && contentType.String != "" {
		w.Header().Set("Content-Type", contentType.String)
	}
	w.Header().Set("Cache-Control", "private, max-age=60")
	http.ServeContent(w, r, info.Name(), info.ModTime(), f)
}
