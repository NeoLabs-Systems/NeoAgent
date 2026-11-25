package agentimport

import (
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
)

var skillFileSkip = map[string]bool{".git": true, "node_modules": true, "__pycache__": true, ".venv": true, "venv": true, ".DS_Store": true}

const maxSkillFileBytes = 5 * 1024 * 1024

// sortedEntries lists a folder in name order, so scans are repeatable.
func sortedEntries(dir string) ([]os.DirEntry, error) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, err
	}
	sort.Slice(entries, func(i, j int) bool { return entries[i].Name() < entries[j].Name() })
	return entries, nil
}

// listSkillFiles lists the files bundled with a skill (scripts, references,
// templates) relative to its folder, without SKILL.md itself.
func listSkillFiles(dir string) []string {
	var files []string
	var walk func(string)
	walk = func(current string) {
		entries, err := sortedEntries(current)
		if err != nil {
			return
		}
		for _, e := range entries {
			if skillFileSkip[e.Name()] {
				continue
			}
			full := filepath.Join(current, e.Name())
			switch {
			case e.IsDir():
				walk(full)
			case e.Type().IsRegular() && full != filepath.Join(dir, "SKILL.md"):
				if st, err := os.Stat(full); err == nil && st.Size() <= maxSkillFileBytes {
					rel, _ := filepath.Rel(dir, full)
					files = append(files, rel)
				}
			}
		}
	}
	walk(dir)
	return files
}

// findSkillDirs lists every folder holding a SKILL.md under root, at any depth
// (Hermes nests skills in category folders). A skill's own subfolders are not
// searched.
func findSkillDirs(root string) []string {
	var found []string
	var walk func(string, int)
	walk = func(dir string, depth int) {
		if depth > 4 {
			return
		}
		entries, err := sortedEntries(dir)
		if err != nil {
			return
		}
		for _, e := range entries {
			if e.Type().IsRegular() && e.Name() == "SKILL.md" {
				found = append(found, dir)
				return
			}
		}
		for _, e := range entries {
			if e.IsDir() && !skillFileSkip[e.Name()] && !strings.HasPrefix(e.Name(), ".") {
				walk(filepath.Join(dir, e.Name()), depth+1)
			}
		}
	}
	if isDir(root) {
		walk(root, 0)
	}
	return found
}

var (
	frontmatter = regexp.MustCompile(`(?s)^---\n(.*?)\n---\n?(.*)$`)
	frontKey    = regexp.MustCompile(`^([A-Za-z_][A-Za-z0-9_-]*)` + ws + `*:` + ws + `*(.*)$`)
	blockStart  = regexp.MustCompile(`^[>|][-+]?$`)
	leadingWS   = regexp.MustCompile(`^` + ws)
	headingHash = regexp.MustCompile(`^#+` + ws + `*`)
)

// parseFrontmatter reads the top-level keys of a SKILL.md header: quoted
// values and YAML block scalars (`>` and `|`), which is how longer
// descriptions are written. ok is false when the file has no header.
func parseFrontmatter(content string) (data map[string]string, body string, ok bool) {
	m := frontmatter.FindStringSubmatch(strings.ReplaceAll(content, "\r\n", "\n"))
	if m == nil {
		return nil, "", false
	}
	data = map[string]string{}
	lines := strings.Split(m[1], "\n")
	for i := 0; i < len(lines); i++ {
		km := frontKey.FindStringSubmatch(lines[i])
		if km == nil {
			continue
		}
		value := trim(km[2])
		if blockStart.MatchString(value) {
			var block []string
			for i+1 < len(lines) && (leadingWS.MatchString(lines[i+1]) || lines[i+1] == "") {
				i++
				block = append(block, trim(lines[i]))
			}
			if strings.HasPrefix(value, "|") {
				value = trim(strings.Join(block, "\n"))
			} else {
				value = trim(wsRun.ReplaceAllString(strings.Join(block, " "), " "))
			}
		} else if n := len(value); n >= 2 && (value[0] == '"' || value[0] == '\'') && value[n-1] == value[0] {
			value = value[1 : n-1]
		}
		data[km[1]] = value
	}
	return data, m[2], true
}

// readSkill reads a skill folder. A SKILL.md without a header still imports,
// named after its folder. It returns false for an empty or missing file.
func readSkill(dir, origin string) (Skill, bool) {
	text, ok := readText(filepath.Join(dir, "SKILL.md"))
	if !ok || trim(text) == "" {
		return Skill{}, false
	}
	data, body, hasHeader := parseFrontmatter(text)
	if !hasHeader {
		body = text
	}
	body = trim(body)
	firstLine := ""
	for _, line := range strings.Split(body, "\n") {
		if l := trim(headingHash.ReplaceAllString(line, "")); l != "" {
			firstLine = l
			break
		}
	}
	name := data["name"]
	if name == "" {
		name = filepath.Base(dir)
	}
	description := data["description"]
	if description == "" {
		description = firstLine
	}
	return Skill{
		Name:        trim(name),
		Description: jsSlice(collapse(description), 300),
		Body:        body,
		Dir:         dir,
		Origin:      origin,
		Files:       listSkillFiles(dir),
	}, true
}
