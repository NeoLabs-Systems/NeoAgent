package repotools

import (
	"context"
	"errors"
	"math"
	"regexp"
	"sort"
	"strconv"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
)

// repo_diff (repo_diff.js): what this run changed, or everything uncommitted,
// or everything since a ref, with a per-file share of the character budget.

const (
	diffDefaultMaxChars = 12_000
	diffMaxChars        = 30_000
	maxListedFiles      = 100
	maxDiffedFiles      = 40
	maxRunPaths         = 500
	maxScriptBytes      = 45_000
	gitDiff             = "g --literal-pathspecs diff --no-ext-diff --no-textconv --no-color --no-renames"
)

// Repository is what a run's checkpoints recorded it changed in one repository.
type Repository struct {
	Root  string
	Paths []RepositoryPath
}

// RepositoryPath is one changed file and the tree it had before the run.
type RepositoryPath struct {
	Path   string
	Source string
}

func enterRepositoryLines(target any, anywhere bool) []string {
	lines := enterScript(target, anywhere)
	lines = append(lines,
		GitFunction,
		"g rev-parse --is-inside-work-tree >/dev/null 2>&1 || { "+section("not-repo")+"; exit 0; }",
		"neo_top=$(g rev-parse --show-toplevel)",
	)
	if !anywhere {
		lines = append(lines, `case "$neo_top/" in "$neo_root"/*) ;; *) `+section("outside")+"; exit 0 ;; esac")
	}
	return append(lines,
		`cd "$neo_top" || exit 1`,
		section("root")+`; printf '%s\n' "$neo_top"`,
		section("branch")+"; g symbolic-ref --short -q HEAD || g rev-parse --short HEAD 2>/dev/null || echo '(no commits)'",
	)
}

var treeID = regexp.MustCompile(`^[0-9a-f]{40,64}$`)

func listingLines(baseExpression string, paths []string) ([]string, error) {
	base := `"$neo_base"`
	if baseExpression != "$neo_base" {
		base = ShellQuote(baseExpression)
		if !treeID.MatchString(baseExpression) {
			return nil, errors.New("A recorded snapshot is not a tree id.")
		}
	}
	pathspec := ""
	if len(paths) > 0 {
		quoted := make([]string, len(paths))
		for i, p := range paths {
			quoted[i] = ShellQuote(p)
		}
		pathspec = " -- " + strings.Join(quoted, " ")
	}
	return []string{
		`printf '%s\n' "@@neoagent:listing "` + base,
		gitDiff + " --raw --numstat " + base + ` "$neo_now"` + pathspec + " | head -n " + strconv.Itoa(maxListedFiles*2),
	}, nil
}

type listedFile struct {
	path       string
	base       string
	status     string
	modeChange string
	binary     bool
	added      int
	removed    int
	hasCounts  bool
}

var (
	rawLine     = regexp.MustCompile(`^:(\d+) (\d+) \S+ \S+ (\w)\S*\t(.+)$`)
	numstatLine = regexp.MustCompile(`^(\d+|-)\t(\d+|-)\t(.+)$`)
)

func parseListing(lines []string, base string) []*listedFile {
	var order []*listedFile
	files := map[string]*listedFile{}
	entry := func(name string) *listedFile {
		if f, ok := files[name]; ok {
			return f
		}
		f := &listedFile{path: name, base: base}
		files[name] = f
		order = append(order, f)
		return f
	}
	for _, line := range lines {
		if m := rawLine.FindStringSubmatch(line); m != nil {
			f := entry(m[4])
			f.status = m[3]
			if m[1] != m[2] && m[1] != "000000" && m[2] != "000000" {
				f.modeChange = m[1] + " -> " + m[2]
			}
			continue
		}
		if m := numstatLine.FindStringSubmatch(line); m != nil {
			f := entry(m[3])
			f.binary = m[1] == "-"
			f.added, _ = strconv.Atoi(m[1])
			f.removed, _ = strconv.Atoi(m[2])
			f.hasCounts = true
		}
	}
	return order
}

func listedFiles(s sections) []*listedFile {
	var out []*listedFile
	for _, entry := range s {
		if base, ok := strings.CutPrefix(entry.name, "listing "); ok {
			out = append(out, parseListing(entry.lines, base)...)
		}
	}
	return out
}

