package agentimport

import (
	"context"
	"errors"
	"fmt"
	"io"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"

	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/runtimecfg"
	"github.com/NeoLabs-Systems/neolabs-go/secretbox"
)

const (
	// maxInstructionsChars is how much of agents.instructions the model sees;
	// anything longer goes to the agent's behaviour notes, which are not cut.
	maxInstructionsChars = 1600
	maxCoreProfileChars  = 1000
	defaultOllamaURL     = "http://localhost:11434"
)

// Entry is one line of an import's record.
type Entry struct {
	Kind   string
	Status string // imported, exists, skipped or failed
	Name   string
	Detail string
	// Count is how many items the line stands for (a line of 8 memories).
	Count int
}

// Env is what an import needs from the installation it writes into.
type Env struct {
	DB   *dbx.DB
	Host Host
	// Box seals channel credentials (the server's encryption key).
	Box *secretbox.Box
	// EnvFile is the server's .env file; keys land there and load at the next
	// start.
	EnvFile string
	// RuntimeHome holds imports/ (reports); AgentDataDir holds users/<id>/daily.
	RuntimeHome  string
	AgentDataDir string
	// AIProviders is the server's provider list.
	AIProviders []AIProvider
}

// Session is one importer run: the account, and which NeoAgent agent each
// source agent landed in. Every step is safe to repeat: things already in
// NeoAgent are left alone and reported as such.
type Session struct {
	env         Env
	userID      int64
	Entries     []Entry
	agentIDs    map[string]string
	mainClaimed bool
}

// NewSession starts a run for the account.
func NewSession(env Env, userID int64) *Session {
	return &Session{env: env, userID: userID, agentIDs: map[string]string{}}
}

func (s *Session) record(kind, status, name, detail string, count ...int) {
	n := 1
	if len(count) > 0 {
		n = count[0]
	}
	s.Entries = append(s.Entries, Entry{kind, status, name, detail, n})
}

// ApplyBundle writes a scanned bundle into NeoAgent. A step that fails is
// recorded and the next one still runs.
func (s *Session) ApplyBundle(ctx context.Context, b Bundle) {
	steps := []struct {
		label string
		run   func() error
	}{
		{"Keys and AI providers", func() error { return s.applyKeys(b) }},
		{"Agents and personality", func() error { return s.applyAgents(ctx, b) }},
		{"Memories", func() error { return s.applyMemories(ctx, b) }},
		{"Skills", func() error { return s.applySkills(ctx, b) }},
		{"Default model", func() error { return s.applyModel(ctx, b) }},
		{"MCP servers", func() error { return s.applyMCP(ctx, b) }},
		{"Automations", func() error { return s.applyTasks(ctx, b) }},
		{"Messaging channels", func() error { return s.applyChannels(ctx, b) }},
	}
	for _, step := range steps {
		if err := step.run(); err != nil {
			s.record(step.label, "failed", b.Label, err.Error())
		}
	}
	for _, item := range b.Skipped {
		s.record(item.Kind, "skipped", item.Name, item.Reason)
	}
}

// ---- the server's .env file ---------------------------------------------------

// envFileValues reads KEY=value lines as the server's loader does: the value is
// the rest of the line, unquoted and untrimmed, and the last assignment wins.
func envFileValues(file string) map[string]string {
	values := map[string]string{}
	raw, err := os.ReadFile(file)
	if err != nil {
		return values
	}
	for _, line := range regexp.MustCompile(`\r?\n`).Split(string(raw), -1) {
		if line == "" || strings.HasPrefix(line, "#") || !strings.Contains(line, "=") {
			continue
		}
		idx := strings.Index(line, "=")
		if key := trim(line[:idx]); key != "" {
			values[key] = line[idx+1:]
		}
	}
	return values
}

var envName = regexp.MustCompile(`^[A-Za-z_][A-Za-z0-9_]*$`)
var lineBreaks = strings.NewReplacer("\r", "", "\n", "")

