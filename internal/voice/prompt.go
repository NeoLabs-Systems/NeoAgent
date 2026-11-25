package voice

import (
	"context"
	"fmt"
	"math"
	"strings"
	"unicode/utf16"

	"github.com/NeoLabs-Systems/neolabs-go/livevoice"
)

const (
	historyMessages       = 24
	maxHistoryMessageChar = 700
	// devicePlatformStickC is the wearable whose small screen shows the answer.
	devicePlatformStickC = "m5stickc-plus2"
)

// clampText cuts text to max UTF-16 units, as the prompts always did.
func clampText(text string, max int) string {
	value := livevoice.TrimJS(text)
	units := utf16.Encode([]rune(value))
	if len(units) > max {
		return string(utf16.Decode(units[:max])) + "…"
	}
	return value
}

// callRules lead the prompt, because the persona's casual register otherwise
// wins over them. Gemini Live calls the task tools itself; GPT-Live can only
// hand off, and the run it starts sees the owner's running tasks.
func callRules(render Renderer, taskTools bool) string {
	tools := "voice/handoff_tools.md"
	if taskTools {
		tools = "voice/task_tools.md"
	}
	return render("voice/call_rules.md", nil) + "\n" + render(tools, nil)
}

// recentSpokenHistory is the thread a call continues: user and assistant text
// turns, without tool calls.
func recentSpokenHistory(persona Persona, conversationID string) (summary string, messages []livevoice.Message, err error) {
	if conversationID == "" {
		return "", nil, nil
	}
	ctx, err := persona.RecentContext(conversationID, historyMessages)
	if err != nil {
		return "", nil, err
	}
	for _, m := range ctx.Messages {
		if (m.Role == "user" || m.Role == "assistant") && livevoice.TrimJS(m.Content) != "" && !m.HasToolCalls {
			messages = append(messages, livevoice.Message{Role: m.Role, Text: clampText(m.Content, maxHistoryMessageChar)})
		}
	}
	return livevoice.TrimJS(ctx.Summary), messages, nil
}

// describeRunningTasks lists the tasks running as the call connected.
func describeRunningTasks(tasks []map[string]any) string {
	if len(tasks) == 0 {
		return ""
	}
	lines := []string{"## tasks running as the call connected"}
	for _, task := range tasks {
		seconds, _ := task["running_for_seconds"].(int)
		minutes := int(math.Floor(float64(seconds)/60 + 0.5))
		lines = append(lines, fmt.Sprintf("- task %v (started in %v, running for %d min): %s",
			task["task_id"], task["started_in"], minutes, clampText(fmt.Sprint(task["request"]), 300)))
	}
	return strings.Join(lines, "\n")
}

// promptInputs is what a call's opening prompt is built from.
type promptInputs struct {
	userID         int64
	agentID        string
	conversationID string
	runningTasks   []map[string]any
	taskTools      bool
	devicePlatform string
}

// buildLivePrompt: the live model speaks with the same persona the agent runs
// write with, plus owner instructions, style notes and memory about the owner.
// Delegated runs keep the normal agent prompt and do the work.
func buildLivePrompt(ctx context.Context, persona Persona, render Renderer, in promptInputs) (livevoice.Prompt, error) {
	sections, err := persona.Sections(ctx, in.userID, in.agentID)
	if err != nil {
		return livevoice.Prompt{}, err
	}
	summary, history, err := recentSpokenHistory(persona, in.conversationID)
	if err != nil {
		return livevoice.Prompt{}, err
	}
	small := ""
	if in.devicePlatform == devicePlatformStickC {
		small = "The answer is displayed on a very small wearable screen. Keep every response extra short, using only the essential words."
	}
	earlier := ""
	if summary != "" {
		earlier = "## earlier in this conversation (summary)\n" + summary
	}
	parts := []string{callRules(render, in.taskTools), small}
	parts = append(parts, sections...)
	parts = append(parts, "now: "+persona.LocalNow(in.userID), describeRunningTasks(in.runningTasks), earlier)
	var kept []string
	for _, p := range parts {
		if p != "" {
			kept = append(kept, p)
		}
	}
	return livevoice.Prompt{Instructions: strings.Join(kept, "\n\n"), History: history}, nil
}

func utf16Units(s string) []uint16  { return utf16.Encode([]rune(s)) }
func utf16Decode(u []uint16) []rune { return utf16.Decode(u) }
