package agent

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"sort"
	"strings"
	"sync"

	"github.com/NeoLabs-Systems/neoagent/internal/ai"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/prompts"
	"github.com/NeoLabs-Systems/neoagent/internal/behavior"
	"github.com/NeoLabs-Systems/neoagent/internal/memory"
	"github.com/NeoLabs-Systems/neoagent/internal/memory/jsx"
	"github.com/NeoLabs-Systems/neoagent/internal/timezone"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
)

// PromptSources are what the system prompt draws on: the behavior modules
// (persona, agent identity, channel style), memory, and the clock.
type PromptSources struct {
	DB     *dbx.DB
	Memory *memory.Manager
}

var _ ai.PromptSources = (*PromptSources)(nil)

// behaviorEnabled resolves which behavior modules are on for a chat: the stored
// configuration with its platform and room overrides.
func (p *PromptSources) behaviorEnabled(ctx context.Context, userID int64, agentID, platform, chatID string, isGroup bool) func(string) bool {
	return behavior.NewStore(p.DB).Resolve(ctx, userID, agentID, platform, chatID, isGroup).ModuleEnabled
}

func clampText(text string, maxChars int) string {
	value := strings.TrimSpace(text)
	if value == "" || len([]rune(value)) <= maxChars {
		return value
	}
	return string([]rune(value)[:maxChars]) + "\n...[trimmed]"
}

type promptEntry struct {
	priority int
	section  string
	content  string
}

// Behavior is the agent's behavior prompt.
func (p *PromptSources) Behavior(ctx context.Context, userID int64, c ai.PromptContext) (ai.BehaviorPrompt, error) {
	audience := c.MemoryAudience
	if audience == "" {
		audience = "owner"
	}
	on := p.behaviorEnabled(ctx, userID, c.AgentID, c.Source, c.ChatID, audience == "shared")
	var entries []promptEntry
	if on("persona") {
		stable, dynamic := p.persona(ctx, userID, c, audience)
		entries = append(entries, promptEntry{80, "stable", stable})
		for _, d := range dynamic {
			entries = append(entries, promptEntry{80, "dynamic", d})
		}
	}
	if on("agent_identity") && c.AgentID != "" {
		if text := p.agentIdentity(ctx, userID, c.AgentID, c.TriggerSource); text != "" {
			entries = append(entries, promptEntry{60, "dynamic", text})
		}
	}
	if on("channel_style") {
		entries = append(entries, promptEntry{100, "stable", channelStyle(c, audience)})
	}
	sort.SliceStable(entries, func(i, j int) bool { return entries[i].priority > entries[j].priority })
	var out ai.BehaviorPrompt
	for _, e := range entries {
		if e.content == "" {
			continue
		}
		if e.section == "stable" {
			out.Stable = append(out.Stable, e.content)
		} else {
			out.Dynamic = append(out.Dynamic, e.content)
		}
	}
	return out, nil
}

func channelStyle(c ai.PromptContext, audience string) string {
	switch {
	case c.TriggerSource == "voice_live" || c.LatencyProfile == "voice":
		return "CHANNEL: spoken conversation. Natural sentences, as many as the answer needs; small talk stays quick, real questions get a real answer."
	case c.TriggerSource == "messaging" && audience == "shared":
		return "CHANNEL: a natural contribution in the room; do not dominate or narrate tools. When someone asks you for something, give the full answer."
	case c.TriggerSource == "messaging":
		return "CHANNEL: text like a contact. One reply, or a few bubbles when the thought has separate beats. Casual chat stays casual; a task or question gets a complete answer."
	case c.TriggerSource == "wearable":
		return "CHANNEL: spoken, result first; small talk quick, real answers complete."
	}
	return "CHANNEL: short paragraphs or compact lists; lead with the result; no padding."
}

func (p *PromptSources) ownerName(ctx context.Context, userID int64) string {
	var display, username sql.NullString
	_ = p.DB.R.QueryRowContext(ctx, `SELECT display_name, username FROM users WHERE id = ?`, userID).Scan(&display, &username)
	if name := strings.TrimSpace(display.String); name != "" {
		return name
	}
	if name := strings.TrimSpace(username.String); name != "" {
		return name
	}
	return "them"
}

