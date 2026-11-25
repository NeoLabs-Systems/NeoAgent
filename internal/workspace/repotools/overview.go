package repotools

import (
	"context"
	"regexp"
	"sort"
	"strconv"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/tasks/jsv"
)

// repo_overview and test detection (repo_inspect.js).

const (
	maxLayoutEntries = 40
	maxDirtyFiles    = 20
	maxLanguages     = 8
	maxScripts       = 8
	maxScriptChars   = 100
)

var (
	docFile   = regexp.MustCompile(`(?i)^(readme|agents|claude|contributing|guidelines)(\.\w+)?$`)
	manifests = map[string]bool{
		"package.json": true, "pnpm-workspace.yaml": true, "pyproject.toml": true, "setup.py": true, "requirements.txt": true, "go.mod": true, "Cargo.toml": true,
		"pubspec.yaml": true, "Gemfile": true, "pom.xml": true, "build.gradle": true, "build.gradle.kts": true, "composer.json": true, "Makefile": true, "CMakeLists.txt": true,
		"Dockerfile": true, "tsconfig.json": true,
	}
	usefulScript    = regexp.MustCompile(`^(test|lint|build|check|typecheck|format)`)
	noTestSpecified = regexp.MustCompile(`(?i)no test specified`)
)

func probeScript() []string {
	return []string{
		section("listing") + "; ls -Ap | head -n 200",
		section("package") + "; [ -f package.json ] && head -c 65536 package.json; echo",
		section("make") + "; [ -f Makefile ] && grep -E '^(test|check)[A-Za-z0-9_-]*:' Makefile | head -n 5",
		section("flutter") + "; [ -f pubspec.yaml ] && grep -cE '^[[:space:]]*flutter:' pubspec.yaml",
		section("pytest") + "; [ -f pyproject.toml ] && grep -c pytest pyproject.toml",
	}
}

type probe struct {
	listing     []string
	names       map[string]bool
	packageJSON *jsv.Object
	makeTargets []string
	flutter     bool
	pytest      bool
}

func parseProbe(s sections) probe {
	p := probe{listing: s.lines("listing"), names: map[string]bool{}}
	for _, entry := range p.listing {
		p.names[strings.TrimSuffix(entry, "/")] = true
	}
	if v, err := jsv.Decode([]byte(strings.Join(s.raw("package"), "\n"))); err == nil {
		if o, ok := v.(*jsv.Object); ok {
			p.packageJSON = o
		}
	}
	for _, line := range s.lines("make") {
		p.makeTargets = append(p.makeTargets, strings.Split(line, ":")[0])
	}
	p.flutter = firstNumber(s.lines("flutter")) > 0
	p.pytest = firstNumber(s.lines("pytest")) > 0
	return p
}

func firstNumber(lines []string) float64 {
	if len(lines) == 0 {
		return 0
	}
	return jsNumber(lines[0])
}

func (p probe) scripts() *jsv.Object {
	if p.packageJSON == nil {
		return nil
	}
	s, _ := p.packageJSON.Val("scripts").(*jsv.Object)
	return s
}

func packageTestCommand(p probe) string {
	scripts := p.scripts()
	if scripts == nil {
		return ""
	}
	script, ok := scripts.Val("test").(string)
	if !ok || noTestSpecified.MatchString(script) {
		return ""
	}
	switch {
	case p.names["pnpm-lock.yaml"]:
		return "pnpm test"
	case p.names["yarn.lock"]:
		return "yarn test"
	case p.names["bun.lock"] || p.names["bun.lockb"]:
		return "bun run test"
	}
	return "npm test"
}

type testCommand struct{ command, source string }

func detectTestCommand(p probe) *testCommand {
	n := p.names
	if cmd := packageTestCommand(p); cmd != "" {
		return &testCommand{cmd, "package.json"}
	}
	for _, t := range p.makeTargets {
		if t == "test" {
			return &testCommand{"make test", "Makefile"}
		}
	}
	switch {
	case n["go.mod"]:
		return &testCommand{"go test ./...", "go.mod"}
	case n["Cargo.toml"]:
		return &testCommand{"cargo test", "Cargo.toml"}
	case n["pubspec.yaml"]:
		if p.flutter {
			return &testCommand{"flutter test", "pubspec.yaml"}
		}
		return &testCommand{"dart test", "pubspec.yaml"}
	case n["pytest.ini"] || n["conftest.py"] || n["tox.ini"] || p.pytest:
		return &testCommand{"python3 -m pytest", "pytest config"}
	case n["tests"] && (n["pyproject.toml"] || n["setup.py"] || n["requirements.txt"]):
		return &testCommand{"python3 -m pytest", "tests/"}
	case n["Gemfile"] && n["spec"]:
		return &testCommand{"bundle exec rspec", "Gemfile"}
	case n["gradlew"]:
		return &testCommand{"./gradlew test", "gradlew"}
	case n["build.gradle"] || n["build.gradle.kts"]:
		return &testCommand{"gradle test", "build.gradle"}
	case n["pom.xml"]:
		return &testCommand{"mvn test", "pom.xml"}
	case n["package.json"] && (n["test"] || n["tests"]):
		return &testCommand{"node --test", "test directory"}
	}
	return nil
}

