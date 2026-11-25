package skills

import (
	"github.com/NeoLabs-Systems/neoagent/internal/jsrules"
	"regexp"
	"strings"
	"unicode"

	"github.com/NeoLabs-Systems/neoagent/internal/workspace"
)

// JavaScript's \s and "." differ from RE2's, and the Node parsers relied on
// them (a "\r" at the end of a line stops a value from matching), so the
// patterns spell the JavaScript classes out.
const (
	jsSpaceClass = `\t\n\v\f\r \x{a0}\x{1680}\x{2000}-\x{200a}\x{2028}\x{2029}\x{202f}\x{205f}\x{3000}\x{feff}`
	jsDotClass   = `[^\n\r\x{2028}\x{2029}]`
)

var (
	documentRE    = regexp.MustCompile(`(?s)^---\n(.*?)\n---\n?(.*)`)
	strictDocRE   = regexp.MustCompile(`(?s)^---\n(.*?)\n---\n?(.*)$`)
	metaLineRE    = regexp.MustCompile(`^(\w[\w-]*)[` + jsSpaceClass + `]*:[` + jsSpaceClass + `]*(` + jsDotClass + `+)$`)
	shareKeyRE    = regexp.MustCompile(`^([A-Za-z_][\w-]*)[` + jsSpaceClass + `]*:[` + jsSpaceClass + `]*(` + jsDotClass + `*)$`)
	blockStartRE  = regexp.MustCompile(`^[>|][-+]?$`)
	spaceRunRE    = regexp.MustCompile(`[` + jsSpaceClass + `]+`)
	frontOnlyRE   = regexp.MustCompile(`(?s)^---\n(.*?)\n---`)
	storeIDLineRE = regexp.MustCompile(`(?m)^store_id[` + jsSpaceClass + `]*:`)
)

func collapseSpaces(s string) string { return jsrules.Trim(spaceRunRE.ReplaceAllString(s, " ")) }

// parseScalar reads one front matter value: true and false become booleans,
// a JSON object or array its decoded form (kept raw when it is not valid
// JSON), anything else the text.
func parseScalar(value string) any {
	switch value {
	case "true":
		return true
	case "false":
		return false
	}
	if strings.HasPrefix(value, "{") || strings.HasPrefix(value, "[") {
		if parsed, err := workspace.DecodeJSON([]byte(value)); err == nil {
			return parsed
		}
	}
	return value
}

// splitDocument is the front matter text and the body of a skill file.
func splitDocument(content string) (front, body string, ok bool) {
	m := documentRE.FindStringSubmatch(content)
	if m == nil {
		return "", "", false
	}
	return m[1], m[2], true
}

// loadedSkill is what a SKILL.md says about itself.
type loadedSkill struct {
	Name         string
	Description  string
	Metadata     Meta
	Instructions string
}

// parseSkillFile reads a SKILL.md the way the runner does. It reports false
// when the file has no front matter or no usable name.
func parseSkillFile(content string) (loadedSkill, bool) {
	front, body, ok := splitDocument(content)
	if !ok {
		return loadedSkill{}, false
	}
	meta := Meta{}
	for _, line := range strings.Split(front, "\n") {
		m := metaLineRE.FindStringSubmatch(line)
		if m == nil {
			continue
		}
		meta = meta.With(strings.TrimSpace(m[1]), parseScalar(jsrules.Trim(m[2])))
	}
	name := NormalizeName(jsrules.String(jsrules.OrDefault(meta.Value("name"), "")))
	if name == "" {
		return loadedSkill{}, false
	}
	return loadedSkill{
		Name:         name,
		Description:  jsrules.OrEmpty(meta.Value("description")),
		Metadata:     meta,
		Instructions: jsrules.Trim(body),
	}, true
}

// isRetiredStoreSkill reports a skill the removed built-in store installed; it
// carries a store_id key.
func isRetiredStoreSkill(content string) bool {
	m := frontOnlyRE.FindStringSubmatch(strings.ReplaceAll(content, "\r\n", "\n"))
	return m != nil && storeIDLineRE.MatchString(m[1])
}

// Document is a skill as the editor submits it.
type Document struct {
	Name         string
	Description  string
	Instructions string
	Metadata     Meta
}

