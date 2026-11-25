package ai

import (
	"github.com/NeoLabs-Systems/neolabs-go/llm"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/textx"
)

// Every turn resends every earlier tool result, which is where a long run's
// tokens go: the model has acted on a result from twenty turns ago and rarely
// needs all of it again. Older results shrink in batches, so the prefix a
// provider caches stays the same between batches. The model can always make the
// call again.
const (
	agingKeepRecent = 8
	agingBatch      = 6
	agingKeptChars  = 400
)

// ResultAger shortens old tool results of one run.
type ResultAger struct{ aged map[int]bool }

// Age shortens the oldest batch of long tool results once enough have piled up
// and reports whether it did. The answers these calls gave are no longer in
// view, so the caller tells the repetition guard that asking again is not a
// repeat.
func (a *ResultAger) Age(messages []llm.Message) bool {
	if a.aged == nil {
		a.aged = map[int]bool{}
	}
	var results []int
	for i, m := range messages {
		if m.Role == "tool" && !a.aged[i] && textx.Len(dyn.Str(m.Content)) > agingKeptChars {
			results = append(results, i)
		}
	}
	if len(results) < agingKeepRecent+agingBatch {
		return false
	}
	for _, i := range results[:agingBatch] {
		messages[i].Content = textx.Head(dyn.Str(messages[i].Content), agingKeptChars) +
			"\n[older result shortened to save context; make the call again if you need the rest]"
		a.aged[i] = true
	}
	return true
}

// Reset forgets which results were shortened; use it when the transcript is rebuilt.
func (a *ResultAger) Reset() { a.aged = nil }
