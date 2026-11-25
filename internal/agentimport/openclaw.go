package agentimport

import (
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"path/filepath"
	"regexp"
	"strings"
	"time"
)

// Scanner reads OpenClaw and Hermes installations. It only reads: the source
// agents keep running and nothing in them changes.
type Scanner struct {
	// HomeDir is the user's home folder; empty means the current user's.
	HomeDir string
	// Getenv reads OPENCLAW_STATE_DIR and HERMES_HOME; nil reads nothing.
	Getenv func(string) string
	// Now is the clock used to drop one-time jobs that already ran; nil is the
	// system clock.
	Now func() time.Time
	// From limits Scan to one installation folder (`neoagent migrate --from`).
	From string
}

func (s Scanner) home() string { return homeDirOr(s.HomeDir) }

func (s Scanner) env(name string) string {
	if s.Getenv == nil {
		return ""
	}
	return s.Getenv(name)
}

func (s Scanner) now() time.Time {
	if s.Now != nil {
		return s.Now()
	}
	return time.Now()
}

var openclawConfigNames = []string{"openclaw.json", "clawdbot.json", "moltbot.json", "config.json"}

var openclawProfileDir = regexp.MustCompile(`^\.openclaw-[\w.-]+$`)

// FindOpenClawHomes lists every OpenClaw state folder on this computer: the
// default one, named profiles (~/.openclaw-<profile>), the pre-rename folders
// and an OPENCLAW_STATE_DIR override.
func (s Scanner) FindOpenClawHomes() []string {
	home := s.home()
	var candidates []string
	if v := s.env("OPENCLAW_STATE_DIR"); v != "" {
		candidates = append(candidates, expandHome(v, home))
	}
	candidates = append(candidates, filepath.Join(home, ".openclaw"))
	if names, err := sortedEntries(home); err == nil {
		for _, e := range names {
			if openclawProfileDir.MatchString(e.Name()) {
				candidates = append(candidates, filepath.Join(home, e.Name()))
			}
		}
	}
	candidates = append(candidates, filepath.Join(home, ".clawdbot"), filepath.Join(home, ".moltbot"))
	seen := map[string]bool{}
	var out []string
	for _, dir := range candidates {
		abs, _ := filepath.Abs(dir)
		if seen[abs] || openclawConfig(abs) == "" {
			continue
		}
		seen[abs] = true
		out = append(out, dir)
	}
	return out
}

func openclawConfig(home string) string {
	for _, name := range openclawConfigNames {
		if p := filepath.Join(home, name); isFile(p) {
			return p
		}
	}
	return ""
}

var profileName = regexp.MustCompile(`^\.openclaw-(.+)$`)

func (s Scanner) describeHome(home, label string) (string, string) {
	display := home
	if h := s.home(); strings.HasPrefix(home, h) {
		display = "~" + home[len(h):]
	}
	return label, display
}

func sha256Hex(text string) string {
	sum := sha256.Sum256([]byte(text))
	return hex.EncodeToString(sum[:])
}

