package systemone

import (
	"context"
	"errors"
	"testing"

	"github.com/NeoLabs-Systems/neolabs-go/llm"
)

type source struct {
	setting string
	models  []Model
	client  *decider
}

func (s *source) Selection(context.Context, int64, string) (string, error) { return s.setting, nil }
func (s *source) Models(context.Context, int64, string) ([]Model, error)   { return s.models, nil }
func (s *source) Provider(context.Context, int64, string, Model) (llm.Decider, error) {
	return s.client, nil
}

type decider struct {
	request  llm.DecisionRequest
	response map[string]any
	err      error
}

func (d *decider) DecisionModels(context.Context) ([]llm.Model, error) { return nil, nil }
func (d *decider) Decide(_ context.Context, r llm.DecisionRequest) (map[string]any, error) {
	d.request = r
	return d.response, d.err
}
func TestDecisionSelectionAndValidation(t *testing.T) {
	d := &decider{response: map[string]any{"answers": map[string]any{"speak": map[string]any{"type": "noul", "noul": 0.8}, "urgency": map[string]any{"type": "score", "score": 1.0}}}}
	src := &source{setting: "auto", models: []Model{{ID: "first", ModelID: "first", Available: true}, {ID: "router", ModelID: "auto:default", Provider: "neorouter", Available: true}}, client: d}
	svc := Service{Source: src}
	req := Request{UserID: 1, Questions: map[string]any{"speak": map[string]any{"type": "noul"}, "urgency": map[string]any{"type": "score"}}}
	answers, err := svc.Decide(context.Background(), req)
	if err != nil || answers == nil || d.request.Model != "auto:default" || d.request.Questions["speak"] == nil {
		t.Fatal(answers, err, d.request)
	}
	d.response["answers"].(map[string]any)["speak"] = map[string]any{"type": "noul", "noul": 1.2}
	answers, err = svc.Decide(context.Background(), req)
	if err != nil || answers != nil {
		t.Fatal(answers, err)
	}
	src.setting = "off"
	d.err = errors.New("not called")
	answers, err = svc.Decide(context.Background(), req)
	if err != nil || answers != nil {
		t.Fatal(answers, err)
	}
}
func TestChoiceAnswerMustMatchCriteria(t *testing.T) {
	q := map[string]any{"type": "choice", "criteria": map[string]any{"a": "one"}}
	if !validAnswer(q, map[string]any{"type": "choice", "choice": "a", "confidence": 0.5, "probabilities": map[string]any{"a": 0.5}}) {
		t.Fatal("valid answer rejected")
	}
	if validAnswer(q, map[string]any{"type": "choice", "choice": "b", "confidence": 0.5, "probabilities": map[string]any{"b": 0.5}}) {
		t.Fatal("unknown choice accepted")
	}
}
