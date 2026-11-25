package workspace

import (
	"encoding/base64"
	"encoding/hex"
	"errors"
	"fmt"
	"io/fs"
	"math"
	"os"
	"path"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"
)

const (
	maxReadChars     = 20000
	maxSearchMatches = 100
	maxLinkHops      = 40
)

// Options carries the JSON arguments of a file tool call.
type Options map[string]any

// Manager owns the per-user workspaces under RootDir. Every path a caller
// names is confined to the user's workspace, symlinks included, by opening it
// through an os.Root.
type Manager struct {
	rootDir string
	pinned  bool
}

var keyJunk = regexp.MustCompile(`[^a-z0-9_-]+`)

// SanitizeKey turns an account id into the workspace directory name.
func SanitizeKey(value string) string {
	key := strings.Trim(keyJunk.ReplaceAllString(strings.ToLower(strings.TrimSpace(value)), "-"), "-")
	if len(key) > 64 {
		key = key[:64]
	}
	if key == "" {
		return "default"
	}
	return key
}

// New creates the manager. With pinned set, rootDir is the workspace itself
// (a checkout the caller already owns) rather than a parent of per-user
// directories.
func New(rootDir string, pinned bool) (*Manager, error) {
	abs, err := filepath.Abs(rootDir)
	if err != nil {
		return nil, err
	}
	if err := os.MkdirAll(abs, 0o700); err != nil {
		return nil, fmt.Errorf("Failed to create workspace dir %s: %w", abs, err)
	}
	return &Manager{rootDir: abs, pinned: pinned}, nil
}

// Root returns the absolute workspace directory of a user, creating it.
func (m *Manager) Root(userKey string) (string, error) {
	if m.pinned {
		return m.rootDir, nil
	}
	root := filepath.Join(m.rootDir, SanitizeKey(userKey))
	if err := os.MkdirAll(root, 0o700); err != nil {
		return "", fmt.Errorf("Failed to create workspace dir for user %s: %w", userKey, err)
	}
	return root, nil
}

// ToolingRoot returns the directory a tool keeps its own files in.
func (m *Manager) ToolingRoot(userKey, tool string) (string, error) {
	root, err := m.Root(userKey)
	if err != nil {
		return "", err
	}
	dir := filepath.Join(root, ".tooling", SanitizeKey(tool))
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return "", fmt.Errorf("Failed to create tooling dir for user %s and tool %s: %w", userKey, tool, err)
	}
	return dir, nil
}

var legacyMarkers = []string{"/.neoagent/agent-data/workspaces/", "/.neoagent/", "/workspace/"}

// normalize maps the spellings models use for the workspace ("/workspace/x",
// old absolute data-dir paths) onto a path the workspace can resolve.
func normalize(candidate string) string {
	raw := strings.TrimSpace(candidate)
	switch {
	case raw == "":
		return "."
	case raw == "/workspace":
		return "."
	case strings.HasPrefix(raw, "/workspace/"):
		return raw[len("/workspace/"):]
	case path.IsAbs(raw):
		for _, marker := range legacyMarkers {
			if i := strings.Index(raw, marker); i >= 0 {
				if rel := strings.TrimLeft(raw[i+len(marker):], "/"); rel != "" {
					return rel
				}
			}
		}
	}
	return raw
}

func outside(label string) error {
	return fmt.Errorf("%s is outside the per-user workspace.", label)
}

// Rel resolves a path the model named to a slash path inside the user's
// workspace ("." for the workspace itself). It fails with Node's error text
// when the path leaves the workspace.
func (m *Manager) Rel(userKey, candidate, label string) (string, error) {
	root, err := m.Root(userKey)
	if err != nil {
		return "", err
	}
	n := normalize(candidate)
	var abs string
	if filepath.IsAbs(n) {
		abs = filepath.Clean(n)
	} else {
		abs = filepath.Join(root, n)
	}
	rel, err := filepath.Rel(root, abs)
	if err != nil || rel == ".." || strings.HasPrefix(rel, ".."+string(filepath.Separator)) {
		return "", outside(label)
	}
	return filepath.ToSlash(rel), nil
}