func pathFilters(paths any, root string) []string {
	prefix := strings.TrimRight(WorkspaceRelative(root), "/") + "/"
	list, ok := paths.([]any)
	if !ok {
		list = []any{paths}
	}
	var out []string
	for _, item := range list {
		s, ok := item.(string)
		if !ok || strings.TrimSpace(s) == "" {
			continue
		}
		entry := strings.TrimRight(strings.TrimPrefix(WorkspaceRelative(s), "./"), "/")
		out = append(out, strings.TrimPrefix(entry, prefix))
	}
	return out
}

func matchesFilters(file string, filters []string) bool {
	if len(filters) == 0 {
		return true
	}
	for _, f := range filters {
		if file == f || strings.HasPrefix(file, f+"/") || strings.HasSuffix(f, "/"+file) {
			return true
		}
	}
	return false
}

func fileLine(f *listedFile) string {
	// A file listed only by --raw has no counts; Node printed "undefined".
	added, removed := "undefined", "undefined"
	if f.hasCounts {
		added, removed = strconv.Itoa(f.added), strconv.Itoa(f.removed)
	}
	counts := "+" + added + " -" + removed
	if f.binary {
		counts = "binary"
	}
	status := f.status
	if status == "" {
		status = "?"
	}
	mode := ""
	if f.modeChange != "" {
		mode = " mode " + f.modeChange
	}
	return status + " " + f.path + " " + counts + mode
}

func diffScript(root, now string, files []*listedFile, capBytes int) string {
	lines := []string{"CDPATH= cd -- " + ShellQuote(root) + " || exit 1", GitFunction}
	for i, f := range files {
		lines = append(lines,
			section("file "+strconv.Itoa(i)),
			gitDiff+" --unified=2 "+ShellQuote(f.base)+" "+ShellQuote(now)+" -- "+ShellQuote(f.path)+" | head -c "+strconv.Itoa(capBytes),
			"echo",
		)
	}
	return strings.Join(lines, "\n")
}

func hunksOnly(lines []string) string {
	for i, line := range lines {
		if strings.HasPrefix(line, "@@") {
			return trimEndJS(strings.Join(lines[i:], "\n"))
		}
	}
	return ""
}

type diffEntry struct {
	file    *listedFile
	header  string
	body    string
	clipped bool
	allowed int
}

func shareBudget(entries []*diffEntry, maxChars int) {
	headers := 0
	for _, e := range entries {
		headers += lenUTF16(e.header) + 1
	}
	remaining := max(0, maxChars-headers)
	left := len(entries)
	sorted := append([]*diffEntry(nil), entries...)
	sort.SliceStable(sorted, func(i, j int) bool { return lenUTF16(sorted[i].body) < lenUTF16(sorted[j].body) })
	for _, e := range sorted {
		e.allowed = min(lenUTF16(e.body), int(math.Floor(float64(remaining)/float64(left))))
		remaining -= e.allowed
		left--
	}
}

func cutBody(e *diffEntry) string {
	if !(e.clipped || e.allowed < lenUTF16(e.body)) {
		return e.body
	}
	kept := sliceUTF16(e.body, e.allowed)
	if end := strings.LastIndex(kept, "\n"); end > 0 {
		kept = kept[:end]
	}
	return kept + "\n...[cut: pass paths: [\"" + e.file.path + "\"] to see more of this file]"
}

type rendered struct {
	diff    string
	cut     bool
	omitted []string
	err     string
}

func renderDiff(ctx context.Context, shell Shell, root, now string, files []*listedFile, maxChars int) (rendered, error) {
	var diffable []*listedFile
	for _, f := range files {
		if !f.binary && !strings.HasPrefix(f.path, `"`) {
			diffable = append(diffable, f)
		}
	}
	shown := diffable[:min(len(diffable), maxDiffedFiles)]
	if len(shown) == 0 {
		return rendered{}, nil
	}
	capBytes := maxScriptBytes / len(shown)
	result, err := shell.Run(ctx, diffScript(root, now, shown, capBytes), 0)
	if err != nil {
		return rendered{}, err
	}
	if failure := commandError(result); failure != "" {
		return rendered{err: failure}, nil
	}
	secs := parseSections(result["stdout"])
	entries := make([]*diffEntry, len(shown))
	for i, f := range shown {
		body := hunksOnly(secs.raw("file " + strconv.Itoa(i)))
		entries[i] = &diffEntry{file: f, header: "=== " + fileLine(f), body: body, clipped: len(body) >= capBytes-1}
	}
	shareBudget(entries, maxChars)
	parts := make([]string, len(entries))
	cut := false
	for i, e := range entries {
		body := cutBody(e)
		if body == "" {
			parts[i] = e.header
		} else {
			parts[i] = e.header + "\n" + body
		}
		if e.clipped || e.allowed < lenUTF16(e.body) {
			cut = true
		}
	}
	var omitted []string
	for _, f := range diffable[len(shown):] {
		omitted = append(omitted, f.path)
	}
	return rendered{diff: strings.Join(parts, "\n"), cut: cut, omitted: omitted}, nil
}

