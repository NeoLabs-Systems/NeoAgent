// Package neocloud implements the NeoCloud integration: a self-hosted NeoCloud
// server connected through the companion OAuth contract, with file, PDF and
// e-signature tools. Only the tools a connection's grant allows are offered.
package neocloud

import (
	"context"
	_ "embed"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/companion"
	"github.com/NeoLabs-Systems/neolabs-go/oauthclient"
	"github.com/NeoLabs-Systems/neolabs-go/ssrf"
)

//go:embed provider.json
var specJSON []byte

var scopes = []string{"files:read", "files:write", "signing:read", "signing:write"}

// Options are the seams; the zero value is production.
type Options struct {
	// HTTP reaches the server; nil allows private addresses, as NeoCloud is
	// usually self-hosted on the person's own network.
	HTTP *http.Client
	Now  func() time.Time
}

type provider struct {
	*companion.Provider
	server    companion.Server
	toolScope map[string]string
}

// New builds the provider.
func New(svc *integrations.Services, o Options) integrations.Provider {
	client := o.HTTP
	if client == nil {
		client = ssrf.NewClient(ssrf.Options{AllowPrivate: true})
	}
	spec := integrations.LoadSpec(specJSON)
	p := &provider{
		server:    companion.Server{Label: "NeoCloud", URLLabel: "NeoCloud server URL", HTTP: client, Now: o.Now},
		toolScope: map[string]string{},
	}
	for _, raw := range spec.Tools {
		var t struct{ Name, Scope string }
		_ = json.Unmarshal(raw, &t)
		p.toolScope[t.Name] = t.Scope
	}
	p.Provider = companion.NewProvider(svc, companion.Product{
		Spec:           spec,
		Server:         p.server,
		ReadySummary:   "NeoCloud is ready for account connections.",
		MissingSummary: "Add the NeoCloud server URL to enable file and signature tools.",
		HealthCheck:    healthCheck,
		AuthorizeScope: func(map[string]any) string { return strings.Join(scopes, " ") },
		GrantedScopes:  grantedScopes,
		Execute:        p.execute,
		FilterTools:    p.filterTools,
		Summarize:      summarize,
	})
	return p
}

func healthCheck(ctx context.Context, s companion.Server, baseURL string) error {
	health, _, err := s.Fetch(ctx, "NeoCloud health check", oauthclient.Request{Method: "GET", URL: baseURL + "/api/health"})
	if err != nil {
		return err
	}
	version, _, err := s.Fetch(ctx, "NeoCloud version check", oauthclient.Request{Method: "GET", URL: baseURL + "/api/version"})
	if err != nil {
		return err
	}
	if companion.Text(health["status"]) != "ok" || companion.Text(version["product"]) != "neocloud" {
		return errors.New("The configured endpoint did not identify itself as a healthy NeoCloud server.")
	}
	return nil
}

func grantedScopes(issued, info map[string]any) ([]string, string, error) {
	granted := companion.SplitScopes(integrations.Or(issued["scope"], info["scope"]))
	if len(granted) == 0 {
		return nil, "", errors.New("NeoCloud did not report which access was granted.")
	}
	return granted, strings.Join(granted, " "), nil
}

func (p *provider) allows(conn integrations.Connection, t integrations.Tool) bool {
	if !companion.DecodeScopes(conn)[p.toolScope[t.Name]] {
		return false
	}
	return t.Access == "read" || integrations.AccessMode(&conn) != integrations.AccessReadOnly
}

func (p *provider) filterTools(tools []integrations.Tool, connections []integrations.Connection) []integrations.Tool {
	var out []integrations.Tool
	for _, t := range tools {
		for _, c := range connections {
			if p.allows(c, t) {
				out = append(out, t)
				break
			}
		}
	}
	return out
}

func summarize(s integrations.Snapshot) string {
	switch {
	case !s.Env.Configured:
		return "NeoCloud: setup is not complete yet."
	case !s.Connection.Connected:
		return "NeoCloud: setup is ready, but no NeoCloud account is connected."
	}
	return strings.Join([]string{
		"NeoCloud: connected. It is the user's own cloud drive and e-signature service.",
		"Use neocloud_list_files, neocloud_search_files and neocloud_read_file to find and read their files,",
		"and the write tools to save files, folders and PDFs (neocloud_create_pdf turns Markdown into a PDF).",
		"For \"write a quick contract and send me the links for my friend to sign\", call neocloud_request_signatures",
		"once with document { path, title, markdown } and the signers (name, optional email); NeoCloud saves the PDF,",
		"adds the signature block and returns each signer's private url. Reply with every signer's name and url so",
		"the user can forward them; the links are private and are only returned once. Use",
		"neocloud_get_signature_request to check who has signed. Only the tools this account granted are offered.",
	}, " ")
}

