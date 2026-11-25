// Package systemone selects and validates typed decision-model answers.
package systemone

import (
	"context"
	"encoding/json"
	"math"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/llm"
)

type Model struct {
	ID, ModelID, Provider string
	Available             bool
}

// Source supplies the current setting, available models and provider instance.
type Source interface {
	Selection(context.Context, int64, string) (string, error)
	Models(context.Context, int64, string) ([]Model, error)
	Provider(context.Context, int64, string, Model) (llm.Decider, error)
}

// Observer handles usage and model failures without making decisions fail.
type Observer interface {
	Used(context.Context, Request, Model, map[string]any, time.Duration)
	Failed(context.Context, Request, Model, error)
}
type Service struct {
	Source   Source
	Observer Observer
}
type Request struct {
	UserID                        int64
	AgentID, RunID, StepID, Phase string
	State                         map[string]any
	Questions                     map[string]any
}

func choose(selection string, models []Model) *Model {
	ready := make([]Model, 0, len(models))
	for _, m := range models {
		if m.Available {
			ready = append(ready, m)
		}
	}
	for i := range ready {
		if ready[i].ID == selection {
			return &ready[i]
		}
	}
	for i := range ready {
		if ready[i].Provider == "neorouter" && ready[i].ModelID == "auto:default" {
			return &ready[i]
		}
	}
	for i := range ready {
		if ready[i].ModelID == "jev-1.13.0" || ready[i].ModelID == "typesafe/jev-1.13" {
			return &ready[i]
		}
	}
	if len(ready) > 0 {
		return &ready[0]
	}
	return nil
}
func number(v any) (float64, bool) {
	switch x := v.(type) {
	case float64:
		return x, !math.IsNaN(x) && !math.IsInf(x, 0)
	case int:
		return float64(x), true
	case json.Number:
		n, e := x.Float64()
		return n, e == nil && !math.IsNaN(n) && !math.IsInf(n, 0)
	}
	return 0, false
}
func probability(v any) bool { n, ok := number(v); return ok && n >= 0 && n <= 1 }
func validAnswer(question, answer any) bool {
	q, ok := question.(map[string]any)
	if !ok {
		return false
	}
	a, ok := answer.(map[string]any)
	if !ok {
		return false
	}
	questionType, qok := q["type"].(string)
	answerType, aok := a["type"].(string)
	if !qok || !aok || questionType != answerType {
		return false
	}
	switch questionType {
	case "noul":
		return probability(a["noul"])
	case "score":
		_, ok := number(a["score"])
		return ok
	case "choice":
		criteria, ok := q["criteria"].(map[string]any)
		if !ok {
			return false
		}
		choice, ok := a["choice"].(string)
		if !ok {
			return false
		}
		if _, ok := criteria[choice]; !ok || !probability(a["confidence"]) {
			return false
		}
		probabilities, ok := a["probabilities"].(map[string]any)
		if !ok {
			return false
		}
		for _, v := range probabilities {
			if !probability(v) {
				return false
			}
		}
		return true
	}
	return false
}

// Decide returns nil when the feature is off, unavailable or the provider's
// answers fail validation. Cancellation is propagated to the caller.
func (s *Service) Decide(ctx context.Context, req Request) (map[string]any, error) {
	if req.UserID <= 0 {
		return nil, nil
	}
	start := time.Now()
	selection, err := s.Source.Selection(ctx, req.UserID, req.AgentID)
	if err != nil {
		if ctx.Err() != nil {
			return nil, ctx.Err()
		}
		return nil, nil
	}
	if selection == "off" {
		return nil, nil
	}
	models, err := s.Source.Models(ctx, req.UserID, req.AgentID)
	if err != nil {
		if ctx.Err() != nil {
			return nil, ctx.Err()
		}
		return nil, nil
	}
	model := choose(selection, models)
	if model == nil {
		return nil, nil
	}
	provider, err := s.Source.Provider(ctx, req.UserID, req.AgentID, *model)
	if err == nil {
		var response map[string]any
		response, err = provider.Decide(ctx, llm.DecisionRequest{Model: model.ModelID, State: req.State, Questions: req.Questions, Timeout: 4 * time.Second})
		if err == nil {
			answers, ok := response["answers"].(map[string]any)
			if ok {
				for key, q := range req.Questions {
					if !validAnswer(q, answers[key]) {
						ok = false
						break
					}
				}
			}
			if ok {
				if req.RunID != "" && s.Observer != nil {
					s.Observer.Used(ctx, req, *model, response, time.Since(start))
				}
				return answers, nil
			}
		}
	}
	if ctx.Err() != nil {
		return nil, ctx.Err()
	}
	if err != nil && s.Observer != nil {
		s.Observer.Failed(ctx, req, *model, err)
	}
	return nil, nil
}

// Ready reports whether a SystemOne model can answer for this agent now
// (isSystemOneReady): the feature is on and an available model resolves.
// Only cancellation is an error.
func (s *Service) Ready(ctx context.Context, userID int64, agentID string) (bool, error) {
	if userID <= 0 {
		return false, nil
	}
	selection, err := s.Source.Selection(ctx, userID, agentID)
	if err != nil || selection == "off" {
		return false, ctx.Err()
	}
	models, err := s.Source.Models(ctx, userID, agentID)
	if err != nil {
		return false, ctx.Err()
	}
	return choose(selection, models) != nil, nil
}