type snapshot struct {
	secs      sections
	now       string
	root      string
	branch    string
	hasBranch bool
	porcelain []string
}

func readSnapshot(result dyn.Map, target any) (*snapshot, string) {
	if failure := commandError(result); failure != "" {
		return nil, failure
	}
	secs := parseSections(result["stdout"])
	if location := locationError(secs, target); location != "" {
		return nil, location
	}
	if secs.first("not-repo") != nil {
		return nil, WorkspaceRelative(target) + " is not a git repository. Pass path with a repository directory."
	}
	if secs.first("bad-base") != nil {
		return nil, "base is not a commit in this repository."
	}
	if secs.first("failed") != nil {
		return nil, "Could not read the working tree: " + strings.Join(secs.lines("failed"), " ")
	}
	now := ""
	if l := secs.lines("now"); len(l) > 0 {
		now = l[0]
	}
	if now == "" {
		return nil, "Could not read the repository: " + sliceUTF16(dyn.Str(result["stderr"]), 300)
	}
	s := &snapshot{secs: secs, now: now}
	if l := secs.lines("root"); len(l) > 0 {
		s.root = l[0]
	}
	if l := secs.lines("branch"); len(l) > 0 {
		s.branch, s.hasBranch = l[0], true
	}
	if entry := secs.first("porcelain"); entry != nil {
		for _, line := range entry.lines {
			if line != "" {
				s.porcelain = append(s.porcelain, line)
			}
		}
	}
	return s, ""
}

func describeRepository(ctx context.Context, shell Shell, snap *snapshot, files []*listedFile, filters []string, maxChars int, scope string, extra dyn.Ordered) (dyn.Ordered, error) {
	var selected []*listedFile
	for _, f := range files {
		if matchesFilters(f.path, filters) {
			selected = append(selected, f)
		}
	}
	r, err := renderDiff(ctx, shell, snap.root, snap.now, selected, maxChars)
	if err != nil {
		return nil, err
	}
	if r.err != "" {
		return dyn.Ordered{{Key: "error", Value: r.err}}, nil
	}
	listed := selected[:min(len(selected), maxListedFiles)]
	out := dyn.Ordered{{Key: "scope", Value: scope}, {Key: "root", Value: snap.root}}
	if snap.hasBranch {
		out = append(out, dyn.KV{Key: "branch", Value: snap.branch})
	}
	out = append(out, extra...)
	lines := []any{}
	for _, f := range listed {
		lines = append(lines, fileLine(f))
	}
	out = append(out, dyn.KV{Key: "files", Value: lines})
	if len(selected) > len(listed) {
		out = append(out, dyn.KV{Key: "files_omitted", Value: len(selected) - len(listed)})
	}
	out = append(out,
		dyn.KV{Key: "diff", Value: r.diff},
		dyn.KV{Key: "truncated", Value: r.cut || len(r.omitted) > 0 || len(selected) > len(listed)},
	)
	if len(r.omitted) > 0 {
		out = append(out, dyn.KV{Key: "not_diffed", Value: toAny(r.omitted)})
	}
	if len(selected) == 0 {
		out = append(out, dyn.KV{Key: "note", Value: "No changes."})
	}
	return out, nil
}

