package skills

import (
	"context"
	"encoding/json"
	"errors"
	"github.com/NeoLabs-Systems/neoagent/internal/jsrules"
	"io/fs"
	"os"
	"path"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
)

// A skill library is a zip of skill folders, each holding a SKILL.md, the way
// a `.claude/skills` folder is laid out. Every skill installs as an ordinary
// user skill tagged with the library's name, so the app can group them.
const (
	maxLibrarySkills = 300
	manifestFile     = "library.json"
)

var (
	libraryTextExt  = setOf(".css", ".csv", ".html", ".js", ".json", ".md", ".mjs", ".py", ".sh", ".toml", ".ts", ".txt", ".xml", ".yaml", ".yml")
	ignoredSegments = setOf("__MACOSX", ".git", "node_modules")
	controlCharRE   = regexp.MustCompile(`[\x00-\x1f]`)
	zipSuffixRE     = regexp.MustCompile(`(?i)\.zip$`)
)

func setOf(items ...string) map[string]bool {
	m := make(map[string]bool, len(items))
	for _, item := range items {
		m[item] = true
	}
	return m
}

// StatusError is a failure the API reports with its own status.
type StatusError struct {
	Status  int
	Message string
}

func (e *StatusError) Error() string { return e.Message }

// libraryNameFrom turns "via-main.zip" into "via-main"; anything unusable
// becomes "skill-library".
func libraryNameFrom(value string) string {
	if name := NormalizeName(jsrules.Trim(zipSuffixRE.ReplaceAllString(value, ""))); name != "" {
		return name
	}
	return "skill-library"
}

// safeEntries drops entries that could escape a folder, cannot be file
// names, or are archive clutter.
func safeEntries(entries []zipEntry) []zipEntry {
	var out []zipEntry
	for _, e := range entries {
		if controlCharRE.MatchString(e.path) || strings.HasPrefix(e.path, "/") {
			continue
		}
		parts := strings.Split(e.path, "/")
		bad := false
		for _, p := range parts {
			bad = bad || p == ".." || p == "" || ignoredSegments[p]
		}
		if bad || parts[len(parts)-1] == ".DS_Store" {
			continue
		}
		out = append(out, e)
	}
	return out
}

type foundSkill struct {
	dir    string
	file   zipEntry
	extras []zipEntry
}

// findSkills finds the skill folders in an archive. A SKILL.md inside another
// skill's folder belongs to that skill (a bundled example, say), not to a
// skill of its own.
func findSkills(entries []zipEntry) []foundSkill {
	type root struct {
		dir   string
		file  int
		depth int
	}
	var roots []root
	for i, e := range entries {
		if strings.ToLower(path.Base(e.path)) == "skill.md" {
			dir := path.Dir(e.path)
			roots = append(roots, root{dir: dir, file: i, depth: len(strings.Split(dir, "/"))})
		}
	}
	sort.SliceStable(roots, func(a, b int) bool { return roots[a].depth < roots[b].depth })
	var skills []foundSkill
	for _, r := range roots {
		nested := false
		for _, s := range skills {
			nested = nested || s.dir == "." || strings.HasPrefix(r.dir, s.dir+"/")
		}
		if nested {
			continue
		}
		prefix := ""
		if r.dir != "." {
			prefix = r.dir + "/"
		}
		skill := foundSkill{dir: r.dir, file: entries[r.file]}
		for i, e := range entries {
			if i != r.file && strings.HasPrefix(e.path, prefix) {
				skill.extras = append(skill.extras, e)
			}
		}
		skills = append(skills, skill)
	}
	return skills
}

// extraContent is the bytes to write for a bundled file: text is scrubbed of
// invisible characters, anything else is kept as it is.
func extraContent(e zipEntry) []byte {
	if libraryTextExt[strings.ToLower(path.Ext(e.path))] {
		return []byte(scrubInvisible(string(e.data)))
	}
	return e.data
}

