package artifacts

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/google/uuid"

	"github.com/NeoLabs-Systems/neolabs-go/dbx"
)

// Store keeps artifact files under Root/<user>/ and their rows in the
// artifacts table.
type Store struct {
	DB   *dbx.DB
	Root string
}

// File is the content and description of a new artifact.
type File struct {
	Kind, Backend, Extension, ContentType, FilenameBase, OriginalFilename string
	Content                                                               []byte
	Metadata                                                              map[string]any
}

// Stored is a written artifact.
type Stored struct {
	ID, URL, StoragePath, ContentType string
	ByteSize                          int64
}

var (
	dotRun     = regexp.MustCompile(`\.+`)
	unsafeRun  = regexp.MustCompile(`[^a-z0-9_-]+`)
	edgeDashes = regexp.MustCompile(`^-+|-+$`)
)

// sanitizeSegment turns a value into a safe path segment.
func sanitizeSegment(value, fallback string) string {
	s := strings.ToLower(strings.TrimSpace(value))
	s = dotRun.ReplaceAllString(s, "-")
	s = unsafeRun.ReplaceAllString(s, "-")
	s = edgeDashes.ReplaceAllString(s, "")
	if s == "" || s == "." || s == ".." {
		return fallback
	}
	return s
}

// URL is where an artifact's content is served.
func URL(id string) string {
	return "/api/artifacts/" + encodeSegment(strings.TrimSpace(id)) + "/content"
}

func encodeSegment(s string) string {
	var b strings.Builder
	for _, c := range []byte(s) {
		if (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || strings.IndexByte("-_.!~*'()", c) >= 0 {
			b.WriteByte(c)
		} else {
			fmt.Fprintf(&b, "%%%02X", c)
		}
	}
	return b.String()
}

func (s *Store) userDir(userKey string) (string, error) {
	root, err := filepath.Abs(s.Root)
	if err != nil {
		return "", err
	}
	dir := filepath.Join(root, sanitizeSegment(userKey, "anonymous"))
	rel, err := filepath.Rel(root, dir)
	if err != nil || rel == "." || strings.HasPrefix(rel, "..") {
		return "", errors.New("artifact user directory escapes the artifact root.")
	}
	return dir, nil
}

// CreateBufferArtifact writes content atomically and records it; a failed
// write leaves neither file nor row behind.
func (s *Store) CreateBufferArtifact(ctx context.Context, userKey string, f File) (Stored, error) {
	if s == nil || s.DB == nil || s.Root == "" {
		return Stored{}, errors.New("Artifact store is unavailable.")
	}
	dir, err := s.userDir(userKey)
	if err != nil {
		return Stored{}, err
	}
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return Stored{}, err
	}
	id := uuid.NewString()
	suffix := ""
	if ext := strings.TrimPrefix(strings.TrimSpace(f.Extension), "."); ext != "" {
		suffix = "." + ext
	}
	base := f.FilenameBase
	if base == "" {
		base = f.Kind
	}
	if base == "" {
		base = "artifact"
	}
	storagePath := filepath.Join(dir, id+"-"+sanitizeSegment(base, "artifact")+suffix)
	original := f.OriginalFilename
	if original == "" {
		original = filepath.Base(storagePath)
	}
	kind := f.Kind
	if kind == "" {
		kind = "artifact"
	}
	backend := f.Backend
	if backend == "" {
		backend = "host"
	}
	metadata := f.Metadata
	if metadata == nil {
		metadata = map[string]any{}
	}
	meta, err := json.Marshal(metadata)
	if err != nil {
		return Stored{}, err
	}
	var contentType any
	if f.ContentType != "" {
		contentType = f.ContentType
	}
	if _, err := s.DB.W.ExecContext(ctx, `INSERT INTO artifacts (id, user_id, kind, backend, content_type, storage_path, original_filename, byte_size, metadata_json)
      VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?)`, id, userKey, kind, backend, contentType, storagePath, original, string(meta)); err != nil {
		return Stored{}, err
	}
	fail := func(err error) (Stored, error) {
		_ = os.Remove(storagePath)
		_, _ = s.DB.W.ExecContext(context.Background(), `DELETE FROM artifacts WHERE id = ?`, id)
		return Stored{}, err
	}
	if err := ctx.Err(); err != nil {
		return fail(err)
	}
	temporary := storagePath + ".tmp"
	if err := os.WriteFile(temporary, f.Content, 0o600); err != nil {
		_ = os.Remove(temporary)
		return fail(err)
	}
	if err := os.Rename(temporary, storagePath); err != nil {
		_ = os.Remove(temporary)
		return fail(err)
	}
	if _, err := s.DB.W.ExecContext(ctx, `UPDATE artifacts SET byte_size = ? WHERE id = ?`, len(f.Content), id); err != nil {
		return fail(err)
	}
	return Stored{ID: id, URL: URL(id), StoragePath: storagePath, ContentType: f.ContentType, ByteSize: int64(len(f.Content))}, nil
}