// open returns the user's workspace as an os.Root.
func (m *Manager) open(userKey string) (*os.Root, error) {
	dir, err := m.Root(userKey)
	if err != nil {
		return nil, err
	}
	return os.OpenRoot(dir)
}

// confined turns an os.Root escape into the workspace error.
func confined(err error, label string) error {
	if err != nil && strings.Contains(err.Error(), "escapes from parent") {
		return outside(label)
	}
	return err
}

// Stat reports on a workspace path (following links inside the workspace).
func (m *Manager) Stat(userKey, candidate, label string) (fs.FileInfo, error) {
	rel, err := m.Rel(userKey, candidate, label)
	if err != nil {
		return nil, err
	}
	root, err := m.open(userKey)
	if err != nil {
		return nil, err
	}
	defer root.Close()
	info, err := root.Stat(rel)
	return info, confined(err, label)
}

// OpenFile opens a regular workspace file for reading.
func (m *Manager) OpenFile(userKey, candidate, label string) (*os.File, error) {
	rel, err := m.Rel(userKey, candidate, label)
	if err != nil {
		return nil, err
	}
	root, err := m.open(userKey)
	if err != nil {
		return nil, err
	}
	defer root.Close()
	f, err := root.Open(rel)
	return f, confined(err, label)
}

func utf16Len(s string) int {
	n := 0
	for _, r := range s {
		if r >= 0x10000 {
			n += 2
		} else {
			n++
		}
	}
	return n
}

func public(rel string) string {
	if rel == "." {
		return ""
	}
	return rel
}

// number reads a JSON argument the way JS Number() does; ok is false for null.
func number(v any) (float64, bool) {
	switch x := v.(type) {
	case nil:
		return 0, false
	case float64:
		return x, true
	case bool:
		if x {
			return 1, true
		}
		return 0, true
	case string:
		t := strings.TrimSpace(x)
		if t == "" {
			return 0, true
		}
		f, err := strconv.ParseFloat(t, 64)
		if err != nil {
			return math.NaN(), true
		}
		return f, true
	}
	return math.NaN(), true
}

func isInt(f float64) bool { return !math.IsNaN(f) && !math.IsInf(f, 0) && f == math.Trunc(f) }

func (o Options) str(key string) string {
	switch v := o[key].(type) {
	case nil:
		return ""
	case string:
		return v
	default:
		return CoerceText(v)
	}
}

func decode(raw []byte, encoding string) (string, error) {
	switch encoding {
	case "utf8", "utf-8":
		return strings.ToValidUTF8(string(raw), "�"), nil
	case "base64":
		return base64.StdEncoding.EncodeToString(raw), nil
	case "base64url":
		return base64.RawURLEncoding.EncodeToString(raw), nil
	case "hex":
		return hex.EncodeToString(raw), nil
	case "latin1", "binary":
		runes := make([]rune, len(raw))
		for i, b := range raw {
			runes[i] = rune(b)
		}
		return string(runes), nil
	case "ascii":
		runes := make([]rune, len(raw))
		for i, b := range raw {
			runes[i] = rune(b & 0x7f)
		}
		return string(runes), nil
	}
	return "", fmt.Errorf("Unknown encoding: %s", encoding)
}

func clip(content string) string {
	if utf16Len(content) > maxReadChars {
		return truncateUnits(content, maxReadChars) + "\n...[truncated]"
	}
	return content
}

func failureRead(msg, rel string, haveRel bool) Obj {
	var p any
	if haveRel {
		p = public(rel)
	}
	return Obj{{"error", msg}, {"path", p}}
}

