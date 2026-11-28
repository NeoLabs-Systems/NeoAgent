package wiring

import (
	"context"
	"errors"
	"fmt"

	"github.com/NeoLabs-Systems/neoagent/internal/agent"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/handlers"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/systemone"
	"github.com/NeoLabs-Systems/neoagent/internal/behavior"
	"github.com/NeoLabs-Systems/neoagent/internal/memory"
	"github.com/NeoLabs-Systems/neoagent/internal/messaging"
)

// behaviorInference is the agent engine and SystemOne as the behavior
// pipeline's gate uses them.
type behaviorInference struct {
	link      *engineLink
	systemOne func() *systemone.Service
}

func (b behaviorInference) InferStructured(ctx context.Context, req behavior.StructuredRequest) (behavior.StructuredAnswer, error) {
	e := b.link.get()
	if e == nil {
		return behavior.StructuredAnswer{}, errEngineNotReady
	}
	answer, err := e.InferStructured(ctx, agent.StructuredRequest{UserID: req.UserID, AgentID: req.AgentID, ModelID: req.ModelID, Purpose: req.Purpose,
		System: req.System, Prompt: req.Prompt, MaxTokens: req.MaxTokens})
	if err != nil {
		return behavior.StructuredAnswer{}, err
	}
	return behavior.StructuredAnswer{Parsed: answer.Parsed, Model: answer.Model, ModelSelectionID: answer.ModelSelectionID, Usage: answer.Usage}, nil
}

func (b behaviorInference) Decide(ctx context.Context, req behavior.DecisionRequest) (map[string]any, error) {
	svc := b.systemOne()
	if svc == nil {
		return nil, nil
	}
	return svc.Decide(ctx, systemone.Request{UserID: req.UserID, AgentID: req.AgentID, Phase: req.Phase, State: req.State, Questions: req.Questions})
}

func (b behaviorInference) SystemOneReady(ctx context.Context, userID int64, agentID string) (bool, error) {
	svc := b.systemOne()
	if svc == nil {
		return false, nil
	}
	return svc.Ready(ctx, userID, agentID)
}

// behaviorMemory recalls the memories a group chat shares.
type behaviorMemory struct{ mem *memory.Manager }

func (b behaviorMemory) RecallChannel(ctx context.Context, userID int64, agentID, query string, limit int, scopeID string) ([]behavior.Recalled, error) {
	results, err := b.mem.RecallMemory(ctx, userID, query, limit, memory.RecallOptions{AgentID: agentID, Scope: &memory.ScopeInput{Type: "channel", ID: scopeID}})
	if err != nil {
		return nil, err
	}
	out := make([]behavior.Recalled, len(results))
	for i, r := range results {
		out[i] = behavior.Recalled{ID: r.ID, Category: r.Category, Summary: r.Summary, Content: r.Content}
	}
	return out, nil
}

// behaviorSender delivers the pipeline's bubbles through the messaging manager.
type behaviorSender struct{ mgr func() *messaging.Manager }

func (b behaviorSender) Send(ctx context.Context, out behavior.Outgoing) (behavior.Sent, error) {
	mgr := b.mgr()
	if mgr == nil {
		return behavior.Sent{}, errors.New("messaging is not running")
	}
	result, err := mgr.SendAgentMessage(ctx, messaging.AgentSend{UserID: out.UserID, AgentID: out.AgentID, Platform: out.Platform, To: out.ChatID,
		Content: out.Content, MediaReference: out.MediaPath, RunID: out.RunID, DeliveryKind: out.Kind, Metadata: out.Metadata})
	if err != nil {
		return behavior.Sent{}, err
	}
	return behavior.Sent{Success: result["success"] != false, Suppressed: result["suppressed"] == true, Reason: dyn.Str(result["reason"]),
		Error: dyn.Str(result["error"]), Result: result["result"]}, nil
}

func (b behaviorSender) Typing(ctx context.Context, userID int64, agentID, platform, chatID string, on bool) {
	if mgr := b.mgr(); mgr != nil {
		mgr.SendTyping(ctx, userID, agentID, platform, chatID, on)
	}
}

// behaviorDelivery gives the send tools and the engine's final delivery the
// pipeline's reply delivery.
type behaviorDelivery struct{ p *behavior.Pipeline }

func (b behaviorDelivery) deliver(ctx context.Context, userID int64, agentID string, state *handlers.Behavior, content, mediaPath, runID string) (behavior.DeliverResult, error) {
	m, ok := state.Message.(*messaging.Message)
	if !ok || m == nil {
		return behavior.DeliverResult{}, fmt.Errorf("behavior delivery has no inbound message")
	}
	cfg, _ := state.Config.(*behavior.Effective)
	return b.p.DeliverReply(ctx, behavior.DeliverRequest{UserID: userID, AgentID: agentID, Message: m, Config: cfg, Content: content, MediaPath: mediaPath,
		RunID: runID, TurnEpoch: state.TurnEpoch})
}

// DeliverReply is handlers.BehaviorPipeline.
func (b behaviorDelivery) DeliverReply(ctx context.Context, userID int64, agentID string, state *handlers.Behavior, content, mediaPath, runID string) (handlers.BehaviorResult, error) {
	r, err := b.deliver(ctx, userID, agentID, state, content, mediaPath, runID)
	if err != nil {
		return handlers.BehaviorResult{}, err
	}
	out := handlers.BehaviorResult{Delivered: r.Delivered, Suppressed: r.Suppressed, Reason: r.Reason}
	if r.Delivery != nil {
		out.Delivery, out.DeliveredBubbles = r.Delivery, r.Delivery.DeliveredBubbles
	}
	return out, nil
}

// Deliver is agent.BehaviorDelivery: a messaging run's final answer.
func (b behaviorDelivery) Deliver(ctx context.Context, userID int64, agentID string, state any, content, runID string) (agent.BehaviorOutcome, error) {
	s, ok := state.(*handlers.Behavior)
	if !ok || s == nil || !s.Enabled {
		return agent.BehaviorOutcome{Skipped: true}, nil
	}
	r, err := b.deliver(ctx, userID, agentID, s, content, "", runID)
	if err != nil {
		return agent.BehaviorOutcome{}, err
	}
	out := agent.BehaviorOutcome{Delivered: r.Delivered, Suppressed: r.Suppressed, Reason: r.Reason, Content: r.Content}
	if r.Delivery != nil {
		out.DeliveredBubbles = r.Delivery.DeliveredBubbles
	}
	return out, nil
}
