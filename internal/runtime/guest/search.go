package guest

import (
	"math"
	"net/http"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

var skippedSearchDirs = map[string]bool{".git": true, "node_modules": true, ".cache": true}

const maxSearchFileBytes = 2 * 1024 * 1024

func (s *Server) workspaceSearch(w http.ResponseWriter, r *http.Request) {
	body, err := readBody(r)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, errorBody(err.Error()))
		return
	}
	work(w, func() (any, error) {
		pathValue := text(body, "path")
		if pathValue == "" {
			pathValue = "."
		}
		start, err := s.ws.resolve(pathValue, true)
		if err != nil {
			return nil, err
		}
		filename := strings.ReplaceAll(strings.ToLower(strings.TrimSpace(text(body, "glob", "filename"))), "*", "")
		contentQuery := strings.TrimSpace(text(body, "query"))
		limit := number(body, "maxResults")
		if !truthy(body["maxResults"]) {
			limit = 100
		}
		maximum := 100
		if finite(limit) {
			maximum = int(math.Min(500, math.Max(1, limit)))
		}
		real, err := filepath.EvalSymlinks(start)
		if err != nil {
			return nil, err
		}
		results := []object{}
		err = s.ws.open(real, func(root *os.Root, rel string) error {
			pending := []string{rel}
			for len(pending) > 0 && len(results) < maximum {
				current := pending[0]
				pending = pending[1:]
				dir, err := root.Open(current)
				if err != nil {
					return err
				}
				entries, err := dir.ReadDir(-1)
				dir.Close()
				sort.Slice(entries, func(i, j int) bool { return entries[i].Name() < entries[j].Name() })
				if err != nil {
					return err
				}
				for _, entry := range entries {
					if entry.Type()&os.ModeSymlink != 0 {
						continue
					}
					entryPath := filepath.Join(current, entry.Name())
					if entry.IsDir() {
						if !skippedSearchDirs[entry.Name()] {
							pending = append(pending, entryPath)
						}
						continue
					}
					if !entry.Type().IsRegular() {
						continue
					}
					if filename != "" && !strings.Contains(strings.ToLower(entry.Name()), filename) {
						continue
					}
					info, err := root.Stat(entryPath)
					if err != nil {
						return err
					}
					within, _ := filepath.Rel(rel, entryPath)
					display := s.ws.relative(filepath.Join(start, within))
					if contentQuery == "" {
						results = append(results, obj("path", display, "size", info.Size()))
						if len(results) >= maximum {
							break
						}
						continue
					}
					if info.Size() > maxSearchFileBytes {
						continue
					}
					data, err := root.ReadFile(entryPath)
					if err != nil {
						return err
					}
					for index, line := range strings.Split(string(data), "\n") {
						if len(results) >= maximum {
							break
						}
						if strings.Contains(line, contentQuery) {
							results = append(results, obj("path", display, "line", index+1, "text", utf16Prefix(line, 500)))
						}
					}
				}
			}
			return nil
		})
		if err != nil {
			return nil, err
		}
		return obj("results", results, "truncated", len(results) >= maximum), nil
	})
}
