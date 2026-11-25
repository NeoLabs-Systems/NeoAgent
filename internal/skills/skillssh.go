package skills

import (
	"context"
	"encoding/json"
	"fmt"
	"github.com/NeoLabs-Systems/neoagent/internal/jsrules"
	"io"
	"net/http"
	"path"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"
)

// skills.sh is a directory of agent skills hosted in public GitHub repos. Its
// search API names a skill by repo ("owner/repo") plus the skill's id; the
// files themselves are fetched straight from GitHub.
const (
	featuredLimit      = 36
	featuredCacheTTL   = 6 * time.Hour
	searchLimit        = 30
	maxBundleFiles     = 200
	maxBundleFileBytes = 1024 * 1024
	maxBundleBytes     = 8 * 1024 * 1024
	maxFrontmatterScan = 40
	maxFetchBytes      = 16 * 1024 * 1024
)

var (
	segmentRE       = regexp.MustCompile(`^[A-Za-z0-9._-]+$`)
	notSpace        = `[^` + jsSpaceClass + `]`
	addCommandRE    = regexp.MustCompile(`skills[` + jsSpaceClass + `]+add[` + jsSpaceClass + `]+(` + notSpace + `+)[` + jsSpaceClass + `]+(?:--skill|-s)[` + jsSpaceClass + `]+(` + notSpace + `+)`)
	githubPrefixRE  = regexp.MustCompile(`(?i)^https?://(www\.)?github\.com/`)
	gitSuffixRE     = regexp.MustCompile(`(?i)\.git$`)
	trailingSlashRE = regexp.MustCompile(`/+$`)
	quoteEdgeRE     = regexp.MustCompile(`^['"]|['"]$`)
	skillsShPrefix  = regexp.MustCompile(`(?i)^https?://(www\.)?skills\.sh/`)
	queryTailRE     = regexp.MustCompile(`[?#]` + jsDotClass + `*$`)
	featuredEntryRE = regexp.MustCompile(`\{"source":"([^"]+)","skillId":"([^"]+)","name":"([^"]*)","installs":(\d+)(?:,"weeklyInstalls":\[[\d,]*\])?(?:,"isOfficial":(true|false))?`)
	notAlnumRE      = regexp.MustCompile(`[^a-z0-9]`)
	notesHeadingRE  = regexp.MustCompile(`(?m)^## NeoAgent Notes$`)
	leadingNewlines = regexp.MustCompile(`^\n+`)
	textExt         = setOf(".css", ".html", ".js", ".json", ".md", ".mjs", ".py", ".sh", ".toml", ".ts", ".txt", ".xml", ".yaml", ".yml")
	featuredPages   = map[string]string{"popular": "/", "trending": "/trending"}
)

// SkillsShConfig wires the skills.sh client. Zero values take the public
// addresses.
type SkillsShConfig struct {
	// Client must only reach public hosts (neolabs-go/ssrf).
	Client      *http.Client
	SearchURL   string
	SiteURL     string
	GithubAPI   string
	RawURL      string
	GithubToken string
	Now         func() time.Time
}

// SkillsSh searches skills.sh and installs skills from GitHub.
type SkillsSh struct {
	cfg SkillsShConfig

	mu       sync.Mutex
	featured map[string]featuredEntry
}

type featuredEntry struct {
	at     time.Time
	skills []Listing
}

// NewSkillsSh builds a client.
func NewSkillsSh(cfg SkillsShConfig) *SkillsSh {
	if cfg.SearchURL == "" {
		cfg.SearchURL = "https://skills.sh/api/search"
	}
	if cfg.SiteURL == "" {
		cfg.SiteURL = "https://skills.sh"
	}
	if cfg.GithubAPI == "" {
		cfg.GithubAPI = "https://api.github.com"
	}
	if cfg.RawURL == "" {
		cfg.RawURL = "https://raw.githubusercontent.com"
	}
	if cfg.Now == nil {
		cfg.Now = time.Now
	}
	return &SkillsSh{cfg: cfg, featured: map[string]featuredEntry{}}
}

// Ref names a skill on skills.sh.
type Ref struct {
	Source  string `json:"source"`
	SkillID string `json:"skillId"`
	Name    string `json:"name"`
}

// Listing is a search or leaderboard hit. Installs is null when unknown and
// Official is only present on leaderboard entries.
type Listing struct {
	ID            string `json:"id"`
	Source        string `json:"source"`
	SkillID       string `json:"skillId"`
	Name          string `json:"name"`
	Installs      *int64 `json:"installs"`
	Official      *bool  `json:"official,omitempty"`
	InstalledName string `json:"installedName"`
}

func isRepoSource(source string) bool {
	parts := strings.Split(source, "/")
	return len(parts) == 2 && segmentRE.MatchString(parts[0]) && segmentRE.MatchString(parts[1])
}

