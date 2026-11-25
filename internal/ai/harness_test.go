package ai

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"reflect"
	"strings"
	"testing"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/llm"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
)

// norm round-trips a value through JSON so Go structs and decoded Node output
// compare as the plain documents they are.
func norm(t *testing.T, v any) any {
	t.Helper()
	raw, err := json.Marshal(v)
	if err != nil {
		t.Fatal(err)
	}
	var out any
	if err := json.Unmarshal(raw, &out); err != nil {
		t.Fatal(err)
	}
	return out
}

func same(t *testing.T, name string, got, want any) {
	t.Helper()
	g, w := norm(t, got), norm(t, want)
	if !reflect.DeepEqual(g, w) {
		gj, _ := json.Marshal(g)
		wj, _ := json.Marshal(w)
		t.Errorf("%s differs:\n got  %.700s\n want %.700s", name, gj, wj)
	}
}

type harnessVectors struct {
	Hashes []struct {
		Value any    `json:"value"`
		Hash  string `json:"hash"`
	} `json:"hashes"`
	Intents []struct {
		Command string  `json:"command"`
		Intent  dyn.Map `json:"intent"`
	} `json:"intents"`
	Guard [][]struct {
		Op       string  `json:"op"`
		Tool     string  `json:"tool"`
		Args     dyn.Map `json:"args"`
		Scope    *string `json:"scope"`
		Ms       int     `json:"ms"`
		Result   any     `json:"result"`
		Failure  string  `json:"failure"`
		ReadOnly bool    `json:"readOnly"`
		Out      any     `json:"out"`
	} `json:"guard"`
	Salvage []struct {
		Text    string   `json:"text"`
		Tools   []string `json:"tools"`
		Content string   `json:"content"`
		Calls   []struct {
			Name      string `json:"name"`
			Arguments string `json:"arguments"`
			IDPrefix  string `json:"idPrefix"`
			Type      string `json:"type"`
		} `json:"calls"`
	} `json:"salvage"`
	Streaming []struct {
		Text    string `json:"text"`
		Visible string `json:"visible"`
	} `json:"streaming"`
	Sanitize []struct {
		Text  string `json:"text"`
		Model string `json:"model"`
		Out   string `json:"out"`
	} `json:"sanitize"`
	SanitizeConfigured []struct {
		Text  string `json:"text"`
		Model string `json:"model"`
		Out   string `json:"out"`
	} `json:"sanitizeConfigured"`
	Raw []struct {
		Text string `json:"text"`
		Raw  bool   `json:"raw"`
		May  bool   `json:"may"`
	} `json:"raw"`
	Compaction []struct {
		Name         string        `json:"name"`
		TargetTokens int           `json:"targetTokens"`
		Messages     []llm.Message `json:"messages"`
		CutRaw       struct {
			Compactable     bool          `json:"compactable"`
			SplitTurn       bool          `json:"splitTurn"`
			Reason          string        `json:"reason"`
			PreviousSummary string        `json:"previousSummary"`
			ProjectedTokens int           `json:"projectedTokens"`
			Leading         []llm.Message `json:"leading"`
			Compacted       []llm.Message `json:"compacted"`
			Retained        []llm.Message `json:"retained"`
		} `json:"cutRaw"`
		Applied []llm.Message `json:"applied"`
	} `json:"compaction"`
	Estimates []struct {
		Name       string `json:"name"`
		Tokens     int    `json:"tokens"`
		PerMessage []int  `json:"perMessage"`
	} `json:"estimates"`
	Serialized []struct {
		Name string `json:"name"`
		Text string `json:"text"`
	} `json:"serialized"`
	SummaryMessages []struct {
		PreviousSummary string        `json:"previousSummary"`
		Source          string        `json:"source"`
		Messages        []llm.Message `json:"messages"`
	} `json:"summaryMessages"`
	Budgets []struct {
		Window int           `json:"window"`
		MaxOut int           `json:"maxOut"`
		Budget ContextBudget `json:"budget"`
	} `json:"budgets"`
	Overflow []struct {
		Error struct {
			Code    string `json:"code"`
			Type    string `json:"type"`
			Message string `json:"message"`
		} `json:"error"`
		Result bool `json:"result"`
	} `json:"overflow"`
	Pressure []struct {
		Name   string `json:"name"`
		Window int    `json:"window"`
		Force  bool   `json:"force"`
		Error  string `json:"error"`
		Events []struct {
			Kind string         `json:"kind"`
			Data map[string]any `json:"data"`
		} `json:"events"`
		SummaryCalls int `json:"summaryCalls"`
		Result       *struct {
			Messages     json.RawMessage `json:"messages"`
			Changed      bool            `json:"changed"`
			Irreducible  bool            `json:"irreducible"`
			Reason       string          `json:"reason"`
			BeforeTokens int             `json:"beforeTokens"`
			AfterTokens  int             `json:"afterTokens"`
			Budget       ContextBudget   `json:"budget"`
		} `json:"result"`
	} `json:"pressure"`
	Recoveries []any `json:"recoveries"`
	LoopPolicy []struct {
		Settings dyn.Map `json:"settings"`
		Options  dyn.Map `json:"options"`
		Policy   struct {
			MaxIterations    int `json:"maxIterations"`
			MaxIdleTurns     int `json:"maxIdleTurns"`
			MaxFailedTurns   int `json:"maxFailedTurns"`
			ToolResultBudget struct {
				Default int `json:"default"`
				File    int `json:"file"`
				Browser int `json:"browser"`
				Command int `json:"command"`
			} `json:"toolResultBudget"`
			HardLimitMultiplier int `json:"hardLimitMultiplier"`
			AbsoluteHardLimit   int `json:"absoluteHardLimit"`
		} `json:"policy"`
		Limits []struct {
			Tool      string `json:"tool"`
			SoftLimit int    `json:"softLimit"`
			HardLimit int    `json:"hardLimit"`
		} `json:"limits"`
	} `json:"loopPolicy"`
	Interim struct {
		Kinds []struct {
			Value any    `json:"value"`
			Kind  string `json:"kind"`
		} `json:"kinds"`
		Metadata []struct {
			Kind         *string `json:"kind"`
			ExpectsReply *bool   `json:"expectsReply"`
			Out          any     `json:"out"`
		} `json:"metadata"`
		Parsed []struct {
			Value any `json:"value"`
			Out   struct {
				Interim      bool   `json:"interim"`
				Kind         string `json:"kind"`
				ExpectsReply bool   `json:"expectsReply"`
			} `json:"out"`
			Is bool `json:"is"`
		} `json:"parsed"`
		Signatures []struct {
			Content      *string `json:"content"`
			Kind         *string `json:"kind"`
			ExpectsReply *bool   `json:"expectsReply"`
			Platform     *string `json:"platform"`
			Out          string  `json:"out"`
		} `json:"signatures"`
	} `json:"interim"`
	Evidence []struct {
		Tool      string  `json:"tool"`
		Args      dyn.Map `json:"args"`
		Result    any     `json:"result"`
		Error     string  `json:"error"`
		Execution struct {
			ToolName         string `json:"toolName"`
			OK               bool   `json:"ok"`
			Error            string `json:"error"`
			EvidenceSource   string `json:"evidenceSource"`
			EvidenceRelevant bool   `json:"evidenceRelevant"`
			StateChanged     bool   `json:"stateChanged"`
			Summary          string `json:"summary"`
		} `json:"execution"`
		Inferred    string `json:"inferred"`
		Substantive bool   `json:"substantive"`
	} `json:"evidence"`
	EvidenceSummary struct {
		All      string `json:"all"`
		Gathered []bool `json:"gathered"`
	} `json:"evidenceSummary"`
	SanitizeHistory []struct {
		Messages []llm.Message `json:"messages"`
		Out      []llm.Message `json:"out"`
	} `json:"sanitizeHistory"`
	StoredUser []struct {
		Input struct {
			UserMessage    string `json:"userMessage"`
			RawUserMessage string `json:"rawUserMessage"`
			Platform       string `json:"platform"`
			Speaker        string `json:"speaker"`
			IsGroup        bool   `json:"isGroup"`
		} `json:"input"`
		Out string `json:"out"`
	} `json:"storedUser"`
	SummaryCarrier []struct {
		S     string `json:"s"`
		Out   any    `json:"out"`
		Clamp string `json:"clamp"`
	} `json:"summaryCarrier"`
	SummaryRefresh []struct {
		Prompt []llm.Message `json:"prompt"`
	} `json:"summaryRefresh"`
	TextPayload []struct {
		Text    string `json:"text"`
		Options struct {
			MaxLines int `json:"maxLines"`
			MaxChars int `json:"maxChars"`
		} `json:"options"`
		Out struct {
			Text    string `json:"text"`
			Metrics struct {
				InputChars   int      `json:"inputChars"`
				OutputChars  int      `json:"outputChars"`
				ReducedChars int      `json:"reducedChars"`
				Applied      bool     `json:"applied"`
				Strategies   []string `json:"strategies"`
			} `json:"metrics"`
		} `json:"out"`
	} `json:"textPayload"`
	ClampRun []struct {
		Text       any    `json:"text"`
		Max        int    `json:"max"`
		Out        string `json:"out"`
		Normalized string `json:"normalized"`
	} `json:"clampRun"`
	Fence []struct {
		Text     string `json:"text"`
		Fenced   string `json:"fenced"`
		Neutral  string `json:"neutral"`
		Scrubbed string `json:"scrubbed"`
	} `json:"fence"`
	Aging []struct {
		Count      int   `json:"count"`
		First      bool  `json:"first"`
		Second     bool  `json:"second"`
		GuardCalls int   `json:"guardCalls"`
		Contents   []int `json:"contents"`
	} `json:"aging"`
}