// ScanOpenClaw reads an OpenClaw state folder into a bundle.
func (s Scanner) ScanOpenClaw(home string) Bundle {
	text, _ := readText(openclawConfig(home))
	if text == "" {
		text = "{}"
	}
	var config *Obj
	if v, err := parseJSON5(text); err == nil {
		config = asObj(v)
	}
	stateDB := openSqlite(filepath.Join(home, "state", "openclaw.sqlite"))
	if stateDB != nil {
		defer stateDB.Close()
	}
	var skipped []Skipped

	env := s.collectEnv(home, config, stateDB)
	agents := s.collectAgents(home, config, stateDB, &skipped)
	envKeys, ignored := mapEnvKeys(env)
	keys := collectAuthProfileKeys(home, agents, &skipped)
	for _, name := range envKeys.names {
		keys.set(name, envKeys.get(name))
	}
	providerKeys := collectOpenClawProviders(config, env, s.home(), &skipped)
	for _, name := range providerKeys.names {
		keys.set(name, providerKeys.get(name))
	}

	defaults := asObj(asObj(config.Get("agents")).Get("defaults"))
	sourceModel := openclawModel(defaults.Get("model"), defaults.Get("models"))
	label := "OpenClaw"
	if m := profileName.FindStringSubmatch(filepath.Base(home)); m != nil {
		label = "OpenClaw (" + m[1] + ")"
	}
	label, display := s.describeHome(home, label)
	bundle := Bundle{
		Source:      "openclaw",
		Label:       label,
		Path:        display,
		Home:        home,
		Agents:      agents,
		Skills:      collectOpenClawSkills(home, agents),
		Keys:        keys,
		IgnoredKeys: ignored,
		SourceModel: sourceModel,
		Model:       fromSlashModel(sourceModel),
		MCP:         collectOpenClawMCP(config, env, s.home(), &skipped),
		Tasks:       s.collectOpenClawTasks(home, stateDB, agents, &skipped),
		Channels:    s.collectOpenClawChannels(home, config, env, stateDB, &skipped),
	}
	bundle.Skipped = skipped
	for _, t := range bundle.Tasks {
		if t.TZ != "" {
			bundle.Timezone = t.TZ
			break
		}
	}
	if bundle.Timezone == "" {
		bundle.Timezone = timezoneFromProfile(agents)
	}
	return bundle
}

// openclawModel reads agents.defaults.model: "provider/model", { primary }, or
// an alias name from agents.defaults.models. It returns "" when unset.
func openclawModel(model, catalog any) string {
	raw := ""
	if s, ok := model.(string); ok {
		raw = s
	} else {
		raw = str(asObj(model).Get("primary"))
	}
	if raw == "" {
		return ""
	}
	if strings.Contains(raw, "/") {
		return raw
	}
	if c := asObj(catalog); c != nil {
		for _, key := range c.Keys() {
			if str(asObj(c.Get(key)).Get("alias")) == raw {
				return key
			}
		}
	}
	return ""
}

func (s Scanner) collectEnv(home string, config *Obj, stateDB *sql.DB) *envVars {
	text, _ := readText(filepath.Join(home, ".env"))
	env := parseDotEnv(text)
	merged := newObj()
	if inline := asObj(config.Get("env")); inline != nil {
		for _, k := range inline.Keys() {
			merged.set(k, inline.Get(k))
		}
		if vars := asObj(inline.Get("vars")); vars != nil {
			for _, k := range vars.Keys() {
				merged.set(k, vars.Get(k))
			}
		}
	}
	for _, k := range merged.Keys() {
		if v, ok := merged.Get(k).(string); ok && v != "" && env.get(k) == "" {
			env.set(k, v)
		}
	}
	for _, row := range queryStrings(stateDB, `SELECT name, value FROM secret_store_entries WHERE deleted_at_ms IS NULL`, 2) {
		if row[1] != "" && env.get(row[0]) == "" {
			env.set(row[0], row[1])
		}
	}
	return env
}

