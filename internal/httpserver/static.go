package httpserver

import (
	"fmt"
	"io"
	"io/fs"
	"net/http"
	"os"
	"path"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/httpx"
)

// flutterNoStore are the files the browser must always revalidate, so a new
// release is picked up immediately.
var flutterNoStore = map[string]bool{
	"index.html":                true,
	"flutter_bootstrap.js":      true,
	"flutter_service_worker.js": true,
	"version.json":              true,
}

func setNoStore(h http.Header) {
	h.Set("Cache-Control", "no-store, no-cache, must-revalidate, proxy-revalidate")
	h.Set("Pragma", "no-cache")
	h.Set("Expires", "0")
	h.Set("Surrogate-Control", "no-store")
	h.Set("CDN-Cache-Control", "no-store")
}

// openRooted opens rel inside dir. os.Root refuses `..` and symlinks that leave
// the directory, so a crafted URL can never read outside the web root.
func openRooted(dir, rel string) (*os.File, fs.FileInfo, error) {
	root, err := os.OpenRoot(dir)
	if err != nil {
		return nil, nil, err
	}
	defer root.Close()
	f, err := root.Open(rel)
	if err != nil {
		return nil, nil, err
	}
	st, err := f.Stat()
	if err != nil || st.IsDir() {
		f.Close()
		if err == nil {
			err = fs.ErrNotExist
		}
		return nil, nil, err
	}
	return f, st, nil
}

func serveFile(w http.ResponseWriter, r *http.Request, f *os.File, st fs.FileInfo) {
	w.Header().Set("ETag", fmt.Sprintf(`W/"%x-%x"`, st.Size(), st.ModTime().UnixMilli()))
	if w.Header().Get("Cache-Control") == "" {
		w.Header().Set("Cache-Control", "public, max-age=0")
	}
	http.ServeContent(w, r, st.Name(), st.ModTime(), f)
}

// flutterApp serves the Flutter web build under /app/. Real files are served
// as they are; any other path falls back to index.html with the base href
// rewritten so client-side routes survive a reload.
func flutterApp(webDir string) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet && r.Method != http.MethodHead {
			w.Header().Set("Allow", "GET, HEAD")
			httpx.Error(w, http.StatusMethodNotAllowed, "Method not allowed")
			return
		}
		rel := path.Clean(strings.TrimPrefix(r.URL.Path, "/app"))
		rel = strings.TrimPrefix(rel, "/")
		if rel != "" && rel != "." && rel != "index.html" {
			if f, st, err := openRooted(webDir, rel); err == nil {
				defer f.Close()
				if flutterNoStore[path.Base(rel)] {
					setNoStore(w.Header())
				}
				serveFile(w, r, f, st)
				return
			}
		}
		f, _, err := openRooted(webDir, "index.html")
		if err != nil {
			http.Error(w, `Flutter web build not found. Run "npm run flutter:build:web" to generate the bundled client.`, http.StatusServiceUnavailable)
			return
		}
		defer f.Close()
		raw, err := io.ReadAll(f)
		if err != nil {
			httpx.Error(w, http.StatusInternalServerError, "Internal server error")
			return
		}
		html := strings.Replace(string(raw), `<base href="/">`, `<base href="/app/">`, 1)
		setNoStore(w.Header())
		w.Header().Set("Content-Type", "text/html")
		_, _ = io.WriteString(w, html)
	})
}

// landing serves the marketing site at / and the browser 404 page. API clients
// keep JSON errors; only browsers that ask for HTML get the page.
func landing(dir string) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet && r.Method != http.MethodHead {
			httpx.Error(w, http.StatusNotFound, "Not found")
			return
		}
		rel := strings.TrimPrefix(path.Clean(r.URL.Path), "/")
		switch rel {
		case "", ".":
			rel = "index.html"
		case "status":
			rel = "status.html"
		}
		if f, st, err := openRooted(dir, rel); err == nil {
			defer f.Close()
			serveFile(w, r, f, st)
			return
		}
		if !strings.HasPrefix(r.URL.Path, "/api/") && prefersHTML(r) {
			if f, st, err := openRooted(dir, "404.html"); err == nil {
				defer f.Close()
				w.Header().Set("Content-Type", "text/html; charset=utf-8")
				w.Header().Set("Last-Modified", st.ModTime().UTC().Format(time.RFC1123))
				w.WriteHeader(http.StatusNotFound)
				if r.Method != http.MethodHead {
					_, _ = io.Copy(w, f)
				}
				return
			}
		}
		httpx.Error(w, http.StatusNotFound, "Not found")
	})
}

func prefersHTML(r *http.Request) bool {
	accept := r.Header.Get("Accept")
	h := strings.Index(accept, "text/html")
	j := strings.Index(accept, "application/json")
	return h >= 0 && (j < 0 || h < j)
}
