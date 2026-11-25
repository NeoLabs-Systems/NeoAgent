package bitwarden

import (
	"context"
	"errors"
	"net/http"

	"github.com/NeoLabs-Systems/neoagent/internal/credentials"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neolabs-go/httpx"
)

// Broker is the part of the credential broker the vault routes use.
type Broker interface {
	ListVaultItems(ctx context.Context, userID int64, agentID string) ([]credentials.SafeItem, error)
	ListBindings(ctx context.Context, userID int64, agentID string) ([]credentials.Binding, error)
	CreateBinding(ctx context.Context, userID int64, agentID string, input map[string]any) (*credentials.Binding, error)
	UpdateBinding(ctx context.Context, userID int64, agentID, bindingID string, input map[string]any) (*credentials.Binding, error)
	DeleteBinding(ctx context.Context, userID int64, agentID, bindingID string) (bool, error)
}

// Routes mounts the vault routes (/api/integrations/bitwarden/...).
func Routes(mux *http.ServeMux, api *integrations.API, p *Provider, broker Broker) {
	fail := func(w http.ResponseWriter, err error) { api.FailWithCode(w, http.StatusBadRequest, err) }
	needBroker := func(w http.ResponseWriter) bool {
		if broker == nil {
			fail(w, errors.New("Credential broker is unavailable."))
			return false
		}
		return true
	}
	h := func(pattern string, fn func(http.ResponseWriter, *http.Request, integrations.Scope, map[string]any)) {
		mux.Handle(pattern, api.Scoped(fn))
	}
	h("POST /api/integrations/bitwarden/unlock", func(w http.ResponseWriter, r *http.Request, s integrations.Scope, body map[string]any) {
		password, _ := body["masterPassword"].(string)
		out, err := p.Unlock(r.Context(), s, password, body["persistSession"] != false, body["twoStepMethod"], body["twoStepCode"])
		if err != nil {
			fail(w, err)
			return
		}
		httpx.WriteJSON(w, http.StatusOK, out)
	})
	h("POST /api/integrations/bitwarden/lock", func(w http.ResponseWriter, r *http.Request, s integrations.Scope, _ map[string]any) {
		if p.cli == nil {
			fail(w, errors.New("Bitwarden credential service is unavailable."))
			return
		}
		p.cli.Lock(r.Context(), s.UserID, s.AgentID)
		httpx.WriteJSON(w, http.StatusOK, map[string]any{"locked": true})
	})
	h("GET /api/integrations/bitwarden/items", func(w http.ResponseWriter, r *http.Request, s integrations.Scope, _ map[string]any) {
		if !needBroker(w) {
			return
		}
		items, err := broker.ListVaultItems(r.Context(), s.UserID, s.AgentID)
		if err != nil {
			fail(w, err)
			return
		}
		if items == nil {
			items = []credentials.SafeItem{}
		}
		httpx.WriteJSON(w, http.StatusOK, map[string]any{"items": items})
	})
	h("GET /api/integrations/bitwarden/bindings", func(w http.ResponseWriter, r *http.Request, s integrations.Scope, _ map[string]any) {
		if !needBroker(w) {
			return
		}
		list, err := broker.ListBindings(r.Context(), s.UserID, s.AgentID)
		if err != nil {
			fail(w, err)
			return
		}
		if list == nil {
			list = []credentials.Binding{}
		}
		httpx.WriteJSON(w, http.StatusOK, map[string]any{"bindings": list})
	})
	h("POST /api/integrations/bitwarden/bindings", func(w http.ResponseWriter, r *http.Request, s integrations.Scope, body map[string]any) {
		if !needBroker(w) {
			return
		}
		b, err := broker.CreateBinding(r.Context(), s.UserID, s.AgentID, body)
		if err != nil {
			fail(w, err)
			return
		}
		httpx.WriteJSON(w, http.StatusCreated, map[string]any{"binding": b})
	})
	h("PUT /api/integrations/bitwarden/bindings/{bindingId}", func(w http.ResponseWriter, r *http.Request, s integrations.Scope, body map[string]any) {
		if !needBroker(w) {
			return
		}
		b, err := broker.UpdateBinding(r.Context(), s.UserID, s.AgentID, r.PathValue("bindingId"), body)
		if err != nil {
			fail(w, err)
			return
		}
		httpx.WriteJSON(w, http.StatusOK, map[string]any{"binding": b})
	})
	h("DELETE /api/integrations/bitwarden/bindings/{bindingId}", func(w http.ResponseWriter, r *http.Request, s integrations.Scope, _ map[string]any) {
		if !needBroker(w) {
			return
		}
		deleted, err := broker.DeleteBinding(r.Context(), s.UserID, s.AgentID, r.PathValue("bindingId"))
		if err != nil {
			fail(w, err)
			return
		}
		httpx.WriteJSON(w, http.StatusOK, map[string]any{"deleted": deleted})
	})
}