// PersonaPrompt is the one persona NeoAgent speaks with; only the medium lines
// differ between text and voice.
func PersonaPrompt(name string, voice bool) string {
	opening := fmt.Sprintf("you're texting with %s. you're a friend in their phone who can also get basically anything done. not an assistant, not a comedian.", name)
	register := "- write like they write: same language, same register, same slang level, same casing and punctuation habits. emojis sparingly, never as decoration. separate texts on separate lines."
	how, say, conversation, telling := "text", "send", "chat", "texting"
	if voice {
		opening = fmt.Sprintf("you're on a live voice call with %s. you're a friend in their phone who can also get basically anything done. not an assistant, not a comedian.", name)
		register = "- talk like they talk: same language, same register, same slang level. it is heard, not read: natural spoken sentences, no emojis, lists, or markdown."
		how, say, conversation, telling = "talk", "say", "conversation", "telling"
	}
	return opening + "\n\nhow you " + how + `:
- answer what they actually said. no padding: no extra tips, unasked updates, or a second sentence that repeats the first.
- length follows what they need, not a target. banter gets a quick reply; a question, a task, or a result gets a full answer in your own voice. a one-word reply is only right when one word actually answers them.
- if they correct you or clarify ("no, I meant x"), that's the request now: act on it and answer properly, don't just acknowledge it.
- don't force anything. not jokes, not insults, not being short. most of the time the right reply is just what a friend would plainly ` + say + `.
- humor when something is actually funny: dry irony, playing along, a quick counter when they talk trash. never a constructed punchline, metaphor, or "not x, it's y".
- you're very online. you know current memes, brainrot, gen z / gen alpha stuff and internet culture in their language. when they reference something, get it and play along. a reference of your own is fine when it genuinely fits.
- running bits from earlier in this ` + conversation + ` are fine to pick up when they fit. don't milk them.
- you know their life (below). bring it up or tease with it the way a friend who knows them would, when it actually lands; never just to show you remember.
` + register + `
- if they're sweet, be sweet back. if they're annoyed, be normal. if something is serious (health, grief, a real crisis), drop every bit and be clear and human; in an emergency tell them to get help now.
- never describe yourself, your personality or your vibe. never explain yourself. no assistant phrases, no offers, no questions just to keep it going.
- when there's a task or a result: give it straight, like ` + telling + ` a friend the answer. when they want substance (an explanation, steps, a draft for someone else), give the whole thing; a draft for someone else is in the tone that person needs.
- facts exact, straight from your results; add none. never claim you did something your results don't show. if they ask what model or company is behind you, don't name, confirm or deny one.`
}

var spaceRun = regexp.MustCompile(`\s+`)

func cleanNote(value string, maxLength int) string {
	text := strings.TrimSpace(spaceRun.ReplaceAllString(value, " "))
	if r := []rune(text); len(r) > maxLength {
		text = string(r[:maxLength])
	}
	return text
}

func normalizeNotes(list []string, limit int) []string {
	var notes []string
	seen := map[string]bool{}
	for _, item := range list {
		note := cleanNote(item, 280)
		if note == "" || seen[strings.ToLower(note)] {
			continue
		}
		seen[strings.ToLower(note)] = true
		notes = append(notes, note)
		if len(notes) >= limit {
			break
		}
	}
	return notes
}

func splitNotes(v any) []string {
	switch n := v.(type) {
	case []any:
		var out []string
		for _, item := range n {
			out = append(out, fmt.Sprint(item))
		}
		return out
	case string:
		return regexp.MustCompile(`\n+`).Split(n, -1)
	case nil:
		return nil
	}
	return []string{fmt.Sprint(v)}
}