// upsertEnvValue replaces the first KEY= line of the file, or appends one, and
// rewrites the file atomically with mode 0600.
func upsertEnvValue(file, key, value string) error {
	key = lineBreaks.Replace(key)
	if !envName.MatchString(key) {
		return fmt.Errorf("Invalid environment variable name: %s", orWord(key, "(empty)"))
	}
	safe := lineBreaks.Replace(value)
	var lines []string
	if raw, err := os.ReadFile(file); err == nil && len(raw) > 0 {
		lines = strings.Split(string(raw), "\n")
	}
	replaced := false
	for i, line := range lines {
		if strings.HasPrefix(line, key+"=") {
			lines[i] = key + "=" + safe
			replaced = true
			break
		}
	}
	if !replaced {
		lines = append(lines, key+"="+safe)
	}
	if lines[len(lines)-1] == "" {
		lines = lines[:len(lines)-1]
	}
	if err := os.MkdirAll(filepath.Dir(file), 0o700); err != nil {
		return err
	}
	return runtimecfg.WritePrivateFile(file, []byte(strings.Join(lines, "\n")+"\n"))
}

func orWord(s, fallback string) string {
	if s == "" {
		return fallback
	}
	return s
}

func (s *Session) applyKeys(b Bundle) error {
	current := envFileValues(s.env.EnvFile)
	for _, key := range b.Keys.names {
		value := b.Keys.get(key)
		stored := trim(current[key])
		existing := stored
		if key == "OLLAMA_URL" && stored == defaultOllamaURL {
			existing = ""
		}
		switch {
		case existing == value:
			s.record("Key", "exists", key, "")
		case existing != "":
			s.record("Key", "exists", key, "kept the value NeoAgent already had ("+b.Label+" has a different one)")
		default:
			if err := upsertEnvValue(s.env.EnvFile, key, value); err != nil {
				return err
			}
			s.record("Key", "imported", key, "")
		}
	}
	for _, key := range b.IgnoredKeys {
		s.record("Key", "skipped", key, "NeoAgent does not use this service")
	}
	return nil
}

// ---- agents -------------------------------------------------------------------

func agentRef(b Bundle, a *Agent) string {
	key := ""
	if a != nil {
		key = a.Key
	}
	return b.Source + ":" + b.Home + ":" + key
}

var nonSlug = regexp.MustCompile(`[^a-z0-9]+`)

func slugFor(value string) string {
	slug := nonSlug.ReplaceAllString(strings.ToLower(nfkd(orWord(value, "agent"))), "-")
	slug = strings.TrimPrefix(slug, "-")
	slug = strings.TrimSuffix(slug, "-")
	if len(slug) > 40 {
		slug = slug[:40]
	}
	return orWord(slug, "agent")
}

func defaultAgent(b Bundle) *Agent {
	for i := range b.Agents {
		if b.Agents[i].IsDefault {
			return &b.Agents[i]
		}
	}
	return nil
}

// agentID is the NeoAgent agent a source agent landed in; "" when none did.
func (s *Session) agentID(b Bundle, key string) string {
	var source *Agent
	for i := range b.Agents {
		if b.Agents[i].Key == key {
			source = &b.Agents[i]
			break
		}
	}
	if source == nil {
		source = defaultAgent(b)
	}
	return s.agentIDs[agentRef(b, source)]
}

