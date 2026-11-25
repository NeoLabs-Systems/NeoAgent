package ai

import "github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"

// RunGuards are the runaway guards. The model decides how the work goes and when
// it is done; these only end a run that is spinning: tool turns that change
// nothing and learn nothing, tool turns in which every call fails, or the
// emergency turn ceiling. The run then gets one last turn to tell the user where
// it stands.
type RunGuards struct {
	Policy          LoopPolicy
	maxTotalTokens  float64
	modelTurns      int
	totalTokens     int
	idleTurns       int
	failedTurns     int
	sameActionTurns int
	lastActionKey   string
}

// NewRunGuards derives the guards from the account's AI settings and the run's
// options (maxTotalTokens ends a run that has spent its tokens).
func NewRunGuards(aiSettings, options dyn.Map) *RunGuards {
	g := &RunGuards{Policy: BuildLoopPolicy(aiSettings, options)}
	if tokens, ok := dyn.Float(options["maxTotalTokens"]); ok && tokens > 0 {
		g.maxTotalTokens = tokens
	}
	return g
}

// RecordModelTurn counts a model request.
func (g *RunGuards) RecordModelTurn() { g.modelTurns++ }

// RecordTokens adds a turn's token use.
func (g *RunGuards) RecordTokens(tokens int) { g.totalTokens += tokens }

// ToolTurnOutcome is what a tool turn tells the guards.
type ToolTurnOutcome struct {
	Progressed bool
	AllFailed  bool
	ActionKey  string
	// TerminalAnswer is the run's answer when the turn only delivered it; nil
	// means the run goes on.
	TerminalAnswer *string
}

// RecordToolTurn updates the streaks after a tool turn.
func (g *RunGuards) RecordToolTurn(t ToolTurnOutcome) {
	if t.Progressed {
		g.idleTurns = 0
	} else {
		g.idleTurns++
	}
	if t.AllFailed {
		g.failedTurns++
	} else {
		g.failedTurns = 0
	}
	if t.ActionKey != "" && t.ActionKey == g.lastActionKey {
		g.sameActionTurns++
	} else {
		g.sameActionTurns = 0
	}
	g.lastActionKey = t.ActionKey
}

// Streaks are the current runs of stalled turns.
type Streaks struct{ IdleTurns, FailedTurns, SameActionTurns int }

// Streaks reports them.
func (g *RunGuards) Streaks() Streaks {
	return Streaks{g.idleTurns, g.failedTurns, g.sameActionTurns}
}

// StopReason is why the run must wrap up now, or "".
func (g *RunGuards) StopReason() string {
	switch {
	case g.modelTurns >= g.Policy.MaxIterations:
		return "turn_limit"
	case g.maxTotalTokens > 0 && float64(g.totalTokens) >= g.maxTotalTokens:
		return "token_budget"
	case g.idleTurns >= g.Policy.MaxIdleTurns:
		return "no_progress"
	case g.failedTurns >= g.Policy.MaxFailedTurns:
		return "tool_failures"
	}
	return ""
}