// ReadFile reads a file, or a line range of it.
func (m *Manager) ReadFile(userKey string, o Options) (Obj, error) {
	rel, err := m.Rel(userKey, o.str("path"), "path")
	if err != nil {
		return nil, err
	}
	encoding := strings.ToLower(o.str("encoding"))
	if encoding == "" {
		encoding = "utf8"
	}
	root, err := m.open(userKey)
	if err != nil {
		return nil, err
	}
	defer root.Close()
	raw, err := root.ReadFile(rel)
	if err != nil {
		return failureRead("Failed to read file: "+readReason(confined(err, "path")), rel, true), nil
	}
	_, hasStart := number(o["start_line"])
	_, hasEnd := number(o["end_line"])
	if hasStart || hasEnd {
		start := 1.0
		if v, ok := number(o["start_line"]); ok {
			start = v
		}
		end, hasEndNum := number(o["end_line"])
		if !isInt(start) || start < 1 {
			return failureRead("start_line must be a positive integer", rel, true), nil
		}
		if hasEndNum && (!isInt(end) || end < 1) {
			return failureRead("end_line must be a positive integer", rel, true), nil
		}
		if hasEndNum && start > end {
			return failureRead("start_line must be less than or equal to end_line", rel, true), nil
		}
		content, err := decode(raw, encoding)
		if err != nil {
			return failureRead("Failed to read file: "+err.Error(), rel, true), nil
		}
		lines := strings.Split(content, "\n")
		from := int(math.Max(1, start))
		to := len(lines)
		if hasEndNum {
			to = int(math.Min(end, float64(len(lines))))
		}
		to = min(to, len(lines))
		var sliced string
		if from-1 < to {
			sliced = strings.Join(lines[from-1:to], "\n")
		}
		return Obj{{"path", public(rel)}, {"content", clip(sliced)}, {"totalLines", len(lines)}, {"rangeShown", []int{from, to}}}, nil
	}
	content, err := decode(raw, encoding)
	if err != nil {
		return failureRead("Failed to read file: "+err.Error(), rel, true), nil
	}
	return Obj{{"path", public(rel)}, {"content", clip(content)}, {"byteSize", len(raw)}}, nil
}

// readReason words an I/O failure the way Node's error messages did.
func readReason(err error) string {
	switch {
	case errors.Is(err, fs.ErrNotExist):
		return "ENOENT: no such file or directory"
	case errors.Is(err, fs.ErrPermission):
		return "EACCES: permission denied"
	}
	var pe *fs.PathError
	if errors.As(err, &pe) && strings.Contains(pe.Err.Error(), "is a directory") {
		return "EISDIR: illegal operation on a directory, read"
	}
	return err.Error()
}

// resolveLinks follows symbolic links at rel so a write lands on the target,
// as Node's writeFileAtomicSync did. A link pointing outside fails.
func resolveLinks(root *os.Root, rootDir, rel string) (string, error) {
	for range maxLinkHops {
		info, err := root.Lstat(rel)
		if err != nil || info.Mode()&fs.ModeSymlink == 0 {
			return rel, nil
		}
		target, err := root.Readlink(rel)
		if err != nil {
			return rel, err
		}
		if filepath.IsAbs(target) {
			r, err := filepath.Rel(rootDir, target)
			if err != nil || strings.HasPrefix(r, "..") {
				return "", outside("path")
			}
			rel = filepath.ToSlash(r)
		} else {
			rel = path.Join(path.Dir(rel), filepath.ToSlash(target))
		}
		if rel == ".." || strings.HasPrefix(rel, "../") {
			return "", outside("path")
		}
	}
	return "", errors.New("too many levels of symbolic links")
}

// writeAtomic puts data in place without ever leaving a partial file: it is
// written under a temporary name in the same directory, then renamed. The mode
// of an existing file carries over; new files are private (0600).
func writeAtomic(root *os.Root, rootDir, rel string, data []byte) error {
	target, err := resolveLinks(root, rootDir, rel)
	if err != nil {
		return err
	}
	mode := fs.FileMode(0o600)
	if info, err := root.Stat(target); err == nil {
		mode = info.Mode().Perm()
		if mode&0o200 == 0 {
			return fmt.Errorf("EACCES: permission denied, access '%s'", target)
		}
	}
	tmp := path.Join(path.Dir(target), fmt.Sprintf(".%s.%d.tmp", path.Base(target), time.Now().UnixNano()))
	f, err := root.OpenFile(tmp, os.O_WRONLY|os.O_CREATE|os.O_EXCL, mode)
	if err != nil {
		return err
	}
	fail := func(err error) error {
		f.Close()
		root.Remove(tmp)
		return err
	}
	if _, err := f.Write(data); err != nil {
		return fail(err)
	}
	if err := f.Chmod(mode); err != nil {
		return fail(err)
	}
	if err := f.Sync(); err != nil {
		return fail(err)
	}
	if err := f.Close(); err != nil {
		root.Remove(tmp)
		return err
	}
	if err := root.Rename(tmp, target); err != nil {
		root.Remove(tmp)
		return err
	}
	return nil
}

