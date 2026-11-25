package agentimport

import (
	"path/filepath"
	"regexp"
	"strings"
)

// compatibleProviders reach NeoAgent through its OpenAI-compatible slot.
var compatibleProviders = map[string]bool{"custom": true, "lmstudio": true}

// defaultSoulPrefix is the persona Hermes writes when none exists; it is not
// the user's.
const defaultSoulPrefix = "You are Hermes Agent, built by Nous Research."

// FindHermesHomes lists the Hermes Agent folders on this computer.
func (s Scanner) FindHermesHomes() []string {
	home := s.home()
	var candidates []string
	if v := s.env("HERMES_HOME"); v != "" {
		candidates = append(candidates, expandHome(v, home))
	}
	candidates = append(candidates, filepath.Join(home, ".hermes"))
	seen := map[string]bool{}
	var out []string
	for _, dir := range candidates {
		abs, _ := filepath.Abs(dir)
		// A profile folder passed through HERMES_HOME is read with its parent.
		if seen[abs] || filepath.Base(filepath.Dir(abs)) == "profiles" {
			continue
		}
		if !isFile(filepath.Join(abs, "config.yaml")) && !isFile(filepath.Join(abs, ".env")) {
			continue
		}
		seen[abs] = true
		out = append(out, dir)
	}
	return out
}

type hermesHome struct {
	key       string
	dir       string
	isDefault bool
}

// ScanHermes reads a Hermes Agent folder into a bundle. The default home
// becomes NeoAgent's main agent and every profile under profiles/ becomes an
// agent of its own.
func (s Scanner) ScanHermes(home string) Bundle {
	var skipped []Skipped
	homes := []hermesHome{{"default", home, true}}
	if profiles := filepath.Join(home, "profiles"); isDir(profiles) {
		if entries, err := sortedEntries(profiles); err == nil {
			for _, e := range entries {
				if dir := filepath.Join(profiles, e.Name()); isDir(dir) {
					homes = append(homes, hermesHome{e.Name(), dir, false})
				}
			}
		}
	}

	var config *Obj
	if text, ok := readText(filepath.Join(home, "config.yaml")); ok {
		if v, err := parseYAML(text); err == nil {
			config = asObj(v)
		}
	}
	envText, _ := readText(filepath.Join(home, ".env"))
	env := parseDotEnv(envText)
	keys, ignored := mapEnvKeys(env)
	for _, profile := range homes[1:] {
		// Profile-only keys still count: NeoAgent has one set for every agent.
		text, _ := readText(filepath.Join(profile.dir, ".env"))
		profileKeys, _ := mapEnvKeys(parseDotEnv(text))
		for _, name := range profileKeys.names {
			keys.setIfEmpty(name, profileKeys.get(name))
		}
	}
	providerKeys := collectHermesProviders(config, env, &skipped)
	for _, name := range providerKeys.names {
		keys.set(name, providerKeys.get(name))
	}

	var agents []Agent
	for _, h := range homes {
		agents = append(agents, readHermesAgent(h))
	}
	var skills []Skill
	seen := map[string]bool{}
	for _, h := range homes {
		origin := h.key
		if h.isDefault {
			origin = "Hermes"
		}
		for _, skill := range collectHermesSkills(h.dir, origin) {
			if !seen[skill.Name] {
				seen[skill.Name] = true
				skills = append(skills, skill)
			}
		}
	}

	model, hasModel := hermesModelOf(config.Get("model"))
	sourceModel := ""
	if hasModel {
		sourceModel = model.model + " (" + configuredProvider(config.Get("model")) + ")"
	}
	label, display := s.describeHome(home, "Hermes Agent")
	bundle := Bundle{
		Source:      "hermes",
		Label:       label,
		Path:        display,
		Home:        home,
		Agents:      agents,
		Skills:      skills,
		Keys:        keys,
		IgnoredKeys: ignored,
		SourceModel: sourceModel,
		MCP:         collectHermesMCP(config, env, s.home(), &skipped),
	}
	if hasModel {
		bundle.Model = toNeoAgentModel(model.provider, model.model)
	}
	for _, h := range homes {
		bundle.Tasks = append(bundle.Tasks, s.collectHermesTasks(h, &skipped)...)
	}
	bundle.Channels = collectHermesChannels(env, &skipped)
	if tz, ok := config.Get("timezone").(string); ok && strings.Contains(tz, "/") {
		bundle.Timezone = tz
	}
	bundle.Skipped = skipped
	return bundle
}