func detectProjectTests(ctx context.Context, shell Shell, target any) (*testCommand, string, error) {
	script := append(enterScript(target, true), probeScript()...)
	result, err := shell.Run(ctx, strings.Join(script, "\n"), 0)
	if err != nil {
		return nil, "", err
	}
	if failure := commandError(result); failure != "" {
		return nil, failure, nil
	}
	secs := parseSections(result["stdout"])
	if location := locationError(secs, target); location != "" {
		return nil, location, nil
	}
	return detectTestCommand(parseProbe(secs)), "", nil
}

func overviewScript(target any) string {
	tally := `awk -F/ '{ top[NF>1 ? $1 "/" : $1]++; n=split($NF, p, "."); if (n>1) ext[tolower(p[n])]++ } END { for (k in top) print "T", top[k], k; for (k in ext) print "E", ext[k], k }'`
	lines := enterScript(target, false)
	lines = append(lines, GitFunction, section("root")+"; pwd -P")
	lines = append(lines, probeScript()...)
	lines = append(lines,
		"if g rev-parse --is-inside-work-tree >/dev/null 2>&1; then",
		"  neo_top=$(g rev-parse --show-toplevel)",
		`  case "$neo_top/" in "$neo_root"/*) ;; *) `+section("outside")+"; exit 0 ;; esac",
		"  "+section("toplevel")+`; printf '%s\n' "$neo_top"`,
		"  "+section("branch")+"; g symbolic-ref --short -q HEAD || g rev-parse --short HEAD 2>/dev/null || echo '(no commits)'",
		"  "+section("head")+"; g log -1 --format='%h %s' 2>/dev/null | cut -c 1-120",
		"  "+section("upstream")+"; g rev-parse --abbrev-ref '@{u}' 2>/dev/null && g rev-list --left-right --count '@{u}...HEAD' 2>/dev/null",
	)
	lines = append(lines, snapshotLines(true)...)
	lines = append(lines,
		"  "+section("dirty")+`; tail -n +3 "$neo_tmp/snapshot" | awk 'NR<=`+strconv.Itoa(maxDirtyFiles)+` { print } END { print "total " NR }'`,
		"  "+section("tally")+"; g ls-files | "+tally,
		"else",
		"  "+section("repos")+`; for neo_d in */; do [ -e "$neo_d/.git" ] && printf '%s\n' "$neo_d"; done 2>/dev/null | head -n 20`,
		"  "+section("tally")+`; find . -maxdepth 4 \( -name node_modules -o -name .git -o -name .cache \) -prune -o -type f -print 2>/dev/null | head -n 5000 | sed 's|^\./||' | `+tally,
		"fi",
	)
	return strings.Join(lines, "\n")
}

var tallyLine = regexp.MustCompile(`^([TE]) (\d+) (.+)$`)

type extCount struct {
	name  string
	files int
}

func parseTally(lines []string) (map[string]int, []extCount) {
	tops := map[string]int{}
	var exts []extCount
	for _, line := range lines {
		m := tallyLine.FindStringSubmatch(line)
		if m == nil {
			continue
		}
		n, _ := strconv.Atoi(m[2])
		if m[1] == "T" {
			tops[m[3]] = n
		} else {
			exts = append(exts, extCount{m[3], n})
		}
	}
	sort.SliceStable(exts, func(i, j int) bool {
		if exts[i].files != exts[j].files {
			return exts[i].files > exts[j].files
		}
		return localeCompare(exts[i].name, exts[j].name) < 0
	})
	return tops, exts
}

func layoutEntries(listing []string, tops map[string]int) []any {
	var entries []string
	for _, entry := range listing {
		if entry == ".git/" || entry == ".git" {
			continue
		}
		if n := tops[entry]; n > 1 {
			entry += " (" + strconv.Itoa(n) + ")"
		}
		entries = append(entries, entry)
	}
	out := []any{}
	for i, entry := range entries {
		if i == maxLayoutEntries {
			out = append(out, "...and "+strconv.Itoa(len(entries)-maxLayoutEntries)+" more")
			break
		}
		out = append(out, entry)
	}
	return out
}

func usefulScripts(p probe) any {
	scripts := p.scripts()
	if scripts == nil {
		return nil
	}
	out := dyn.Ordered{}
	for _, name := range scripts.Keys() {
		value, ok := scripts.Val(name).(string)
		if !usefulScript.MatchString(name) || !ok {
			continue
		}
		if len(out) == maxScripts {
			break
		}
		if lenUTF16(value) > maxScriptChars {
			value = sliceUTF16(value, maxScriptChars) + "..."
		}
		out = append(out, dyn.KV{Key: name, Value: value})
	}
	if len(out) == 0 {
		return nil
	}
	return out
}

