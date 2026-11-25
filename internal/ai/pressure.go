package ai

import (
	"context"
	"errors"
	"math"
	"regexp"
	"strings"

	"github.com/NeoLabs-Systems/neolabs-go/llm"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/textx"
)

// Default output reserve and how many times one run may recover from a provider
// that rejected the prompt as too long.
const (
	DefaultMaxOutputTokens = 16384
	MaxOverflowRecoveries  = 2
)

// ContextBudget is how a model's context window is divided.
type ContextBudget struct {
	ContextWindow int
	OutputReserve int
	SafetyReserve int
	InputBudget   int
	TargetTokens  int
}

// ContextBudgetFor splits a model's context window into the room for the
// answer, a safety margin, and what the prompt may use.
func ContextBudgetFor(contextWindow, maxOutputTokens int) ContextBudget {
	if contextWindow <= 0 {
		contextWindow = 128000
	}
	if maxOutputTokens <= 0 {
		maxOutputTokens = DefaultMaxOutputTokens
	}
	safety := max(2048, min(32768, int(math.Ceil(float64(contextWindow)*0.05))))
	output := min(maxOutputTokens, max(1, contextWindow-safety-1))
	input := max(1, contextWindow-output-safety)
	return ContextBudget{
		ContextWindow: contextWindow,
		OutputReserve: output,
		SafetyReserve: safety,
		InputBudget:   input,
		TargetTokens:  max(1, int(math.Floor(float64(input)*0.75))),
	}
}

var contextOverflowMessage = regexp.MustCompile(`maximum context|context length|context window|prompt is too long|too many tokens`)

// IsContextOverflowError recognises a provider's "prompt too long" refusal.
func IsContextOverflowError(err error) bool {
	if err == nil {
		return false
	}
	var providerErr *llm.Error
	code := ""
	if errors.As(err, &providerErr) {
		code = strings.ToLower(providerErr.Code)
	}
	return strings.Contains(code, "context_length") || strings.Contains(code, "context_window") || code == "context_overflow" ||
		contextOverflowMessage.MatchString(strings.ToLower(err.Error()))
}

// PressureEvent is reported while the transcript is being shrunk.
type PressureEvent struct {
	Kind   string // "pressure" or "compacted"
	Fields map[string]any
}

// ContextPressure keeps a run's prompt inside the model's context window by
// summarising old turns.
type ContextPressure struct {
	// Summarize runs the summary request; it is the run's own model.
	Summarize func(ctx context.Context, messages []llm.Message) (string, error)
	OnEvent   func(PressureEvent)

	overflowRecoveries int
}

// PrepareRequest is one fitting attempt.
type PrepareRequest struct {
	ContextWindow   int
	Messages        []llm.Message
	FixedMessages   []llm.Message
	Tools           []llm.Tool
	MaxOutputTokens int
	Force           bool
	Reason          string
}

// PrepareResult is the (possibly shorter) transcript.
type PrepareResult struct {
	Messages     []llm.Message
	Changed      bool
	Irreducible  bool
	Reason       string
	BeforeTokens int
	AfterTokens  int
	Budget       ContextBudget
}

func (p *ContextPressure) emit(kind string, fields map[string]any) {
	if p.OnEvent != nil {
		p.OnEvent(PressureEvent{Kind: kind, Fields: fields})
	}
}

func budgetFields(b ContextBudget) map[string]any {
	return map[string]any{
		"contextWindow": b.ContextWindow, "outputReserve": b.OutputReserve, "safetyReserve": b.SafetyReserve,
		"inputBudget": b.InputBudget, "targetTokens": b.TargetTokens,
	}
}

// Prepare shrinks the transcript when it does not fit (or when forced). A
// transcript that cannot be cut safely comes back unchanged and marked
// irreducible.
func (p *ContextPressure) Prepare(ctx context.Context, req PrepareRequest) (PrepareResult, error) {
	reason := req.Reason
	if reason == "" {
		reason = "threshold"
	}
	budget := ContextBudgetFor(req.ContextWindow, req.MaxOutputTokens)
	before := EstimateTokenCount(append(append([]llm.Message{}, req.Messages...), req.FixedMessages...), req.Tools)
	if !req.Force && before <= budget.InputBudget {
		return PrepareResult{Messages: req.Messages, BeforeTokens: before, AfterTokens: before, Budget: budget}, nil
	}
	pressure := budgetFields(budget)
	pressure["reason"], pressure["forced"], pressure["estimated_tokens"] = reason, req.Force, before
	p.emit("pressure", pressure)

	cut := SelectTurnSafeCut(CutRequest{Messages: req.Messages, FixedMessages: req.FixedMessages, Tools: req.Tools, TargetTokens: budget.TargetTokens})
	if !cut.Compactable {
		return PrepareResult{Messages: req.Messages, Irreducible: true, Reason: cut.Reason, BeforeTokens: before, AfterTokens: before, Budget: budget}, nil
	}
	if p.Summarize == nil {
		return PrepareResult{}, errors.New("Context compaction requires a summarizer.")
	}

	summaryBudget := ContextBudgetFor(req.ContextWindow, 1600)
	source := SerializeForSummary(cut.Compacted)
	summary := cut.PreviousSummary
	offset := 0
	sourceLen := textx.Len(source)
	for offset < sourceLen {
		var summaryTokens int
		if summary != "" {
			summaryTokens = EstimateTokenCount([]llm.Message{{Role: "user", Content: summary}}, nil)
		}
		chunk := max(1000, int(math.Floor(float64(max(250, summaryBudget.TargetTokens-summaryTokens-350))*4)))
		var summaryMessages []llm.Message
		for {
			summaryMessages = BuildSummaryMessages(summary, textx.Slice(source, offset, offset+chunk))
			if EstimateTokenCount(summaryMessages, nil) <= summaryBudget.InputBudget {
				break
			}
			chunk = int(math.Floor(float64(chunk) * 0.75))
			if chunk < 1000 {
				break
			}
		}
		if EstimateTokenCount(summaryMessages, nil) > summaryBudget.InputBudget {
			return PrepareResult{}, errors.New("A historical compaction chunk cannot fit the summarizer context.")
		}
		next, err := p.Summarize(ctx, summaryMessages)
		if err != nil {
			return PrepareResult{}, err
		}
		summary = next
		offset += chunk
	}
	compacted := ApplyCompaction(cut, summary)
	after := EstimateTokenCount(append(append([]llm.Message{}, compacted...), req.FixedMessages...), req.Tools)
	done := budgetFields(budget)
	done["reason"], done["forced"], done["before_tokens"], done["after_tokens"] = reason, req.Force, before, after
	done["compacted_messages"], done["split_turn"] = len(cut.Compacted), cut.SplitTurn
	p.emit("compacted", done)
	return PrepareResult{Messages: compacted, Changed: true, BeforeTokens: before, AfterTokens: after, Budget: budget}, nil
}

// ClaimOverflowRecovery grants one of the run's limited recoveries from a
// provider's context-overflow refusal.
func (p *ContextPressure) ClaimOverflowRecovery() bool {
	if p.overflowRecoveries >= MaxOverflowRecoveries {
		return false
	}
	p.overflowRecoveries++
	return true
}

// OverflowRecoveries is how many recoveries the run has used.
func (p *ContextPressure) OverflowRecoveries() int { return p.overflowRecoveries }