type providerModel struct{ provider, model string }

// hermesModelOf reads `model`: "name" or { default|model, provider }. "auto"
// picks a provider from whichever key is present; the model id then says which
// ("anthropic/…").
func hermesModelOf(model any) (providerModel, bool) {
	var id, provider string
	if text, ok := model.(string); ok {
		id, provider = trim(text), "auto"
	} else {
		o := asObj(model)
		id = trim(firstNonEmpty(str(o.Get("default")), str(o.Get("model"))))
		provider = trim(firstNonEmpty(str(o.Get("provider")), "auto"))
	}
	if id == "" {
		return providerModel{}, false
	}
	if compatibleProviders[provider] {
		return providerModel{"openai-compatible", id}, true
	}
	if provider != "auto" {
		return providerModel{provider, id}, true
	}
	if slash := strings.Index(id, "/"); slash > 0 {
		return providerModel{id[:slash], id[slash+1:]}, true
	}
	return providerModel{}, false
}

func configuredProvider(model any) string {
	provider := "auto"
	if o := asObj(model); o != nil {
		provider = firstNonEmpty(str(o.Get("provider")), "auto")
	}
	if provider == "nous-api" || provider == "nous" {
		return "Nous Portal"
	}
	return provider
}

func readHermesAgent(h hermesHome) Agent {
	soulText, _ := readText(filepath.Join(h.dir, "SOUL.md"))
	soul := trim(soulText)
	memory, _ := readText(filepath.Join(h.dir, "memories", "MEMORY.md"))
	user, userOK := readText(filepath.Join(h.dir, "memories", "USER.md"))
	_, memoryOK := readText(filepath.Join(h.dir, "memories", "MEMORY.md"))
	agent := Agent{Key: h.key, Name: h.key, IsDefault: h.isDefault, Workspace: h.dir}
	if h.isDefault {
		agent.Name = "Hermes"
	}
	if soul != "" && !strings.HasPrefix(soul, defaultSoulPrefix) {
		agent.Instructions = soul
	}
	if memoryOK && memory != "" {
		for _, item := range splitMemoryEntries(memory) {
			agent.Memories = append(agent.Memories, Memory{Text: item.Text, Category: categoryFor(item.Text, "episodic")})
		}
	}
	if userOK && user != "" {
		var lines []string
		for _, item := range splitMemoryEntries(user) {
			lines = append(lines, item.Text)
		}
		agent.UserProfile = strings.Join(lines, "\n")
	}
	return agent
}

// collectHermesSkills lists the user's skills. Skills Hermes ships itself are
// listed in skills/.bundled_manifest ("name:hash" per line).
func collectHermesSkills(dir, origin string) []Skill {
	root := filepath.Join(dir, "skills")
	bundled := map[string]bool{}
	manifest, _ := readText(filepath.Join(root, ".bundled_manifest"))
	for _, line := range strings.Split(manifest, "\n") {
		if name := trim(strings.SplitN(line, ":", 2)[0]); name != "" {
			bundled[name] = true
		}
	}
	var skills []Skill
	for _, skillDir := range findSkillDirs(root) {
		skill, ok := readSkill(skillDir, origin)
		if ok && !bundled[skill.Name] && !bundled[filepath.Base(skill.Dir)] {
			skills = append(skills, skill)
		}
	}
	return skills
}

type customProvider struct{ name, baseURL, apiKey string }

