package runtime

import (
	"bytes"
	"crypto/sha256"
	"embed"
	"encoding/hex"
	"io/fs"
	"net/http"
	"path"
	"strings"
	"sync"
	"time"
)

// noVNC 1.7.0 (MPL-2.0, see novnc/LICENSE.txt): the RFB client the display
// page loads from /api/computer/novnc/.
//
//go:embed novnc
var noVNCFiles embed.FS

var (
	noVNCOnce  sync.Once
	noVNCRoot  fs.FS
	noVNCEtags sync.Map
)

// NoVNCHandler serves the vendored noVNC files under prefix. Like the static
// mount it replaces, it lists no directories and caches for a day.
func NoVNCHandler(prefix string) http.Handler {
	noVNCOnce.Do(func() { noVNCRoot, _ = fs.Sub(noVNCFiles, "novnc") })
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet && r.Method != http.MethodHead {
			http.NotFound(w, r)
			return
		}
		name := strings.TrimPrefix(path.Clean("/"+strings.TrimPrefix(r.URL.Path, prefix)), "/")
		if name == "" || name == "." {
			http.NotFound(w, r)
			return
		}
		data, err := fs.ReadFile(noVNCRoot, name)
		if err != nil {
			http.NotFound(w, r)
			return
		}
		etag, ok := noVNCEtags.Load(name)
		if !ok {
			sum := sha256.Sum256(data)
			etag = `"` + hex.EncodeToString(sum[:8]) + `"`
			noVNCEtags.Store(name, etag)
		}
		w.Header().Set("Cache-Control", "public, max-age=86400, immutable")
		w.Header().Set("ETag", etag.(string))
		http.ServeContent(w, r, name, time.Time{}, bytes.NewReader(data))
	})
}