// applyAgents: the source's default agent becomes NeoAgent's main agent. When
// main already has instructions (yours, or another source's), the source agent
// is added beside it instead, so no personality is overwritten.
func (s *Session) applyAgents(ctx context.Context, b Bundle) error {
	host := s.env.Host
	main, err := host.EnsureMainAgent(ctx, s.userID)
	if err != nil {
		return err
	}
	for i := range b.Agents {
		source := &b.Agents[i]
		ref := agentRef(b, source)
		if source.IsDefault && source.Instructions != "" {
			holds, err := s.holdsInstructions(ctx, main, source.Instructions)
			if err != nil {
				return err
			}
			if holds {
				s.mainClaimed = true
				s.agentIDs[ref] = main.ID
				s.record("Agent", "exists", source.Name+" → main agent", "")
				continue
			}
		}
		if source.IsDefault && trim(main.Instructions) == "" && !s.mainClaimed {
			s.mainClaimed = true
			s.agentIDs[ref] = main.ID
			if source.Instructions != "" {
				if err := s.writeInstructions(ctx, main.ID, source.Instructions, "main"); err != nil {
					return err
				}
				s.record("Agent", "imported", source.Name+" → main agent", "personality and instructions")
			}
			continue
		}
		if source.IsDefault && source.Instructions == "" {
			s.agentIDs[ref] = main.ID
			continue
		}
		name := source.Name
		if name == "Hermes" {
			name = "hermes"
		} else if name == "" {
			name = source.Key
		}
		slug := slugFor(name)
		existing, err := host.AgentBySlug(ctx, s.userID, slug)
		if err != nil {
			return err
		}
		if existing != nil {
			s.agentIDs[ref] = existing.ID
			s.record("Agent", "exists", existing.DisplayName, "")
			continue
		}
		created, err := host.CreateAgent(ctx, s.userID, NewAgent{Slug: slug, DisplayName: source.Name, Description: "Imported from " + b.Label})
		if err != nil {
			return err
		}
		s.agentIDs[ref] = created.ID
		if source.Instructions != "" {
			// The created agent has no short name of its own to report.
			if err := s.writeInstructions(ctx, created.ID, source.Instructions, "agent"); err != nil {
				return err
			}
		}
		s.record("Agent", "imported", source.Name, `new agent "`+slug+`"`)
	}
	return nil
}

// holdsInstructions finds the text a repeat run wrote last time, in either
// place.
func (s *Session) holdsInstructions(ctx context.Context, agent AgentInfo, text string) (bool, error) {
	if trim(agent.Instructions) == trim(text) {
		return true, nil
	}
	notes, err := s.env.Host.BehaviorNotes(ctx, s.userID, agent.ID)
	return trim(notes) == trim(text), err
}

func (s *Session) writeInstructions(ctx context.Context, agentID, text, name string) error {
	if jsLen(text) <= maxInstructionsChars {
		return s.env.Host.SetInstructions(ctx, s.userID, agentID, text)
	}
	if err := s.env.Host.SetBehaviorNotes(ctx, s.userID, agentID, text); err != nil {
		return err
	}
	s.record("Agent", "imported", name, "long personality saved as behaviour notes")
	return nil
}

// ---- memories -----------------------------------------------------------------

func (s *Session) countMemories(ctx context.Context, agentID string) (int, error) {
	var n int
	err := s.env.DB.W.QueryRowContext(ctx,
		`SELECT COUNT(*) FROM memories WHERE user_id = ? AND agent_id = ? AND archived = 0`, s.userID, nullable(agentID)).Scan(&n)
	return n, err
}

// nullable binds "" as NULL, which an unresolved agent id is in the database.
func nullable(id string) any {
	if id == "" {
		return nil
	}
	return id
}

type fact struct{ text, category string }