func collectHermesProviders(config *Obj, env *envVars, skipped *[]Skipped) *keyList {
	keys := newKeyList()
	model := asObj(config.Get("model"))
	var entries []customProvider
	for _, item := range asList(config.Get("custom_providers")) {
		o := asObj(item)
		entries = append(entries, customProvider{
			name:    firstNonEmpty(str(o.Get("name")), "custom"),
			baseURL: firstNonEmpty(str(o.Get("base_url")), str(o.Get("baseUrl"))),
			apiKey:  firstNonEmpty(str(o.Get("api_key")), str(o.Get("apiKey"))),
		})
	}
	var lead []customProvider
	if str(model.Get("provider")) == "custom" && truthy(model.Get("base_url")) {
		lead = append(lead, customProvider{"custom", str(model.Get("base_url")), firstNonEmpty(str(model.Get("api_key")), env.get("OPENAI_API_KEY"))})
	}
	if str(model.Get("provider")) == "lmstudio" {
		lead = append(lead, customProvider{"lmstudio", firstNonEmpty(str(model.Get("base_url")), "http://127.0.0.1:1234/v1"), env.get("LM_API_KEY")})
	}
	// unshift puts the later one first: lmstudio, then custom.
	for i := len(lead) - 1; i >= 0; i-- {
		entries = append([]customProvider{lead[i]}, entries...)
	}
	// A Portal login (provider "nous") is OAuth; only an API key carries over.
	if str(model.Get("provider")) == "nous" && env.get("NOUS_API_KEY") == "" {
		*skipped = append(*skipped, Skipped{Kind: "Sign-in", Name: "Nous Portal",
			Reason: "the Portal sign-in cannot be copied; create an API key at portal.nousresearch.com and run the import again"})
	}
	ollama := regexp.MustCompile(`(?i)ollama`)
	for _, entry := range entries {
		baseURL := trim(entry.baseURL)
		if baseURL == "" {
			continue
		}
		switch {
		case ollamaPort.MatchString(baseURL) || ollama.MatchString(entry.name):
			keys.setIfEmpty("OLLAMA_URL", v1Suffix.ReplaceAllString(baseURL, ""))
		case keys.get("OPENAI_COMPATIBLE_BASE_URL") == "":
			keys.set("OPENAI_COMPATIBLE_BASE_URL", baseURL)
			if entry.apiKey != "" {
				keys.set("OPENAI_COMPATIBLE_API_KEY", entry.apiKey)
			}
		default:
			*skipped = append(*skipped, Skipped{Kind: "AI provider", Name: entry.name, Reason: oneCompat})
		}
	}
	return keys
}

