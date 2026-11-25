package settings

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"math"
)

type usageDay struct {
	Date   string `json:"date"`
	Tokens int64  `json:"tokens"`
	Runs   int64  `json:"runs"`
}

type usageTotals struct {
	TotalTokens     int64 `json:"totalTokens"`
	TotalRuns       int64 `json:"totalRuns"`
	AvgTokensPerRun int64 `json:"avgTokensPerRun"`
	Last7DaysTokens int64 `json:"last7DaysTokens"`
	Last7DaysRuns   int64 `json:"last7DaysRuns"`
}

type promptAverage struct {
	SystemPromptTokens   int64 `json:"systemPromptTokens"`
	ToolSchemaTokens     int64 `json:"toolSchemaTokens"`
	HistoryTokens        int64 `json:"historyTokens"`
	RecalledMemoryTokens int64 `json:"recalledMemoryTokens"`
	ToolReplayTokens     int64 `json:"toolReplayTokens"`
}

type promptMetrics struct {
	SampleCount int             `json:"sampleCount"`
	Average     *promptAverage  `json:"average"`
	Latest      json.RawMessage `json:"latest"`
}

type modelUsage struct {
	InputTokens      int64    `json:"inputTokens"`
	OutputTokens     int64    `json:"outputTokens"`
	ReasoningTokens  int64    `json:"reasoningTokens"`
	CachedReadTokens int64    `json:"cachedReadTokens"`
	CacheWriteTokens int64    `json:"cacheWriteTokens"`
	TotalTokens      int64    `json:"totalTokens"`
	EstimatedCostUSD *float64 `json:"estimatedCostUsd"`
	PricedCallCount  int64    `json:"pricedCallCount"`
	CallCount        int64    `json:"callCount"`
	CacheHitRatio    float64  `json:"cacheHitRatio"`
}

// TokenUsage is the body of GET /api/settings/token-usage/summary.
type TokenUsage struct {
	Totals        usageTotals   `json:"totals"`
	Last7Days     []usageDay    `json:"last7Days"`
	PromptMetrics promptMetrics `json:"promptMetrics"`
	ModelUsage    modelUsage    `json:"modelUsage"`
}

// jsRound is Math.round, which rounds halves up.
func jsRound(x float64) int64 { return int64(math.Floor(x + 0.5)) }

// TokenUsage summarizes one agent's runs for the settings screen.
func (s *Store) TokenUsage(ctx context.Context, userID int64, agentID string) (TokenUsage, error) {
	var out TokenUsage
	var avg float64
	err := s.DB.R.QueryRowContext(ctx, `
		SELECT
		  COALESCE(SUM(total_tokens), 0),
		  COUNT(*),
		  COALESCE(AVG(CASE WHEN total_tokens > 0 THEN total_tokens END), 0)
		FROM agent_runs
		WHERE user_id = ? AND agent_id = ?`, userID, agentID).Scan(&out.Totals.TotalTokens, &out.Totals.TotalRuns, &avg)
	if err != nil {
		return out, err
	}
	out.Totals.AvgTokensPerRun = jsRound(avg)

	if out.Last7Days, err = s.lastSevenDays(ctx, userID, agentID); err != nil {
		return out, err
	}
	for _, day := range out.Last7Days {
		out.Totals.Last7DaysTokens += day.Tokens
		out.Totals.Last7DaysRuns += day.Runs
	}
	if out.PromptMetrics, err = s.promptMetrics(ctx, userID, agentID); err != nil {
		return out, err
	}

	var cost sql.NullFloat64
	u := &out.ModelUsage
	err = s.DB.R.QueryRowContext(ctx, `
		SELECT
		  COALESCE(SUM(input_tokens), 0),
		  COALESCE(SUM(output_tokens), 0),
		  COALESCE(SUM(reasoning_tokens), 0),
		  COALESCE(SUM(cached_read_tokens), 0),
		  COALESCE(SUM(cache_write_tokens), 0),
		  COALESCE(SUM(total_tokens), 0),
		  SUM(estimated_cost_usd),
		  COUNT(estimated_cost_usd),
		  COUNT(*)
		FROM agent_model_usage
		WHERE user_id = ? AND agent_id = ?`, userID, agentID).Scan(&u.InputTokens, &u.OutputTokens, &u.ReasoningTokens,
		&u.CachedReadTokens, &u.CacheWriteTokens, &u.TotalTokens, &cost, &u.PricedCallCount, &u.CallCount)
	if err != nil {
		return out, err
	}
	if u.PricedCallCount > 0 && cost.Valid {
		u.EstimatedCostUSD = &cost.Float64
	}
	if u.InputTokens > 0 {
		u.CacheHitRatio = math.Min(1, float64(u.CachedReadTokens)/float64(u.InputTokens))
	}
	return out, nil
}