func (s *Session) applyMemories(ctx context.Context, b Bundle) error {
	host := s.env.Host
	for i := range b.Agents {
		source := &b.Agents[i]
		agentID := s.agentID(b, source.Key)
		var facts []fact
		for _, item := range source.Memories {
			for _, text := range toShortFacts(item.Text) {
				facts = append(facts, fact{text, item.Category})
			}
		}
		if source.UserProfile != "" {
			current, err := host.UserProfile(ctx, s.userID, agentID)
			if err != nil {
				return err
			}
			switch {
			case current == source.UserProfile:
				s.record("Memory", "exists", source.Name+": about you", "")
			case current == "" && jsLen(source.UserProfile) <= maxCoreProfileChars:
				if err := host.SetUserProfile(ctx, s.userID, agentID, source.UserProfile); err != nil {
					return err
				}
				s.record("Memory", "imported", source.Name+": about you", "saved to core memory")
			default:
				for _, line := range strings.Split(source.UserProfile, "\n") {
					for _, text := range toShortFacts(line) {
						facts = append(facts, fact{text, "identity"})
					}
				}
			}
		}

		saved, known := 0, 0
		for _, f := range facts {
			before, err := s.countMemories(ctx, agentID)
			if err != nil {
				return err
			}
			result, err := host.SaveMemory(ctx, s.userID, agentID, MemoryToSave{
				Text: f.text, Category: f.category, Importance: 6,
				SourceType: "import", SourceID: b.Source + ":" + source.Key, SourceLabel: b.Label + " import",
			})
			if err != nil {
				return err
			}
			after, err := s.countMemories(ctx, agentID)
			if err != nil {
				return err
			}
			if result && after > before {
				saved++
			} else {
				known++
			}
		}
		if saved > 0 {
			noun := "memories"
			if saved == 1 {
				noun = "memory"
			}
			s.record("Memory", "imported", fmt.Sprintf("%s: %d %s", source.Name, saved, noun), "", saved)
		}
		if known > 0 {
			s.record("Memory", "exists", fmt.Sprintf("%s: %d already known", source.Name, known), "", known)
		}
		if source.IsDefault && len(source.DailyLogs) > 0 {
			if err := s.writeDailyLogs(source.DailyLogs, source.Name); err != nil {
				return err
			}
		}
	}
	return nil
}

// writeDailyLogs maps daily notes one to one onto NeoAgent's daily logs
// (YYYY-MM-DD.md).
func (s *Session) writeDailyLogs(logs []DailyLog, agentName string) error {
	dir := filepath.Join(s.env.AgentDataDir, "users", strconv.FormatInt(s.userID, 10), "daily")
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return err
	}
	written := 0
	for _, log := range logs {
		file := filepath.Join(dir, log.Date+".md")
		existing, _ := os.ReadFile(file)
		if strings.Contains(string(existing), log.Content) {
			continue
		}
		content := log.Content + "\n"
		if len(existing) > 0 {
			content = strings.TrimRight(string(existing), " \t\r\n") + "\n\n" + log.Content + "\n"
		}
		if err := os.WriteFile(file, []byte(content), 0o600); err != nil {
			return err
		}
		written++
	}
	days := fmt.Sprintf("%d day", len(logs))
	if len(logs) != 1 {
		days += "s"
	}
	if written > 0 {
		s.record("Daily notes", "imported", agentName, days, written)
	} else {
		s.record("Daily notes", "exists", agentName, days, len(logs))
	}
	return nil
}

// ---- skills -------------------------------------------------------------------

func (s *Session) applySkills(ctx context.Context, b Bundle) error {
	for _, skill := range b.Skills {
		file, err := s.env.Host.CreateSkill(ctx, s.userID, NewSkill{
			Name: skill.Name, Description: skill.Description, Body: skill.Body, Source: b.Source, ImportedFrom: skill.Dir,
		})
		if err != nil {
			if errors.Is(err, ErrSkillExists) {
				s.record("Skill", "exists", skill.Name, "")
			} else {
				s.record("Skill", "failed", skill.Name, err.Error())
			}
			continue
		}
		if err := copySkillFiles(skill, filepath.Dir(file)); err != nil {
			return err
		}
		detail := ""
		if n := len(skill.Files); n > 0 {
			detail = fmt.Sprintf("with %d file", n)
			if n != 1 {
				detail += "s"
			}
		}
		s.record("Skill", "imported", skill.Name, detail)
	}
	return nil
}