func loadHarness(t *testing.T) harnessVectors {
	t.Helper()
	var v harnessVectors
	readVectors(t, "harness.json", &v)
	return v
}

func TestStableHashAndIntentsMatchNode(t *testing.T) {
	v := loadHarness(t)
	for _, c := range v.Hashes {
		if got := StableHash(c.Value); got != c.Hash {
			t.Errorf("hash of %v = %s, want %s", c.Value, got, c.Hash)
		}
	}
	for _, c := range v.Intents {
		same(t, "intent of "+c.Command, NormalizeReadOnlyShellIntent(c.Command), c.Intent)
	}
}

func TestRepetitionGuardMatchesNode(t *testing.T) {
	for n, steps := range loadHarness(t).Guard {
		clock := time.UnixMilli(1_000_000)
		guard := NewToolRepetitionGuard(0, func() time.Time { return clock })
		scope := func(s *string) string {
			if s == nil {
				return ""
			}
			return *s
		}
		for i, step := range steps {
			name := fmt.Sprintf("scenario %d step %d (%s)", n, i, step.Op)
			switch step.Op {
			case "claim":
				fp := guard.Fingerprint(step.Tool, step.Args, scope(step.Scope))
				prior := guard.ClaimRead(fp, 3)
				want := step.Out.(map[string]any)
				if want["fingerprint"] != fp {
					t.Errorf("%s: fingerprint %s, want %v", name, fp, want["fingerprint"])
				}
				if (prior != nil) != (want["prior"] != nil) {
					t.Errorf("%s: prior %v, want %v", name, prior, want["prior"])
				}
			case "fingerprint":
				if got := guard.Fingerprint(step.Tool, step.Args, scope(step.Scope)); got != step.Out {
					t.Errorf("%s: %s, want %v", name, got, step.Out)
				}
			case "stateChanged":
				guard.NoteStateChanged(scope(step.Scope))
			case "compaction":
				guard.NoteCompaction()
			case "advance":
				clock = clock.Add(time.Duration(step.Ms) * time.Millisecond)
			case "observe":
				got := guard.Observe(step.Tool, step.Args, step.Result, step.Failure, scope(step.Scope))
				same(t, name, map[string]any{"unchangedCount": got.UnchangedCount, "failure": got.Failure}, step.Out)
			case "block":
				if got := guard.ShouldBlock(step.Tool, step.Args, step.ReadOnly, scope(step.Scope)); got != step.Out {
					t.Errorf("%s: %v, want %v", name, got, step.Out)
				}
			case "last":
				if got := guard.LastFailure(step.Tool, step.Args, scope(step.Scope)); got != step.Out {
					t.Errorf("%s: %q, want %v", name, got, step.Out)
				}
			case "resting":
				got := guard.ToolResting(step.Tool)
				if got == nil {
					if step.Out != nil {
						t.Errorf("%s: not resting, want %v", name, step.Out)
					}
					continue
				}
				same(t, name, map[string]any{"failure": got.Failure, "count": got.Count, "retryInMs": got.RetryIn.Milliseconds(), "serviceWait": got.ServiceWait}, step.Out)
			}
		}
	}
}

