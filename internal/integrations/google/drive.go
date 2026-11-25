package google

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"mime/multipart"
	"net/textproto"
	"net/url"
	"os"
	"path/filepath"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neolabs-go/oauthclient"
)

const (
	fileFields    = "id,name,mimeType,modifiedTime,size,webViewLink,webContentLink,parents"
	maxUploadSize = 256 << 20
	maxDownload   = 512 << 20
)

type fileSummary struct {
	ID             *string  `json:"id"`
	Name           string   `json:"name"`
	MimeType       *string  `json:"mimeType"`
	ModifiedTime   *string  `json:"modifiedTime"`
	Size           any      `json:"size"`
	WebViewLink    *string  `json:"webViewLink"`
	WebContentLink *string  `json:"webContentLink"`
	Parents        []string `json:"parents"`
}

func summarizeFile(file map[string]any) fileSummary {
	opt := func(key string) *string {
		if integrations.Truthy(file[key]) {
			s := integrations.Str(file[key])
			return &s
		}
		return nil
	}
	f := fileSummary{
		ID: opt("id"), Name: textOf(file["name"]), MimeType: opt("mimeType"), ModifiedTime: opt("modifiedTime"),
		WebViewLink: opt("webViewLink"), WebContentLink: opt("webContentLink"), Parents: []string{},
	}
	if file["size"] != nil {
		if n, ok := integrations.JSNumber(file["size"]); ok {
			f.Size = n
		}
	}
	if list, ok := file["parents"].([]any); ok {
		for _, p := range list {
			f.Parents = append(f.Parents, integrations.Str(p))
		}
	}
	return f
}

func requireNonEmpty(value any, label string) (string, error) {
	v := trimmed(value)
	if v == "" {
		return "", fmt.Errorf("%s is required.", label)
	}
	return v, nil
}

func validateReadableFile(filePath any) (string, error) {
	normalized := trimmed(filePath)
	if normalized == "" {
		return "", errors.New("file_path is required.")
	}
	for _, segment := range strings.FieldsFunc(normalized, func(r rune) bool { return r == '/' || r == '\\' }) {
		if segment == ".." {
			return "", errors.New("file_path must not contain parent traversal segments.")
		}
	}
	resolved, err := filepath.Abs(normalized)
	if err != nil {
		return "", err
	}
	info, err := os.Stat(resolved)
	if err != nil {
		return "", err
	}
	if !info.Mode().IsRegular() {
		return "", errors.New("file_path must point to a readable file.")
	}
	return resolved, nil
}

func requireDestination(value any, label string) (string, error) {
	v, err := requireNonEmpty(value, label)
	if err != nil {
		return "", err
	}
	return filepath.Abs(v)
}

func writeDownloaded(destination string, data []byte) error {
	if err := os.MkdirAll(filepath.Dir(destination), 0o755); err != nil {
		return err
	}
	return os.WriteFile(destination, data, 0o644)
}

func (s *session) driveURL(rest string) string { return s.p.ep.api + "/drive/v3/" + rest }