func diffAgainstBase(ctx context.Context, shell Shell, args dyn.Map, maxChars int) (dyn.Ordered, error) {
	base := ""
	if args["base"] != nil {
		base = strings.TrimSpace(dyn.String(args["base"]))
	}
	if strings.HasPrefix(base, "-") {
		return dyn.Ordered{{Key: "error", Value: "base must be a git ref."}}, nil
	}
	resolveBase := "neo_base=$(g rev-parse -q --verify HEAD || g hash-object -t tree /dev/null)"
	if base != "" {
		resolveBase = "neo_base=$(g merge-base " + ShellQuote(base) + " HEAD 2>/dev/null || g rev-parse -q --verify " + ShellQuote(base+"^{commit}") + ")"
	}
	lines := enterRepositoryLines(args["path"], false)
	lines = append(lines, resolveBase, `[ -n "$neo_base" ] || { `+section("bad-base")+"; exit 0; }")
	lines = append(lines, snapshotLines(true)...)
	listing, _ := listingLines("$neo_base", nil)
	lines = append(lines, listing...)
	result, err := shell.Run(ctx, strings.Join(lines, "\n"), 0)
	if err != nil {
		return nil, err
	}
	snap, failure := readSnapshot(result, args["path"])
	if failure != "" {
		return dyn.Ordered{{Key: "error", Value: failure}}, nil
	}
	scope, extra := "uncommitted", dyn.Ordered{}
	if base != "" {
		scope, extra = "base", dyn.Ordered{{Key: "base", Value: base}}
	}
	return describeRepository(ctx, shell, snap, listedFiles(snap.secs), pathFilters(args["paths"], snap.root), maxChars, scope, extra)
}

func diffRunChanges(ctx context.Context, shell Shell, repo Repository, args dyn.Map, maxChars int) (dyn.Ordered, error) {
	paths := repo.Paths[:min(len(repo.Paths), maxRunPaths)]
	var sources []string
	bySource := map[string][]string{}
	for _, p := range paths {
		if _, ok := bySource[p.Source]; !ok {
			sources = append(sources, p.Source)
		}
		bySource[p.Source] = append(bySource[p.Source], p.Path)
	}
	lines := enterRepositoryLines(repo.Root, true)
	lines = append(lines, snapshotLines(true)...)
	for _, source := range sources {
		listing, err := listingLines(source, bySource[source])
		if err != nil {
			return nil, err
		}
		lines = append(lines, listing...)
	}
	result, err := shell.Run(ctx, strings.Join(lines, "\n"), 0)
	if err != nil {
		return nil, err
	}
	snap, failure := readSnapshot(result, repo.Root)
	if failure != "" {
		return dyn.Ordered{{Key: "error", Value: failure}}, nil
	}
	owned := map[string]bool{}
	for _, p := range repo.Paths {
		owned[p.Path] = true
	}
	others := 0
	for _, line := range snap.porcelain {
		if !owned[sliceFrom(line, 3)] {
			others++
		}
	}
	extra := dyn.Ordered{}
	if others > 0 {
		extra = dyn.Ordered{{Key: "other_uncommitted_files", Value: others}}
	}
	return describeRepository(ctx, shell, snap, listedFiles(snap.secs), pathFilters(args["paths"], snap.root), maxChars, "run", extra)
}

func sliceFrom(s string, n int) string {
	if len(s) <= n {
		return ""
	}
	return s[n:]
}

// Diff runs repo_diff. repositories are the ones the run changed.
func Diff(ctx context.Context, shell Shell, args dyn.Map, repositories []Repository) (any, error) {
	maxChars := diffDefaultMaxChars
	if requested := jsNumber(args["max_chars"]); args["max_chars"] != nil && !math.IsNaN(requested) && !math.IsInf(requested, 0) && requested > 0 {
		maxChars = min(int(math.Floor(requested)), diffMaxChars)
	}
	useRun := !dyn.Truthy(args["base"]) && args["scope"] != "uncommitted"
	var changed []Repository
	if useRun {
		for _, r := range repositories {
			if len(r.Paths) > 0 {
				changed = append(changed, r)
			}
		}
	}
	switch len(changed) {
	case 0:
		result, err := diffAgainstBase(ctx, shell, args, maxChars)
		if err != nil {
			return nil, err
		}
		if useRun && args["scope"] == "run" && result.Get("error") == nil {
			result = result.Set("note", "This run has recorded no changes, so this is everything uncommitted.")
		}
		return result, nil
	case 1:
		return diffRunChanges(ctx, shell, changed[0], args, maxChars)
	}
	share := maxChars / len(changed)
	results := []any{}
	for _, repo := range changed {
		r, err := diffRunChanges(ctx, shell, repo, args, share)
		if err != nil {
			return nil, err
		}
		results = append(results, r)
	}
	return dyn.Ordered{{Key: "scope", Value: "run"}, {Key: "repositories", Value: results}}, nil
}