func msg(err error) string { return readReason(err) }

// WriteFile writes (or appends to) a file, creating parent directories.
func (m *Manager) WriteFile(userKey string, o Options) (Obj, error) {
	rel, err := m.Rel(userKey, o.str("path"), "path")
	if err != nil {
		return nil, err
	}
	dir, err := m.Root(userKey)
	if err != nil {
		return nil, err
	}
	root, err := os.OpenRoot(dir)
	if err != nil {
		return nil, err
	}
	defer root.Close()
	fail := func(err error) (Obj, error) {
		return Obj{{"success", false}, {"path", public(rel)}, {"error", msg(confined(err, "path"))}}, nil
	}
	if err := root.MkdirAll(path.Dir(rel), 0o700); err != nil {
		return fail(err)
	}
	data := []byte(CoerceText(o["content"]))
	if strings.ToLower(o.str("mode")) == "append" {
		existing, _ := root.ReadFile(rel)
		data = append(existing, data...)
	}
	if err := writeAtomic(root, dir, rel, data); err != nil {
		return fail(err)
	}
	return Obj{{"success", true}, {"path", public(rel)}}, nil
}

// EditFile applies exact-text edits to a file, all or nothing.
func (m *Manager) EditFile(userKey string, path string, edits []Edit) Obj {
	rel, err := m.Rel(userKey, path, "path")
	if err != nil {
		return Obj{{"success", false}, {"path", nil}, {"error", err.Error()}}
	}
	dir, err := m.Root(userKey)
	if err != nil {
		return Obj{{"success", false}, {"path", public(rel)}, {"error", err.Error()}}
	}
	root, err := os.OpenRoot(dir)
	if err != nil {
		return Obj{{"success", false}, {"path", public(rel)}, {"error", err.Error()}}
	}
	defer root.Close()
	raw, err := root.ReadFile(rel)
	if errors.Is(err, fs.ErrNotExist) {
		return Obj{{"error", "File not found: " + public(rel)}}
	}
	if err != nil {
		return Obj{{"success", false}, {"path", public(rel)}, {"error", msg(confined(err, "path"))}}
	}
	res := ApplyEdits(strings.ToValidUTF8(string(raw), "�"), edits)
	if res.Modified {
		if err := writeAtomic(root, dir, rel, []byte(res.Content)); err != nil {
			return Obj{{"success", false}, {"path", public(rel)}, {"error", msg(err)}}
		}
	}
	return Obj{{"success", res.Modified}, {"report", res.Report}, {"path", public(rel)}}
}