// collectAgents lists the agents with their workspace files. Template files
// that were never edited are left out: OpenClaw records the hash of every file
// it generated.
func (s Scanner) collectAgents(home string, config *Obj, stateDB *sql.DB, skipped *[]Skipped) []Agent {
	generated := map[string]bool{}
	for _, row := range queryStrings(stateDB, `SELECT sha256 FROM workspace_generated_bootstrap_hashes`, 1) {
		generated[row[0]] = true
	}
	agentsCfg := asObj(config.Get("agents"))
	defaults := asObj(agentsCfg.Get("defaults"))
	var entries []*Obj
	if e := asObj(agentsCfg.Get("entries")); truthy(agentsCfg.Get("entries")) && e != nil {
		for _, id := range e.Keys() {
			entry := newObj()
			entry.set("id", id)
			if src := asObj(e.Get(id)); src != nil {
				for _, k := range src.Keys() {
					entry.set(k, src.Get(k))
				}
			}
			entries = append(entries, entry)
		}
	} else {
		for _, item := range asList(agentsCfg.Get("list")) {
			if o := asObj(item); o != nil {
				entries = append(entries, o)
			}
		}
	}
	if len(entries) == 0 {
		o := newObj()
		o.set("id", "main")
		entries = append(entries, o)
	}
	defaultID := str(asObj(defaults.Get("systemAgent")).Get("agentId"))
	if defaultID == "" {
		for _, e := range entries {
			if truthy(e.Get("default")) {
				defaultID = str(e.Get("id"))
				break
			}
		}
	}
	if defaultID == "" {
		defaultID = str(entries[0].Get("id"))
	}

	var agents []Agent
	for _, entry := range entries {
		id := str(entry.Get("id"))
		workspace := s.resolveWorkspace(home, entry, defaults, len(entries))
		read := func(name string) string {
			text, ok := readText(filepath.Join(workspace, name))
			if !ok || trim(text) == "" || generated[sha256Hex(text)] {
				return ""
			}
			return text
		}
		if read("AGENTS.md") != "" {
			*skipped = append(*skipped, Skipped{Kind: "Instructions", Name: id + "/AGENTS.md",
				Reason: "OpenClaw's operating manual for its own tools; copy any rules you added by hand"})
		}
		name := str(asObj(entry.Get("identity")).Get("name"))
		if name == "" {
			name = identityNameFrom(read("IDENTITY.md"))
		}
		soul := cleanPersona(read("SOUL.md"))
		memory := read("MEMORY.md")
		user := read("USER.md")

		agent := Agent{
			Key:       id,
			Name:      firstNonEmpty(name, str(entry.Get("name")), id),
			IsDefault: id == defaultID,
			Workspace: workspace,
			Model:     fromSlashModel(openclawModel(entry.Get("model"), defaults.Get("models"))),
			DailyLogs: readDailyLogs(filepath.Join(workspace, "memory")),
		}
		var parts []string
		if name != "" {
			parts = append(parts, "Your name is "+name+".")
		}
		if soul != "" {
			parts = append(parts, soul)
		}
		agent.Instructions = strings.Join(parts, "\n\n")
		if memory != "" {
			for _, item := range splitMemoryEntries(memory) {
				agent.Memories = append(agent.Memories, Memory{Text: item.Text, Category: categoryFor(item.Heading, "episodic")})
			}
		}
		if user != "" {
			agent.UserProfile = userProfileFrom(user)
		}
		agents = append(agents, agent)
	}
	return agents
}

func firstNonEmpty(values ...string) string {
	for _, v := range values {
		if v != "" {
			return v
		}
	}
	return ""
}

func (s Scanner) resolveWorkspace(home string, entry, defaults *Obj, agentCount int) string {
	h := s.home()
	if w := str(entry.Get("workspace")); w != "" {
		return expandHome(w, h)
	}
	if agentCount == 1 {
		if w := str(defaults.Get("workspace")); w != "" {
			return expandHome(w, h)
		}
		if main := filepath.Join(home, "workspace-main"); isDir(main) {
			return main
		}
		return filepath.Join(home, "workspace")
	}
	if w := str(defaults.Get("workspace")); w != "" {
		return filepath.Join(expandHome(w, h), str(entry.Get("id")))
	}
	return filepath.Join(home, "workspace-"+str(entry.Get("id")))
}

var (
	identityNameRe = regexp.MustCompile(`(?mi)^` + ws + `*[-*]?` + ws + `*\*{0,2}Name:?\*{0,2}:?` + ws + `*(.+)$`)
	parenOnly      = regexp.MustCompile(`^\(.*\)$`)
	soulHeading    = regexp.MustCompile(`(?mi)^#` + ws + `*SOUL\.md.*$`)
	personaHint    = regexp.MustCompile(`(?m)^_?\(.*\)_?$`)
	tzInProfile    = regexp.MustCompile(`(?i)time` + ws + `*zone:` + ws + `*([A-Za-z_]+/[A-Za-z_]+)`)
	dailyLogName   = regexp.MustCompile(`^\d{4}-\d{2}-\d{2}\.md$`)
	starUnderscore = strings.NewReplacer("*", "", "_", "")
)

