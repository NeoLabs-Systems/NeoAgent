package wearable

import (
	"net/http"

	"github.com/NeoLabs-Systems/neolabs-go/httpx"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
)

// RoutesConfig wires the /api/wearable routes.
type RoutesConfig struct {
	Service *Service
	// UserID returns the signed-in account of a request. Nil reads "userId"
	// from the session.
	UserID func(*http.Request) (int64, bool)
	// Username returns the signed-in account's name for the bootstrap. Nil
	// reads "username" from the session.
	Username func(*http.Request) string
	// Sanitize hides paths in errors shown to the client (publicerr.Sanitize).
	Sanitize func(string) string
}

// API serves the /api/wearable routes.
type API struct{ cfg RoutesConfig }

// NewAPI builds the routes.
func NewAPI(cfg RoutesConfig) *API {
	if cfg.UserID == nil {
		cfg.UserID = sessionUserID
	}
	if cfg.Username == nil {
		cfg.Username = func(r *http.Request) string {
			if sess := sessionx.FromContext(r.Context()); sess != nil {
				return sess.String("username")
			}
			return ""
		}
	}
	return &API{cfg: cfg}
}

// Routes registers the HTTP routes on mux. The socket itself is the gateway's.
func (a *API) Routes(mux *http.ServeMux) {
	// Intentionally public so an already provisioned wearable can sync local
	// time before the user finishes session based pairing on the device.
	mux.HandleFunc("GET /api/wearable/timezone", func(w http.ResponseWriter, r *http.Request) {
		httpx.WriteJSON(w, 200, a.cfg.Service.TimeConfig(r))
	})
	mux.HandleFunc("GET /api/wearable/bootstrap", a.authed(func(w http.ResponseWriter, r *http.Request, userID int64) {
		body, err := a.cfg.Service.Bootstrap(r.Context(), r, userID, a.cfg.Username(r))
		a.reply(w, body, err)
	}))
	mux.HandleFunc("GET /api/wearable/firmware/manifest", a.authed(func(w http.ResponseWriter, r *http.Request, _ int64) {
		body, err := a.cfg.Service.FirmwareManifest(r.Context(), r)
		a.reply(w, body, err)
	}))
	mux.HandleFunc("GET /api/wearable/connections", a.authed(func(w http.ResponseWriter, r *http.Request, userID int64) {
		list := make([]fields, 0)
		for _, c := range a.cfg.Service.Connections(userID) {
			list = append(list, connectionJSON(c))
		}
		httpx.WriteJSON(w, 200, fields{{"connections", list}})
	}))
}

func (a *API) authed(next func(http.ResponseWriter, *http.Request, int64)) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID, ok := a.cfg.UserID(r)
		if !ok {
			httpx.Error(w, 401, "Unauthorized")
			return
		}
		next(w, r, userID)
	}
}

func (a *API) reply(w http.ResponseWriter, body any, err error) {
	if err != nil {
		message := err.Error()
		if a.cfg.Sanitize != nil {
			message = a.cfg.Sanitize(message)
		}
		httpx.WriteJSON(w, 400, map[string]any{"error": message})
		return
	}
	httpx.WriteJSON(w, 200, body)
}
