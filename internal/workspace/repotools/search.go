package repotools

import (
	"context"
	"fmt"
	"math"
	"regexp"
	"strconv"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
)

// search_files (code_search.js): ripgrep when the computer has it, grep
// otherwise, with the same flat result either way.

const (
	searchDefaultMaxResults = 50
	searchMaxResults        = 200
	searchDefaultPerFile    = 15
	searchMaxContext        = 5
	searchMaxLineChars      = 160
	searchMaxOutputBytes    = 45_000
	searchDefaultMaxFile    = 1024 * 1024
)

var (
	skippedDirs = []string{".git", "node_modules", "dist", "build", "coverage", ".next", ".cache", "target", "vendor", "__pycache__", ".venv", "venv"}
	secretFiles = []string{".env", ".env.*"}
)

// boundedInteger is Math.floor(Number(value)) clamped, or fallback when value
// is missing or not a number.
func boundedInteger(value any, fallback, lo, hi int) int {
	if value == nil {
		return fallback
	}
	n := math.Floor(jsNumber(value))
	if math.IsNaN(n) || math.IsInf(n, 0) {
		return fallback
	}
	return int(math.Min(math.Max(n, float64(lo)), float64(hi)))
}

func firstDefined(args dyn.Map, keys ...string) any {
	for _, k := range keys {
		if v := args[k]; v != nil {
			return v
		}
	}
	return nil
}

func includeGlobs(include any) []string {
	list, ok := include.([]any)
	if !ok {
		list = []any{include}
	}
	var out []string
	for _, glob := range list {
		text := ""
		if glob != nil {
			text = strings.TrimSpace(dyn.String(glob))
		}
		if text != "" {
			out = append(out, text)
		}
	}
	return out
}

var bracesPattern = regexp.MustCompile(`^(.*)\{([^{}]*)\}(.*)$`)

func basenameGlobs(glob string) []string {
	parts := strings.Split(glob, "/")
	last := parts[len(parts)-1]
	if last == "" {
		last = "*"
	}
	if m := bracesPattern.FindStringSubmatch(last); m != nil {
		var out []string
		for _, part := range strings.Split(m[2], ",") {
			out = append(out, m[1]+part+m[3])
		}
		return out
	}
	return []string{last}
}

var (
	globToken    = regexp.MustCompile(`\*\*/|\*\*|\*|\?|\{[^{}]*\}|[.+^$()|\\]`)
	globSpecials = regexp.MustCompile(`[.+^$()|\\]`)
)