func TestSalvageAndSanitizersMatchNode(t *testing.T) {
	v := loadHarness(t)
	for _, c := range v.Salvage {
		var offered []llm.Tool
		for _, name := range c.Tools {
			offered = append(offered, llm.Tool{Name: name})
		}
		content, calls := SalvageTextToolCalls(c.Text, offered)
		if content != c.Content || len(calls) != len(c.Calls) {
			t.Errorf("salvage %q: content %q (%d calls), want %q (%d calls)", c.Text, content, len(calls), c.Content, len(c.Calls))
			continue
		}
		for i, call := range calls {
			want := c.Calls[i]
			if call.Function.Name != want.Name || call.Function.Arguments != want.Arguments || !strings.HasPrefix(call.ID, want.IDPrefix) || call.Type != want.Type {
				t.Errorf("salvage %q call %d: %+v, want %+v", c.Text, i, call, want)
			}
		}
	}
	for _, c := range v.Streaming {
		if got := SanitizeStreamingToolCallText(c.Text); got != c.Visible {
			t.Errorf("streaming %q: %q, want %q", c.Text, got, c.Visible)
		}
	}
	for _, c := range v.Sanitize {
		if got := SanitizeModelOutput(c.Text, SanitizeOptions{Model: c.Model}); got != c.Out {
			t.Errorf("sanitize %q (%s): %q, want %q", c.Text, c.Model, got, c.Out)
		}
	}
	for _, c := range v.SanitizeConfigured {
		if got := SanitizeModelOutput(c.Text, SanitizeOptions{Model: c.Model, HanModels: []string{"custom-model", " Other"}}); got != c.Out {
			t.Errorf("configured sanitize (%s): %q, want %q", c.Model, got, c.Out)
		}
	}
	for _, c := range v.Raw {
		if IsRawToolCall(c.Text) != c.Raw || MayBeRawToolCall(c.Text) != c.May {
			t.Errorf("raw tool call %q: got %v/%v, want %v/%v", c.Text, IsRawToolCall(c.Text), MayBeRawToolCall(c.Text), c.Raw, c.May)
		}
	}
}