// ParseRef accepts what people copy from skills.sh: a skill page URL, an
// "owner/repo/skill" id, or the `npx skills add <repo> --skill <name>`
// command.
func ParseRef(input string) (Ref, bool) {
	text := jsrules.Trim(input)
	if m := addCommandRE.FindStringSubmatch(text); m != nil {
		source := githubPrefixRE.ReplaceAllString(m[1], "")
		source = trailingSlashRE.ReplaceAllString(gitSuffixRE.ReplaceAllString(source, ""), "")
		name := quoteEdgeRE.ReplaceAllString(m[2], "")
		if !isRepoSource(source) {
			return Ref{}, false
		}
		return Ref{Source: source, SkillID: name, Name: name}, true
	}
	id := skillsShPrefix.ReplaceAllString(text, "")
	id = trailingSlashRE.ReplaceAllString(queryTailRE.ReplaceAllString(id, ""), "")
	parts := strings.Split(id, "/")
	if len(parts) != 3 {
		return Ref{}, false
	}
	for _, p := range parts {
		if !segmentRE.MatchString(p) {
			return Ref{}, false
		}
	}
	return Ref{Source: parts[0] + "/" + parts[1], SkillID: parts[2], Name: parts[2]}, true
}

// encodeURIComponent is the JavaScript function of that name.
func encodeURIComponent(s string) string {
	const keep = "-_.!~*'()"
	var b strings.Builder
	for _, c := range []byte(s) {
		if c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c >= '0' && c <= '9' || strings.IndexByte(keep, c) >= 0 {
			b.WriteByte(c)
		} else {
			fmt.Fprintf(&b, "%%%02X", c)
		}
	}
	return b.String()
}

func (s *SkillsSh) fetch(ctx context.Context, target string) ([]byte, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, target, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", "NeoAgent")
	if strings.HasPrefix(target, s.cfg.GithubAPI) {
		req.Header.Set("Accept", "application/vnd.github+json")
		if s.cfg.GithubToken != "" {
			req.Header.Set("Authorization", "Bearer "+s.cfg.GithubToken)
		}
	}
	ctx, cancel := context.WithTimeout(ctx, 15*time.Second)
	defer cancel()
	resp, err := s.cfg.Client.Do(req.WithContext(ctx))
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode > 299 {
		status := 502
		if resp.StatusCode == 404 {
			status = 404
		}
		return nil, &StatusError{Status: status, Message: req.URL.Host + " returned " + strconv.Itoa(resp.StatusCode)}
	}
	return io.ReadAll(io.LimitReader(resp.Body, maxFetchBytes))
}

func (s *SkillsSh) fetchJSON(ctx context.Context, target string, into any) error {
	body, err := s.fetch(ctx, target)
	if err != nil {
		return err
	}
	return json.Unmarshal(body, into)
}

// Search finds skills by name, or answers the one skill a pasted reference
// names.
func (s *SkillsSh) Search(ctx context.Context, query string) ([]Listing, error) {
	if ref, ok := ParseRef(query); ok {
		return []Listing{{ID: ref.Source + "/" + ref.SkillID, Source: ref.Source, SkillID: ref.SkillID, Name: ref.Name}}, nil
	}
	if jsrules.Len(jsrules.Trim(query)) < 2 {
		return []Listing{}, nil
	}
	var body any
	if err := s.fetchJSON(ctx, s.cfg.SearchURL+"?q="+encodeURIComponent(jsrules.Trim(query))+"&limit="+strconv.Itoa(searchLimit), &body); err != nil {
		return nil, err
	}
	out := []Listing{}
	data, _ := body.(map[string]any)
	list, _ := data["skills"].([]any)
	for _, item := range list {
		skill, _ := item.(map[string]any)
		source, _ := skill["source"].(string)
		if !isRepoSource(source) || !jsrules.Truthy(skill["skillId"]) {
			continue
		}
		skillID := jsrules.String(skill["skillId"])
		l := Listing{ID: source + "/" + skillID, Source: source, SkillID: skillID, Name: jsrules.String(jsrules.OrDefault(skill["name"], skillID))}
		if n, ok := skill["installs"].(float64); ok {
			v := int64(n)
			l.Installs = &v
		}
		out = append(out, l)
	}
	return out, nil
}

