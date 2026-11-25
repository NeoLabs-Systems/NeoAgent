package datasharing

import (
	"encoding/json"
	"net/http"
	"regexp"
	"strings"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/accounts"
	"github.com/NeoLabs-Systems/neolabs-go/httpx"
	"github.com/NeoLabs-Systems/neolabs-go/ratelimit"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
)

type API struct {
	Users      *accounts.Repo
	TrustProxy bool
	mu         sync.Mutex
}
type client struct {
	Platform   *string `json:"platform"`
	AppVersion *string `json:"appVersion"`
}

var versionPattern = regexp.MustCompile(`^[0-9A-Za-z.+-]{1,32}$`)

func normalizeClient(v any) *client {
	m, ok := v.(map[string]any)
	if !ok {
		return nil
	}
	out := &client{}
	platform, _ := m["platform"].(string)
	platform = strings.ToLower(platform)
	switch platform {
	case "android", "ios", "web", "macos", "windows", "linux":
		out.Platform = &platform
	}
	version, _ := m["appVersion"].(string)
	if versionPattern.MatchString(version) {
		out.AppVersion = &version
	}
	return out
}
func (a *API) Routes(mux *http.ServeMux) {
	limit := ratelimit.New(ratelimit.Config{Window: 15 * time.Minute, Max: 30, Message: map[string]string{"error": "Too many account security attempts, try again later"}, Key: func(r *http.Request) string { return httpx.ClientIP(r, a.TrustProxy) }})
	mux.Handle("PUT /api/account/data-sharing", limit.Middleware(http.HandlerFunc(a.update)))
	mux.HandleFunc("PUT /api/account/data-sharing/client", a.updateClient)
}
func (a *API) handle(w http.ResponseWriter, r *http.Request, snapshot bool) {
	sess := sessionx.FromContext(r.Context())
	if sess == nil {
		httpx.WriteJSON(w, 401, map[string]any{"error": "Unauthorized"})
		return
	}
	uid, ok := sess.Int64("userId")
	if !ok || uid <= 0 {
		httpx.WriteJSON(w, 401, map[string]any{"error": "Unauthorized"})
		return
	}
	var b map[string]any
	dec := json.NewDecoder(http.MaxBytesReader(w, r.Body, 1<<20))
	if err := dec.Decode(&b); err != nil {
		httpx.WriteJSON(w, 400, map[string]any{"error": "Invalid JSON body"})
		return
	}
	user, err := a.Users.ByID(r.Context(), uid)
	if err != nil {
		httpx.WriteJSON(w, 500, map[string]any{"error": "Internal server error"})
		return
	}
	if user == nil {
		httpx.WriteJSON(w, 401, map[string]any{"error": "Unauthorized"})
		return
	}
	a.mu.Lock()
	defer a.mu.Unlock()
	current := a.Users.DataSharing(r.Context(), uid)
	if snapshot && !current.Enabled {
		httpx.WriteJSON(w, 200, map[string]any{"dataSharing": current})
		return
	}
	enabled := true
	if !snapshot {
		enabled, ok = b["enabled"].(bool)
		if !ok {
			httpx.WriteJSON(w, 400, map[string]any{"error": "enabled must be true or false"})
			return
		}
	}
	record := map[string]any{"enabled": enabled}
	if enabled {
		since := current.Since
		if since == nil {
			now := time.Now().UTC().Format("2006-01-02T15:04:05.000Z")
			since = &now
		}
		var c any = normalizeClient(b["client"])
		if !snapshot && c.(*client) == nil {
			c = current.Client
		}
		record["since"], record["client"] = since, c
	}
	raw, err := json.Marshal(record)
	if err == nil {
		_, err = a.Users.DB.W.ExecContext(r.Context(), `INSERT INTO user_settings (user_id, key, value) VALUES (?, 'usage_data_sharing', ?) ON CONFLICT(user_id, key) DO UPDATE SET value = excluded.value`, uid, string(raw))
	}
	if err != nil {
		httpx.WriteJSON(w, 500, map[string]any{"error": "Internal server error"})
		return
	}
	httpx.WriteJSON(w, 200, map[string]any{"dataSharing": a.Users.DataSharing(r.Context(), uid)})
}
func (a *API) update(w http.ResponseWriter, r *http.Request)       { a.handle(w, r, false) }
func (a *API) updateClient(w http.ResponseWriter, r *http.Request) { a.handle(w, r, true) }
