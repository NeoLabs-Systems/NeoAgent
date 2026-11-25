package nextcloud

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"math"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/dav"
)

const (
	maxUploadBytes = 100 * 1024 * 1024
	maxReadBytes   = 512 * 1024
)

const propfindBody = `<?xml version="1.0"?>
<d:propfind xmlns:d="DAV:" xmlns:oc="http://owncloud.org/ns" xmlns:nc="http://nextcloud.org/ns">
  <d:prop>
    <d:displayname/>
    <d:getcontentlength/>
    <d:getcontenttype/>
    <d:getlastmodified/>
    <d:resourcetype/>
    <oc:fileid/>
    <nc:trashbin-deletion-time/>
    <nc:trashbin-original-filename/>
    <nc:trashbin-original-location/>
  </d:prop>
</d:propfind>`

var utf16Charset = regexp.MustCompile(`(?i)charset=utf-16`)

func davPath(kind, username string, remote any) (string, error) {
	user, err := integrations.RequireText(username, "username")
	if err != nil {
		return "", err
	}
	enc, err := dav.EncodePathSegments(remote)
	if err != nil {
		return "", err
	}
	out := "/remote.php/dav/" + kind + "/" + dav.EncodeURIComponent(user)
	if enc != "" {
		out += "/" + enc
	}
	return out, nil
}

func nullable(s string) any {
	if strings.TrimSpace(s) == "" {
		return nil
	}
	return strings.TrimSpace(s)
}

func summarize(e dav.Entry, username, kind string) dyn.Ordered {
	prefix := "/remote.php/dav/files/" + username + "/"
	if kind == "trash" {
		prefix = "/remote.php/dav/trashbin/" + username + "/"
	}
	remote := dav.HrefToRemotePath(e.Href, prefix)
	name := strings.TrimSpace(e.DisplayName)
	if name == "" {
		parts := strings.Split(remote, "/")
		name = parts[len(parts)-1]
		if name == "" {
			name = "/"
		}
	}
	typ := "file"
	if e.IsCollection {
		typ = "folder"
	}
	var size any
	if e.ContentLength != "" {
		if n, ok := integrations.JSNumber(e.ContentLength); ok {
			size = n
		}
	}
	return dyn.Ordered{
		{Key: "path", Value: remote}, {Key: "name", Value: name}, {Key: "type", Value: typ}, {Key: "size", Value: size},
		{Key: "mimeType", Value: nullable(e.ContentType)}, {Key: "lastModified", Value: nullable(e.LastModified)},
		{Key: "fileId", Value: nullable(e.FileID)}, {Key: "deletedAt", Value: nullable(e.TrashDeletedAt)},
		{Key: "originalPath", Value: nullable(e.TrashOriginalPath)},
	}
}

func (p *Provider) list(ctx context.Context, a account, path, kind string) ([]dyn.Ordered, error) {
	collection := path
	if !strings.HasSuffix(collection, "/") {
		collection += "/"
	}
	res, err := p.dav(ctx, a, collection, davOpts{method: "PROPFIND",
		headers: map[string]string{"Depth": "1", "Content-Type": "application/xml; charset=utf-8"}, body: []byte(propfindBody)})
	if err != nil {
		return nil, err
	}
	prefix := "/remote.php/dav/files/" + a.username + "/"
	if kind == "trash" {
		prefix = "/remote.php/dav/trashbin/" + a.username + "/"
	}
	self := dav.HrefToRemotePath(path, prefix)
	out := []dyn.Ordered{}
	for _, e := range dav.ParseResponses(string(res.body)) {
		if !e.OK {
			continue
		}
		entry := summarize(e, a.username, kind)
		if entry.Get("path") != self {
			out = append(out, entry)
		}
	}
	return out, nil
}

func normalized(v any) string {
	out, _ := dav.NormalizeRemotePath(v)
	return out
}

func hasParent(path string) bool {
	for _, part := range regexp.MustCompile(`[\\/]+`).Split(path, -1) {
		if part == ".." {
			return true
		}
	}
	return false
}

func readableFile(value any) (string, int64, error) {
	raw := text(value)
	if raw == "" {
		return "", 0, errors.New("file_path is required.")
	}
	if hasParent(raw) {
		return "", 0, errors.New("file_path must not contain parent traversal segments.")
	}
	resolved, err := filepath.Abs(raw)
	if err != nil {
		return "", 0, err
	}
	info, err := os.Stat(resolved)
	if err != nil {
		return "", 0, err
	}
	if !info.Mode().IsRegular() {
		return "", 0, errors.New("file_path must point to a readable file.")
	}
	if info.Size() > maxUploadBytes {
		return "", 0, fmt.Errorf("file_path exceeds the %d-byte upload limit.", maxUploadBytes)
	}
	return resolved, info.Size(), nil
}