// ReplaceFileRange swaps a 1-based inclusive line range for new content.
func (m *Manager) ReplaceFileRange(userKey string, o Options) Obj {
	fail := func(rel string, haveRel bool, text string, extra ...Field) Obj {
		var p any
		if haveRel {
			p = public(rel)
		}
		out := Obj{{"success", false}, {"error", text}, {"path", p}}
		return append(out, extra...)
	}
	rel, err := m.Rel(userKey, o.str("path"), "path")
	if err != nil {
		return Obj{{"success", false}, {"path", nil}, {"error", err.Error()}}
	}
	dir, err := m.Root(userKey)
	if err != nil {
		return fail(rel, true, err.Error())
	}
	root, err := os.OpenRoot(dir)
	if err != nil {
		return fail(rel, true, err.Error())
	}
	defer root.Close()
	raw, err := root.ReadFile(rel)
	if errors.Is(err, fs.ErrNotExist) {
		return fail(rel, true, "File not found: "+public(rel))
	}
	if err != nil {
		return Obj{{"success", false}, {"path", public(rel)}, {"error", msg(confined(err, "path"))}}
	}
	pick := func(keys ...string) any {
		for _, k := range keys {
			if o[k] != nil {
				return o[k]
			}
		}
		return nil
	}
	start, ok := number(pick("start_line", "startLine"))
	if !ok {
		start = math.NaN() // Number(undefined)
	}
	end := start
	if v := pick("end_line", "endLine"); v != nil {
		end, _ = number(v)
	}
	if !isInt(start) || start < 1 {
		return fail(rel, true, "start_line must be a positive integer")
	}
	if !isInt(end) || end < 1 {
		return fail(rel, true, "end_line must be a positive integer")
	}
	if start > end {
		return fail(rel, true, "start_line must be less than or equal to end_line")
	}
	original := strings.ReplaceAll(strings.ToValidUTF8(string(raw), "�"), "\r\n", "\n")
	finalNewline := strings.HasSuffix(original, "\n")
	lines := strings.Split(original, "\n")
	if finalNewline {
		lines = lines[:len(lines)-1]
	}
	total := max(len(lines), 1)
	s, e := int(start), int(end)
	if s > total || e > total {
		return fail(rel, true, fmt.Sprintf("line range %d-%d is outside file with %d lines", s, e, total), Field{"totalLines", total})
	}
	replacement := ""
	if v := o["content"]; v != nil {
		replacement = CoerceText(v)
	}
	replacement = strings.ReplaceAll(replacement, "\r\n", "\n")
	var repl []string
	if replacement != "" {
		repl = strings.Split(strings.TrimSuffix(replacement, "\n"), "\n")
	}
	lines = append(lines[:s-1:s-1], append(repl, lines[min(e, len(lines)):]...)...)
	next := strings.Join(lines, "\n")
	if finalNewline {
		next += "\n"
	}
	if err := writeAtomic(root, dir, rel, []byte(next)); err != nil {
		return Obj{{"success", false}, {"path", public(rel)}, {"error", msg(err)}}
	}
	return Obj{
		{"success", true}, {"path", public(rel)}, {"startLine", s}, {"endLine", e},
		{"replacedLines", e - s + 1}, {"insertedLines", len(repl)}, {"totalLines", len(lines)},
	}
}

// DirEntry is one row of a directory listing.
type DirEntry struct {
	Name  string `json:"name"`
	Type  string `json:"type"`
	Path  string `json:"path"`
	Size  int64  `json:"size"`
	Mtime string `json:"mtime"`
}

// ListDirectory lists a directory, optionally a few levels deep.
func (m *Manager) ListDirectory(userKey string, o Options) (Obj, error) {
	p := o.str("path")
	if p == "" {
		p = "."
	}
	rel, err := m.Rel(userKey, p, "path")
	if err != nil {
		return nil, err
	}
	root, err := m.open(userKey)
	if err != nil {
		return nil, err
	}
	defer root.Close()
	depth := 1.0
	if v, ok := number(o["depth"]); ok {
		depth = v
	} else if r, _ := o["recursive"].(bool); r {
		depth = 3
	}
	maxDepth := 1
	if !math.IsNaN(depth) && !math.IsInf(depth, 0) {
		maxDepth = int(math.Min(math.Max(1, math.Floor(depth)), 5))
	}
	entries := []DirEntry{}
	var walk func(dir string, level int)
	walk = func(dir string, level int) {
		d, err := root.Open(dir)
		if err != nil {
			return
		}
		items, err := d.ReadDir(-1)
		d.Close()
		if err != nil {
			return
		}
		sort.Slice(items, func(a, b int) bool { return items[a].Name() < items[b].Name() })
		for _, item := range items {
			full := path.Join(dir, item.Name())
			info, err := root.Stat(full)
			if err != nil {
				continue
			}
			kind := "file"
			if item.IsDir() {
				kind = "directory"
			}
			entries = append(entries, DirEntry{item.Name(), kind, public(full), info.Size(), info.ModTime().UTC().Format("2006-01-02T15:04:05.000Z")})
			if item.IsDir() && level < maxDepth && !strings.HasPrefix(item.Name(), ".") && item.Name() != "node_modules" {
				walk(full, level+1)
			}
		}
	}
	walk(rel, 1)
	return Obj{{"path", public(rel)}, {"entries", entries}}, nil
}

// Match is one line found by SearchFiles.
type Match struct {
	File    string `json:"file"`
	Line    int    `json:"line"`
	Content string `json:"content"`
}