// lastSevenDays has one entry per day, today last, zeros for quiet days.
func (s *Store) lastSevenDays(ctx context.Context, userID int64, agentID string) ([]usageDay, error) {
	rows, err := s.DB.R.QueryContext(ctx, `
		SELECT date(created_at), COALESCE(SUM(total_tokens), 0), COUNT(*)
		FROM agent_runs
		WHERE user_id = ? AND agent_id = ? AND created_at >= datetime('now', '-6 days')
		GROUP BY date(created_at)
		ORDER BY date(created_at) ASC`, userID, agentID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	byDay := map[string]usageDay{}
	for rows.Next() {
		var day usageDay
		if err := rows.Scan(&day.Date, &day.Tokens, &day.Runs); err != nil {
			return nil, err
		}
		byDay[day.Date] = day
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	days := make([]usageDay, 0, 7)
	for offset := 6; offset >= 0; offset-- {
		var date string
		if err := s.DB.R.QueryRowContext(ctx, `SELECT date('now', ?)`, fmt.Sprintf("-%d days", offset)).Scan(&date); err != nil {
			return nil, err
		}
		day := byDay[date]
		days = append(days, usageDay{Date: date, Tokens: day.Tokens, Runs: day.Runs})
	}
	return days, nil
}

// promptMetrics averages the prompt-size estimates of the 20 latest runs that
// recorded one. A stored value that is not JSON, or is empty, is skipped.
func (s *Store) promptMetrics(ctx context.Context, userID int64, agentID string) (promptMetrics, error) {
	rows, err := s.DB.R.QueryContext(ctx, `
		SELECT prompt_metrics FROM agent_runs
		WHERE user_id = ? AND agent_id = ? AND prompt_metrics IS NOT NULL
		ORDER BY created_at DESC
		LIMIT 20`, userID, agentID)
	if err != nil {
		return promptMetrics{}, err
	}
	defer rows.Close()

	result := promptMetrics{Latest: nullJSON}
	var sums [5]float64
	fields := [5]string{"systemPromptTokens", "toolSchemaTokens", "historyTokens", "recalledMemoryTokens", "toolReplayTokens"}
	for rows.Next() {
		var text string
		if err := rows.Scan(&text); err != nil {
			return result, err
		}
		item := decode(json.RawMessage(text))
		if !truthy(item) {
			continue
		}
		if result.SampleCount == 0 {
			result.Latest = json.RawMessage(text)
		}
		result.SampleCount++
		members, _ := item.(map[string]any)
		last, _ := members["lastEstimate"].(map[string]any)
		for i, field := range fields {
			sums[i] += number(last[field])
		}
	}
	if err := rows.Err(); err != nil {
		return result, err
	}
	if result.SampleCount > 0 {
		n := float64(result.SampleCount)
		result.Average = &promptAverage{
			SystemPromptTokens: jsRound(sums[0] / n), ToolSchemaTokens: jsRound(sums[1] / n),
			HistoryTokens: jsRound(sums[2] / n), RecalledMemoryTokens: jsRound(sums[3] / n),
			ToolReplayTokens: jsRound(sums[4] / n),
		}
	}
	return result, nil
}
