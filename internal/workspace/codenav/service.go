package codenav

import (
	"context"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"errors"
	"math"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/memory"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
)

var codeExtensions = map[string]bool{".js": true, ".cjs": true, ".mjs": true, ".jsx": true, ".ts": true, ".tsx": true}

const (
	maxIndexedFiles = 500
	maxIndexedBytes = 512 * 1024
)

// Workspace maps workspace paths of a user to host paths.
type Workspace interface {
	ResolvePath(userKey, candidate, label string) (string, error)
	Root(userKey string) (string, error)
}

// Service answers code_navigate.
type Service struct {
	DB        *dbx.DB
	Workspace Workspace
	// Embed is a text embedding, nil when no embedding provider answers.
	Embed func(ctx context.Context, text string) ([]float32, error)
}

func userKey(id int64) string { return strconv.FormatInt(id, 10) }

func text(args map[string]any, key string) string {
	s, _ := args[key].(string)
	return s
}

// Navigate is code_navigate: mode structure or semantic.
func (s *Service) Navigate(ctx context.Context, userID int64, args map[string]any) (any, error) {
	switch text(args, "mode") {
	case "structure":
		return s.structure(userID, text(args, "path"))
	case "semantic":
		return s.semantic(ctx, userID, args)
	}
	return nil, errors.New("mode must be structure or semantic. To search for text, use search_files.")
}

type structureResult struct {
	Mode        string   `json:"mode"`
	Path        string   `json:"path"`
	ParseErrors []string `json:"parseErrors"`
	Symbols     []Symbol `json:"symbols"`
}

func (s *Service) structureOf(abs string) (structureResult, error) {
	raw, err := os.ReadFile(abs)
	if err != nil {
		return structureResult{}, err
	}
	if !codeExtensions[strings.ToLower(filepath.Ext(abs))] {
		return structureResult{}, errors.New("Structural parsing currently supports JavaScript and TypeScript files.")
	}
	symbols, parseErrors := Structure(strings.ToValidUTF8(string(raw), "�"))
	return structureResult{Mode: "structure", Path: abs, ParseErrors: parseErrors, Symbols: symbols}, nil
}

func (s *Service) structure(userID int64, path string) (structureResult, error) {
	abs, err := s.Workspace.ResolvePath(userKey(userID), path, "path")
	if err != nil {
		return structureResult{}, err
	}
	return s.structureOf(abs)
}

type indexStatus struct {
	FilesScanned   int `json:"filesScanned"`
	SymbolsIndexed int `json:"symbolsIndexed"`
}

func (s *Service) index(ctx context.Context, userID int64, path string) (indexStatus, error) {
	if path == "" {
		path = "."
	}
	root, err := s.Workspace.ResolvePath(userKey(userID), path, "path")
	if err != nil {
		return indexStatus{}, err
	}
	workspaceRoot, err := s.Workspace.Root(userKey(userID))
	if err != nil {
		return indexStatus{}, err
	}
	var files []string
	var walk func(dir string) error
	walk = func(dir string) error {
		if len(files) >= maxIndexedFiles {
			return nil
		}
		entries, err := os.ReadDir(dir)
		if err != nil {
			return err
		}
		for _, e := range entries {
			name := e.Name()
			if name == "node_modules" || name == ".git" || strings.HasPrefix(name, ".neoagent-") {
				continue
			}
			full := filepath.Join(dir, name)
			switch {
			case e.IsDir():
				if err := walk(full); err != nil {
					return err
				}
			case e.Type().IsRegular() && codeExtensions[strings.ToLower(filepath.Ext(name))]:
				files = append(files, full)
			}
		}
		return nil
	}
	if err := walk(root); err != nil {
		return indexStatus{}, err
	}
	indexed := 0
	for _, file := range files {
		info, err := os.Stat(file)
		if err != nil {
			return indexStatus{}, err
		}
		if info.Size() > maxIndexedBytes {
			continue
		}
		structure, err := s.structureOf(file)
		if err != nil {
			return indexStatus{}, err
		}
		rel, err := filepath.Rel(workspaceRoot, file)
		if err != nil {
			return indexStatus{}, err
		}
		rel = filepath.ToSlash(rel)
		for _, sym := range structure.Symbols {
			sum := sha256.Sum256([]byte(sym.Excerpt))
			hash := hex.EncodeToString(sum[:])
			var existing string
			err := s.DB.R.QueryRowContext(ctx, `SELECT content_hash FROM workspace_code_index WHERE user_id = ? AND path = ? AND symbol = ? AND start_line = ?`,
				userID, rel, sym.Name, sym.StartLine).Scan(&existing)
			if err != nil && !errors.Is(err, sql.ErrNoRows) {
				return indexStatus{}, err
			}
			if existing == hash {
				continue
			}
			var embedding any
			if s.Embed != nil {
				vec, err := s.Embed(ctx, sym.Name+"\n"+sym.Excerpt)
				if err != nil && ctx.Err() != nil {
					return indexStatus{}, ctx.Err()
				}
				if len(vec) > 0 {
					embedding = memory.SerializeEmbedding(vec)
				}
			}
			if _, err := s.DB.W.ExecContext(ctx, `INSERT INTO workspace_code_index (
            user_id, path, symbol, symbol_type, start_line, end_line, content, content_hash, embedding
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
          ON CONFLICT(user_id, path, symbol, start_line) DO UPDATE SET
            symbol_type = excluded.symbol_type,
            end_line = excluded.end_line,
            content = excluded.content,
            content_hash = excluded.content_hash,
            embedding = excluded.embedding,
            updated_at = datetime('now')`,
				userID, rel, sym.Name, sym.Type, sym.StartLine, sym.EndLine, sym.Excerpt, hash, embedding); err != nil {
				return indexStatus{}, err
			}
			indexed++
		}
	}
	return indexStatus{FilesScanned: len(files), SymbolsIndexed: indexed}, nil
}

