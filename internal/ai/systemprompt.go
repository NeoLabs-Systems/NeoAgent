package ai

import (
	"context"
	_ "embed"
	"encoding/json"
	"fmt"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/prompts"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/textx"
)

//go:embed zonenames.json
var zoneNamesJSON []byte

type zoneName struct {
	Name   string `json:"name"`
	Offset int    `json:"offset"`
}

var (
	zoneNamesOnce sync.Once
	zoneNames     map[string]struct{ Jan, Jul zoneName }
)

func loadZoneNames() {
	var raw map[string]struct {
		Jan zoneName `json:"jan"`
		Jul zoneName `json:"jul"`
	}
	if err := json.Unmarshal(zoneNamesJSON, &raw); err != nil {
		panic(fmt.Sprintf("ai: zonenames.json: %v", err))
	}
	zoneNames = make(map[string]struct{ Jan, Jul zoneName }, len(raw))
	for zone, v := range raw {
		zoneNames[zone] = struct{ Jan, Jul zoneName }{v.Jan, v.Jul}
	}
}

var fixedOffsetZone = regexp.MustCompile(`^([+-])(\d{2}):(\d{2})$`)

// locationFor resolves a canonical zone name as the timezone package returns it
// (an IANA name, or a fixed offset such as "+05:30").
func locationFor(zone string) (*time.Location, error) {
	if m := fixedOffsetZone.FindStringSubmatch(zone); m != nil {
		hours, _ := strconv.Atoi(m[2])
		minutes, _ := strconv.Atoi(m[3])
		seconds := (hours*60 + minutes) * 60
		if m[1] == "-" {
			seconds = -seconds
		}
		return time.FixedZone(zone, seconds), nil
	}
	return time.LoadLocation(zone)
}

// FormatUTCOffset is "+HH:MM" for an offset in minutes.
func FormatUTCOffset(minutes int) string {
	sign := "+"
	if minutes < 0 {
		sign = "-"
		minutes = -minutes
	}
	return fmt.Sprintf("%s%02d:%02d", sign, minutes/60, minutes%60)
}

// longZoneName is the long name of a zone at an instant, as ICU gives it in
// English ("Central European Summer Time"). It chooses between the zone's
// winter and summer name by the offset in force.
func longZoneName(zone string, offsetMinutes int) string {
	zoneNamesOnce.Do(loadZoneNames)
	if names, ok := zoneNames[zone]; ok {
		if names.Jan.Offset == offsetMinutes || names.Jul.Offset != offsetMinutes {
			return names.Jan.Name
		}
		return names.Jul.Name
	}
	if offsetMinutes == 0 {
		return "Greenwich Mean Time"
	}
	return "GMT" + FormatUTCOffset(offsetMinutes)
}

// FormatCurrentLocalDateTime renders an instant in a zone for the prompt:
// "Tuesday 2026-05-05T12:00:00 (Europe/Berlin, Central European Summer Time, UTC+02:00)".
func FormatCurrentLocalDateTime(zone string, now time.Time) (string, error) {
	loc, err := locationFor(zone)
	if err != nil {
		return "", err
	}
	local := now.In(loc)
	_, offsetSeconds := local.Zone()
	offset := offsetSeconds / 60
	return fmt.Sprintf("%s %s (%s, %s, UTC%s)", local.Weekday(), local.Format("2006-01-02T15:04:05"), zone, longZoneName(zone, offset), FormatUTCOffset(offset)), nil
}

// PromptContext is what a system prompt is built for.
type PromptContext struct {
	AgentID        string
	TriggerSource  string
	MemoryAudience string
	Source         string
	ChatID         string
	LatencyProfile string
	DeviceTarget   string
	WorkspaceRoot  string
	// AdditionalContext is appended (clamped) to the dynamic part.
	AdditionalContext string
	// IncludeRuntimeDetails adds host details; public audiences never get them.
	IncludeRuntimeDetails bool
	// PublicAudience: a public thread gets neither the owner's timezone nor host details.
	PublicAudience bool
}