func globToRegexp(glob string) *regexp.Regexp {
	pattern := globToken.ReplaceAllStringFunc(glob, func(token string) string {
		switch {
		case token == "**/":
			return "(?:.*/)?"
		case token == "**":
			return ".*"
		case token == "*":
			return "[^/]*"
		case token == "?":
			return "[^/]"
		case strings.HasPrefix(token, "{"):
			var alts []string
			for _, part := range strings.Split(token[1:len(token)-1], ",") {
				part = globSpecials.ReplaceAllString(part, `\$0`)
				alts = append(alts, strings.ReplaceAll(part, "*", "[^/]*"))
			}
			return "(?:" + strings.Join(alts, "|") + ")"
		}
		return `\` + token
	})
	re, err := regexp.Compile("^(?:.*/)?" + pattern + "$")
	if err != nil {
		return regexp.MustCompile(`^\b$`)
	}
	return re
}

type searchOptions struct {
	query        string
	target       any
	maxResults   int
	regex        bool
	ignoreCase   bool
	context      int
	maxDepth     int
	maxFileBytes int
	inGenerated  bool
	include      []string
}

func ripgrepCommand(o searchOptions) string {
	flags := []string{
		"--no-config", "--color=never", "--no-heading", "--with-filename", "--line-number", "--null",
		"--hidden", "--sort=path", "--max-columns=400", "--max-columns-preview",
		"--max-filesize=" + strconv.Itoa(o.maxFileBytes), `--max-count="$neo_per"`,
	}
	if !o.regex {
		flags = append(flags, "--fixed-strings")
	}
	if o.ignoreCase {
		flags = append(flags, "--ignore-case")
	} else {
		flags = append(flags, "--case-sensitive")
	}
	if o.context > 0 {
		flags = append(flags, "--context="+strconv.Itoa(o.context))
	}
	if o.maxDepth > 0 {
		flags = append(flags, "--max-depth="+strconv.Itoa(o.maxDepth))
	}
	globs := []string{"!.git"}
	for _, name := range secretFiles {
		globs = append(globs, "!"+name)
	}
	if !o.inGenerated {
		globs = append(globs, "!node_modules")
	}
	globs = append(globs, o.include...)
	args := make([]string, len(globs))
	for i, glob := range globs {
		args[i] = "--glob " + ShellQuote(glob)
	}
	return "rg " + strings.Join(flags, " ") + " " + strings.Join(args, " ") + " -e " + ShellQuote(o.query) + ` -- "$neo_name"`
}

func grepCommand(o searchOptions) string {
	flags := []string{"-rnIH", "--null", "--color=never", `-m "$neo_per"`}
	if o.regex {
		flags = append(flags, "-E")
	} else {
		flags = append(flags, "-F")
	}
	if o.ignoreCase {
		flags = append(flags, "-i")
	}
	if o.context > 0 {
		flags = append(flags, "-C "+strconv.Itoa(o.context))
	}
	var includes []string
	for _, glob := range o.include {
		for _, name := range basenameGlobs(glob) {
			includes = append(includes, "--include="+ShellQuote(name))
		}
	}
	var excludes []string
	for _, name := range skippedDirs {
		excludes = append(excludes, "--exclude-dir="+ShellQuote(name))
	}
	for _, name := range secretFiles {
		excludes = append(excludes, "--exclude="+ShellQuote(name))
	}
	return "grep " + strings.Join(flags, " ") + " " + strings.Join(includes, " ") + " " + strings.Join(excludes, " ") + " -e " + ShellQuote(o.query) + ` -- "$neo_name"`
}

func searchScript(o searchOptions) string {
	lines := enterScript(o.target, false)
	lines = append(lines,
		"neo_per="+strconv.Itoa(searchDefaultPerFile),
		`[ "$neo_name" = . ] || neo_per=`+strconv.Itoa(o.maxResults+1),
		section("directory")+`; printf '%s`+"\n"+`' "$neo_dir"`,
		"neo_tmp=$(mktemp -d) || exit 1",
		`trap 'rm -rf "$neo_tmp"' EXIT`,
		"if command -v rg >/dev/null 2>&1; then",
		"  "+section("engine")+"; echo rg",
		"  "+ripgrepCommand(o)+` >"$neo_tmp/out" 2>"$neo_tmp/err"`,
		"else",
		"  "+section("engine")+"; echo grep",
		"  "+grepCommand(o)+` >"$neo_tmp/out" 2>"$neo_tmp/err"`,
		"fi",
		"neo_code=$?",
		section("exit")+`; echo "$neo_code"`,
		section("size")+`; wc -c <"$neo_tmp/out"`,
		section("stderr")+`; head -c 400 "$neo_tmp/err"; echo`,
		section("matches")+`; LC_ALL=C cut -b 1-700 "$neo_tmp/out" | head -c `+strconv.Itoa(searchMaxOutputBytes),
	)
	return strings.Join(lines, "\n")
}

type searchLine struct {
	file    string
	depth   int
	line    int
	isMatch bool
	content string
}

var outputLinePattern = regexp.MustCompile(`(?s)^(\d+)([:-])(.*)$`)

func cleanRelative(base, name string) string {
	if base == "." {
		return name
	}
	return strings.TrimRight(base, "/") + "/" + name
}

func outputLine(raw, base string) *searchLine {
	sep := strings.IndexByte(raw, 0)
	if sep < 0 {
		return nil
	}
	m := outputLinePattern.FindStringSubmatch(raw[sep+1:])
	if m == nil {
		return nil
	}
	name := strings.TrimPrefix(raw[:sep], "./")
	n, _ := strconv.Atoi(m[1])
	return &searchLine{
		file:    cleanRelative(base, name),
		depth:   len(strings.Split(name, "/")),
		line:    n,
		isMatch: m[2] == ":",
		content: sliceUTF16(trimEndJS(m[3]), searchMaxLineChars),
	}
}

func groupMatches(lines []*searchLine, maxResults int) (matches []any, shown, total, files int) {
	var order []string
	byFile := map[string][]*searchLine{}
	for _, line := range lines {
		if _, ok := byFile[line.file]; !ok {
			order = append(order, line.file)
		}
		byFile[line.file] = append(byFile[line.file], line)
	}
	matches = []any{}
	for _, file := range order {
		named := false
		for _, entry := range byFile[file] {
			if entry.isMatch {
				total++
			}
			if shown >= maxResults {
				continue
			}
			if entry.isMatch {
				shown++
			}
			item := dyn.Ordered{}
			if !named {
				item = append(item, dyn.KV{Key: "file", Value: file})
			}
			var line any = entry.line
			if !entry.isMatch {
				line = strconv.Itoa(entry.line) + "-"
			}
			item = append(item, dyn.KV{Key: "line", Value: line}, dyn.KV{Key: "content", Value: entry.content})
			matches = append(matches, item)
			named = true
		}
	}
	return matches, shown, total, len(order)
}

var patternLike = regexp.MustCompile(`[|\\^$]|\.\*|\(.*\)|\[.*\]`)

func emptyResultNote(o searchOptions) string {
	if !o.regex && patternLike.MatchString(o.query) {
		return "No matches for this exact text. If it was meant as a pattern, set regex to true."
	}
	return "No matches. Ignored and generated files are not searched."
}

var (
	hasUpper      = regexp.MustCompile(`[A-Z]`)
	nodeModulesIn = regexp.MustCompile(`(^|/)node_modules(/|$)`)
)

func searchFailure(msg string) dyn.Ordered {
	return dyn.Ordered{{Key: "error", Value: msg}, {Key: "count", Value: 0}, {Key: "matches", Value: []any{}}}
}

// Search runs search_files.
func Search(ctx context.Context, shell Shell, args dyn.Map) (any, error) {
	query := ""
	if args["query"] != nil {
		query = dyn.String(args["query"])
	}
	if strings.TrimSpace(query) == "" {
		return searchFailure("search_files requires a query."), nil
	}
	if strings.ContainsAny(query, "\r\n") {
		return searchFailure("query must be a single line."), nil
	}
	maxResults := boundedInteger(firstDefined(args, "max_results", "maxResults"), searchDefaultMaxResults, 1, searchMaxResults)
	include := includeGlobs(args["include"])
	o := searchOptions{
		query:        query,
		target:       args["path"],
		maxResults:   maxResults,
		regex:        args["regex"] == true,
		context:      boundedInteger(args["context"], 0, 0, searchMaxContext),
		maxDepth:     boundedInteger(firstDefined(args, "maxDepth", "max_depth"), 0, 0, 32),
		maxFileBytes: boundedInteger(firstDefined(args, "maxFileSize", "max_file_size"), searchDefaultMaxFile, 1, 64*1024*1024),
		inGenerated:  nodeModulesIn.MatchString(WorkspaceRelative(args["path"])),
		include:      include,
	}
	if cs, ok := args["case_sensitive"].(bool); ok {
		o.ignoreCase = !cs
	} else {
		o.ignoreCase = !hasUpper.MatchString(query)
	}

	result, err := shell.Run(ctx, searchScript(o), 0)
	if err != nil {
		return nil, err
	}
	if failure := commandError(result); failure != "" {
		return searchFailure(failure), nil
	}
	secs := parseSections(result["stdout"])
	if location := locationError(secs, args["path"]); location != "" {
		return searchFailure(location), nil
	}
	exitCode := jsNumber(secs.line("exit", 0))
	if secs.first("exit") == nil || len(secs.raw("exit")) == 0 {
		exitCode = math.NaN()
	}
	stderr := strings.TrimSpace(strings.Join(secs.raw("stderr"), " "))
	body := secs.raw("matches")
	engine := secs.line("engine", 0)
	var pathFilters []*regexp.Regexp
	if engine == "grep" {
		for _, glob := range include {
			if strings.Contains(glob, "/") {
				pathFilters = append(pathFilters, globToRegexp(glob))
			}
		}
	}
	directory := secs.line("directory", 0)
	if directory == "" {
		directory = "."
	}
	var lines []*searchLine
	for _, raw := range body {
		line := outputLine(raw, directory)
		if line == nil {
			continue
		}
		if len(pathFilters) > 0 && !anyMatch(pathFilters, line.file) {
			continue
		}
		if engine == "grep" && o.maxDepth > 0 && line.depth > o.maxDepth {
			continue
		}
		lines = append(lines, line)
	}
	if len(lines) == 0 && exitCode > 1 {
		msg := stderr
		if msg == "" {
			msg = fmt.Sprintf("search failed with exit code %s", dyn.Number(exitCode))
		}
		return searchFailure(msg), nil
	}
	matches, shown, total, files := groupMatches(lines, maxResults)
	cut := jsNumber(secs.line("size", 0)) > searchMaxOutputBytes
	out := dyn.Ordered{
		{Key: "count", Value: total},
		{Key: "files", Value: files},
		{Key: "matches", Value: matches},
		{Key: "truncated", Value: cut || total > shown},
	}
	if secs.first("engine") != nil && len(secs.raw("engine")) > 0 {
		out = append(out, dyn.KV{Key: "engine", Value: engine})
	}
	if total == 0 {
		out = append(out, dyn.KV{Key: "note", Value: emptyResultNote(o)})
	}
	return out, nil
}

func anyMatch(filters []*regexp.Regexp, s string) bool {
	for _, f := range filters {
		if f.MatchString(s) {
			return true
		}
	}
	return false
}

// sliceUTF16 is String.prototype.slice(0, n) counted in UTF-16 units.
func sliceUTF16(s string, n int) string {
	units := 0
	for i, r := range s {
		w := 1
		if r > 0xFFFF {
			w = 2
		}
		if units+w > n {
			return s[:i]
		}
		units += w
	}
	return s
}

// lenUTF16 is String.prototype.length.
func lenUTF16(s string) int {
	n := 0
	for _, r := range s {
		if r > 0xFFFF {
			n += 2
		} else {
			n++
		}
	}
	return n
}

// trimEndJS is String.prototype.trimEnd.
func trimEndJS(s string) string {
	return strings.TrimRightFunc(s, isJSSpace)
}

func isJSSpace(r rune) bool {
	switch r {
	case '\t', '\n', '\v', '\f', '\r', ' ', 0xA0, 0x1680, 0x2028, 0x2029, 0x202F, 0x205F, 0x3000, 0xFEFF:
		return true
	}
	return r >= 0x2000 && r <= 0x200A
}