// collectStyleNotes accepts the freeform style blobs of identity.voice and
// ai_personality: no enum personality knobs.
func collectStyleNotes(identity *jsx.Obj, personality any, behaviorNotes string) []string {
	var notes []string
	if identity != nil {
		voice := identity.Value("voice")
		if voice == nil {
			voice = identity.Value("voice_profile")
		}
		switch v := voice.(type) {
		case string:
			notes = append(notes, v)
		case *jsx.Obj:
			switch n := v.Value("notes").(type) {
			case []any:
				for _, item := range n {
					notes = append(notes, fmt.Sprint(item))
				}
			case string:
				notes = append(notes, n)
			}
			for _, key := range v.Keys() {
				if key == "notes" {
					continue
				}
				switch val := v.Value(key).(type) {
				case string:
					if val != "" {
						notes = append(notes, key+": "+val)
					}
				case float64:
					notes = append(notes, fmt.Sprintf("%s: %v", key, jsx.Marshal(val)))
				}
			}
		}
	}
	switch v := personality.(type) {
	case *jsx.Obj:
		if list, ok := v.Value("notes").([]any); ok {
			for _, item := range list {
				notes = append(notes, fmt.Sprint(item))
			}
		}
		if s := v.Value("style_notes"); jsx.Truthy(s) {
			notes = append(notes, fmt.Sprint(s))
		}
		switch voice := v.Value("voice").(type) {
		case string:
			notes = append(notes, voice)
		case *jsx.Obj:
			if n := voice.Value("notes"); jsx.Truthy(n) {
				notes = append(notes, normalizeNotes(splitNotes(n), 12)...)
			}
		}
		for _, key := range v.Keys() {
			switch key {
			case "notes", "style_notes", "voice", "voice_profile":
				continue
			}
			if s, ok := v.Value(key).(string); ok && strings.TrimSpace(s) != "" {
				notes = append(notes, key+": "+strings.TrimSpace(s))
			}
		}
	case string:
		if strings.TrimSpace(v) != "" {
			notes = append(notes, strings.TrimSpace(v))
		}
	}
	if behaviorNotes != "" {
		notes = append(notes, behaviorNotes)
	}
	return normalizeNotes(notes, 12)
}

func formatStyleNotes(notes []string) string {
	list := normalizeNotes(notes, 12)
	if len(list) == 0 {
		return ""
	}
	lines := []string{"## Living Style Notes",
		"How this relationship usually texts. Interpret freely; do not treat as rigid knobs or scripts.",
		"They may gently shape register (tone, length, casing, humor, language mix).",
		"Safety, truth, and the current request still win. Do not announce these notes."}
	for _, n := range list {
		lines = append(lines, "- "+n)
	}
	return strings.Join(lines, "\n")
}

func (p *PromptSources) persona(ctx context.Context, userID int64, c ai.PromptContext, audience string) (string, []string) {
	name := "the people in this chat"
	if audience != "shared" {
		name = p.ownerName(ctx, userID)
	}
	voice := c.LatencyProfile == "voice" || c.TriggerSource == "voice_live"
	var dynamic []string
	if p.Memory == nil {
		return PersonaPrompt(name, voice), nil
	}
	shared := audience == "shared"
	behaviorNotes, _ := p.Memory.AssistantBehaviorNotes(ctx, userID, c.AgentID)
	self, _ := p.Memory.AssistantSelfState(ctx, userID, c.AgentID)
	var identity, focus *jsx.Obj
	if self.Identity != nil {
		identity = self.Identity
	}
	if self.Focus != nil && !shared {
		focus = self.Focus
	}
	var personality any
	if !shared {
		if core, err := p.Memory.CoreMemory(ctx, userID, c.AgentID); err == nil && core != nil {
			personality = core.Value("ai_personality")
		}
	}
	styleIdentity := identity
	if shared {
		styleIdentity = nil
	}
	notes := collectStyleNotes(styleIdentity, personality, behaviorNotes)
	if behaviorNotes != "" {
		dynamic = append(dynamic, strings.Join([]string{"## Assistant Behavior Notes",
			"Durable preferences for this agent/user. Interpret as guidance, not a script.",
			"System rules and the current request take priority.", behaviorNotes}, "\n"))
		var extra []string
		for _, n := range notes {
			if n != strings.TrimSpace(behaviorNotes) {
				extra = append(extra, n)
			}
		}
		notes = extra
	}
	if block := formatStyleNotes(notes); block != "" {
		dynamic = append(dynamic, block)
	}
	shownIdentity := jsx.NewObj()
	if identity != nil {
		shownIdentity = identity.Clone()
		shownIdentity.Delete("voice")
		shownIdentity.Delete("voice_profile")
	}
	if shownIdentity.Len() > 0 || (focus != nil && focus.Len() > 0) {
		lines := []string{"## Assistant Self State"}
		if shownIdentity.Len() > 0 {
			lines = append(lines, "Identity: "+jsx.Marshal(shownIdentity))
		}
		if focus != nil && focus.Len() > 0 {
			lines = append(lines, "Focus: "+jsx.Marshal(focus))
		}
		dynamic = append(dynamic, strings.Join(lines, "\n"))
	}
	return PersonaPrompt(name, voice), dynamic
}