func (p *Provider) files(ctx context.Context, name string, args map[string]any, creds map[string]any) (any, bool, error) {
	if !strings.HasPrefix(name, "nextcloud_") {
		return nil, false, nil
	}
	a, err := parseAccount(creds)
	if err != nil {
		return nil, true, err
	}
	filePath := func(remote any) (string, error) { return davPath("files", a.username, remote) }
	switch name {
	case "nextcloud_list_files":
		path, err := filePath(args["path"])
		if err != nil {
			return nil, true, err
		}
		out, err := p.list(ctx, a, path, "files")
		return out, true, err
	case "nextcloud_search_files":
		query, err := integrations.RequireText(args["query"], "query")
		if err != nil {
			return nil, true, err
		}
		n, ok := integrations.JSNumber(args["limit"])
		if !ok || n == 0 {
			n = 20
		}
		n = max(1, min(n, 100))
		out, err := p.ocs(ctx, a, "/ocs/v2.php/search/providers/files/search", ocsOpts{ordered: []queryPair{{"term", query}, {"limit", n}}, service: "Nextcloud search"})
		return out, true, err
	case "nextcloud_read_file":
		path, err := filePath(args["path"])
		if err != nil {
			return nil, true, err
		}
		res, err := p.dav(ctx, a, path, davOpts{method: "GET", maxBytes: maxReadBytes})
		if err != nil {
			return nil, true, err
		}
		contentType := res.header.Get("Content-Type")
		if utf16Charset.MatchString(contentType) || bytes.IndexByte(res.body, 0) >= 0 {
			return dyn.Ordered{{Key: "path", Value: normalized(args["path"])}, {Key: "binary", Value: true}, {Key: "size", Value: len(res.body)},
				{Key: "note", Value: "Use nextcloud_download_file for binary content."}}, true, nil
		}
		return dyn.Ordered{{Key: "path", Value: normalized(args["path"])}, {Key: "mimeType", Value: nullable(contentType)},
			{Key: "content", Value: strings.ToValidUTF8(string(res.body), "�")}, {Key: "size", Value: len(res.body)}}, true, nil
	case "nextcloud_download_file":
		dest, err := integrations.RequireText(args["destination_path"], "destination_path")
		if err != nil {
			return nil, true, err
		}
		destination, err := filepath.Abs(dest)
		if err != nil {
			return nil, true, err
		}
		if hasParent(destination) {
			return nil, true, errors.New("destination_path must not contain parent traversal segments.")
		}
		path, err := filePath(args["path"])
		if err != nil {
			return nil, true, err
		}
		res, err := p.dav(ctx, a, path, davOpts{method: "GET"})
		if err != nil {
			return nil, true, err
		}
		if err := os.MkdirAll(filepath.Dir(destination), 0o700); err != nil {
			return nil, true, err
		}
		if err := os.WriteFile(destination, res.body, 0o600); err != nil {
			return nil, true, err
		}
		return dyn.Ordered{{Key: "path", Value: normalized(args["path"])}, {Key: "destination_path", Value: destination}, {Key: "size", Value: len(res.body)}}, true, nil
	case "nextcloud_upload_file":
		local, size, err := readableFile(args["file_path"])
		if err != nil {
			return nil, true, err
		}
		body, err := os.ReadFile(local)
		if err != nil {
			return nil, true, err
		}
		path, err := filePath(args["path"])
		if err != nil {
			return nil, true, err
		}
		if _, err := p.dav(ctx, a, path, davOpts{method: "PUT", headers: map[string]string{"Content-Type": "application/octet-stream"}, body: body}); err != nil {
			return nil, true, err
		}
		return dyn.Ordered{{Key: "path", Value: normalized(args["path"])}, {Key: "size", Value: size}}, true, nil
	case "nextcloud_write_file":
		path, err := filePath(args["path"])
		if err != nil {
			return nil, true, err
		}
		content := ""
		if args["content"] != nil {
			content = integrations.Str(args["content"])
		}
		if _, err := p.dav(ctx, a, path, davOpts{method: "PUT", headers: map[string]string{"Content-Type": "text/plain; charset=utf-8"}, body: []byte(content)}); err != nil {
			return nil, true, err
		}
		return dyn.Ordered{{Key: "path", Value: normalized(args["path"])}}, true, nil
	case "nextcloud_mkdir":
		path, err := filePath(args["path"])
		if err != nil {
			return nil, true, err
		}
		if _, err := p.dav(ctx, a, path, davOpts{method: "MKCOL"}); err != nil {
			return nil, true, err
		}
		return dyn.Ordered{{Key: "path", Value: normalized(args["path"])}, {Key: "type", Value: "folder"}}, true, nil
	case "nextcloud_move_file", "nextcloud_copy_file":
		destination, err := filePath(args["destination"])
		if err != nil {
			return nil, true, err
		}
		path, err := filePath(args["path"])
		if err != nil {
			return nil, true, err
		}
		method, overwrite := "COPY", "F"
		if name == "nextcloud_move_file" {
			method = "MOVE"
		}
		if args["overwrite"] == true {
			overwrite = "T"
		}
		if _, err := p.dav(ctx, a, path, davOpts{method: method, headers: map[string]string{"Destination": a.baseURL + destination, "Overwrite": overwrite}}); err != nil {
			return nil, true, err
		}
		return dyn.Ordered{{Key: "path", Value: normalized(args["destination"])}, {Key: "from", Value: normalized(args["path"])}}, true, nil
	case "nextcloud_delete_file":
		path, err := filePath(args["path"])
		if err != nil {
			return nil, true, err
		}
		if _, err := p.dav(ctx, a, path, davOpts{method: "DELETE"}); err != nil {
			return nil, true, err
		}
		return dyn.Ordered{{Key: "deleted", Value: true}, {Key: "path", Value: normalized(args["path"])}}, true, nil
	case "nextcloud_list_shares":
		var query []queryPair
		if text(args["path"]) != "" {
			query = append(query, queryPair{"path", "/" + normalized(args["path"])})
		}
		if args["shared_with_me"] == true {
			query = append(query, queryPair{"shared_with_me", "true"})
		}
		out, err := p.ocs(ctx, a, "/ocs/v2.php/apps/files_sharing/api/v1/shares", ocsOpts{ordered: query, service: "Nextcloud shares"})
		return out, true, err
	case "nextcloud_create_share":
		form := [][2]string{{"path", "/" + normalized(args["path"])}}
		form = append(form, [2]string{"shareType", numberArg(args, "share_type", 3)})
		if v := text(args["share_with"]); v != "" {
			form = append(form, [2]string{"shareWith", v})
		}
		form = append(form, [2]string{"permissions", numberArg(args, "permissions", 1)})
		for _, f := range [][2]string{{"password", "password"}, {"expireDate", "expire_date"}, {"note", "note"}} {
			if v := text(args[f[1]]); v != "" {
				form = append(form, [2]string{f[0], v})
			}
		}
		out, err := p.ocs(ctx, a, "/ocs/v2.php/apps/files_sharing/api/v1/shares", ocsOpts{method: "POST", form: form, service: "Nextcloud share create"})
		return out, true, err
	case "nextcloud_delete_share":
		id, err := integrations.RequireText(args["share_id"], "share_id")
		if err != nil {
			return nil, true, err
		}
		if _, err := p.ocs(ctx, a, "/ocs/v2.php/apps/files_sharing/api/v1/shares/"+dav.EncodeURIComponent(id), ocsOpts{method: "DELETE", service: "Nextcloud share delete"}); err != nil {
			return nil, true, err
		}
		return dyn.Ordered{{Key: "deleted", Value: true}, {Key: "share_id", Value: text(args["share_id"])}}, true, nil
	case "nextcloud_list_trash":
		path, err := davPath("trashbin", a.username, "trash")
		if err != nil {
			return nil, true, err
		}
		out, err := p.list(ctx, a, path, "trash")
		return out, true, err
	case "nextcloud_restore_trash":
		trash, err := davPath("trashbin", a.username, args["trash_path"])
		if err != nil {
			return nil, true, err
		}
		parts := strings.Split(normalized(args["trash_path"]), "/")
		restore, err := davPath("trashbin", a.username, "restore/"+parts[len(parts)-1])
		if err != nil {
			return nil, true, err
		}
		if _, err := p.dav(ctx, a, trash, davOpts{method: "MOVE", headers: map[string]string{"Destination": a.baseURL + restore}}); err != nil {
			return nil, true, err
		}
		return dyn.Ordered{{Key: "restored", Value: true}, {Key: "trash_path", Value: normalized(args["trash_path"])}}, true, nil
	case "nextcloud_ocs_request":
		path, err := integrations.RequireText(args["path"], "path")
		if err != nil {
			return nil, true, err
		}
		query, _ := args["query"].(map[string]any)
		body, _ := args["body"].(map[string]any)
		o := ocsOpts{method: args["method"], query: query}
		if body != nil {
			o.json = body
		}
		out, err := p.ocs(ctx, a, path, o)
		return out, true, err
	}
	return nil, false, nil
}

// numberArg is Number.isFinite(Number(args[key])) ? Number(...) : fallback,
// as text; an absent member is NaN, a null one 0.
func numberArg(args map[string]any, key string, fallback float64) string {
	if v, present := args[key]; present {
		if n, ok := integrations.JSNumber(v); ok && !math.IsInf(n, 0) {
			return dyn.Number(n)
		}
	}
	return dyn.Number(fallback)
}
