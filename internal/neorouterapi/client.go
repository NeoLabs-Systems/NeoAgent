package neorouterapi

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
)

// APIError is returned when a NeoRouter endpoint responds with a non-2xx status.
type APIError struct {
	Status  int
	Message string
}

func (e *APIError) Error() string {
	if e.Message != "" {
		return "NeoRouter: " + e.Message
	}
	return fmt.Sprintf("NeoRouter: HTTP %d", e.Status)
}

// CallOptions configures a raw call to a NeoRouter OpenAI-style endpoint.
type CallOptions struct {
	Method           string
	Body             any
	Timeout          time.Duration
	MaxResponseBytes int64
}

// Model is a model entry returned by NeoRouter's /v1/models?type=... endpoint.
type Model struct {
	ID        string         `json:"id"`
	NeoRouter *ModelMetadata `json:"neorouter,omitempty"`
	Raw       map[string]any `json:"-"`
}

// ModelMetadata holds NeoRouter-specific flags on a model entry.
type ModelMetadata struct {
	Decision  bool     `json:"decision,omitempty"`
	Protocols []string `json:"protocols,omitempty"`
}

// NotAllowedCounts reports how many models are excluded for the current key.
type NotAllowedCounts struct {
	Free           int         `json:"free,omitempty"`
	Plan           int         `json:"plan,omitempty"`
	Paid           int         `json:"paid,omitempty"`
	DecisionModels *TierCounts `json:"decision_models,omitempty"`
}

// TierCounts holds free/plan/paid counts.
type TierCounts struct {
	Free int `json:"free,omitempty"`
	Plan int `json:"plan,omitempty"`
	Paid int `json:"paid,omitempty"`
}

// ModelListResult is the response of ModelList.
type ModelListResult struct {
	Models     []Model
	NotAllowed NotAllowedCounts
}

// EmbedResult is the response of Embed.
type EmbedResult struct {
	Vector   []float64
	Model    string
	ServedBy string
}

// SearchResult is one item returned by SearchWeb.
type SearchResult struct {
	Rank        int    `json:"rank"`
	Title       string `json:"title"`
	URL         string `json:"url"`
	Description string `json:"description"`
}

// Call invokes a NeoRouter OpenAI-style endpoint using conn.
func (s *Service) Call(ctx context.Context, conn *Connection, path string, opts CallOptions) ([]byte, http.Header, error) {
	if conn == nil || conn.APIBase == "" || conn.APIKey == "" {
		return nil, nil, &APIError{Status: 400, Message: "NeoRouter is not connected"}
	}
	method := opts.Method
	if method == "" {
		method = http.MethodGet
	}
	timeout := opts.Timeout
	if timeout <= 0 {
		timeout = 30 * time.Second
	}
	maxBytes := opts.MaxResponseBytes
	if maxBytes <= 0 {
		maxBytes = 4 * 1024 * 1024
	}

	var bodyReader io.Reader
	if opts.Body != nil {
		raw, err := json.Marshal(opts.Body)
		if err != nil {
			return nil, nil, err
		}
		bodyReader = bytes.NewReader(raw)
	}

	reqCtx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()

	req, err := http.NewRequestWithContext(reqCtx, method, conn.APIBase+path, bodyReader)
	if err != nil {
		return nil, nil, err
	}
	req.Header.Set("Authorization", "Bearer "+conn.APIKey)
	req.Header.Set("Accept", "application/json")
	if opts.Body != nil {
		req.Header.Set("Content-Type", "application/json")
	}

	client := s.http
	if server := s.ServerConnection(); conn.Scope == "server" || (server != nil && conn.APIBase == server.APIBase) {
		client = s.trustedHTTP
	}
	resp, err := client.Do(req)
	if err != nil {
		return nil, nil, err
	}
	defer resp.Body.Close()

	data, err := io.ReadAll(io.LimitReader(resp.Body, maxBytes+1))
	if err != nil {
		return nil, resp.Header, err
	}
	if int64(len(data)) > maxBytes {
		return nil, resp.Header, fmt.Errorf("NeoRouter: response exceeded %d bytes", maxBytes)
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		var errBody struct {
			Error *struct {
				Message string `json:"message"`
			} `json:"error"`
		}
		_ = json.Unmarshal(data, &errBody)
		msg := ""
		if errBody.Error != nil {
			msg = errBody.Error.Message
		}
		return nil, resp.Header, &APIError{Status: resp.StatusCode, Message: msg}
	}
	return data, resp.Header, nil
}