// SkipNote says why a skill of an archive was not installed.
type SkipNote struct {
	Name   string `json:"name"`
	Reason string `json:"reason"`
}

// Installed is what installing a library answers.
type Installed struct {
	Library   string     `json:"library"`
	Installed []string   `json:"installed"`
	Skipped   []SkipNote `json:"skipped"`
	Removed   []string   `json:"removed"`
}

type libraryOptions struct {
	library     string
	rootName    string
	keepLibrary bool
}

// InstallLibrary installs the skills of an uploaded zip for a user.
func (r *Runner) InstallLibrary(ctx context.Context, userID int64, zip []byte, filename, name string) (Installed, error) {
	entries, err := readZipEntries(zip)
	if err != nil {
		return Installed{}, err
	}
	if name == "" {
		name = filename
	}
	return r.installEntries(ctx, userID, entries, libraryOptions{
		library: libraryNameFrom(name), rootName: libraryNameFrom(filename),
	})
}

// installEntries installs skill folders given as entries, whatever they were
// read from. One skill is just a skill unless keepLibrary is set; several
// always make a library.
func (r *Runner) installEntries(ctx context.Context, userID int64, raw []zipEntry, o libraryOptions) (Installed, error) {
	entries := safeEntries(raw)
	found := findSkills(entries)
	if len(found) == 0 {
		return Installed{}, &StatusError{Status: 422, Message: "No skills found. The zip needs folders that each contain a SKILL.md."}
	}
	if len(found) > maxLibrarySkills {
		return Installed{}, &StatusError{Status: 413, Message: "The archive has " + strconv.Itoa(len(found)) + " skills; the limit is " + strconv.Itoa(maxLibrarySkills)}
	}

	library := ""
	if len(found) > 1 || o.keepLibrary {
		library = o.library
	}
	out := Installed{Library: library, Installed: []string{}, Skipped: []SkipNote{}, Removed: []string{}}
	seen := map[string]bool{}
	for _, skill := range found {
		content := scrubInvisible(string(skill.file.data))
		parsed, hasFront := ParseFrontmatter(content)
		folder := o.rootName
		if folder == "" {
			folder = o.library
		}
		if skill.dir != "." {
			folder = path.Base(skill.dir)
		}
		name := NormalizeName(orDefaultString(parsed.Data["name"], folder))
		if name == "" {
			out.Skipped = append(out.Skipped, SkipNote{Name: folder, Reason: "No usable skill name"})
			continue
		}
		if seen[name] {
			out.Skipped = append(out.Skipped, SkipNote{Name: name, Reason: "Another skill in this zip has the same name"})
			continue
		}
		seen[name] = true

		// Uploading the same library again replaces its skills; a name the
		// user already has from anywhere else is left alone.
		if existing, ok := r.userSkill(userID, name); ok {
			if library == "" || existing.Metadata.Value("library") != library {
				out.Skipped = append(out.Skipped, SkipNote{Name: name, Reason: "You already have a skill with this name"})
				continue
			}
			if _, err := r.Delete(ctx, userID, name); err != nil {
				return out, err
			}
		}

		body := content
		if hasFront {
			body = parsed.Body
		}
		meta := Meta{{Key: "source", Value: "user"}}
		if library != "" {
			meta = Meta{{Key: "source", Value: "library"}, {Key: "library", Value: library}}
		}
		saved, err := r.Create(ctx, userID, name, collapseSpaces(parsed.Data["description"]), PrependNeoAgentNotes(body), meta)
		if err != nil {
			if refusal, ok := asRefusal(err); ok {
				out.Skipped = append(out.Skipped, SkipNote{Name: name, Reason: refusal.Message})
				continue
			}
			return out, err
		}

		root := filepath.Dir(saved.Path)
		prefix := ""
		if skill.dir != "." {
			prefix = skill.dir + "/"
		}
		for _, extra := range skill.extras {
			if err := writeBundled(root, strings.TrimPrefix(extra.path, prefix), extraContent(extra)); err != nil {
				return out, err
			}
		}
		out.Installed = append(out.Installed, saved.Name)
	}

	// A re-upload is the library's new contents: skills it no longer has go.
	if library != "" {
		for _, stale := range r.librarySkills(userID, library) {
			if seen[stale.Name] {
				continue
			}
			if _, err := r.Delete(ctx, userID, stale.Name); err != nil {
				return out, err
			}
			out.Removed = append(out.Removed, stale.Name)
		}
	}
	return out, nil
}