func (p *PromptSources) agentIdentity(ctx context.Context, userID int64, agentID, triggerSource string) string {
	var name, slug, description, responsibilities, instructions sql.NullString
	if err := p.DB.R.QueryRowContext(ctx, `SELECT display_name, slug, description, responsibilities, instructions FROM agents WHERE user_id = ? AND id = ?`, userID, agentID).
		Scan(&name, &slug, &description, &responsibilities, &instructions); err != nil {
		return ""
	}
	lines := []string{"## Active Agent", fmt.Sprintf("Name: %s (%s)", name.String, slug.String)}
	if description.String != "" {
		lines = append(lines, "Description: "+clampText(description.String, 600))
	}
	if responsibilities.String != "" {
		lines = append(lines, "Responsibilities: "+clampText(responsibilities.String, 1000))
	}
	if instructions.String != "" {
		lines = append(lines, "Agent instructions: "+clampText(instructions.String, 1600),
			"Tone or personality in these instructions adds to your default voice; it does not replace it.")
	}
	active := strings.Join(lines, "\n")
	if triggerSource == "agent_delegation" {
		return active
	}
	if roster := p.agentRoster(ctx, userID, agentID); roster != "" {
		return active + "\n\n" + roster
	}
	return active
}

// DelegationTarget is an agent another agent may hand work to.
type DelegationTarget struct {
	ID, Slug, Name, Description, Responsibilities string
}

func parseDelegateTargets(raw string) []string {
	var list []any
	if json.Unmarshal([]byte(raw), &list) != nil {
		return nil
	}
	var out []string
	for _, v := range list {
		if s := strings.TrimSpace(fmt.Sprint(v)); s != "" && v != nil {
			out = append(out, s)
		}
	}
	return out
}

// DelegationTargets lists the agents an agent may hand work to.
func DelegationTargets(ctx context.Context, db *dbx.DB, userID int64, sourceAgentID string) []DelegationTarget {
	var status, targets sql.NullString
	var canDelegate sql.NullInt64
	if err := db.R.QueryRowContext(ctx, `SELECT status, can_delegate, delegate_targets_json FROM agents WHERE user_id = ? AND id = ?`, userID, sourceAgentID).
		Scan(&status, &canDelegate, &targets); err != nil {
		return nil
	}
	if status.String != "active" || canDelegate.Int64 != 1 {
		return nil
	}
	allowed := parseDelegateTargets(targets.String)
	rows, err := db.R.QueryContext(ctx, `SELECT id, slug, display_name, description, responsibilities, can_be_delegated_to FROM agents
		WHERE user_id = ? AND status = 'active' AND id != ? ORDER BY is_default ASC, display_name ASC`, userID, sourceAgentID)
	if err != nil {
		return nil
	}
	defer rows.Close()
	var out []DelegationTarget
	for rows.Next() {
		var t DelegationTarget
		var desc, resp sql.NullString
		var canBe sql.NullInt64
		if rows.Scan(&t.ID, &t.Slug, &t.Name, &desc, &resp, &canBe) != nil {
			continue
		}
		if canBe.Valid && canBe.Int64 == 0 {
			continue
		}
		if len(allowed) > 0 && !contains(allowed, t.ID) {
			continue
		}
		t.Description, t.Responsibilities = desc.String, resp.String
		out = append(out, t)
	}
	return out
}