// call is one request on NeoCloud's /api/v1.
type call struct {
	method, path string
	json         any
}

func id(v any, name string) (string, error) {
	t, err := companion.Required(v, name)
	return companion.EncodeComponent(t), err
}

func contentBody(args map[string]any) (companion.Ordered, error) {
	content, hasContent := args["content"]
	encoded, hasEncoded := args["content_base64"]
	if !hasContent && !hasEncoded {
		return nil, errors.New("content or content_base64 is required.")
	}
	if hasEncoded {
		return companion.Ordered{{"contentBase64", jsString(encoded)}}, nil
	}
	return companion.Ordered{{"content", jsString(content)}}, nil
}

// jsString is String(value), with null as "null".
func jsString(v any) string {
	if v == nil {
		return "null"
	}
	return integrations.Str(v)
}

func signingRequestBody(args map[string]any) (companion.Ordered, error) {
	// Any object counts as a document, as typeof does; an array has no fields.
	doc, hasDocument := args["document"].(map[string]any)
	if _, isList := args["document"].([]any); isList {
		hasDocument, doc = true, map[string]any{}
	}
	fileID := companion.Text(args["file_id"])
	if hasDocument == (fileID != "") {
		return nil, errors.New("Pass exactly one of document or file_id.")
	}
	signers := []any{}
	list, _ := args["signers"].([]any)
	for _, raw := range list {
		signer, _ := raw.(map[string]any)
		entry := companion.Compact(companion.Ordered{{"name", companion.Text(signer["name"])}, {"email", companion.Text(signer["email"])}})
		if len(entry) > 0 && entry[0][0] == "name" {
			signers = append(signers, entry)
		}
	}
	if len(signers) == 0 {
		return nil, errors.New("At least one signer with a name is required.")
	}
	var document any
	if hasDocument {
		path, err := companion.Required(doc["path"], "document.path")
		if err != nil {
			return nil, err
		}
		title, err := companion.Required(doc["title"], "document.title")
		if err != nil {
			return nil, err
		}
		markdown, err := companion.Required(doc["markdown"], "document.markdown")
		if err != nil {
			return nil, err
		}
		document = companion.Ordered{{"path", path}, {"title", title}, {"markdown", markdown}}
	}
	var file any
	if fileID != "" {
		file = fileID
	}
	return companion.Compact(companion.Ordered{
		{"fileId", file}, {"document", document}, {"title", companion.Text(args["title"])}, {"signers", signers},
		{"message", companion.Text(args["message"])}, {"sendEmail", args["send_email"] == true},
		{"expiresInDays", args["expires_in_days"]}, {"signingOrder", companion.Text(args["signing_order"])},
	}), nil
}