func collectHermesMCP(config *Obj, env *envVars, home string, skipped *[]Skipped) []MCPServer {
	var servers []MCPServer
	list := asObj(config.Get("mcp_servers"))
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

func (s Scanner) collectHermesTasks(h hermesHome, skipped *[]Skipped) []Task {
	var jobs []*Obj
	if text, ok := readText(filepath.Join(h.dir, "cron", "jobs.json")); ok && text != "" {
		if v, err := parseJSON([]byte(text)); err == nil {
			list, isList := v.([]any)
			if !isList {
				list = asList(asObj(v).Get("jobs"))
			}
			for _, item := range list {
				jobs = append(jobs, asObj(item))
			}
		}
	}

	var tasks []Task
	for _, job := range jobs {
		name := jsSlice(trim(firstNonEmpty(str(job.Get("name")), str(job.Get("prompt")), "Scheduled job")), 80)
		if truthy(job.Get("no_agent")) || (!truthy(job.Get("prompt")) && truthy(job.Get("script"))) {
			var content any = undefined
			if truthy(job.Get("script")) {
				if script, ok := readText(filepath.Join(h.dir, "scripts", str(job.Get("script")))); ok {
					content = jsSlice(script, 2000)
				}
			}
			schedule := asObj(job.Get("schedule"))
			*skipped = append(*skipped, Skipped{Kind: "Automation", Name: name,
				Reason: "runs a script on this computer; NeoAgent's agent works on its own computer",
				Detail: detail("schedule", member(schedule, "display"), "script", member(job, "script"), "content", content)})
			continue
		}
		var skills []string
		for _, item := range asList(job.Get("skills")) {
			if truthy(item) {
				skills = append(skills, str(item))
			}
		}
		var promptParts []string
		if len(skills) > 0 {
			plural := ""
			if len(skills) > 1 {
				plural = "s"
			}
			promptParts = append(promptParts, "Use the "+strings.Join(skills, ", ")+" skill"+plural+".")
		}
		if p := trim(str(job.Get("prompt"))); p != "" {
			promptParts = append(promptParts, p)
		}
		prompt := strings.Join(promptParts, "\n\n")
		trigger, ok := hermesTrigger(asObj(job.Get("schedule")))
		if prompt == "" || !ok {
			reason := "it has no prompt"
			if prompt != "" {
				reason = "its schedule could not be read"
			}
			*skipped = append(*skipped, Skipped{Kind: "Automation", Name: name, Reason: reason})
			continue
		}
		if trigger.Mode == "one_time" && s.passed(trigger.RunAt) {
			*skipped = append(*skipped, Skipped{Kind: "Automation", Name: name, Reason: "a one-time job whose time has passed"})
			continue
		}
		parts := strings.SplitN(str(job.Get("deliver")), ":", 3)
		task := Task{
			Name:     name,
			AgentKey: h.key,
			Prompt:   prompt,
			Trigger:  trigger,
			Enabled:  asBoolNot(job.Get("enabled")) && str(job.Get("state")) != "paused",
			Note:     trigger.Note,
		}
		if isMessagingPlatform(parts[0]) {
			task.Notify = &Notify{Platform: parts[0]}
			if len(parts) > 1 {
				task.Notify.To = parts[1]
			}
		}
		if truthy(job.Get("model")) {
			m := newObj()
			m.set("default", job.Get("model"))
			m.set("provider", firstTruthy(job.Get("provider"), "auto"))
			if pm, ok := hermesModelOf(m); ok {
				task.Model = toNeoAgentModel(pm.provider, pm.model)
			}
		}
		tasks = append(tasks, task)
	}
	return tasks
}

func hermesTrigger(schedule *Obj) (Trigger, bool) {
	switch str(schedule.Get("kind")) {
	case "cron":
		if expr := str(schedule.Get("expr")); expr != "" {
			return cronTrigger(expr)
		}
	case "interval":
		if truthy(schedule.Get("minutes")) {
			minutes, _ := numberOf(schedule.Get("minutes"))
			c := intervalToCron(minutes * 60000)
			note := ""
			if !c.Exact {
				note = "every " + str(schedule.Get("minutes")) + "m rounded to \"" + c.Expr + "\""
			}
			return Trigger{Mode: "recurring", CronExpression: c.Expr, Note: note}, true
		}
	case "once":
		if truthy(schedule.Get("run_at")) {
			return oneTime(schedule.Get("run_at"))
		}
	}
	return Trigger{}, false
}

func splitList(value string) []string {
	var out []string
	for _, item := range strings.Split(value, ",") {
		if item = trim(item); item != "" && item != "*" {
			out = append(out, item)
		}
	}
	return out
}

func unique(lists ...[]string) []string {
	var out []string
	for _, list := range lists {
		for _, v := range list {
			if !contains(out, v) {
				out = append(out, v)
			}
		}
	}
	return out
}

func collectHermesChannels(env *envVars, skipped *[]Skipped) []Channel {
	var channels []Channel
	if env.get("TELEGRAM_BOT_TOKEN") != "" {
		channels = append(channels, Channel{Platform: "telegram", Config: []header{{"botToken", env.get("TELEGRAM_BOT_TOKEN")}},
			Allow: unique(splitList(env.get("TELEGRAM_ALLOWED_USERS")), splitList(env.get("TELEGRAM_HOME_CHANNEL")))})
	}
	if env.get("DISCORD_BOT_TOKEN") != "" {
		channels = append(channels, Channel{Platform: "discord", Config: []header{{"token", env.get("DISCORD_BOT_TOKEN")}},
			Allow: splitList(env.get("DISCORD_ALLOWED_USERS"))})
	}
	if env.get("WHATSAPP_ENABLED") == "true" || env.get("WHATSAPP_ALLOWED_USERS") != "" {
		channels = append(channels, Channel{Platform: "whatsapp", Allow: splitList(env.get("WHATSAPP_ALLOWED_USERS"))})
		*skipped = append(*skipped, Skipped{Kind: "Channel", Name: "WhatsApp", Reason: whatsappNote})
	}
	if env.get("SLACK_BOT_TOKEN") != "" {
		*skipped = append(*skipped, Skipped{Kind: "Channel", Name: "Slack", Reason: slackNote})
	}
	for _, p := range [][2]string{{"SIGNAL_ACCOUNT", "Signal"}, {"MATRIX_ACCESS_TOKEN", "Matrix"}, {"MATTERMOST_TOKEN", "Mattermost"}, {"EMAIL_ADDRESS", "Email"}} {
		if env.get(p[0]) != "" {
			*skipped = append(*skipped, Skipped{Kind: "Channel", Name: p[1], Reason: "not supported by NeoAgent"})
		}
	}
	return channels
}