// copySkillFiles copies a skill's bundled files into the stored skill. Both
// sides are confined with os.Root, so neither a crafted name nor a symlink in
// the source folder can reach outside the two folders.
func copySkillFiles(skill Skill, dest string) error {
	if len(skill.Files) == 0 {
		return nil
	}
	src, err := os.OpenRoot(skill.Dir)
	if err != nil {
		return err
	}
	defer src.Close()
	dst, err := os.OpenRoot(dest)
	if err != nil {
		return err
	}
	defer dst.Close()
	for _, rel := range skill.Files {
		if !filepath.IsLocal(rel) {
			continue
		}
		if dir := filepath.Dir(rel); dir != "." {
			if err := dst.MkdirAll(dir, 0o700); err != nil {
				return err
			}
		}
		in, err := src.Open(rel)
		if err != nil {
			return err
		}
		out, err := dst.OpenFile(rel, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0o600)
		if err != nil {
			in.Close()
			return err
		}
		_, err = io.Copy(out, in)
		in.Close()
		if cerr := out.Close(); err == nil {
			err = cerr
		}
		if err != nil {
			return err
		}
	}
	return nil
}

// ---- model --------------------------------------------------------------------

// providerReady says whether the model's provider has what it needs to answer.
func (s *Session) providerReady(model string, env map[string]string) bool {
	id, _, _ := strings.Cut(model, "::")
	for _, p := range s.env.AIProviders {
		if p.ID == id {
			return p.EnvKey == "" || trim(env[p.EnvKey]) != ""
		}
	}
	return false
}

// applyModel only fills an unset ("auto") model, and only with a provider
// NeoAgent has a key for, so an import never points chat at a model that cannot
// answer.
func (s *Session) applyModel(ctx context.Context, b Bundle) error {
	type target struct {
		model  string
		source *Agent
	}
	targets := []target{{b.Model, defaultAgent(b)}}
	for i := range b.Agents {
		if a := &b.Agents[i]; !a.IsDefault && a.Model != "" {
			targets = append(targets, target{a.Model, a})
		}
	}
	env := envFileValues(s.env.EnvFile)
	for _, t := range targets {
		if t.model == "" || t.source == nil {
			continue
		}
		agentID := s.agentID(b, t.source.Key)
		current, err := s.env.Host.DefaultChatModel(ctx, s.userID, agentID)
		if err != nil {
			return err
		}
		if current != "" && current != "auto" {
			detail := ""
			if current != t.model {
				detail = "kept " + current
			}
			s.record("Model", "exists", t.source.Name, detail)
			continue
		}
		if !s.providerReady(t.model, env) {
			s.record("Model", "skipped", t.model, "no key for this provider was found")
			continue
		}
		if err := s.env.Host.ApplySetting(ctx, s.userID, agentID, "default_chat_model", t.model); err != nil {
			s.record("Model", "failed", t.source.Name+": "+t.model, orWord(err.Error(), "not accepted"))
			continue
		}
		s.record("Model", "imported", t.source.Name+": "+t.model, "")
	}
	return nil
}

// ---- MCP servers --------------------------------------------------------------

// validateRemoteMCPEndpoint accepts only remote http(s) URLs and returns them
// in the form new URL(...).toString() gives.
func validateRemoteMCPEndpoint(value string) (string, error) {
	u, err := url.Parse(trim(value))
	if err != nil || u.Scheme == "" || u.Host == "" && u.Opaque == "" {
		return "", errors.New("MCP server must be a valid remote http(s) URL.")
	}
	if u.Scheme != "http" && u.Scheme != "https" {
		return "", errors.New("MCP server must use http or https. Local stdio/process MCP is disabled.")
	}
	host := strings.ToLower(u.Hostname())
	if strings.Contains(host, ":") {
		host = "[" + host + "]"
	}
	port := u.Port()
	if (u.Scheme == "http" && port == "80") || (u.Scheme == "https" && port == "443") {
		port = ""
	}
	if port != "" {
		host += ":" + port
	}
	out := u.Scheme + "://"
	if u.User != nil {
		out += u.User.String() + "@"
	}
	out += host + orWord(u.EscapedPath(), "/")
	if u.RawQuery != "" {
		out += "?" + u.RawQuery
	}
	if u.Fragment != "" {
		out += "#" + u.EscapedFragment()
	}
	return out, nil
}

