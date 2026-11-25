package agent

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/google/uuid"

	"github.com/NeoLabs-Systems/neolabs-go/llm"
)

// Raw prompts stay out of the permanent ledger. A run keeps its model requests
// only when someone asked for that run or, written when it ends, when it
// failed. Captures expire much sooner than the metrics, and private reasoning
// is never written at all.

const (
	captureNextKey  = "run_capture_next"
	captureTTLHours = 168
)

type captureDecision struct {
	Enabled bool
	Reason  string
}

func (e *Engine) decideCapture(ctx context.Context, userID int64, agentID string, requested bool) captureDecision {
	if requested {
		return captureDecision{Enabled: true, Reason: "requested"}
	}
	res, err := e.deps.DB.W.ExecContext(ctx, `DELETE FROM agent_settings WHERE user_id = ? AND agent_id = ? AND key = ?`, userID, agentID, captureNextKey)
	if err == nil {
		if n, _ := res.RowsAffected(); n > 0 {
			return captureDecision{Enabled: true, Reason: "capture_next"}
		}
	}
	return captureDecision{}
}

func withoutReasoning(messages []llm.Message) []llm.Message {
	out := make([]llm.Message, len(messages))
	for i, m := range messages {
		m.ReasoningState = nil
		m.ProviderContentBlocks = nil
		out[i] = m
	}
	return out
}

func (e *Engine) writeCapture(runID string, userID int64, reason, phase string, iteration int, provider, model string, maxTokens int, effort string, messages []llm.Message, list []llm.Tool) (string, error) {
	requestID := uuid.NewString()
	header := map[string]any{"phase": phase, "iteration": iteration, "provider": nullString(provider), "model": nullString(model)}
	if maxTokens > 0 {
		header["maxTokens"] = maxTokens
	}
	if effort != "" {
		header["reasoningEffort"] = effort
	}
	if list == nil {
		list = []llm.Tool{}
	}
	payload, err := json.Marshal(map[string]any{"header": header, "messages": withoutReasoning(messages), "tools": list})
	if err != nil {
		return "", err
	}
	_, err = e.deps.DB.W.Exec(`INSERT OR IGNORE INTO agent_run_captures (run_id, user_id, request_id, phase, iteration, provider, model, reason, payload_json, expires_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now', ?))`,
		runID, userID, requestID, phase, iteration, nullString(provider), nullString(model), reason, string(payload), fmt.Sprintf("+%d hours", captureTTLHours))
	return requestID, err
}

func (e *Engine) captureRequest(r *Run, phase string, iteration int, provider, model string, maxTokens int, effort string, messages []llm.Message, list []llm.Tool) string {
	if !r.Capture.Enabled {
		return ""
	}
	id, err := e.writeCapture(r.ID, r.UserID, r.Capture.Reason, phase, iteration, provider, model, maxTokens, effort, messages, list)
	if err != nil {
		e.log.Warn("Could not store a prompt capture", "error", err)
		return ""
	}
	return id
}

// captureFailure keeps what a failed run's last turn saw: that is the run
// someone will want to look at.
func (e *Engine) captureFailure(r *Run, iterations int, messages []llm.Message, list []llm.Tool) {
	if r.Capture.Enabled || len(messages) == 0 {
		return
	}
	model := r.Model()
	if _, err := e.writeCapture(r.ID, r.UserID, "failure", "failure", iterations, model.ProviderName, model.Model, 0, "", messages, list); err != nil {
		e.log.Warn("Could not store the failed run's prompt", "error", err)
	}
}