type semanticHit struct {
	Path       string  `json:"path"`
	Symbol     any     `json:"symbol"`
	SymbolType any     `json:"symbolType"`
	StartLine  any     `json:"startLine"`
	EndLine    any     `json:"endLine"`
	Score      float64 `json:"score"`
	Excerpt    string  `json:"excerpt"`
}

func head(s string, units int) string {
	n := 0
	for i, r := range s {
		w := 1
		if r > 0xFFFF {
			w = 2
		}
		if n+w > units {
			return s[:i]
		}
		n += w
	}
	return s
}

func (s *Service) semantic(ctx context.Context, userID int64, args map[string]any) (any, error) {
	query := strings.TrimSpace(text(args, "query"))
	if query == "" {
		return nil, errors.New("query is required.")
	}
	status, err := s.index(ctx, userID, text(args, "path"))
	if err != nil {
		return nil, err
	}
	var queryVec []float32
	if s.Embed != nil {
		if queryVec, err = s.Embed(ctx, query); err != nil && ctx.Err() != nil {
			return nil, ctx.Err()
		}
	}
	rows, err := s.DB.R.QueryContext(ctx, `SELECT path, symbol, symbol_type, start_line, end_line, content, embedding FROM workspace_code_index WHERE user_id = ?`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	limit := 12.0
	if v, ok := args["limit"]; ok && v != nil {
		if f, ok := v.(float64); ok && f != 0 {
			limit = f
		}
	}
	limit = math.Min(math.Max(limit, 1), 50)
	hits := []semanticHit{}
	for rows.Next() {
		var path, content string
		var symbol, symbolType, embedding sql.NullString
		var startLine, endLine sql.NullInt64
		if err := rows.Scan(&path, &symbol, &symbolType, &startLine, &endLine, &content, &embedding); err != nil {
			return nil, err
		}
		var score float64
		vec := memory.DeserializeEmbedding(embedding.String)
		if len(queryVec) > 0 && len(vec) > 0 {
			score = memory.Cosine(queryVec, vec)
		} else {
			score = memory.KeywordSimilarity(query, symbol.String+" "+content)
		}
		if score <= 0 {
			continue
		}
		hits = append(hits, semanticHit{Path: path, Symbol: nullable(symbol), SymbolType: nullable(symbolType), StartLine: nullableInt(startLine), EndLine: nullableInt(endLine), Score: score, Excerpt: head(content, 1600)})
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	sort.SliceStable(hits, func(i, j int) bool { return hits[i].Score > hits[j].Score })
	hits = hits[:min(len(hits), int(limit))]
	return map[string]any{"mode": "semantic", "indexStatus": status, "count": len(hits), "results": hits}, nil
}

func nullable(s sql.NullString) any {
	if !s.Valid {
		return nil
	}
	return s.String
}

func nullableInt(n sql.NullInt64) any {
	if !n.Valid {
		return nil
	}
	return n.Int64
}