func (s *session) drive(ctx context.Context, name string, args map[string]any) (any, error) {
	switch name {
	case "google_workspace_drive_search_files":
		query := oauthclient.Query{}
		if q := trimmed(args["query"]); q != "" {
			query = append(query, [2]string{"q", q})
		}
		query = append(query, [2]string{"pageSize", integrations.Clamp(args["page_size"], 10, 1, 50)},
			[2]string{"orderBy", "modifiedTime desc"},
			[2]string{"fields", "files(" + fileFields + "),nextPageToken"})
		res, err := s.call(ctx, "GET", s.driveURL("files"), query, nil)
		if err != nil {
			return nil, err
		}
		files := []fileSummary{}
		if list, ok := res.object()["files"].([]any); ok {
			for _, f := range list {
				if m, ok := f.(map[string]any); ok {
					files = append(files, summarizeFile(m))
				}
			}
		}
		return struct {
			Count int           `json:"count"`
			Files []fileSummary `json:"files"`
		}{len(files), files}, nil

	case "google_workspace_drive_upload_file":
		path, err := validateReadableFile(args["file_path"])
		if err != nil {
			return nil, err
		}
		data, err := readLimited(path, maxUploadSize)
		if err != nil {
			return nil, err
		}
		metadata := map[string]any{"parents": coerceStringList(args["parent_ids"])}
		if integrations.Truthy(args["name"]) {
			metadata["name"] = args["name"]
		}
		body, contentType, err := multipartRelated(metadata, textOf(args["mime_type"]), data)
		if err != nil {
			return nil, err
		}
		res, err := s.send(ctx, "POST", s.p.ep.upload+"/drive/v3/files?uploadType=multipart&fields="+url.QueryEscape(fileFields), nil, body,
			map[string]string{"Content-Type": contentType}, 0)
		if err != nil {
			return nil, err
		}
		return summarizeFile(res.object()), nil

	case "google_workspace_drive_download_file":
		fileID, err := requireNonEmpty(args["file_id"], "file_id")
		if err != nil {
			return nil, err
		}
		dest, err := requireDestination(args["destination_path"], "destination_path")
		if err != nil {
			return nil, err
		}
		if err := os.MkdirAll(filepath.Dir(dest), 0o755); err != nil {
			return nil, err
		}
		res, err := s.send(ctx, "GET", s.driveURL("files/"+url.PathEscape(fileID)), oauthclient.Query{{"alt", "media"}}, nil, nil, maxDownload)
		if err != nil {
			return nil, err
		}
		if err := writeDownloaded(dest, res.body); err != nil {
			return nil, err
		}
		return struct {
			FileID          string `json:"fileId"`
			DestinationPath string `json:"destinationPath"`
			BytesWritten    int    `json:"bytesWritten"`
		}{fileID, dest, len(res.body)}, nil

	case "google_workspace_drive_export_file":
		fileID, err := requireNonEmpty(args["file_id"], "file_id")
		if err != nil {
			return nil, err
		}
		mimeType, err := requireNonEmpty(args["mime_type"], "mime_type")
		if err != nil {
			return nil, err
		}
		dest, err := requireDestination(args["destination_path"], "destination_path")
		if err != nil {
			return nil, err
		}
		if err := os.MkdirAll(filepath.Dir(dest), 0o755); err != nil {
			return nil, err
		}
		res, err := s.send(ctx, "GET", s.driveURL("files/"+url.PathEscape(fileID)+"/export"), oauthclient.Query{{"mimeType", mimeType}}, nil, nil, maxDownload)
		if err != nil {
			return nil, err
		}
		if err := writeDownloaded(dest, res.body); err != nil {
			return nil, err
		}
		return struct {
			FileID          string `json:"fileId"`
			DestinationPath string `json:"destinationPath"`
			MimeType        string `json:"mimeType"`
		}{fileID, dest, mimeType}, nil

	case "google_workspace_drive_create_share_link":
		fileID, err := requireNonEmpty(args["file_id"], "file_id")
		if err != nil {
			return nil, err
		}
		kind, err := requireNonEmpty(args["type"], "type")
		if err != nil {
			return nil, err
		}
		if kind == "user" {
			if _, err := requireNonEmpty(args["email_address"], "email_address"); err != nil {
				return nil, err
			}
		}
		permission := map[string]any{"role": orDefault(textOf(args["role"]), "reader"), "type": kind}
		if integrations.Truthy(args["email_address"]) {
			permission["emailAddress"] = integrations.Str(args["email_address"])
		}
		if _, err := s.call(ctx, "POST", s.driveURL("files/"+url.PathEscape(fileID)+"/permissions"), nil, permission); err != nil {
			return nil, err
		}
		res, err := s.call(ctx, "GET", s.driveURL("files/"+url.PathEscape(fileID)), oauthclient.Query{{"fields", "id,name,webViewLink,webContentLink"}}, nil)
		if err != nil {
			return nil, err
		}
		return summarizeFile(res.object()), nil

	case "google_workspace_drive_api_request":
		return s.apiRequest(ctx, args, s.p.ep.api)
	}
	return nil, fmt.Errorf("Unknown tool: %s", name)
}

func readLimited(path string, limit int64) ([]byte, error) {
	info, err := os.Stat(path)
	if err != nil {
		return nil, err
	}
	if info.Size() > limit {
		return nil, fmt.Errorf("file_path is larger than the %d MB upload limit.", limit>>20)
	}
	return os.ReadFile(path)
}

// multipartRelated is the body of a Drive multipart upload: the file's
// metadata and its content.
func multipartRelated(metadata map[string]any, mimeType string, content []byte) ([]byte, string, error) {
	var buf bytes.Buffer
	w := multipart.NewWriter(&buf)
	meta, err := oauthclient.MarshalJS(metadata)
	if err != nil {
		return nil, "", err
	}
	part, err := w.CreatePart(textproto.MIMEHeader{"Content-Type": {"application/json; charset=UTF-8"}})
	if err != nil {
		return nil, "", err
	}
	part.Write(meta)
	part, err = w.CreatePart(textproto.MIMEHeader{"Content-Type": {orDefault(mimeType, "application/octet-stream")}})
	if err != nil {
		return nil, "", err
	}
	part.Write(content)
	if err := w.Close(); err != nil {
		return nil, "", err
	}
	return buf.Bytes(), "multipart/related; boundary=" + w.Boundary(), nil
}
