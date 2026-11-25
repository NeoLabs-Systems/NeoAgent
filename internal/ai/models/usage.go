package models

import (
	"context"
	"encoding/json"
	"math"

	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/llm"
)

// Usage is a token count as the harness records it.
type Usage struct {
	InputTokens      int `json:"inputTokens"`
	OutputTokens     int `json:"outputTokens"`
	ReasoningTokens  int `json:"reasoningTokens"`
	CachedReadTokens int `json:"cachedReadTokens"`
	CacheWriteTokens int `json:"cacheWriteTokens"`
	TotalTokens      int `json:"totalTokens"`
}

func finiteToken(v float64) int {
	if math.IsNaN(v) || math.IsInf(v, 0) || v <= 0 {
		return 0
	}
	return int(math.Floor(v))
}

// FromLLM converts a provider's usage report.
func FromLLM(u *llm.Usage) *Usage {
	if u == nil {
		return nil
	}
	return NormalizeUsage(map[string]any{
		"inputTokens": float64(u.InputTokens), "outputTokens": float64(u.OutputTokens), "reasoningTokens": float64(u.ReasoningTokens),
		"cachedReadTokens": float64(u.CachedReadTokens), "cacheWriteTokens": float64(u.CacheWriteTokens),
	})
}

// firstNumber is a ?? b ?? c ...: the first value that is a number.
func firstNumber(values ...any) float64 {
	for _, v := range values {
		if n, ok := v.(float64); ok {
			return n
		}
	}
	return 0
}

func nested(m map[string]any, keys ...string) any {
	var v any = m
	for _, k := range keys {
		obj, ok := v.(map[string]any)
		if !ok {
			return nil
		}
		v = obj[k]
	}
	return v
}

// NormalizeUsage reads the usage shapes the providers report (camelCase,
// OpenAI, Anthropic and Gemini names) into one record. The total is the
// reported one, else input plus output.
func NormalizeUsage(u map[string]any) *Usage {
	if u == nil {
		return nil
	}
	input := finiteToken(firstNumber(u["inputTokens"], u["promptTokens"], u["input_tokens"], u["prompt_tokens"]))
	output := finiteToken(firstNumber(u["outputTokens"], u["completionTokens"], u["output_tokens"], u["completion_tokens"]))
	reasoning := finiteToken(firstNumber(u["reasoningTokens"], u["reasoning_tokens"],
		nested(u, "output_tokens_details", "reasoning_tokens"), nested(u, "completion_tokens_details", "reasoning_tokens")))
	cachedRead := finiteToken(firstNumber(u["cachedReadTokens"], u["cached_read_tokens"], u["cache_read_input_tokens"],
		nested(u, "prompt_tokens_details", "cached_tokens"), nested(u, "input_tokens_details", "cached_tokens"), u["cachedContentTokenCount"]))
	cacheWrite := finiteToken(firstNumber(u["cacheWriteTokens"], u["cache_write_tokens"], u["cache_creation_input_tokens"]))
	total := finiteToken(firstNumber(u["totalTokens"], u["total_tokens"]))
	if total == 0 {
		total = input + output
	}
	return &Usage{input, output, reasoning, cachedRead, cacheWrite, total}
}

// Merge adds two usage records.
func Merge(left, right *Usage) Usage {
	a, b := Usage{}, Usage{}
	if left != nil {
		a = *left
	}
	if right != nil {
		b = *right
	}
	return Usage{
		a.InputTokens + b.InputTokens, a.OutputTokens + b.OutputTokens, a.ReasoningTokens + b.ReasoningTokens,
		a.CachedReadTokens + b.CachedReadTokens, a.CacheWriteTokens + b.CacheWriteTokens, a.TotalTokens + b.TotalTokens,
	}
}

// UsageRecord is one model call to record.
type UsageRecord struct {
	RunID            string
	StepID           string
	UserID           int64
	AgentID          string
	Provider, Model  string
	Phase            string
	Usage            *Usage
	LatencyMs        int64
	EstimatedCostUSD *float64
	Metadata         map[string]any
}

// RecordUsage writes an agent_model_usage row and returns its id; it returns 0
// when the record lacks what the row needs.
func RecordUsage(ctx context.Context, db *dbx.DB, r UsageRecord) (int64, error) {
	if r.RunID == "" || r.UserID == 0 || r.Provider == "" || r.Model == "" || r.Usage == nil {
		return 0, nil
	}
	if r.Phase == "" {
		r.Phase = "model_turn"
	}
	metadata := r.Metadata
	if metadata == nil {
		metadata = map[string]any{}
	}
	meta, err := json.Marshal(metadata)
	if err != nil {
		return 0, err
	}
	var stepID, agentID, cost any
	if r.StepID != "" {
		stepID = r.StepID
	}
	if r.AgentID != "" {
		agentID = r.AgentID
	}
	if r.EstimatedCostUSD != nil {
		cost = *r.EstimatedCostUSD
	}
	u := r.Usage
	result, err := db.W.ExecContext(ctx,
		`INSERT INTO agent_model_usage (
		   run_id, step_id, user_id, agent_id, provider, model, phase,
		   input_tokens, output_tokens, reasoning_tokens, cached_read_tokens,
		   cache_write_tokens, total_tokens, estimated_cost_usd, latency_ms, metadata_json
		 ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		r.RunID, stepID, r.UserID, agentID, r.Provider, r.Model, r.Phase,
		u.InputTokens, u.OutputTokens, u.ReasoningTokens, u.CachedReadTokens, u.CacheWriteTokens, u.TotalTokens,
		cost, max(0, r.LatencyMs), string(meta))
	if err != nil {
		return 0, err
	}
	return result.LastInsertId()
}
