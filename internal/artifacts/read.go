package artifacts

import (
	"context"
	"database/sql"
	"errors"
	"math"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
)

// Record is an artifact row of a user.
type Record struct {
	ID, ContentType, StoragePath, URL string
	ByteSize                          int64
}

const (
	maxQueryMatches  = 200
	maxReadableBytes = 16 * 1024 * 1024
)

func (s *Store) lookup(ctx context.Context, where string, arg any, userID int64) (*Record, error) {
	if s == nil || s.DB == nil {
		return nil, errors.New("Artifact store is unavailable.")
	}
	var r Record
	var contentType sql.NullString
	var size sql.NullInt64
	err := s.DB.R.QueryRowContext(ctx, `SELECT id, content_type, storage_path, byte_size FROM artifacts WHERE `+where+` = ? AND user_id = ?`, arg, userID).
		Scan(&r.ID, &contentType, &r.StoragePath, &size)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	r.ContentType, r.ByteSize, r.URL = contentType.String, size.Int64, URL(r.ID)
	return &r, nil
}

// Get is an artifact the user owns, or nil.
func (s *Store) Get(ctx context.Context, userID int64, id string) (*Record, error) {
	return s.lookup(ctx, "id", id, userID)
}

// GetByStoragePath is the user's artifact stored at path, or nil.
func (s *Store) GetByStoragePath(ctx context.Context, userID int64, path string) (*Record, error) {
	path = strings.TrimSpace(path)
	if path == "" {
		return nil, nil
	}
	return s.lookup(ctx, "storage_path", path, userID)
}

// insideRoot refuses a stored path outside the artifact root.
func (s *Store) insideRoot(candidate string) (string, error) {
	root, err := filepath.Abs(s.Root)
	if err != nil {
		return "", err
	}
	abs, err := filepath.Abs(candidate)
	if err != nil {
		return "", err
	}
	rel, err := filepath.Rel(root, abs)
	if err != nil || rel == "." || strings.HasPrefix(rel, "..") || filepath.IsAbs(rel) {
		return "", errors.New("artifact path escapes the artifact root.")
	}
	return abs, nil
}

var (
	textLike    = regexp.MustCompile(`json|xml|javascript|yaml`)
	lineBreakRE = regexp.MustCompile(`\r?\n`)
)

// jsNumber reads a JSON argument as Number() does for the values tools pass.
func jsNumber(v any) float64 {
	switch x := v.(type) {
	case float64:
		return x
	case int:
		return float64(x)
	case int64:
		return float64(x)
	case string:
		f, err := strconv.ParseFloat(strings.TrimSpace(x), 64)
		if err != nil {
			return math.NaN()
		}
		return f
	case nil:
		return 0
	}
	return math.NaN()
}

// orInt is Math.floor(Number(v) || fallback).
func orInt(v any, fallback int) int {
	n := jsNumber(v)
	if math.IsNaN(n) || n == 0 {
		return fallback
	}
	return int(math.Floor(n))
}

// ReadText is read_artifact (readTextArtifact): a line range or the lines
// matching a query of a text artifact, or a description of a binary one.
func (s *Store) ReadText(ctx context.Context, userID int64, id any, startLine, endLine, query any) (map[string]any, error) {
	idText, _ := id.(string)
	r, err := s.Get(ctx, userID, idText)
	if err != nil {
		return nil, err
	}
	if r == nil {
		return map[string]any{"error": "Artifact not found."}, nil
	}
	ct := strings.ToLower(r.ContentType)
	if !strings.HasPrefix(ct, "text/") && !textLike.MatchString(ct) {
		return map[string]any{"artifactId": r.ID, "contentType": r.ContentType, "byteSize": r.ByteSize, "binary": true, "url": r.URL}, nil
	}
	if r.ByteSize > maxReadableBytes {
		return map[string]any{"error": "Text artifact exceeds the readable 16 MiB limit."}, nil
	}
	path, err := s.insideRoot(r.StoragePath)
	if err != nil {
		return nil, err
	}
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	lines := lineBreakRE.Split(strings.ToValidUTF8(string(raw), "�"), -1)
	q := ""
	if s, ok := query.(string); ok {
		q = strings.ToLower(strings.TrimSpace(s))
	}
	if q != "" {
		var matching []string
		for i, line := range lines {
			if strings.Contains(strings.ToLower(line), q) {
				matching = append(matching, strconv.Itoa(i+1)+": "+line)
			}
		}
		shown := matching[:min(len(matching), maxQueryMatches)]
		return map[string]any{
			"artifactId": r.ID, "contentType": r.ContentType, "byteSize": r.ByteSize,
			"content": strings.Join(shown, "\n"), "matches": len(matching), "totalLines": len(lines),
			"truncated": len(matching) > maxQueryMatches, "url": r.URL,
		}, nil
	}
	start := min(len(lines), max(1, orInt(startLine, 1)))
	end := min(len(lines), max(start, orInt(endLine, start+199)), start+499)
	return map[string]any{
		"artifactId": r.ID, "contentType": r.ContentType, "byteSize": r.ByteSize,
		"content":    strings.Join(lines[start-1:end], "\n"),
		"rangeShown": map[string]any{"startLine": start, "endLine": end},
		"totalLines": len(lines), "truncated": end < len(lines), "url": r.URL,
	}, nil
}