func identityNameFrom(text string) string {
	m := identityNameRe.FindStringSubmatch(text)
	if m == nil {
		return ""
	}
	name := trim(starUnderscore.Replace(m[1]))
	if name == "" || parenOnly.MatchString(name) {
		return ""
	}
	return name
}

func cleanPersona(text string) string {
	if text == "" {
		return ""
	}
	if loc := soulHeading.FindStringIndex(text); loc != nil {
		text = text[:loc[0]] + text[loc[1]:]
	}
	return trim(personaHint.ReplaceAllString(text, ""))
}

// userProfileFrom turns USER.md into plain "Label: value" lines and notes,
// without template headings.
func userProfileFrom(text string) string {
	var lines []string
	for _, e := range splitMemoryEntries(text) {
		lines = append(lines, e.Text)
	}
	return strings.Join(lines, "\n")
}

func timezoneFromProfile(agents []Agent) string {
	for _, a := range agents {
		if m := tzInProfile.FindStringSubmatch(a.UserProfile); m != nil {
			return m[1]
		}
	}
	return ""
}

func readDailyLogs(dir string) []DailyLog {
	if !isDir(dir) {
		return nil
	}
	entries, err := sortedEntries(dir)
	if err != nil {
		return nil
	}
	var logs []DailyLog
	for _, e := range entries {
		if !dailyLogName.MatchString(e.Name()) {
			continue
		}
		text, _ := readText(filepath.Join(dir, e.Name()))
		if content := trim(text); content != "" {
			logs = append(logs, DailyLog{Date: e.Name()[:10], Content: content})
		}
	}
	return logs
}

// collectAuthProfileKeys reads the API keys stored in each agent's auth
// profiles (SQLite since 2026, an auth-profiles.json file before that).
func collectAuthProfileKeys(home string, agents []Agent, skipped *[]Skipped) *keyList {
	keys := newKeyList()
	var stores []*Obj
	for _, agent := range agents {
		agentDir := filepath.Join(home, "agents", agent.Key, "agent")
		db := openSqlite(filepath.Join(agentDir, "openclaw-agent.sqlite"))
		for _, row := range queryStrings(db, `SELECT store_json FROM auth_profile_store`, 1) {
			if v, err := parseJSON([]byte(row[0])); err == nil {
				stores = append(stores, asObj(v))
			}
		}
		if db != nil {
			db.Close()
		}
		if legacy, ok := readText(filepath.Join(agentDir, "auth-profiles.json")); ok && legacy != "" {
			if v, err := parseJSON([]byte(legacy)); err == nil {
				stores = append(stores, asObj(v))
			}
		}
	}
	var oauth []string
	for _, store := range stores {
		profiles := asObj(store.Get("profiles"))
		for _, id := range profiles.Keys() {
			profile := asObj(profiles.Get(id))
			envKey := providerKeyEnv[strings.ToLower(str(profile.Get("provider")))]
			secret := firstNonEmpty(str(profile.Get("key")), str(profile.Get("token")), str(profile.Get("apiKey")))
			kind := str(profile.Get("type"))
			if kind == "" {
				kind = "api_key"
			}
			switch {
			case envKey != "" && secret != "" && (kind == "api_key" || kind == "token"):
				keys.setIfEmpty(envKey, secret)
			case truthy(profile.Get("provider")) && (str(profile.Get("type")) == "oauth" || truthy(profile.Get("access"))):
				provider := str(profile.Get("provider"))
				if !contains(oauth, provider) {
					oauth = append(oauth, provider)
				}
			}
		}
	}
	for _, provider := range oauth {
		*skipped = append(*skipped, Skipped{Kind: "Sign-in", Name: provider,
			Reason: "OAuth sign-ins cannot be copied; sign in again under Admin → Providers in the app"})
	}
	return keys
}