func toolRequest(name string, args map[string]any) (call, error) {
	text := companion.Text
	switch name {
	case "neocloud_list_files":
		path := text(args["path"])
		if path == "" {
			path = "/"
		}
		return call{method: "GET", path: companion.AppendQuery("/api/v1/files", companion.Ordered{{"path", path}})}, nil
	case "neocloud_search_files":
		q, err := companion.Required(args["query"], "query")
		if err != nil {
			return call{}, err
		}
		return call{method: "GET", path: companion.AppendQuery("/api/v1/files/search", companion.Ordered{{"q", q}, {"limit", args["limit"]}})}, nil
	case "neocloud_read_file":
		fid, err := id(args["file_id"], "file_id")
		return call{method: "GET", path: "/api/v1/files/" + fid + "/content"}, err
	case "neocloud_create_file":
		path, err := companion.Required(args["path"], "path")
		if err != nil {
			return call{}, err
		}
		body, err := contentBody(args)
		if err != nil {
			return call{}, err
		}
		json := append(append(companion.Ordered{{"path", path}}, body...), [2]any{"overwrite", args["overwrite"] == true})
		return call{method: "POST", path: "/api/v1/files", json: json}, nil
	case "neocloud_update_file":
		fid, err := id(args["file_id"], "file_id")
		if err != nil {
			return call{}, err
		}
		body, err := contentBody(args)
		if err != nil {
			return call{}, err
		}
		return call{method: "PUT", path: "/api/v1/files/" + fid + "/content", json: companion.Compact(append(body, [2]any{"baseRevision", text(args["base_revision"])}))}, nil
	case "neocloud_create_folder":
		path, err := companion.Required(args["path"], "path")
		return call{method: "POST", path: "/api/v1/folders", json: companion.Ordered{{"path", path}}}, err
	case "neocloud_move_file":
		fid, err := id(args["file_id"], "file_id")
		if err != nil {
			return call{}, err
		}
		json := companion.Compact(companion.Ordered{{"name", text(args["name"])}, {"parentPath", text(args["parent_path"])}})
		if len(json) == 0 {
			return call{}, errors.New("name or parent_path is required.")
		}
		return call{method: "PATCH", path: "/api/v1/files/" + fid, json: json}, nil
	case "neocloud_delete_file":
		fid, err := id(args["file_id"], "file_id")
		return call{method: "DELETE", path: "/api/v1/files/" + fid}, err
	case "neocloud_create_pdf":
		path, err := companion.Required(args["path"], "path")
		if err != nil {
			return call{}, err
		}
		title := text(args["title"])
		markdown, err := companion.Required(args["markdown"], "markdown")
		if err != nil {
			return call{}, err
		}
		return call{method: "POST", path: "/api/v1/documents/pdf", json: companion.Compact(companion.Ordered{
			{"path", path}, {"title", title}, {"markdown", markdown}, {"overwrite", args["overwrite"] == true},
		})}, nil
	case "neocloud_request_signatures":
		body, err := signingRequestBody(args)
		return call{method: "POST", path: "/api/v1/signing/requests", json: body}, err
	case "neocloud_list_signature_requests":
		return call{method: "GET", path: companion.AppendQuery("/api/v1/signing/requests", companion.Ordered{{"status", text(args["status"])}, {"limit", args["limit"]}})}, nil
	case "neocloud_get_signature_request", "neocloud_remind_signers", "neocloud_cancel_signature_request":
		rid, err := id(args["request_id"], "request_id")
		if err != nil {
			return call{}, err
		}
		switch name {
		case "neocloud_get_signature_request":
			return call{method: "GET", path: "/api/v1/signing/requests/" + rid}, nil
		case "neocloud_remind_signers":
			return call{method: "POST", path: "/api/v1/signing/requests/" + rid + "/remind"}, nil
		}
		return call{method: "POST", path: "/api/v1/signing/requests/" + rid + "/cancel"}, nil
	case "neocloud_new_signing_link":
		rid, err := id(args["request_id"], "request_id")
		if err != nil {
			return call{}, err
		}
		sid, err := id(args["signer_id"], "signer_id")
		return call{method: "POST", path: "/api/v1/signing/requests/" + rid + "/signers/" + sid + "/link"}, err
	}
	return call{}, fmt.Errorf("Unsupported NeoCloud tool: %s", name)
}

// failure is the result of a call that failed after the credentials were
// renewed: NeoCloud rotates refresh tokens, so the renewal must still be
// stored, which only a result can carry.
type failure struct {
	Error  string `json:"error"`
	Code   string `json:"code,omitempty"`
	Status int    `json:"status,omitempty"`
}

func (p *provider) execute(ctx context.Context, name string, args map[string]any, tc *integrations.ToolContext) (any, error) {
	if scope := p.toolScope[name]; scope != "" && !companion.DecodeScopes(tc.Connection)[scope] {
		return nil, fmt.Errorf("This NeoCloud account did not grant %s. Reconnect it and allow that access on NeoCloud's consent page.", scope)
	}
	c, err := toolRequest(name, args)
	if err != nil {
		return nil, err
	}
	auth, err := p.server.Authenticate(ctx, tc.Credentials)
	if err != nil {
		return nil, err
	}
	if auth.Refreshed {
		tc.UpdateCredentials(auth.Credentials)
	}
	_, value, err := p.server.Fetch(ctx, "NeoCloud API", oauthclient.Request{
		Method: c.method, URL: auth.BaseURL + c.path, JSON: c.json,
		Header: map[string]string{"Authorization": "Bearer " + auth.AccessToken},
	})
	if err != nil {
		var apiErr *oauthclient.Error
		code, status := "", 0
		if errors.As(err, &apiErr) {
			code, status = companion.Text(apiErr.Data["code"]), apiErr.Status
		}
		msg := err.Error()
		if code != "" && !strings.Contains(msg, code) {
			msg += " (" + code + ")"
		}
		if !auth.Refreshed || ctx.Err() != nil {
			if msg == err.Error() {
				return nil, err
			}
			return nil, errors.New(msg)
		}
		return failure{Error: msg, Code: code, Status: status}, nil
	}
	if value == nil {
		return map[string]any{"ok": true}, nil
	}
	return value, nil
}