// BehaviorPrompt is the agent's own instructions, split into the cacheable and
// the changing part.
type BehaviorPrompt struct{ Stable, Dynamic []string }

// PromptSources are the domains the prompt draws on.
type PromptSources interface {
	// Behavior is the agent's behaviour prompt.
	Behavior(ctx context.Context, userID int64, c PromptContext) (BehaviorPrompt, error)
	// MemoryContext is the memory excerpt shown to the model.
	MemoryContext(ctx context.Context, userID int64, agentID, audience string) (string, error)
	// UserTimeZone is the account's canonical time zone; ok is false when unset.
	UserTimeZone(ctx context.Context, userID int64) (zone string, ok bool)
	// ServerTimeZone is the host's zone, used when the account has none.
	ServerTimeZone() string
	// RuntimeDetails describes the host (platform, os, arch, shell, cwd).
	RuntimeDetails() string
}

// PromptSections is a prompt split at the cache boundary: Stable first, so a
// change in what follows cannot invalidate the provider's prompt cache.
type PromptSections struct {
	Stable        string
	Dynamic       string
	PromptVersion prompts.Version
}

const (
	promptCacheTTL = 30 * time.Second
	promptCacheMax = 500
)

type cachedSections struct {
	sections  PromptSections
	expiresAt time.Time
}

// SystemPrompts builds and caches system prompts.
type SystemPrompts struct {
	Sources PromptSources
	Now     func() time.Time

	mu    sync.Mutex
	cache map[string]cachedSections
	order []string
}

func (p *SystemPrompts) now() time.Time {
	if p.Now != nil {
		return p.Now()
	}
	return time.Now()
}

func userKey(userID int64) string {
	if userID == 0 {
		return "global"
	}
	return strconv.FormatInt(userID, 10)
}

func promptKeyPart(value, fallback string) string {
	if value == "" {
		return fallback
	}
	return value
}

// Invalidate drops the cached prompts of a user (and agent).
func (p *SystemPrompts) Invalidate(userID int64, agentID string) {
	prefix := userKey(userID) + ":" + promptKeyPart(agentID, "main") + ":"
	p.mu.Lock()
	defer p.mu.Unlock()
	for key := range p.cache {
		if strings.HasPrefix(key, prefix) {
			delete(p.cache, key)
		}
	}
	p.order = filterOrder(p.order, p.cache)
}

func filterOrder(order []string, cache map[string]cachedSections) []string {
	kept := order[:0]
	for _, key := range order {
		if _, ok := cache[key]; ok {
			kept = append(kept, key)
		}
	}
	return kept
}

func (p *SystemPrompts) store(key string, sections PromptSections, now time.Time) {
	p.mu.Lock()
	defer p.mu.Unlock()
	if p.cache == nil {
		p.cache = map[string]cachedSections{}
	}
	for k, entry := range p.cache {
		if !now.Before(entry.expiresAt) {
			delete(p.cache, k)
		}
	}
	p.order = filterOrder(p.order, p.cache)
	if _, ok := p.cache[key]; !ok {
		p.order = append(p.order, key)
	}
	p.cache[key] = cachedSections{sections: sections, expiresAt: now.Add(promptCacheTTL)}
	for len(p.cache) > promptCacheMax && len(p.order) > 0 {
		delete(p.cache, p.order[0])
		p.order = p.order[1:]
	}
}

func clampSection(text string, maxChars int) string {
	str := textx.Trim(text)
	if str == "" {
		return ""
	}
	if textx.Len(str) <= maxChars {
		return str
	}
	return textx.Head(str, maxChars) + "\n...[trimmed]"
}

func nonEmpty(parts []string) []string {
	var out []string
	for _, part := range parts {
		if part != "" {
			out = append(out, part)
		}
	}
	return out
}

