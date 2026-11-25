package guest

import (
	"encoding/base64"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

var screenshotPath = regexp.MustCompile(`^/screenshots/`)

// readableRoots are the directories /files/read may serve from, after
// resolving links; ones that do not exist yet are left out.
func (s *Server) readableRoots() []string {
	candidates := []string{
		s.fileRoot,
		filepath.Join(s.cfg.RuntimeHome, "data"),
		filepath.Join(s.cfg.RuntimeHome, "android"),
		os.TempDir(),
		s.ws.root,
	}
	var roots []string
	for _, c := range candidates {
		abs, err := filepath.Abs(c)
		if err != nil {
			continue
		}
		if real, err := filepath.EvalSymlinks(abs); err == nil {
			roots = append(roots, real)
		}
	}
	return roots
}

func (s *Server) insideReadable(target string) bool {
	for _, root := range s.readableRoots() {
		if target == root || strings.HasPrefix(target, root+string(filepath.Separator)) {
			return true
		}
	}
	return false
}

func (s *Server) resolveReadable(value string) (string, bool) {
	raw := strings.TrimSpace(value)
	if screenshotPath.MatchString(raw) {
		real, err := filepath.EvalSymlinks(filepath.Join(s.cfg.DataDir, "screenshots", filepath.Base(raw)))
		if err != nil || !s.insideReadable(real) {
			return "", false
		}
		return real, true
	}
	abs, err := filepath.Abs(value)
	if err != nil {
		return "", false
	}
	real, err := filepath.EvalSymlinks(abs)
	if err != nil || !s.insideReadable(real) {
		return "", false
	}
	return real, true
}

func (s *Server) filesRead(w http.ResponseWriter, r *http.Request) {
	body, err := readBody(r)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, errorBody(err.Error()))
		return
	}
	work(w, func() (any, error) {
		filePath := strings.TrimSpace(text(body, "path"))
		encoding := strings.ToLower(strings.TrimSpace(text(body, "encoding")))
		if encoding == "" {
			encoding = "base64"
		}
		if filePath == "" {
			return errorBody("path is required"), nil
		}
		real, ok := s.resolveReadable(filePath)
		if !ok {
			return errorBody("path is outside guest-agent readable roots"), nil
		}
		info, err := os.Stat(real)
		if err != nil {
			return nil, err
		}
		if info.Size() > maxReadableFileBytes {
			return nil, errTooLarge
		}
		data, err := os.ReadFile(real)
		if err != nil {
			return nil, err
		}
		if body["delete_after_read"] == true && s.deletable(real) {
			if os.Remove(real) == nil {
				_ = os.Remove(filepath.Dir(real))
			}
		}
		content := base64.StdEncoding.EncodeToString(data)
		if encoding == "utf8" {
			content = string(data)
		}
		return obj("path", real, "encoding", encoding, "content", content, "byteSize", len(data)), nil
	})
}

// deletable limits delete_after_read to scratch space: the temporary
// directory and the agent's own file directory.
func (s *Server) deletable(real string) bool {
	for _, dir := range []string{os.TempDir(), s.fileRoot} {
		resolved, err := filepath.EvalSymlinks(dir)
		if err == nil && strings.HasPrefix(real, resolved+string(filepath.Separator)) {
			return true
		}
	}
	return false
}