func globRegexp(pattern string) *regexp.Regexp {
	text := strings.TrimSpace(pattern)
	if text == "" {
		return nil
	}
	q := regexp.QuoteMeta(text)
	q = strings.ReplaceAll(q, `\*`, ".*")
	q = strings.ReplaceAll(q, `\?`, ".")
	return regexp.MustCompile("(?is)^" + q + "$")
}

// SearchFiles finds lines containing a text (case-insensitive) under a path.
func (m *Manager) SearchFiles(userKey string, o Options) (Obj, error) {
	p := o.str("path")
	if p == "" {
		p = "."
	}
	rel, err := m.Rel(userKey, p, "path")
	if err != nil {
		return nil, err
	}
	query := strings.TrimSpace(o.str("query"))
	if query == "" {
		return Obj{{"results", []any{}}, {"message", "query is required"}}, nil
	}
	include := globRegexp(o.str("include"))
	maxDepth := 5
	if v, ok := number(o["maxDepth"]); ok && !math.IsNaN(v) && !math.IsInf(v, 0) {
		maxDepth = int(math.Min(math.Max(0, math.Floor(v)), 10))
	}
	maxSize := int64(1024 * 1024)
	if v, ok := number(o["maxFileSize"]); ok && !math.IsNaN(v) && !math.IsInf(v, 0) {
		maxSize = int64(math.Max(0, math.Floor(v)))
	}
	root, err := m.open(userKey)
	if err != nil {
		return nil, err
	}
	defer root.Close()
	needle := strings.ToLower(query)
	matches := []Match{}
	var walk func(dir string, depth int)
	walk = func(dir string, depth int) {
		if depth >= maxDepth {
			return
		}
		d, err := root.Open(dir)
		if err != nil {
			return
		}
		items, err := d.ReadDir(-1)
		d.Close()
		if err != nil {
			return
		}
		sort.Slice(items, func(a, b int) bool { return items[a].Name() < items[b].Name() })
		for _, item := range items {
			full := path.Join(dir, item.Name())
			info, err := root.Lstat(full)
			if err != nil || info.Mode()&fs.ModeSymlink != 0 {
				continue
			}
			if info.IsDir() {
				if !strings.HasPrefix(item.Name(), ".") && item.Name() != "node_modules" {
					walk(full, depth+1)
				}
				continue
			}
			if !info.Mode().IsRegular() || (include != nil && !include.MatchString(item.Name())) || info.Size() > maxSize {
				continue
			}
			raw, err := root.ReadFile(full)
			if err != nil {
				continue
			}
			for i, line := range strings.Split(strings.ToValidUTF8(string(raw), "�"), "\n") {
				if !strings.Contains(strings.ToLower(line), needle) {
					continue
				}
				matches = append(matches, Match{public(full), i + 1, strings.TrimSpace(line)})
				if len(matches) >= maxSearchMatches {
					return
				}
			}
		}
	}
	walk(rel, 0)
	return Obj{{"matches", matches}, {"count", len(matches)}}, nil
}

// ResolvePath returns the absolute path of a workspace path for callers that
// need a real file name. The nearest existing ancestor is resolved through
// symlinks and must stay inside the workspace, as in Node. Prefer the
// os.Root-based methods when the data can be read through them.
func (m *Manager) ResolvePath(userKey, candidate, label string) (string, error) {
	rel, err := m.Rel(userKey, candidate, label)
	if err != nil {
		return "", err
	}
	dir, err := m.Root(userKey)
	if err != nil {
		return "", err
	}
	realRoot, err := filepath.EvalSymlinks(dir)
	if err != nil {
		return "", err
	}
	abs := filepath.Join(dir, filepath.FromSlash(rel))
	probe := abs
	for {
		if _, err := os.Lstat(probe); err == nil {
			break
		}
		parent := filepath.Dir(probe)
		if parent == probe {
			break
		}
		probe = parent
	}
	realProbe, err := filepath.EvalSymlinks(probe)
	if err != nil {
		return "", outside(label)
	}
	if r, err := filepath.Rel(realRoot, realProbe); err != nil || r == ".." || strings.HasPrefix(r, ".."+string(filepath.Separator)) {
		return "", outside(label)
	}
	return abs, nil
}