func TestCompactionMatchesNode(t *testing.T) {
	v := loadHarness(t)
	for _, c := range v.Compaction {
		name := fmt.Sprintf("%s/%d", c.Name, c.TargetTokens)
		cut := SelectTurnSafeCut(CutRequest{
			Messages:      c.Messages,
			FixedMessages: []llm.Message{{Role: "system", Content: "fixed"}},
			Tools:         []llm.Tool{{Name: "t", Parameters: map[string]any{"type": "object"}}},
			TargetTokens:  c.TargetTokens,
		})
		want := c.CutRaw
		if cut.Compactable != want.Compactable || cut.SplitTurn != want.SplitTurn || cut.Reason != want.Reason || cut.PreviousSummary != want.PreviousSummary || cut.ProjectedTokens != want.ProjectedTokens {
			t.Errorf("%s: cut %+v, want %+v", name, cut, want)
			continue
		}
		same(t, name+" leading", cut.Leading, want.Leading)
		same(t, name+" compacted", cut.Compacted, want.Compacted)
		same(t, name+" retained", cut.Retained, want.Retained)
		if cut.Compactable {
			same(t, name+" applied", ApplyCompaction(cut, "  the summary  "), c.Applied)
		}
	}
	transcripts := map[string][]llm.Message{}
	for _, c := range v.Compaction {
		transcripts[c.Name] = c.Messages
	}
	for _, c := range v.Estimates {
		tokens := EstimateTokenCount(transcripts[c.Name], []llm.Tool{{Name: "tool", Description: "ü"}})
		if tokens != c.Tokens {
			t.Errorf("%s: %d tokens, want %d", c.Name, tokens, c.Tokens)
		}
		for i, m := range transcripts[c.Name] {
			if got := EstimateMessageTokens(m); got != c.PerMessage[i] {
				t.Errorf("%s message %d: %d, want %d", c.Name, i, got, c.PerMessage[i])
			}
		}
	}
	for _, c := range v.Serialized {
		if got := SerializeForSummary(transcripts[c.Name]); got != c.Text {
			t.Errorf("serialized %s differs:\n%s\nwant\n%s", c.Name, got, c.Text)
		}
	}
	for _, c := range v.SummaryMessages {
		same(t, "summary messages", BuildSummaryMessages(c.PreviousSummary, c.Source), c.Messages)
	}
}