// parseFeaturedPage reads the skill list a skills.sh leaderboard page renders.
func parseFeaturedPage(html string) []Listing {
	text := strings.ReplaceAll(html, `\"`, `"`)
	start := strings.Index(text, `"initialSkills":[`)
	if start == -1 {
		return nil
	}
	seen := map[string]bool{}
	var skills []Listing
	for _, m := range featuredEntryRE.FindAllStringSubmatch(text[start:], -1) {
		if len(skills) >= featuredLimit {
			break
		}
		id := m[1] + "/" + m[2]
		if !isRepoSource(m[1]) || seen[id] {
			continue
		}
		seen[id] = true
		installs, _ := strconv.ParseInt(m[4], 10, 64)
		official := m[5] == "true"
		skills = append(skills, Listing{ID: id, Source: m[1], SkillID: m[2], Name: orDefaultString(m[3], m[2]), Installs: &installs, Official: &official})
	}
	return skills
}

// Featured lists a skills.sh leaderboard ("popular" or "trending"). The list
// is kept for six hours, and a stale one is served when skills.sh fails.
func (s *SkillsSh) Featured(ctx context.Context, list string) ([]Listing, error) {
	page, ok := featuredPages[list]
	if !ok {
		return nil, &StatusError{Status: 400, Message: "Unknown skills.sh list '" + list + "'"}
	}
	s.mu.Lock()
	cached, hit := s.featured[list]
	s.mu.Unlock()
	if hit && s.cfg.Now().Sub(cached.at) < featuredCacheTTL {
		return cached.skills, nil
	}
	body, err := s.fetch(ctx, s.cfg.SiteURL+page)
	var skills []Listing
	if err == nil {
		if skills = parseFeaturedPage(string(body)); len(skills) == 0 {
			err = fmt.Errorf("skills.sh leaderboard had no skills")
		}
	}
	if err != nil {
		// A stale list beats none when skills.sh is slow or changed its page.
		if hit {
			return cached.skills, nil
		}
		return nil, err
	}
	s.mu.Lock()
	s.featured[list] = featuredEntry{at: s.cfg.Now(), skills: skills}
	s.mu.Unlock()
	return skills, nil
}

func compact(value string) string { return notAlnumRE.ReplaceAllString(strings.ToLower(value), "") }

type treeEntry struct {
	Path string  `json:"path"`
	Type string  `json:"type"`
	Size float64 `json:"size"`
}

func (s *SkillsSh) rawURL(source, file string) string {
	parts := strings.Split(file, "/")
	for i, p := range parts {
		parts[i] = encodeURIComponent(p)
	}
	return s.cfg.RawURL + "/" + source + "/HEAD/" + strings.Join(parts, "/")
}

type located struct{ file, content string }

// locate finds the skill's SKILL.md in a repo tree. The skills.sh id comes
// from the skill's frontmatter name and its index can trail the repo, so an
// exact name match wins and a directory or punctuation-insensitive match is
// the fallback.
func (s *SkillsSh) locate(ctx context.Context, source string, ref Ref, tree []treeEntry) (*located, error) {
	var skillFiles []string
	for _, e := range tree {
		if e.Type == "blob" && path.Base(e.Path) == "SKILL.md" {
			skillFiles = append(skillFiles, e.Path)
		}
	}
	if len(skillFiles) == 0 {
		return nil, nil
	}
	wanted := map[string]bool{compact(ref.SkillID): true, compact(ref.Name): true}
	var byDir, probes []string
	for _, f := range skillFiles {
		if wanted[compact(path.Base(path.Dir(f)))] {
			byDir = append(byDir, f)
		}
	}
	probes = append(probes, byDir...)
	for _, f := range skillFiles {
		if !contains(byDir, f) {
			probes = append(probes, f)
		}
	}
	if len(probes) > maxFrontmatterScan {
		probes = probes[:maxFrontmatterScan]
	}
	read := func(file string) (*located, error) {
		body, err := s.fetch(ctx, s.rawURL(source, file))
		return &located{file: file, content: string(body)}, err
	}
	for _, f := range probes {
		l, err := read(f)
		if err != nil {
			return nil, err
		}
		parsed, _ := ParseFrontmatter(l.content)
		if name := parsed.Data["name"]; name != "" && (name == ref.Name || name == ref.SkillID || wanted[compact(name)]) {
			return l, nil
		}
	}
	switch {
	case len(byDir) == 1:
		return read(byDir[0])
	case len(skillFiles) == 1:
		return read(skillFiles[0])
	}
	return nil, nil
}

func contains(list []string, item string) bool {
	for _, x := range list {
		if x == item {
			return true
		}
	}
	return false
}

type bundledFile struct {
	relative string
	data     []byte
}