func orDefaultString(value, fallback string) string {
	if value == "" {
		return fallback
	}
	return value
}

// writeBundled writes a file of a skill folder, refusing a path that leaves it.
func writeBundled(root, relative string, data []byte) error {
	target := filepath.Join(root, filepath.FromSlash(relative))
	if !strings.HasPrefix(target, root+string(filepath.Separator)) {
		return nil
	}
	if err := os.MkdirAll(filepath.Dir(target), 0o700); err != nil {
		return err
	}
	return os.WriteFile(target, data, 0o600)
}

func (r *Runner) userSkill(userID int64, name string) (Skill, bool) {
	for _, s := range r.GetAll(userID) {
		if s.Name == name && s.OwnerType == ownerUser {
			return s, true
		}
	}
	return Skill{}, false
}

func (r *Runner) librarySkills(userID int64, library string) []Skill {
	var out []Skill
	for _, s := range r.GetAll(userID) {
		if s.OwnerType == ownerUser && s.Metadata.Value("library") == library {
			out = append(out, s)
		}
	}
	return out
}

// LibraryToggled is what switching a library answers.
type LibraryToggled struct {
	Success bool   `json:"success"`
	Library string `json:"library"`
	Count   int    `json:"count"`
}

// SetLibraryEnabled switches every skill of a library on or off.
func (r *Runner) SetLibraryEnabled(ctx context.Context, userID int64, library string, enabled bool) (LibraryToggled, error) {
	skills := r.librarySkills(userID, library)
	if len(skills) == 0 {
		return LibraryToggled{}, &StatusError{Status: 404, Message: "No skill library named '" + library + "'"}
	}
	for _, s := range skills {
		if _, err := r.SetEnabled(ctx, userID, s.Name, enabled); err != nil {
			return LibraryToggled{}, err
		}
	}
	return LibraryToggled{Success: true, Library: library, Count: len(skills)}, nil
}

// LibraryDeleted is what deleting a library answers.
type LibraryDeleted struct {
	Success bool     `json:"success"`
	Library string   `json:"library"`
	Deleted []string `json:"deleted"`
}

// DeleteLibrary removes every skill of a library.
func (r *Runner) DeleteLibrary(ctx context.Context, userID int64, library string) (LibraryDeleted, error) {
	skills := r.librarySkills(userID, library)
	if len(skills) == 0 {
		return LibraryDeleted{}, &StatusError{Status: 404, Message: "No skill library named '" + library + "'"}
	}
	deleted := make([]string, 0, len(skills))
	for _, s := range skills {
		if _, err := r.Delete(ctx, userID, s.Name); err != nil {
			return LibraryDeleted{}, err
		}
		deleted = append(deleted, s.Name)
	}
	return LibraryDeleted{Success: true, Library: library, Deleted: deleted}, nil
}

// BuiltinSkill is a skill of a shipped library.
type BuiltinSkill struct {
	Name        string `json:"name"`
	Description string `json:"description"`
}

// Builtin is a skill library shipped with NeoAgent.
type Builtin struct {
	ID          string         `json:"id"`
	Title       string         `json:"title"`
	Description string         `json:"description"`
	Homepage    string         `json:"homepage"`
	License     string         `json:"license"`
	Revision    string         `json:"revision"`
	Skills      []BuiltinSkill `json:"skills"`
}