func TestContextPressureMatchesNode(t *testing.T) {
	v := loadHarness(t)
	for _, c := range v.Budgets {
		if got := ContextBudgetFor(c.Window, c.MaxOut); got != c.Budget {
			t.Errorf("budget %d/%d: %+v, want %+v", c.Window, c.MaxOut, got, c.Budget)
		}
	}
	for _, c := range v.Overflow {
		var err error
		if code := firstNonEmpty(c.Error.Code, c.Error.Type); code != "" {
			err = &llm.Error{Code: code, Message: c.Error.Message}
		} else {
			err = errors.New(c.Error.Message)
		}
		if got := IsContextOverflowError(err); got != c.Result {
			t.Errorf("overflow %+v: %v, want %v", c.Error, got, c.Result)
		}
	}
	transcripts := map[string][]llm.Message{}
	for _, c := range v.Compaction {
		transcripts[c.Name] = c.Messages
	}
	for _, c := range v.Pressure {
		name := fmt.Sprintf("%s window=%d force=%v", c.Name, c.Window, c.Force)
		summaries := 0
		var events []map[string]any
		controller := &ContextPressure{
			Summarize: func(ctx context.Context, messages []llm.Message) (string, error) {
				summaries++
				return fmt.Sprintf("summary#%d", summaries), nil
			},
			OnEvent: func(e PressureEvent) { events = append(events, map[string]any{"kind": e.Kind, "data": e.Fields}) },
		}
		messages := transcripts[c.Name]
		result, err := controller.Prepare(context.Background(), PrepareRequest{
			ContextWindow: c.Window, Messages: messages, FixedMessages: []llm.Message{{Role: "system", Content: "fixed"}}, Force: c.Force,
		})
		if (err != nil) != (c.Error != "") || err != nil && err.Error() != c.Error {
			t.Errorf("%s: error %v, want %q", name, err, c.Error)
			continue
		}
		if err != nil {
			continue
		}
		var wantEvents []map[string]any
		for _, e := range c.Events {
			wantEvents = append(wantEvents, map[string]any{"kind": e.Kind, "data": e.Data})
		}
		same(t, name+" events", events, wantEvents)
		if summaries != c.SummaryCalls {
			t.Errorf("%s: %d summaries, want %d", name, summaries, c.SummaryCalls)
		}
		want := c.Result
		if result.Changed != want.Changed || result.Irreducible != want.Irreducible || result.Reason != want.Reason || result.BeforeTokens != want.BeforeTokens || result.AfterTokens != want.AfterTokens || result.Budget != want.Budget {
			t.Errorf("%s: result %+v, want %+v", name, result, want)
			continue
		}
		if string(want.Messages) != `"same"` {
			var wantMessages []llm.Message
			if err := json.Unmarshal(want.Messages, &wantMessages); err != nil {
				t.Fatal(err)
			}
			same(t, name+" messages", result.Messages, wantMessages)
		}
	}
	p := &ContextPressure{}
	got := []any{p.ClaimOverflowRecovery(), p.ClaimOverflowRecovery(), p.ClaimOverflowRecovery(), float64(p.OverflowRecoveries())}
	same(t, "recoveries", got, v.Recoveries)
}

