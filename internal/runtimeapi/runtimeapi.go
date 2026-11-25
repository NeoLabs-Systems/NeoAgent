package runtimeapi

import (
	"net/http"

	"github.com/NeoLabs-Systems/neolabs-go/httpx"
)

// API serves /api/runtime/config.
type API struct{}

// New creates a runtimeapi API.
func New() *API { return &API{} }

// Routes registers /api/runtime/config on mux.
func (a *API) Routes(mux *http.ServeMux) {
	mux.HandleFunc("GET /api/runtime/config", func(w http.ResponseWriter, _ *http.Request) {
		httpx.WriteJSON(w, http.StatusOK, map[string]any{
			"analytics": map[string]any{
				"enabled":         false,
				"provider":        nil,
				"requiresConsent": true,
			},
		})
	})
}