// readTree lists every file under root as an entry with a forward-slash path.
func readTree(fsys fs.FS, root, relative string) ([]zipEntry, error) {
	items, err := fs.ReadDir(fsys, path.Join(root, relative))
	if err != nil {
		return nil, err
	}
	var entries []zipEntry
	for _, item := range items {
		child := item.Name()
		if relative != "" {
			child = relative + "/" + item.Name()
		}
		switch {
		case item.IsDir():
			sub, err := readTree(fsys, root, child)
			if err != nil {
				return nil, err
			}
			entries = append(entries, sub...)
		case item.Type().IsRegular():
			data, err := fs.ReadFile(fsys, path.Join(root, child))
			if err != nil {
				return nil, err
			}
			entries = append(entries, zipEntry{path: child, data: data})
		}
	}
	return entries, nil
}

func (r *Runner) loadBuiltin(id string) (Builtin, error) {
	raw, err := fs.ReadFile(r.libraries, path.Join(id, manifestFile))
	if err != nil {
		return Builtin{}, err
	}
	var manifest map[string]any
	if err := json.Unmarshal(raw, &manifest); err != nil {
		return Builtin{}, err
	}
	entries, err := readTree(r.libraries, id, "")
	if err != nil {
		return Builtin{}, err
	}
	skills := []BuiltinSkill{}
	for _, f := range findSkills(entries) {
		parsed, _ := ParseFrontmatter(string(f.file.data))
		skills = append(skills, BuiltinSkill{
			Name:        NormalizeName(orDefaultString(parsed.Data["name"], path.Base(f.dir))),
			Description: collapseSpaces(parsed.Data["description"]),
		})
	}
	text := func(key string) string { return jsrules.String(jsrules.OrDefault(manifest[key], "")) }
	return Builtin{
		ID: id, Title: jsrules.String(jsrules.OrDefault(manifest["title"], id)), Description: text("description"),
		Homepage: text("homepage"), License: text("license"), Revision: text("revision"), Skills: skills,
	}, nil
}

// BuiltinLibraries lists the libraries shipped with NeoAgent. The catalog
// ships with the code, so it is read once.
func (r *Runner) BuiltinLibraries() ([]Builtin, error) {
	r.catalogMu.Lock()
	defer r.catalogMu.Unlock()
	if r.catalog != nil {
		return r.catalog, nil
	}
	catalog := []Builtin{}
	items, err := fs.ReadDir(r.libraries, ".")
	if err != nil && !errors.Is(err, fs.ErrNotExist) {
		return nil, err
	}
	for _, item := range items {
		if !item.IsDir() {
			continue
		}
		if _, err := fs.Stat(r.libraries, path.Join(item.Name(), manifestFile)); err != nil {
			continue
		}
		lib, err := r.loadBuiltin(item.Name())
		if err != nil {
			return nil, err
		}
		catalog = append(catalog, lib)
	}
	sort.SliceStable(catalog, func(i, j int) bool { return localeLess(catalog[i].Title, catalog[j].Title) })
	r.catalog = catalog
	return catalog, nil
}

// InstallBuiltin installs, or reinstalls, every skill of a shipped library.
func (r *Runner) InstallBuiltin(ctx context.Context, userID int64, id string) (Installed, error) {
	catalog, err := r.BuiltinLibraries()
	if err != nil {
		return Installed{}, err
	}
	// Only ids from the catalog reach the file system.
	known := false
	for _, lib := range catalog {
		known = known || lib.ID == id
	}
	if !known {
		return Installed{}, &StatusError{Status: 404, Message: "No built-in skill library named '" + id + "'"}
	}
	all, err := readTree(r.libraries, id, "")
	if err != nil {
		return Installed{}, err
	}
	var entries []zipEntry
	for _, e := range all {
		if e.path != manifestFile {
			entries = append(entries, e)
		}
	}
	return r.installEntries(ctx, userID, entries, libraryOptions{library: id, rootName: id, keepLibrary: true})
}