func (s *Session) applyMCP(ctx context.Context, b Bundle) error {
	var key string
	if d := defaultAgent(b); d != nil {
		key = d.Key
	}
	agentID := s.agentID(b, key)
	for _, server := range b.MCP {
		var exists int64
		err := s.env.DB.W.QueryRowContext(ctx, `SELECT id FROM mcp_servers WHERE user_id = ? AND name = ?`, s.userID, server.Name).Scan(&exists)
		if err == nil {
			s.record("MCP server", "exists", server.Name, "")
			continue
		}
		if !isNoRows(err) {
			return err
		}
		endpoint, err := validateRemoteMCPEndpoint(server.URL)
		if err != nil {
			return err
		}
		config := newObj()
		config.set("transport", server.Transport)
		if server.Token != nil {
			auth := newObj()
			auth.set("type", "bearer")
			auth.set("token", *server.Token)
			config.set("auth", auth)
		}
		if len(server.Headers) > 0 {
			config.set("headers", headerObj(server.Headers))
		}
		enabled := 0
		if server.Enabled {
			enabled = 1
		}
		if _, err := s.env.DB.W.ExecContext(ctx,
			`INSERT INTO mcp_servers (user_id, agent_id, name, command, config, enabled) VALUES (?, ?, ?, ?, ?, ?)`,
			s.userID, nullable(agentID), server.Name, endpoint, marshal(config), enabled); err != nil {
			return err
		}
		detail := ""
		if !server.Enabled {
			detail = "kept switched off"
		}
		s.record("MCP server", "imported", server.Name, detail)
	}
	return nil
}

func headerObj(h []header) *Obj {
	o := newObj()
	for _, x := range h {
		o.set(x.Name, x.Value)
	}
	return o
}

// ---- automations --------------------------------------------------------------

func (s *Session) applyTasks(ctx context.Context, b Bundle) error {
	if err := s.applyTimezone(ctx, b); err != nil {
		return err
	}
	for _, task := range b.Tasks {
		agentID := s.agentID(b, task.AgentKey)
		var exists int64
		err := s.env.DB.W.QueryRowContext(ctx, `SELECT id FROM scheduled_tasks WHERE user_id = ? AND agent_id IS ? AND name = ?`,
			s.userID, nullable(agentID), task.Name).Scan(&exists)
		if err == nil {
			s.record("Automation", "exists", task.Name, "")
			continue
		}
		if !isNoRows(err) {
			return err
		}
		triggerConfig, err := s.env.Host.ValidateSchedule(ctx, s.userID, agentID, task.Trigger)
		if err != nil {
			return err
		}
		config := TaskConfig{Prompt: task.Prompt, Model: task.Model}
		if task.Notify != nil {
			config.NotifyPlatform, config.NotifyTo = task.Notify.Platform, task.Notify.To
		}
		if err := s.env.Host.CreateTask(ctx, s.userID, TaskSpec{
			AgentID: agentID, Name: task.Name, TriggerConfig: triggerConfig, TaskConfig: config, Enabled: task.Enabled,
		}); err != nil {
			return err
		}
		var notes []string
		if !task.Enabled {
			notes = append(notes, "paused")
		}
		if task.Note != "" {
			notes = append(notes, task.Note)
		}
		s.record("Automation", "imported", task.Name, strings.Join(notes, "; "))
	}
	return nil
}