// ModelList lists the models of typ ("chat", "moderation", etc.) that conn's key may use.
func (s *Service) ModelList(ctx context.Context, conn *Connection, typ string) (ModelListResult, error) {
	if typ == "" {
		typ = "chat"
	}
	raw, _, err := s.Call(ctx, conn, "/models?type="+url.QueryEscape(typ), CallOptions{})
	if err != nil {
		return ModelListResult{}, err
	}
	var parsed struct {
		Data      []json.RawMessage `json:"data"`
		NeoRouter *struct {
			NotAllowedForKey *NotAllowedCounts `json:"not_allowed_for_key"`
		} `json:"neorouter"`
	}
	if err := json.Unmarshal(raw, &parsed); err != nil {
		return ModelListResult{}, nil
	}
	models := make([]Model, 0, len(parsed.Data))
	for _, item := range parsed.Data {
		var m Model
		if err := json.Unmarshal(item, &m); err == nil {
			_ = json.Unmarshal(item, &m.Raw)
			models = append(models, m)
		}
	}
	var notAllowed NotAllowedCounts
	if parsed.NeoRouter != nil && parsed.NeoRouter.NotAllowedForKey != nil {
		notAllowed = *parsed.NeoRouter.NotAllowedForKey
	}
	return ModelListResult{Models: models, NotAllowed: notAllowed}, nil
}

// ListModels returns just the model slice from ModelList.
func (s *Service) ListModels(ctx context.Context, conn *Connection, typ string) ([]Model, error) {
	res, err := s.ModelList(ctx, conn, typ)
	if err != nil {
		return nil, err
	}
	return res.Models, nil
}

// IsDecisionModel reports whether model is a System One decision model.
func IsDecisionModel(m Model) bool {
	return m.NeoRouter != nil && m.NeoRouter.Decision
}

// Embed requests an embedding vector from NeoRouter.
func (s *Service) Embed(ctx context.Context, conn *Connection, text, inputType string) (*EmbedResult, error) {
	it := "query"
	if inputType == "document" {
		it = "document"
	}
	raw, hdr, err := s.Call(ctx, conn, "/embeddings", CallOptions{
		Method: http.MethodPost,
		Body: map[string]any{
			"model":      "auto",
			"input":      text,
			"input_type": it,
		},
		Timeout: 15 * time.Second,
	})
	if err != nil {
		return nil, err
	}
	var parsed struct {
		Model string `json:"model"`
		Data  []struct {
			Embedding []float64 `json:"embedding"`
		} `json:"data"`
	}
	if err := json.Unmarshal(raw, &parsed); err != nil || len(parsed.Data) == 0 || len(parsed.Data[0].Embedding) == 0 {
		return nil, nil
	}
	space := strings.TrimSpace(hdr.Get("x-neorouter-embedding-pin"))
	model := space
	if model == "" {
		if parsed.Model != "" {
			model = parsed.Model
		} else {
			model = "auto"
		}
	}
	return &EmbedResult{
		Vector:   parsed.Data[0].Embedding,
		Model:    model,
		ServedBy: parsed.Model,
	}, nil
}

// GenerateImages requests base64-encoded images from NeoRouter.
func (s *Service) GenerateImages(ctx context.Context, conn *Connection, prompt string, n int) ([]string, error) {
	if n <= 0 {
		n = 1
	}
	raw, _, err := s.Call(ctx, conn, "/images/generations", CallOptions{
		Method: http.MethodPost,
		Body: map[string]any{
			"model":           "auto",
			"prompt":          prompt,
			"n":               n,
			"response_format": "b64_json",
		},
		Timeout:          180 * time.Second,
		MaxResponseBytes: 64 * 1024 * 1024,
	})
	if err != nil {
		return nil, err
	}
	var parsed struct {
		Data []struct {
			B64JSON string `json:"b64_json"`
		} `json:"data"`
	}
	if err := json.Unmarshal(raw, &parsed); err != nil {
		return nil, nil
	}
	out := make([]string, 0, len(parsed.Data))
	for _, img := range parsed.Data {
		if img.B64JSON != "" {
			out = append(out, img.B64JSON)
		}
	}
	return out, nil
}

var freshnessToRecency = map[string]string{
	"pd": "day",
	"pw": "week",
	"pm": "month",
	"py": "year",
}

// SearchWeb queries NeoRouter's /v1/search endpoint.
func (s *Service) SearchWeb(ctx context.Context, conn *Connection, query string, count int, freshness string) ([]SearchResult, error) {
	if count <= 0 {
		count = 5
	}
	body := map[string]any{
		"query":       query,
		"max_results": count,
	}
	if recency, ok := freshnessToRecency[freshness]; ok {
		body["recency"] = recency
	}
	raw, _, err := s.Call(ctx, conn, "/search", CallOptions{
		Method:  http.MethodPost,
		Body:    body,
		Timeout: 20 * time.Second,
	})
	if err != nil {
		return nil, err
	}
	var parsed struct {
		Results []struct {
			Title       string `json:"title"`
			URL         string `json:"url"`
			Content     string `json:"content"`
			Snippet     string `json:"snippet"`
			Description string `json:"description"`
		} `json:"results"`
	}
	if err := json.Unmarshal(raw, &parsed); err != nil {
		return nil, nil
	}
	out := make([]SearchResult, 0, len(parsed.Results))
	for i, item := range parsed.Results {
		desc := item.Content
		if desc == "" {
			desc = item.Snippet
		}
		if desc == "" {
			desc = item.Description
		}
		out = append(out, SearchResult{
			Rank:        i + 1,
			Title:       item.Title,
			URL:         item.URL,
			Description: desc,
		})
	}
	return out, nil
}
