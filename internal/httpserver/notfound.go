package httpserver

import (
	"html"
	"net/http"
	"strings"

	"github.com/NeoLabs-Systems/neolabs-go/httpx"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
)

// signedInPrefixes are the API areas whose every route needs a session, so an
// unknown path below them answers 401 to a visitor before it can answer 404
// (the Node routers checked the session first).
var signedInPrefixes = []string{
	"/api/computer/", "/api/account/", "/api/delegation/", "/api/admin/", "/api/neorouter/",
	"/api/behavior/", "/api/agent-profiles/", "/api/messaging/", "/api/mcp/", "/api/integrations/",
	"/api/artifacts/", "/api/web-shares/", "/api/memory/", "/api/tasks/", "/api/android/",
	"/api/stream/", "/api/social-video/", "/api/social-reach/", "/api/voice-assistant/",
	"/api/wearable/", "/api/mobile/health/", "/api/mobile/device-sync/", "/api/triggers/", "/api/security/",
}

// apiNotFound answers an API path no route serves, as Express did: 401 for a
// visitor in a signed-in area, 403 for a non-admin under /api/admin, otherwise
// Express's plain "Cannot METHOD /path" page.
func apiNotFound(isAdmin func(*http.Request) bool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if signedInArea(r.URL.Path) {
			if uid, ok := sessionUserID(r); !ok || uid <= 0 {
				httpx.WriteJSON(w, http.StatusUnauthorized, map[string]any{"error": "Unauthorized"})
				return
			}
			if strings.HasPrefix(r.URL.Path, "/api/admin/") && isAdmin != nil && !isAdmin(r) {
				httpx.WriteJSON(w, http.StatusForbidden, map[string]any{"error": "Admin access required", "code": "ADMIN_REQUIRED"})
				return
			}
		}
		h := w.Header()
		h.Set("Content-Security-Policy", "default-src 'none'")
		h.Set("X-Content-Type-Options", "nosniff")
		h.Set("Content-Type", "text/html; charset=utf-8")
		w.WriteHeader(http.StatusNotFound)
		_, _ = w.Write([]byte("<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n<meta charset=\"utf-8\">\n<title>Error</title>\n</head>\n<body>\n<pre>Cannot " +
			html.EscapeString(r.Method+" "+r.URL.EscapedPath()) + "</pre>\n</body>\n</html>\n"))
	}
}

func signedInArea(path string) bool {
	for _, p := range signedInPrefixes {
		if strings.HasPrefix(path, p) {
			return true
		}
	}
	return false
}

func sessionUserID(r *http.Request) (int64, bool) {
	sess := sessionx.FromContext(r.Context())
	if sess == nil {
		return 0, false
	}
	return sess.Int64("userId")
}
