package agent

import (
	"context"
	"database/sql"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/behavior"
	"github.com/NeoLabs-Systems/neoagent/internal/memory"
	"github.com/NeoLabs-Systems/neoagent/internal/memory/jsx"
)

const maxVoiceMemoryLines = 32

// VoicePersonaSections is the persona for a live voice call, where the live
// model talks and runs do the work: the same persona, the owner's additions,
// and what it knows about the owner (buildVoicePersonaSections).
func (p *PromptSources) VoicePersonaSections(ctx context.Context, userID int64, agentID, query string) ([]string, error) {
	sections := []string{PersonaPrompt(p.ownerName(ctx, userID), true)}
	var additions []string
	if agentID != "" {
		var instructions sql.NullString
		if p.DB.R.QueryRowContext(ctx, `SELECT instructions FROM agents WHERE user_id = ? AND id = ?`, userID, agentID).Scan(&instructions) == nil && instructions.String != "" {
			additions = append(additions, behavior.Truncate(instructions.String, 1600))
		}
	}
	if p.Memory != nil {
		notes := p.ownerStyleNotes(ctx, userID, agentID)
		if len(notes) > 8 {
			notes = notes[:8]
		}
		additions = append(additions, notes...)
	}
	if len(additions) > 0 {
		sections = append(sections, strings.Join(append([]string{"## from the owner (adds to how you talk; it doesn't replace it)"}, additions...), "\n"))
	}
	facts, err := p.voiceMemoryFacts(ctx, userID, agentID, query)
	if err != nil {
		return nil, err
	}
	if len(facts) > 0 {
		lines := []string{"## what you know about them"}
		for _, fact := range facts {
			lines = append(lines, "- "+fact)
		}
		sections = append(sections, strings.Join(lines, "\n"))
	}
	return sections, nil
}

// ownerStyleNotes are the style notes for the owner's own audience.
func (p *PromptSources) ownerStyleNotes(ctx context.Context, userID int64, agentID string) []string {
	behaviorNotes, _ := p.Memory.AssistantBehaviorNotes(ctx, userID, agentID)
	self, _ := p.Memory.AssistantSelfState(ctx, userID, agentID)
	var personality any
	if core, err := p.Memory.CoreMemory(ctx, userID, agentID); err == nil && core != nil {
		personality = core.Value("ai_personality")
	}
	return collectStyleNotes(self.Identity, personality, behaviorNotes)
}

func factText(v any) string {
	switch x := v.(type) {
	case string:
		return x
	case *jsx.Obj, []any, map[string]any, nil:
		return jsx.Marshal(x)
	}
	return jsx.Marshal(v)
}

// voiceMemoryFacts is what a friend would know: core facts, the maintained
// profile, and the memories that relate to what was just said.
func (p *PromptSources) voiceMemoryFacts(ctx context.Context, userID int64, agentID, query string) ([]string, error) {
	if p.Memory == nil {
		return nil, nil
	}
	var lines []string
	add := func(text string) {
		line := behavior.Truncate(text, 240)
		if line != "" && !contains(lines, line) {
			lines = append(lines, line)
		}
	}
	if core, err := p.Memory.CoreMemory(ctx, userID, agentID); err == nil && core != nil {
		for _, key := range core.Keys() {
			// active_context is run state, and ai_personality arrives as a style note.
			if key == "active_context" || key == "ai_personality" {
				continue
			}
			add(key + ": " + factText(core.Value(key)))
		}
	}
	if profile, err := p.Memory.UserProfile(ctx, userID, agentID, 12); err == nil {
		for _, fact := range append(append([]string{}, profile.Static...), profile.Dynamic...) {
			add(fact)
		}
	}
	if strings.TrimSpace(query) != "" {
		recalled, err := p.Memory.RecallMemory(ctx, userID, query, 5, memory.RecallOptions{AgentID: agentID})
		if err != nil && ctx.Err() != nil {
			return nil, ctx.Err()
		}
		for _, m := range recalled {
			add(m.Content)
		}
	}
	if len(lines) > maxVoiceMemoryLines {
		lines = lines[:maxVoiceMemoryLines]
	}
	return lines, nil
}

// LocalNow is the owner's current local time as a voice prompt shows it
// ("Thu 5 Mar, 08:04").
func (p *PromptSources) LocalNow(ctx context.Context, userID int64, now time.Time) string {
	zone, ok := p.UserTimeZone(ctx, userID)
	if !ok {
		zone = ServerTimeZone()
	}
	loc, err := time.LoadLocation(zone)
	if err != nil {
		loc = time.UTC
	}
	return now.In(loc).Format("Mon 2 Jan, 15:04")
}