func contains(list []string, item string) bool {
	for _, v := range list {
		if v == item {
			return true
		}
	}
	return false
}

var (
	ollamaPort = regexp.MustCompile(`:11434\b`)
	v1Suffix   = regexp.MustCompile(`/v1/?$`)
	openaiWord = regexp.MustCompile(`openai`)
	oneCompat  = "NeoAgent has room for one OpenAI-compatible endpoint; add this one by hand if you need it"
)

// collectOpenClawProviders maps custom providers: Ollama becomes OLLAMA_URL,
// the first other OpenAI-compatible endpoint becomes NeoAgent's
// "OpenAI-compatible" provider.
func collectOpenClawProviders(config *Obj, env *envVars, home string, skipped *[]Skipped) *keyList {
	keys := newKeyList()
	providers := asObj(asObj(config.Get("models")).Get("providers"))
	for _, name := range providers.Keys() {
		provider := asObj(providers.Get(name))
		if provider == nil {
			continue
		}
		apiKey := resolveSecret(provider.Get("apiKey"), env, home)
		knownEnv := providerKeyEnv[strings.ToLower(name)]
		if knownEnv != "" && apiKey != "" && !truthy(provider.Get("baseUrl")) {
			keys.set(knownEnv, apiKey)
			continue
		}
		baseURL := trim(str(provider.Get("baseUrl")))
		if baseURL == "" {
			continue
		}
		api := "openai"
		if truthy(provider.Get("api")) {
			api = str(provider.Get("api"))
		}
		switch {
		case strings.ToLower(name) == "ollama" || ollamaPort.MatchString(baseURL):
			keys.set("OLLAMA_URL", v1Suffix.ReplaceAllString(baseURL, ""))
		case keys.get("OPENAI_COMPATIBLE_BASE_URL") == "" && openaiWord.MatchString(api):
			keys.set("OPENAI_COMPATIBLE_BASE_URL", baseURL)
			if apiKey != "" {
				keys.set("OPENAI_COMPATIBLE_API_KEY", apiKey)
			}
		default:
			*skipped = append(*skipped, Skipped{Kind: "AI provider", Name: name, Reason: oneCompat})
		}
	}
	return keys
}

func collectOpenClawSkills(home string, agents []Agent) []Skill {
	type root struct{ dir, origin string }
	roots := []root{{filepath.Join(home, "skills"), "OpenClaw"}}
	for _, a := range agents {
		roots = append(roots, root{filepath.Join(a.Workspace, "skills"), a.Name})
	}
	seen := map[string]bool{}
	var skills []Skill
	for _, r := range roots {
		for _, dir := range findSkillDirs(r.dir) {
			skill, ok := readSkill(dir, r.origin)
			if !ok || seen[skill.Name] {
				continue
			}
			seen[skill.Name] = true
			skills = append(skills, skill)
		}
	}
	return skills
}

func localProgram(server *Obj) string {
	command := str(server.Get("command"))
	if command == "" {
		command = "stdio"
	}
	return "runs a local program (" + command + "); NeoAgent connects to MCP servers by URL"
}

func collectOpenClawMCP(config *Obj, env *envVars, home string, skipped *[]Skipped) []MCPServer {
	var servers []MCPServer
	list := asObj(asObj(config.Get("mcp")).Get("servers"))
	for _, name := range list.Keys() {
		server := asObj(list.Get(name))
		if server == nil {
			continue
		}
		if !truthy(server.Get("url")) {
			*skipped = append(*skipped, Skipped{Kind: "MCP server", Name: name, Reason: localProgram(server), Detail: server})
			continue
		}
		servers = append(servers, mcpEntry(name, str(server.Get("url")), server.Get("headers"), str(server.Get("transport")),
			asBoolNot(server.Get("enabled")), env, home))
	}
	return servers
}

// asBoolNot is `value !== false`.
func asBoolNot(v any) bool {
	b, ok := v.(bool)
	return !ok || b
}
