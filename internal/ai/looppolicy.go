package ai

import (
	"math"
	"strconv"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/textx"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/tools"
)

// Limits for the runaway guards and tool-result replay. None of them shapes
// normal work: the model decides how many steps a task takes and when it is
// done. The turn ceiling is an emergency stop only.
const (
	EmergencyMaxIterations = 5000
	// Consecutive tool turns that changed no state and surfaced no new evidence.
	DefaultMaxIdleTurns = 8
	// Consecutive tool turns in which every call failed.
	DefaultMaxFailedTurns       = 5
	maxAllowedIdleTurns         = 25
	maxAllowedFailedTurns       = 50
	maxAllowedBudgetChars       = 500000
	defaultToolResultBudgetChar = 12000
)

// ResultBudgets are the per-category sizes tool results are held to.
type ResultBudgets struct{ Default, File, Browser, Command int }

// LoopPolicy is the limits one run applies.
type LoopPolicy struct {
	MaxIterations    int
	MaxIdleTurns     int
	MaxFailedTurns   int
	ToolResultBudget ResultBudgets
	// The hard ceiling is twice the soft budget, capped at an absolute max.
	HardLimitMultiplier int
	AbsoluteHardLimit   int
}

// numberOf is Number(value) for settings that may be stored as text or number;
// null and "" are NaN.
func numberOf(v any) float64 {
	switch x := v.(type) {
	case float64:
		return x
	case int:
		return float64(x)
	case int64:
		return float64(x)
	case bool:
		if x {
			return 1
		}
		return 0
	case string:
		text := textx.Trim(x)
		if text == "" {
			return math.NaN()
		}
		if n, err := strconv.ParseFloat(text, 64); err == nil && !strings.ContainsAny(text, "_") {
			return n
		}
		if n, err := strconv.ParseInt(text, 0, 64); err == nil {
			return float64(n)
		}
	}
	return math.NaN()
}

func clampFinite(n, lo, hi float64, fallback int) int {
	if math.IsNaN(n) || math.IsInf(n, 0) {
		return fallback
	}
	return int(math.Min(math.Max(n, lo), hi))
}

// firstDefined is a ?? b.
func firstDefined(a, b any) any {
	if a != nil {
		return a
	}
	return b
}

// BuildLoopPolicy derives a run's limits from the AI settings and the options
// it was started with.
func BuildLoopPolicy(aiSettings, options dyn.Map) LoopPolicy {
	floor := func(v any) float64 { return math.Floor(numberOf(v)) }
	maxIterations := clampFinite(floor(options["maxIterations"]), 1, EmergencyMaxIterations, EmergencyMaxIterations)
	maxIdle := clampFinite(floor(firstDefined(options["maxConsecutiveReadOnlyIterations"], aiSettings["max_consecutive_read_only_iterations"])), 3, maxAllowedIdleTurns, DefaultMaxIdleTurns)
	maxFailed := clampFinite(floor(firstDefined(options["maxConsecutiveToolFailures"], aiSettings["max_consecutive_tool_failures"])), 1, maxAllowedFailedTurns, DefaultMaxFailedTurns)

	// Results cut below what the model needs are re-fetched in slices, and each
	// slice is a full model turn, so the budget errs on the side of complete. A
	// stored value below these is never cheaper: older settings kept 1200, and one
	// run read its results back in 2 KB slices for 346 turns and 48M tokens.
	defaultBudget := clampFinite(floor(aiSettings["tool_replay_budget_chars"]), defaultToolResultBudgetChar, maxAllowedBudgetChars, defaultToolResultBudgetChar)
	category := func(setting string, lower int) int {
		floorValue := max(defaultBudget, lower)
		return clampFinite(floor(aiSettings[setting]), float64(floorValue), maxAllowedBudgetChars, floorValue)
	}
	return LoopPolicy{
		MaxIterations:  maxIterations,
		MaxIdleTurns:   maxIdle,
		MaxFailedTurns: maxFailed,
		ToolResultBudget: ResultBudgets{
			Default: defaultBudget,
			File:    category("tool_replay_budget_file_chars", 24000),
			Browser: category("tool_replay_budget_browser_chars", 16000),
			Command: category("tool_replay_budget_command_chars", 16000),
		},
		HardLimitMultiplier: 2,
		AbsoluteHardLimit:   48000,
	}
}

// ResultLimits are the soft and hard size of one tool's result.
type ResultLimits struct{ Soft, Hard int }

// ResolveToolResultLimits is the budget for a tool's result.
func (p LoopPolicy) ResolveToolResultLimits(meta tools.Meta) ResultLimits {
	soft := p.ToolResultBudget.Default
	switch tools.ResultBudget(meta) {
	case "file":
		soft = p.ToolResultBudget.File
	case "browser":
		soft = p.ToolResultBudget.Browser
	case "command":
		soft = p.ToolResultBudget.Command
	}
	return ResultLimits{Soft: soft, Hard: min(soft*p.HardLimitMultiplier, p.AbsoluteHardLimit)}
}
