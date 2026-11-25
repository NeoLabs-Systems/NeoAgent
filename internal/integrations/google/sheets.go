package google

import (
	"context"
	"fmt"
	"net/url"

	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neolabs-go/oauthclient"
)

func (s *session) sheetsURL(rest string) string { return s.p.ep.sheets + "/v4/spreadsheets" + rest }

func listOrEmpty(v any) []any {
	if list, ok := v.([]any); ok {
		return list
	}
	return []any{}
}

func (s *session) sheets(ctx context.Context, name string, args map[string]any) (any, error) {
	out, err := s.sheetsCall(ctx, name, args)
	if err != nil {
		msg := err.Error()
		if msg == "" {
			msg = "Unknown error."
		}
		// The wrapped error carries no status, so the model gets the text only.
		return nil, fmt.Errorf("Google Sheets request failed for %s (spreadsheet_id=%s, range=%s): %s",
			name, orDefault(textOf(args["spreadsheet_id"]), "n/a"), orDefault(textOf(args["range"]), "n/a"), msg)
	}
	return out, nil
}

func (s *session) sheetsCall(ctx context.Context, name string, args map[string]any) (any, error) {
	id := url.PathEscape(textOf(args["spreadsheet_id"]))
	rng := url.PathEscape(textOf(args["range"]))
	switch name {
	case "google_workspace_sheets_get_values":
		res, err := s.call(ctx, "GET", s.sheetsURL("/"+id+"/values/"+rng), nil, nil)
		if err != nil {
			return nil, err
		}
		data := res.object()
		return struct {
			Range          string `json:"range"`
			MajorDimension string `json:"majorDimension"`
			Values         []any  `json:"values"`
		}{orDefault(textOf(data["range"]), textOf(args["range"])), orDefault(textOf(data["majorDimension"]), "ROWS"), listOrEmpty(data["values"])}, nil

	case "google_workspace_sheets_update_values":
		res, err := s.call(ctx, "PUT", s.sheetsURL("/"+id+"/values/"+rng), oauthclient.Query{{"valueInputOption", "USER_ENTERED"}},
			map[string]any{"values": listOrEmpty(args["values"])})
		if err != nil {
			return nil, err
		}
		data := res.object()
		return struct {
			UpdatedRange   string `json:"updatedRange"`
			UpdatedRows    any    `json:"updatedRows"`
			UpdatedColumns any    `json:"updatedColumns"`
			UpdatedCells   any    `json:"updatedCells"`
		}{orDefault(textOf(data["updatedRange"]), textOf(args["range"])),
			integrations.Or(data["updatedRows"], 0.0), integrations.Or(data["updatedColumns"], 0.0), integrations.Or(data["updatedCells"], 0.0)}, nil

	case "google_workspace_sheets_append_rows":
		res, err := s.call(ctx, "POST", s.sheetsURL("/"+id+"/values/"+rng+":append"),
			oauthclient.Query{{"valueInputOption", "USER_ENTERED"}, {"insertDataOption", "INSERT_ROWS"}},
			map[string]any{"values": listOrEmpty(args["rows"])})
		if err != nil {
			return nil, err
		}
		data := res.object()
		return struct {
			TableRange any `json:"tableRange"`
			Updates    any `json:"updates"`
		}{integrations.Or(data["tableRange"], nil), integrations.Or(data["updates"], nil)}, nil

	case "google_workspace_sheets_create_spreadsheet":
		body := map[string]any{"properties": map[string]any{"title": textOf(args["title"])}}
		if titles, ok := args["sheet_titles"].([]any); ok {
			sheets := []any{}
			for _, t := range titles {
				if title := trimmed(t); title != "" {
					sheets = append(sheets, map[string]any{"properties": map[string]any{"title": title}})
				}
			}
			body["sheets"] = sheets
		}
		res, err := s.call(ctx, "POST", s.sheetsURL(""), nil, body)
		if err != nil {
			return nil, err
		}
		data := res.object()
		return struct {
			SpreadsheetID  any    `json:"spreadsheetId"`
			SpreadsheetURL any    `json:"spreadsheetUrl"`
			Title          string `json:"title"`
		}{integrations.Or(data["spreadsheetId"], nil), integrations.Or(data["spreadsheetUrl"], nil),
			orDefault(integrations.Str(integrations.Get(data, "properties", "title")), textOf(args["title"]))}, nil

	case "google_workspace_sheets_api_request":
		return s.apiRequest(ctx, args, s.p.ep.sheets)
	}
	return nil, fmt.Errorf("Unknown tool: %s", name)
}
