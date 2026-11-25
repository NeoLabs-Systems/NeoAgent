package google

import (
	"context"
	"fmt"
	"net/url"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
)

func documentToText(doc map[string]any) string {
	var b strings.Builder
	content, _ := integrations.Get(doc, "body", "content").([]any)
	for _, block := range content {
		elements, _ := integrations.Get(block, "paragraph", "elements").([]any)
		for _, el := range elements {
			b.WriteString(integrations.Str(integrations.Get(el, "textRun", "content")))
		}
	}
	return jsTrim(b.String())
}

func (s *session) docsURL(rest string) string { return s.p.ep.docs + "/v1/documents" + rest }

// insertText appends text to the end of a document body.
func (s *session) insertText(ctx context.Context, documentID, text string) (response, error) {
	return s.call(ctx, "POST", s.docsURL("/"+url.PathEscape(documentID)+":batchUpdate"), nil, map[string]any{
		"requests": []any{map[string]any{"insertText": map[string]any{"endOfSegmentLocation": map[string]any{}, "text": text}}},
	})
}

func (s *session) docs(ctx context.Context, name string, args map[string]any) (any, error) {
	switch name {
	case "google_workspace_docs_get_document":
		id, err := requireNonEmpty(args["document_id"], "document_id")
		if err != nil {
			return nil, err
		}
		res, err := s.call(ctx, "GET", s.docsURL("/"+url.PathEscape(id)), nil, nil)
		if err != nil {
			return nil, err
		}
		doc := res.object()
		return struct {
			DocumentID string `json:"documentId"`
			Title      string `json:"title"`
			Text       string `json:"text"`
		}{orDefault(textOf(doc["documentId"]), id), textOf(doc["title"]), documentToText(doc)}, nil

	case "google_workspace_docs_create_document":
		title, err := requireNonEmpty(args["title"], "title")
		if err != nil {
			return nil, err
		}
		res, err := s.call(ctx, "POST", s.docsURL(""), nil, map[string]any{"title": title})
		if err != nil {
			return nil, err
		}
		created := res.object()
		id := textOf(created["documentId"])
		resultTitle := orDefault(textOf(created["title"]), title)
		if integrations.Truthy(args["initial_text"]) {
			if _, err := s.insertText(ctx, id, integrations.Str(args["initial_text"])); err != nil {
				msg := err.Error()
				if msg == "" {
					msg = "Initial document content could not be written."
				}
				return struct {
					DocumentID  string `json:"documentId"`
					Title       string `json:"title"`
					Created     bool   `json:"created"`
					Initialized bool   `json:"initialized"`
					Error       string `json:"error"`
				}{id, resultTitle, true, false, msg}, nil
			}
		}
		return struct {
			DocumentID string `json:"documentId"`
			Title      string `json:"title"`
		}{id, resultTitle}, nil

	case "google_workspace_docs_append_text":
		id, err := requireNonEmpty(args["document_id"], "document_id")
		if err != nil {
			return nil, err
		}
		if _, err := s.insertText(ctx, id, textOf(args["text"])); err != nil {
			return nil, err
		}
		return struct {
			DocumentID string `json:"documentId"`
			Appended   bool   `json:"appended"`
		}{id, true}, nil

	case "google_workspace_docs_replace_text":
		id, err := requireNonEmpty(args["document_id"], "document_id")
		if err != nil {
			return nil, err
		}
		search, err := requireNonEmpty(args["search_text"], "search_text")
		if err != nil {
			return nil, err
		}
		res, err := s.call(ctx, "POST", s.docsURL("/"+url.PathEscape(id)+":batchUpdate"), nil, map[string]any{
			"requests": []any{map[string]any{"replaceAllText": map[string]any{
				"containsText": map[string]any{"text": search, "matchCase": true},
				"replaceText":  textOf(args["replace_text"]),
			}}},
		})
		if err != nil {
			return nil, err
		}
		var changed float64
		if replies, ok := res.object()["replies"].([]any); ok && len(replies) > 0 {
			changed, _ = integrations.JSNumber(integrations.Or(integrations.Get(replies[0], "replaceAllText", "occurrencesChanged"), 0.0))
		}
		return struct {
			DocumentID         string  `json:"documentId"`
			OccurrencesChanged float64 `json:"occurrencesChanged"`
		}{id, changed}, nil

	case "google_workspace_docs_api_request":
		return s.apiRequest(ctx, args, s.p.ep.docs)
	}
	return nil, fmt.Errorf("Unknown tool: %s", name)
}
