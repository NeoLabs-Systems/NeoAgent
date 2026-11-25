package settings

import (
	"context"
	"encoding/json"
	"io"
	"net/http"

	"github.com/NeoLabs-Systems/neolabs-go/httpx"
	"github.com/NeoLabs-Systems/neolabs-go/publicerr"
)

// Catalog provides the AI provider/model lists and BYOK status/test hooks.
type Catalog interface {
	Models(ctx context.Context, userID int64, agentID string) (any, error)
	SystemOneModels(ctx context.Context, userID int64, agentID string) (any, error)
	AIProviders(ctx context.Context, userID int64, agentID string) (any, error)
	BYOKList(ctx context.Context, userID int64, agentID string) (any, error)
	BYOKTest(ctx context.Context, userID int64, agentID, providerID string, body map[string]any) (any, error)
}

func (a *API) handleMetaModels(w http.ResponseWriter, r *http.Request, req request) {
	if a.catalog == nil {
		http.NotFound(w, r)
		return
	}
	res, err := a.catalog.Models(r.Context(), req.userID, req.agentID)
	if err != nil {
		httpx.WriteJSON(w, http.StatusInternalServerError, map[string]any{"error": publicerr.Sanitize(err.Error(), "", "")})
		return
	}
	httpx.WriteJSON(w, http.StatusOK, res)
}

func (a *API) handleMetaSystemOneModels(w http.ResponseWriter, r *http.Request, req request) {
	if a.catalog == nil {
		http.NotFound(w, r)
		return
	}
	res, err := a.catalog.SystemOneModels(r.Context(), req.userID, req.agentID)
	if err != nil {
		httpx.WriteJSON(w, http.StatusInternalServerError, map[string]any{"error": publicerr.Sanitize(err.Error(), "", "")})
		return
	}
	httpx.WriteJSON(w, http.StatusOK, res)
}

func (a *API) handleMetaAIProviders(w http.ResponseWriter, r *http.Request, req request) {
	if a.catalog == nil {
		http.NotFound(w, r)
		return
	}
	res, err := a.catalog.AIProviders(r.Context(), req.userID, req.agentID)
	if err != nil {
		httpx.WriteJSON(w, http.StatusInternalServerError, map[string]any{"error": publicerr.Sanitize(err.Error(), "", "")})
		return
	}
	httpx.WriteJSON(w, http.StatusOK, res)
}

func (a *API) handleBYOKList(w http.ResponseWriter, r *http.Request, req request) {
	if a.catalog == nil {
		http.NotFound(w, r)
		return
	}
	res, err := a.catalog.BYOKList(r.Context(), req.userID, req.agentID)
	if err != nil {
		httpx.WriteJSON(w, http.StatusInternalServerError, map[string]any{"error": publicerr.Sanitize(err.Error(), "", "")})
		return
	}
	httpx.WriteJSON(w, http.StatusOK, res)
}

func (a *API) handleBYOKTest(w http.ResponseWriter, r *http.Request, req request) {
	if a.catalog == nil {
		http.NotFound(w, r)
		return
	}
	var body map[string]any
	_ = json.NewDecoder(io.LimitReader(r.Body, 64*1024)).Decode(&body)
	res, err := a.catalog.BYOKTest(r.Context(), req.userID, req.agentID, r.PathValue("providerId"), body)
	if err != nil {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"success": false, "error": publicerr.Sanitize(err.Error(), "", "")})
		return
	}
	httpx.WriteJSON(w, http.StatusOK, res)
}
