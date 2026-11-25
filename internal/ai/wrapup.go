package ai

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/NeoLabs-Systems/neolabs-go/llm"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/textx"
)

const (
	wrapUpHistoryMessages = 24
	wrapUpAttempts        = 2
	flattenedWorkChars    = 24000
)

func sameContent(a, b any) bool {
	x, _ := json.Marshal(a)
	y, _ := json.Marshal(b)
	return string(x) == string(y)
}

// SelectWrapUpHistory is the conversation a wrap-up turn is written from: the
// leading system messages, the run's own request, and the most recent messages.
// A long tool run pushes the request out of the recent window, and without it
// the model reads its own instructions as what the user asked.
func SelectWrapUpHistory(messages []llm.Message, requestTurn *llm.Message) []llm.Message {
	leading := 0
	for leading < len(messages) && messages[leading].Role == "system" {
		leading++
	}
	recent := messages[leading:]
	if len(recent) > wrapUpHistoryMessages {
		recent = recent[len(recent)-wrapUpHistoryMessages:]
	}
	shown := requestTurn == nil
	for _, m := range recent {
		shown = shown || requestTurn != nil && m.Role == requestTurn.Role && sameContent(m.Content, requestTurn.Content)
	}
	out := append([]llm.Message{}, messages[:leading]...)
	if !shown {
		out = append(out, *requestTurn)
	}
	return append(out, recent...)
}

func flattenToolTurns(history []llm.Message, requestTurn *llm.Message) []llm.Message {
	leading := 0
	for leading < len(history) && history[leading].Role == "system" {
		leading++
	}
	work := SerializeForSummary(history[leading:])
	if n := textx.Len(work); n > flattenedWorkChars {
		work = textx.Slice(work, n-flattenedWorkChars, n)
	}
	out := append([]llm.Message{}, history[:leading]...)
	if requestTurn != nil {
		out = append(out, *requestTurn)
	}
	return append(out, llm.Message{Role: "system", Content: "What this run did so far, oldest first:\n" + work})
}

// WriteWrapUp is the last turn of a run a runaway guard ended. The model writes
// it from the conversation, in its own voice: what it got done, what is missing,
// and why. When it returns nothing the run fails visibly rather than sending the
// user text nobody wrote.
//
// A model can answer this turn with another tool call, even with no tools on
// offer, because the transcript it sees is full of them; the second attempt
// tells the same story as plain text, so there is nothing to continue.
func WriteWrapUp(ctx context.Context, s *Session, reason string, requestTurn *llm.Message, formatting Formatting) (string, error) {
	s.Env.Controls.OpenSteeringIntake(false)
	s.Env.Controls.ApplySteering(s)
	history := SelectWrapUpHistory(s.Messages, requestTurn)
	for attempt := 0; attempt < wrapUpAttempts; attempt++ {
		transcript := history
		if attempt > 0 {
			transcript = flattenToolTurns(history, requestTurn)
		}
		messages := SanitizeConversationMessages(append(append([]llm.Message{}, transcript...),
			llm.Message{Role: "system", Content: BuildWrapUpPrompt(reason, s.Options.Platform, formatting)}))
		result, err := s.Model.Provider.Chat(ctx, messages, nil, llm.Options{Model: s.Model.Model, MaxTokens: s.Options.MaxTokens, ReasoningEffort: s.Options.ReasoningEffort})
		if err != nil {
			if ctx.Err() != nil {
				return "", err
			}
			continue
		}
		s.TotalTokens += usageTokens(result.Usage)
		text := SanitizeModelOutput(textx.Trim(result.Content), s.Env.Sanitize)
		if !IsRawToolCall(text) && normalizeOutgoingDefault(text, true) != "" {
			return text, nil
		}
	}
	return "", fmt.Errorf("Run stopped (%s) and the model could not write a reply", reason)
}