// ParseDocument reads the content the skill editor sends. The error texts are
// the ones the API answers with.
func ParseDocument(content string) (Document, string) {
	m := strictDocRE.FindStringSubmatch(content)
	if m == nil {
		return Document{}, "Skill files must start with frontmatter delimited by ---"
	}
	front := Meta{}
	for _, line := range strings.Split(m[1], "\n") {
		colon := strings.Index(line, ":")
		if colon == -1 {
			continue
		}
		front = front.With(jsrules.Trim(line[:colon]), parseScalar(jsrules.Trim(line[colon+1:])))
	}
	rawName := front.Value("name")
	if !jsrules.Truthy(rawName) {
		return Document{}, "Skill frontmatter must include name"
	}
	return Document{
		Name:         jsrules.String(rawName),
		Description:  jsrules.OrEmpty(front.Value("description")),
		Instructions: jsrules.Trim(m[2]),
		Metadata:     front.Without("name", "description"),
	}, ""
}

// Frontmatter holds the top-level string keys of a skill file written for
// another agent (skills.sh and library skills) and its body.
type Frontmatter struct {
	Data map[string]string
	Body string
}

// ParseFrontmatter reads top-level keys, quoted values and YAML block scalars
// (`>` and `|`), the way longer skill descriptions are written.
func ParseFrontmatter(content string) (Frontmatter, bool) {
	m := strictDocRE.FindStringSubmatch(strings.ReplaceAll(content, "\r\n", "\n"))
	if m == nil {
		return Frontmatter{}, false
	}
	data := map[string]string{}
	lines := strings.Split(m[1], "\n")
	for i := 0; i < len(lines); i++ {
		km := shareKeyRE.FindStringSubmatch(lines[i])
		if km == nil {
			continue
		}
		value := jsrules.Trim(km[2])
		switch {
		case blockStartRE.MatchString(value):
			var block []string
			for i+1 < len(lines) && (lines[i+1] == "" || startsWithSpace(lines[i+1])) {
				i++
				block = append(block, jsrules.Trim(lines[i]))
			}
			if strings.HasPrefix(value, "|") {
				value = jsrules.Trim(strings.Join(block, "\n"))
			} else {
				value = collapseSpaces(strings.Join(block, " "))
			}
		case isQuoted(value):
			value = value[1 : len(value)-1]
		}
		data[km[1]] = value
	}
	return Frontmatter{Data: data, Body: m[2]}, true
}

func startsWithSpace(s string) bool {
	for _, r := range s {
		return jsrules.IsSpace(r)
	}
	return false
}

// isQuoted is /^(['"]).*\1$/ for a value with no line breaks inside.
func isQuoted(v string) bool {
	if len(v) < 2 || (v[0] != '"' && v[0] != '\'') || v[len(v)-1] != v[0] {
		return false
	}
	return !strings.ContainsAny(v[1:len(v)-1], "\n\r  ")
}

// NormalizeName turns a skill name into the folder-safe form: letters, digits
// and single hyphens, lower case.
func NormalizeName(name string) string {
	var b strings.Builder
	dash := false
	for _, r := range jsrules.Trim(name) {
		ok := r < unicode.MaxASCII && (r == '-' || r >= '0' && r <= '9' || r >= 'a' && r <= 'z' || r >= 'A' && r <= 'Z')
		if !ok || r == '-' {
			if !dash {
				b.WriteByte('-')
			}
			dash = true
			continue
		}
		dash = false
		b.WriteRune(r)
	}
	return strings.ToLower(strings.Trim(b.String(), "-"))
}

// buildFrontmatter writes a skill file's header. Object values go in as JSON,
// everything else as text.
func buildFrontmatter(name, description string, metadata Meta) string {
	var b strings.Builder
	b.WriteString("---\nname: " + name + "\ndescription: " + description + "\n")
	for _, f := range metadata {
		if f.Key == "name" || f.Key == "description" {
			continue
		}
		switch v := f.Value.(type) {
		case nil, workspace.Obj, []any:
			b.WriteString(f.Key + ": " + jsrules.JSON(v) + "\n")
		default:
			b.WriteString(f.Key + ": " + workspace.CoerceText(v) + "\n")
		}
	}
	b.WriteString("---")
	return b.String()
}