var (
	totalLine  = regexp.MustCompile(`^total (\d+)$`)
	whitespace = regexp.MustCompile(`\s+`)
)

func gitSummary(s sections) any {
	toplevel := ""
	if l := s.lines("toplevel"); len(l) > 0 {
		toplevel = l[0]
	}
	if toplevel == "" {
		return nil
	}
	dirtyLines := s.lines("dirty")
	total := 0
	if len(dirtyLines) > 0 {
		if m := totalLine.FindStringSubmatch(dirtyLines[len(dirtyLines)-1]); m != nil {
			total, _ = strconv.Atoi(m[1])
		}
	}
	up := s.lines("upstream")
	out := dyn.Ordered{{Key: "toplevel", Value: toplevel}}
	if l := s.lines("branch"); len(l) > 0 {
		out = append(out, dyn.KV{Key: "branch", Value: l[0]})
	}
	if l := s.lines("head"); len(l) > 0 {
		out = append(out, dyn.KV{Key: "head", Value: l[0]})
	}
	if len(up) > 0 && up[0] != "" {
		counts := ""
		if len(up) > 1 {
			counts = up[1]
		}
		parts := whitespace.Split(counts, -1)
		behind := jsNumber(parts[0])
		out = append(out, dyn.KV{Key: "upstream", Value: up[0]})
		if len(parts) > 1 {
			out = append(out, dyn.KV{Key: "ahead", Value: numberValue(jsNumber(parts[1]))})
		}
		out = append(out, dyn.KV{Key: "behind", Value: numberValue(behind)})
	}
	out = append(out, dyn.KV{Key: "dirty", Value: total})
	if total > 0 {
		files := []any{}
		for _, line := range dirtyLines[:len(dirtyLines)-1] {
			files = append(files, trimEndJS(line))
		}
		out = append(out, dyn.KV{Key: "dirty_files", Value: files})
	}
	if total > maxDirtyFiles {
		out = append(out, dyn.KV{Key: "dirty_files_omitted", Value: total - maxDirtyFiles})
	}
	return out
}

// numberValue is a number as JSON.stringify writes it: NaN becomes null.
func numberValue(n float64) any {
	if n != n {
		return nil
	}
	return n
}

// Overview runs repo_overview.
func Overview(ctx context.Context, shell Shell, args dyn.Map) (any, error) {
	result, err := shell.Run(ctx, overviewScript(args["path"]), 0)
	if err != nil {
		return nil, err
	}
	if failure := commandError(result); failure != "" {
		return dyn.Map{"error": failure}, nil
	}
	secs := parseSections(result["stdout"])
	if location := locationError(secs, args["path"]); location != "" {
		return dyn.Map{"error": location}, nil
	}
	if secs.first("failed") != nil {
		return dyn.Map{"error": "Could not snapshot the repository: " + strings.Join(secs.lines("failed"), " ")}, nil
	}
	p := parseProbe(secs)
	tops, exts := parseTally(secs.lines("tally"))
	repos := secs.lines("repos")
	out := dyn.Ordered{
		{Key: "path", Value: WorkspaceRelative(args["path"])},
		{Key: "git", Value: gitSummary(secs)},
	}
	if len(repos) > 0 {
		out = append(out, dyn.KV{Key: "repos", Value: toAny(repos)})
	}
	languages := []any{}
	for i, e := range exts {
		if i == maxLanguages {
			break
		}
		languages = append(languages, e.name+": "+strconv.Itoa(e.files))
	}
	found, docs := []any{}, []any{}
	for _, entry := range p.listing {
		if manifests[entry] {
			found = append(found, entry)
		}
		if docFile.MatchString(entry) {
			docs = append(docs, entry)
		}
	}
	var test any = "not detected: pass a command to run_tests"
	if t := detectTestCommand(p); t != nil {
		test = dyn.Ordered{{Key: "command", Value: t.command}, {Key: "source", Value: t.source}}
	}
	out = append(out,
		dyn.KV{Key: "layout", Value: layoutEntries(p.listing, tops)},
		dyn.KV{Key: "languages", Value: languages},
		dyn.KV{Key: "manifests", Value: found},
		dyn.KV{Key: "docs", Value: docs},
		dyn.KV{Key: "test", Value: test},
	)
	if scripts := usefulScripts(p); scripts != nil {
		out = append(out, dyn.KV{Key: "scripts", Value: scripts})
	}
	return out, nil
}

func toAny(list []string) []any {
	out := make([]any, len(list))
	for i, s := range list {
		out[i] = s
	}
	return out
}

// localeCompare approximates String.prototype.localeCompare for extension
// names: case-insensitive first, then by code point.
func localeCompare(a, b string) int {
	la, lb := strings.ToLower(a), strings.ToLower(b)
	if la != lb {
		return strings.Compare(la, lb)
	}
	return strings.Compare(a, b)
}