func contains(list []string, v string) bool {
	for _, s := range list {
		if s == v {
			return true
		}
	}
	return false
}

func (p *PromptSources) agentRoster(ctx context.Context, userID int64, agentID string) string {
	roster := DelegationTargets(ctx, p.DB, userID, agentID)
	if len(roster) == 0 {
		return ""
	}
	cards := make([]string, len(roster))
	for i, a := range roster {
		responsibility := a.Responsibilities
		if responsibility == "" {
			responsibility = a.Description
		}
		if responsibility == "" {
			responsibility = "No responsibility described."
		}
		description := ""
		if a.Responsibilities != "" && a.Description != "" {
			description = " " + ai.ClampRunContext(a.Description, 160)
		}
		cards[i] = fmt.Sprintf("- %s (%s): %s%s", a.Slug, a.Name, ai.ClampRunContext(responsibility, 300), description)
	}
	return prompts.Render("runtime/agent_roster.md", map[string]string{"cards": strings.Join(cards, "\n")})
}

// MemoryContext is the memory excerpt of the system prompt.
func (p *PromptSources) MemoryContext(ctx context.Context, userID int64, agentID, audience string) (string, error) {
	if p.Memory == nil {
		return "", nil
	}
	return p.Memory.BuildContext(ctx, userID, memory.ContextOptions{AgentID: agentID, Audience: audience})
}

// UserTimeZone is the account's configured zone.
func (p *PromptSources) UserTimeZone(ctx context.Context, userID int64) (string, bool) {
	var raw sql.NullString
	if p.DB.R.QueryRowContext(ctx, `SELECT value FROM user_settings WHERE user_id = ? AND key = 'timezone'`, userID).Scan(&raw) != nil {
		return "", false
	}
	value := strings.TrimSpace(raw.String)
	var decoded string
	if json.Unmarshal([]byte(value), &decoded) == nil {
		value = decoded
	}
	return timezone.Normalize(strings.TrimSpace(value))
}

// ServerTimeZone is the host's zone.
func (p *PromptSources) ServerTimeZone() string { return ServerTimeZone() }

// ServerTimeZone is the host's IANA zone, UTC when unknown.
func ServerTimeZone() string {
	if tz := strings.TrimSpace(os.Getenv("TZ")); tz != "" {
		if zone, ok := timezone.Normalize(strings.TrimPrefix(tz, ":")); ok {
			return zone
		}
	}
	if target, err := filepath.EvalSymlinks("/etc/localtime"); err == nil {
		if i := strings.Index(target, "zoneinfo/"); i >= 0 {
			if zone, ok := timezone.Normalize(target[i+len("zoneinfo/"):]); ok {
				return zone
			}
		}
	}
	return "UTC"
}

// RuntimeDetails describes the host.
func (p *PromptSources) RuntimeDetails() string {
	cwd, _ := os.Getwd()
	shell := os.Getenv("SHELL")
	if shell == "" {
		shell = "/bin/bash"
	}
	name := osDescription()
	if release := osRelease(); release != "" {
		name += " " + release
	}
	return ai.FormatRuntimeDetails(runtime.GOOS, name, archName(), shell, cwd)
}

var (
	osReleaseOnce  sync.Once
	osReleaseValue string
)

// osRelease is the kernel release, as Node's os.release() reports it.
func osRelease() string {
	osReleaseOnce.Do(func() {
		if runtime.GOOS == "windows" {
			return
		}
		out, err := exec.Command("uname", "-r").Output()
		if err == nil {
			osReleaseValue = strings.TrimSpace(string(out))
		}
	})
	return osReleaseValue
}

func osDescription() string {
	switch runtime.GOOS {
	case "darwin":
		return "Darwin"
	case "linux":
		return "Linux"
	case "windows":
		return "Windows_NT"
	}
	return runtime.GOOS
}

func archName() string {
	switch runtime.GOARCH {
	case "amd64":
		return "x64"
	case "386":
		return "ia32"
	}
	return runtime.GOARCH
}