func TestLoopPolicyMatchesNode(t *testing.T) {
	v := loadHarness(t)
	registry := testShaper(t).Tools
	for i, c := range v.LoopPolicy {
		policy := BuildLoopPolicy(c.Settings, c.Options)
		want := c.Policy
		got := fmt.Sprintf("%d %d %d %+v %d %d", policy.MaxIterations, policy.MaxIdleTurns, policy.MaxFailedTurns, policy.ToolResultBudget, policy.HardLimitMultiplier, policy.AbsoluteHardLimit)
		expected := fmt.Sprintf("%d %d %d %+v %d %d", want.MaxIterations, want.MaxIdleTurns, want.MaxFailedTurns,
			ResultBudgets{Default: want.ToolResultBudget.Default, File: want.ToolResultBudget.File, Browser: want.ToolResultBudget.Browser, Command: want.ToolResultBudget.Command},
			want.HardLimitMultiplier, want.AbsoluteHardLimit)
		if got != expected {
			t.Errorf("case %d (%v %v): %s, want %s", i, c.Settings, c.Options, got, expected)
		}
		for _, l := range c.Limits {
			limits := policy.ResolveToolResultLimits(registry.Meta(l.Tool, nil))
			if limits.Soft != l.SoftLimit || limits.Hard != l.HardLimit {
				t.Errorf("case %d %s: %+v, want %d/%d", i, l.Tool, limits, l.SoftLimit, l.HardLimit)
			}
		}
	}
}

func TestInterimMatchesNode(t *testing.T) {
	v := loadHarness(t).Interim
	for _, c := range v.Kinds {
		if got := NormalizeInterimKind(c.Value); got != c.Kind {
			t.Errorf("kind %v: %s, want %s", c.Value, got, c.Kind)
		}
	}
	for _, c := range v.Metadata {
		kind := ""
		if c.Kind != nil {
			kind = *c.Kind
		}
		same(t, "metadata", InterimMetadata(kind, c.ExpectsReply != nil && *c.ExpectsReply), c.Out)
	}
	for _, c := range v.Parsed {
		got := ParseInterimMetadata(c.Value)
		if got.Interim != c.Out.Interim || got.Kind != c.Out.Kind || got.ExpectsReply != c.Out.ExpectsReply || IsInterimAssistantMetadata(c.Value) != c.Is {
			t.Errorf("parsed %v: %+v, want %+v", c.Value, got, c.Out)
		}
	}
	str := func(s *string) string {
		if s == nil {
			return ""
		}
		return *s
	}
	for _, c := range v.Signatures {
		if got := InterimSignature(str(c.Content), str(c.Kind), c.ExpectsReply != nil && *c.ExpectsReply, str(c.Platform)); got != c.Out {
			t.Errorf("signature: %s, want %s", got, c.Out)
		}
	}
}

func TestEvidenceMatchesNode(t *testing.T) {
	v := loadHarness(t)
	shaper := testShaper(t)
	var executions []ToolExecution
	for _, c := range v.Evidence {
		got := shaper.ClassifyToolExecution(c.Tool, c.Args, c.Result, c.Error, nil)
		want := c.Execution
		if got.ToolName != want.ToolName || got.OK != want.OK || got.Error != want.Error || got.EvidenceSource != want.EvidenceSource ||
			got.EvidenceRelevant != want.EvidenceRelevant || got.StateChanged != want.StateChanged || got.Summary != want.Summary {
			t.Errorf("%s %v:\n got  %+v\n want %+v", c.Tool, c.Result, got, want)
		}
		if inferred := shaper.inferToolFailureMessage(c.Tool, c.Result); inferred != c.Inferred {
			t.Errorf("%s %v: inferred %q, want %q", c.Tool, c.Result, inferred, c.Inferred)
		}
		if shaper.IsSubstantiveProgressEvidence(got) != c.Substantive {
			t.Errorf("%s: substantive differs", c.Tool)
		}
		executions = append(executions, got)
	}
	if got := shaper.SummarizeProgressToolExecutions(executions, 10); got != v.EvidenceSummary.All {
		t.Errorf("progress summary:\n%s\nwant\n%s", got, v.EvidenceSummary.All)
	}
	cases := []struct {
		e *ToolExecution
		r *UnchangedObservation
	}{{&executions[0], nil}, {&executions[0], &UnchangedObservation{UnchangedCount: 2}}, {&executions[1], nil}, {&executions[12], nil}, {nil, nil}}
	for i, c := range cases {
		if got := GatheredNewEvidence(c.e, c.r); got != v.EvidenceSummary.Gathered[i] {
			t.Errorf("gathered %d: %v, want %v", i, got, v.EvidenceSummary.Gathered[i])
		}
	}
}