// Sections builds the prompt for a user: the stable head (prompt fragments and
// the behaviour prompt) and the dynamic tail (current time, behaviour, memory,
// extra context).
func (p *SystemPrompts) Sections(ctx context.Context, userID int64, c PromptContext) (PromptSections, error) {
	triggerSource := promptKeyPart(c.TriggerSource, "web")
	key := strings.Join([]string{
		userKey(userID), promptKeyPart(c.AgentID, "main"), triggerSource,
		promptKeyPart(c.MemoryAudience, "owner"), promptKeyPart(c.Source, "none"), promptKeyPart(c.ChatID, "none"),
		promptKeyPart(c.LatencyProfile, "default"), promptKeyPart(c.DeviceTarget, "none"), promptKeyPart(c.WorkspaceRoot, "default"),
	}, ":")
	now := p.now()
	extra := c.AdditionalContext != "" || c.IncludeRuntimeDetails
	if !extra {
		p.mu.Lock()
		cached, ok := p.cache[key]
		p.mu.Unlock()
		if ok && now.Before(cached.expiresAt) {
			return cached.sections, nil
		}
	}

	behaviorCtx := c
	behaviorCtx.TriggerSource = triggerSource
	behavior, err := p.Sources.Behavior(ctx, userID, behaviorCtx)
	if err != nil {
		return PromptSections{}, err
	}
	fragments := prompts.SelectStable(prompts.Context{TriggerSource: triggerSource})
	stable := make([]string, 0, len(fragments)+len(behavior.Stable))
	for _, f := range fragments {
		stable = append(stable, f.Text)
	}
	stable = append(stable, behavior.Stable...)

	var timeLine string
	userZone, hasZone := "", false
	if !c.PublicAudience {
		userZone, hasZone = p.Sources.UserTimeZone(ctx, userID)
	}
	if hasZone {
		local, err := FormatCurrentLocalDateTime(userZone, now)
		if err != nil {
			return PromptSections{}, err
		}
		timeLine = fmt.Sprintf("Current time in the user's timezone: %s. Times the user mentions are in this timezone unless they say otherwise.", local)
	} else {
		serverZone := p.Sources.ServerTimeZone()
		if serverZone == "" {
			serverZone = "UTC"
		}
		local, err := FormatCurrentLocalDateTime(serverZone, now)
		if err != nil {
			return PromptSections{}, err
		}
		timeLine = fmt.Sprintf("Current server clock: %s. Use it for date arithmetic only; it does not establish the user's location or timezone.", local)
	}
	dynamic := append([]string{timeLine}, behavior.Dynamic...)
	if !c.PublicAudience && (c.IncludeRuntimeDetails || c.AdditionalContext != "") {
		dynamic = append(dynamic, "Runtime details:\n"+p.Sources.RuntimeDetails())
	}
	memory, err := p.Sources.MemoryContext(ctx, userID, c.AgentID, promptKeyPart(c.MemoryAudience, "owner"))
	if err != nil {
		return PromptSections{}, err
	}
	if compact := clampSection(memory, 1600); compact != "" {
		dynamic = append(dynamic, compact)
	}
	if c.AdditionalContext != "" {
		dynamic = append(dynamic, "Additional context:\n"+clampSection(c.AdditionalContext, 1800))
	}

	sections := PromptSections{
		Stable:        strings.Join(nonEmpty(stable), "\n\n"),
		Dynamic:       strings.Join(nonEmpty(dynamic), "\n\n"),
		PromptVersion: prompts.VersionOf(fragments),
	}
	if !extra {
		p.store(key, sections, now)
	}
	return sections, nil
}

// Build is the whole prompt: stable part, then dynamic part.
func (p *SystemPrompts) Build(ctx context.Context, userID int64, c PromptContext) (string, error) {
	sections, err := p.Sections(ctx, userID, c)
	if err != nil {
		return "", err
	}
	return strings.Join(nonEmpty([]string{sections.Stable, sections.Dynamic}), "\n\n"), nil
}

// FormatRuntimeDetails is the host description shown to the model.
func FormatRuntimeDetails(platform, osName, arch, shell, cwd string) string {
	if shell == "" {
		shell = "/bin/bash"
	}
	return strings.Join([]string{"platform=" + platform, "os=" + osName, "arch=" + arch, "shell=" + shell, "cwd=" + cwd}, "\n")
}