func (s *SkillsSh) download(ctx context.Context, ref Ref) (string, []bundledFile, error) {
	if !isRepoSource(ref.Source) || ref.SkillID == "" {
		return "", nil, &StatusError{Status: 400, Message: "A skills.sh skill needs a GitHub repo and a skill id"}
	}
	var tree struct {
		Tree []treeEntry `json:"tree"`
	}
	if err := s.fetchJSON(ctx, s.cfg.GithubAPI+"/repos/"+ref.Source+"/git/trees/HEAD?recursive=1", &tree); err != nil {
		return "", nil, err
	}
	name := orDefaultString(ref.Name, ref.SkillID)
	found, err := s.locate(ctx, ref.Source, Ref{Name: name, SkillID: ref.SkillID}, tree.Tree)
	if err != nil {
		return "", nil, err
	}
	if found == nil {
		return "", nil, &StatusError{Status: 404, Message: "No skill named '" + name + "' found in " + ref.Source}
	}

	prefix := ""
	if dir := path.Dir(found.file); dir != "." {
		prefix = dir + "/"
	}
	var extras []treeEntry
	for _, e := range tree.Tree {
		if e.Type == "blob" && e.Path != found.file && strings.HasPrefix(e.Path, prefix) {
			extras = append(extras, e)
		}
	}
	if len(extras) > maxBundleFiles {
		return "", nil, &StatusError{Status: 413, Message: "Skill has " + strconv.Itoa(len(extras)) + " files; the limit is " + strconv.Itoa(maxBundleFiles)}
	}
	var files []bundledFile
	total := int64(len(found.content))
	for _, e := range extras {
		if e.Size > maxBundleFileBytes {
			continue
		}
		total += int64(e.Size)
		if total > maxBundleBytes {
			return "", nil, &StatusError{Status: 413, Message: "Skill files exceed the 8 MB install limit"}
		}
		relative := strings.TrimPrefix(e.Path, prefix)
		data, err := s.fetch(ctx, s.rawURL(ref.Source, e.Path))
		if err != nil {
			return "", nil, err
		}
		if textExt[strings.ToLower(path.Ext(relative))] {
			data = []byte(scrubInvisible(string(data)))
		}
		files = append(files, bundledFile{relative: relative, data: data})
	}
	return scrubInvisible(found.content), files, nil
}

// PrependNeoAgentNotes points a skill written for another agent at NeoAgent's
// tool names.
func PrependNeoAgentNotes(body string) string {
	if notesHeadingRE.MatchString(body) {
		return body
	}
	note := strings.Join([]string{
		"## NeoAgent Notes",
		"",
		"Map any generic tool references in this skill to NeoAgent equivalents:",
		"- shell and scripts (terminal, bash, exec): `execute_command`",
		"- local files and code search (read, write, patch, grep): `read_file`, `search_files`, `write_file`, `edit_file`",
		"- remote pages and APIs (web_extract, web_fetch, browser): `http_request`, `web_search`, and `browser_*` tools",
		"- schedules (cronjob, cron): `create_task`",
		"- memory and messages (memory, send_message): `memory_save`, `memory_recall`, `send_message`",
		"",
	}, "\n")
	return note + "\n" + leadingNewlines.ReplaceAllString(body, "")
}

// Fetched is what installing a skills.sh skill answers, after success.
type Fetched struct {
	Name      string `json:"name"`
	FileCount int    `json:"fileCount"`
}

// Install downloads a skill and its bundled files and saves them as a skill of
// the user.
func (s *SkillsSh) Install(ctx context.Context, runner *Runner, userID int64, ref Ref) (Fetched, error) {
	content, files, err := s.download(ctx, ref)
	if err != nil {
		return Fetched{}, err
	}
	parsed, _ := ParseFrontmatter(content)
	if parsed.Data["name"] == "" {
		return Fetched{}, &StatusError{Status: 422, Message: "Skill file has no frontmatter name"}
	}
	meta := Meta{{Key: "source", Value: "skills.sh"}, {Key: "skills_sh_id", Value: ref.Source + "/" + ref.SkillID}}
	saved, err := runner.Create(ctx, userID, parsed.Data["name"], collapseSpaces(parsed.Data["description"]), PrependNeoAgentNotes(parsed.Body), meta)
	if err != nil {
		if refusal, ok := asRefusal(err); ok {
			return Fetched{}, &StatusError{Status: 409, Message: refusal.Message}
		}
		return Fetched{}, err
	}
	root := filepath.Dir(saved.Path)
	for _, f := range files {
		if err := writeBundled(root, f.relative, f.data); err != nil {
			return Fetched{}, err
		}
	}
	return Fetched{Name: saved.Name, FileCount: len(files) + 1}, nil
}

// InstalledNames maps skills.sh ids to the names the user has them under.
func InstalledNames(skills []Skill) map[string]string {
	names := map[string]string{}
	for _, s := range skills {
		if id := s.Metadata.Value("skills_sh_id"); s.OwnerType == ownerUser && jsrules.Truthy(id) {
			names[jsrules.String(id)] = s.Name
		}
	}
	return names
}