func TestHistoryHelpersMatchNode(t *testing.T) {
	v := loadHarness(t)
	for i, c := range v.SanitizeHistory {
		same(t, fmt.Sprintf("sanitize history %d", i), SanitizeConversationMessages(c.Messages), c.Out)
	}
	for _, c := range v.StoredUser {
		in := c.Input
		if got := StoredUserContent(in.UserMessage, in.RawUserMessage, in.Platform, in.Speaker, in.IsGroup); got != c.Out {
			t.Errorf("stored user %+v: %q, want %q", in, got, c.Out)
		}
	}
	for _, c := range v.SummaryCarrier {
		carrier := SummaryCarrier(c.S)
		if carrier == nil {
			if c.Out != nil {
				t.Errorf("carrier %q: nil, want %v", c.S, c.Out)
			}
		} else {
			same(t, "carrier", carrier, c.Out)
		}
		if got := ClampSummary(" " + c.S + " "); got != c.Clamp {
			t.Errorf("clamp summary: differs")
		}
	}
	prompt := SummaryRefreshMessages("old summary", []llm.Message{
		{Role: "user", Content: "hello"},
		{Role: "assistant", Content: strings.Repeat("x", 500), ToolCalls: []llm.ToolCall{{ID: "1", Function: llm.FunctionCall{Name: "a"}}, {ID: "2", Function: llm.FunctionCall{Name: "b"}}}},
		{Role: "tool", Content: strings.Repeat("y", 400), Name: "a", ToolCallID: "1"},
		{Role: "tool", Content: "z", ToolCallID: "2"},
	}, "web chat")
	same(t, "summary refresh", prompt, v.SummaryRefresh[0].Prompt)
}

func TestTextHelpersMatchNode(t *testing.T) {
	v := loadHarness(t)
	for _, c := range v.TextPayload {
		got, metrics := CompactTextPayload(c.Text, c.Options.MaxLines, c.Options.MaxChars)
		want := c.Out
		if got != want.Text || metrics.InputChars != want.Metrics.InputChars || metrics.OutputChars != want.Metrics.OutputChars ||
			metrics.ReducedChars != want.Metrics.ReducedChars || metrics.Applied != want.Metrics.Applied || !reflect.DeepEqual(metrics.Strategies, want.Metrics.Strategies) {
			t.Errorf("payload %.40q %+v:\n got  %q %+v\n want %q %+v", c.Text, c.Options, got, metrics, want.Text, want.Metrics)
		}
	}
	for _, c := range v.ClampRun {
		if got := ClampRunContext(c.Text, c.Max); got != c.Out {
			t.Errorf("clampRun %v: %q, want %q", c.Text, got, c.Out)
		}
		if got := normalizeOutgoingDefault(c.Text, true); got != c.Normalized {
			t.Errorf("normalize %v: %q, want %q", c.Text, got, c.Normalized)
		}
	}
	for _, c := range v.Fence {
		if FenceUntrusted("external_message", c.Text) != c.Fenced || NeutralizeFenceTags(c.Text) != c.Neutral || ScrubInvisible(c.Text) != c.Scrubbed {
			t.Errorf("fence %q differs", c.Text)
		}
	}
	for _, c := range v.Aging {
		messages := make([]llm.Message, c.Count)
		for i := range messages {
			messages[i] = llm.Message{Role: "tool", Content: strings.Repeat("t", 500) + fmt.Sprint(i), ToolCallID: fmt.Sprintf("a%d", i)}
		}
		var ager ResultAger
		first, second := ager.Age(messages), ager.Age(messages)
		if first != c.First || second != c.Second {
			t.Errorf("aging %d: %v/%v, want %v/%v", c.Count, first, second, c.First, c.Second)
		}
		for i, m := range messages {
			if got := len(dyn.Str(m.Content)); got != c.Contents[i] {
				t.Errorf("aging %d message %d: length %d, want %d", c.Count, i, got, c.Contents[i])
			}
		}
	}
}