// applyTimezone: schedules are read in the account's time zone; take the
// source's when NeoAgent has none yet.
func (s *Session) applyTimezone(ctx context.Context, b Bundle) error {
	if b.Timezone == "" {
		return nil
	}
	current, err := s.env.Host.UserTimeZone(ctx, s.userID)
	if err != nil {
		return err
	}
	if current != "" {
		if current != b.Timezone && len(b.Tasks) > 0 {
			s.record("Automation", "skipped", "timezone", "schedules now run in "+current+"; "+b.Label+" used "+b.Timezone)
		}
		return nil
	}
	if err := s.env.Host.ApplySetting(ctx, s.userID, "", "timezone", b.Timezone); err == nil {
		s.record("Setting", "imported", "timezone", b.Timezone)
	}
	return nil
}

// ---- channels -----------------------------------------------------------------

// accessPolicyKey is the agent_settings key of a platform's access policy.
func accessPolicyKey(platform string) string {
	return "platform_access_policy_" + trim(platform)
}

// applyChannels stores connections the way the server stores them, so they come
// online at its next start; allowlists become NeoAgent access policies.
func (s *Session) applyChannels(ctx context.Context, b Bundle) error {
	var key string
	if d := defaultAgent(b); d != nil {
		key = d.Key
	}
	agentID := s.agentID(b, key)
	db := s.env.DB.W
	for _, channel := range b.Channels {
		label := platformLabels[channel.Platform]
		if channel.Config != nil {
			var exists int64
			err := db.QueryRowContext(ctx, `SELECT id FROM platform_connections WHERE user_id = ? AND agent_id IS ? AND platform = ?`,
				s.userID, nullable(agentID), channel.Platform).Scan(&exists)
			switch {
			case err == nil:
				s.record("Channel", "exists", label, "")
				continue
			case !isNoRows(err):
				return err
			}
			cfg := headerObj(channel.Config)
			cfg.set("autoConnect", true)
			sealed, err := s.env.Box.Seal(marshal(cfg))
			if err != nil {
				return err
			}
			if _, err := db.ExecContext(ctx, `INSERT INTO platform_connections (user_id, agent_id, platform, config, status) VALUES (?, ?, ?, ?, ?)`,
				s.userID, nullable(agentID), channel.Platform, sealed, "connecting"); err != nil {
				return err
			}
			s.record("Channel", "imported", label, "connects when NeoAgent restarts")
		}
		var usable, dropped []string
		for _, entry := range channel.Allow {
			if channel.Platform == "telegram" && strings.HasPrefix(entry, "@") {
				dropped = append(dropped, entry)
			} else {
				usable = append(usable, entry)
			}
		}
		for _, entry := range dropped {
			s.record("Channel", "skipped", label+" "+entry, "usernames cannot be allowed; add the numeric user id")
		}
		if len(usable) == 0 {
			continue
		}
		settingKey := accessPolicyKey(channel.Platform)
		var one int
		err := db.QueryRowContext(ctx, `SELECT 1 FROM agent_settings WHERE user_id = ? AND agent_id = ? AND key = ?`,
			s.userID, nullable(agentID), settingKey).Scan(&one)
		switch {
		case err == nil:
			s.record("Channel", "exists", label+" allowlist", "")
			continue
		case !isNoRows(err):
			return err
		}
		policy, err := s.env.Host.AllowlistPolicy(channel.Platform, usable)
		if err != nil {
			return err
		}
		if _, err := db.ExecContext(ctx, `INSERT INTO agent_settings (user_id, agent_id, key, value) VALUES (?, ?, ?, ?)
			ON CONFLICT(user_id, agent_id, key) DO UPDATE SET value = excluded.value`,
			s.userID, nullable(agentID), settingKey, policy); err != nil {
			return err
		}
		s.record("Channel", "imported", label+" allowlist", fmt.Sprintf("%d allowed", len(usable)))
	}
	return nil
}
