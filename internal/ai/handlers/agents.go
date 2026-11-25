package handlers

import (
	"context"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
)

var agentHandlers = map[string]handler{
	"spawn_subagent":    spawnSubagent,
	"delegate_to_agent": delegateToAgent,
	"agent_task":        agentTask,
	"create_agent":      createAgent,
	"list_subagents":    listSubagents,
	"wait_subagent":     waitSubagent,
	"cancel_subagent":   cancelSubagent,
}

func spawnSubagent(ctx context.Context, c *call) (any, error) {
	e, err := c.engine()
	if err != nil {
		return errResult("Sub-agent failed: " + err.Error()), nil
	}
	var allowed []string
	if list, ok := c.args["tools"].([]any); ok {
		allowed = make([]string, 0, len(list))
		for _, t := range list {
			allowed = append(allowed, dyn.String(t))
		}
	}
	selected := allowed
	if !dyn.Truthy(c.args["tools"]) {
		selected = e.ActiveToolNames(c.run.RunID)
	}
	required := dyn.List(c.args["required_artifacts"])
	if !dyn.Truthy(c.args["required_artifacts"]) {
		required = []any{}
	}
	result, err := e.SpawnSubagent(ctx, c.run, SubagentRequest{
		Task:              str(c.args["task"]),
		Model:             dyn.Str(c.args["model"]),
		Context:           truthyOrNil(c.args["context"]),
		RequiredArtifacts: required,
		AllowedTools:      allowed,
		Write:             c.args["write"] == true,
		MaxTurns:          c.args["max_turns"],
		MaxTokens:         c.args["max_tokens"],
		MaxSeconds:        c.args["max_seconds"],
		SelectedTools:     selected,
	})
	if err != nil {
		if ctx.Err() != nil {
			return nil, ctx.Err()
		}
		return errResult("Sub-agent failed: " + err.Error()), nil
	}
	return result, nil
}

func delegateToAgent(ctx context.Context, c *call) (any, error) {
	e, err := c.engine()
	if err != nil {
		return errResult("delegate_to_agent failed: " + err.Error()), nil
	}
	result, err := e.DelegateTask(ctx, c.run, c.args)
	if err != nil {
		return errResult("delegate_to_agent failed: " + err.Error()), nil
	}
	return result, nil
}

func agentTask(ctx context.Context, c *call) (any, error) {
	e, err := c.engine()
	if err != nil {
		return errResult("agent_task failed: " + err.Error()), nil
	}
	result, err := e.AgentTaskAction(ctx, c.run, c.args)
	if err != nil {
		if ctx.Err() != nil {
			return nil, ctx.Err()
		}
		return errResult("agent_task failed: " + err.Error()), nil
	}
	return result, nil
}

func createAgent(ctx context.Context, c *call) (any, error) {
	if c.b.d.Agents == nil {
		return errResult("create_agent failed: agent creation is unavailable"), nil
	}
	already := c.b.d.Engine != nil && c.b.d.Engine.CreatedAgentInRun(c.run.RunID)
	result, err := c.b.d.Agents.CreateForRun(ctx, c.run, already, c.args)
	if err != nil {
		return errResult("create_agent failed: " + err.Error()), nil
	}
	if dyn.Truthy(result["error"]) {
		return result, nil
	}
	id := dyn.Str(result["id"])
	if c.b.d.Engine != nil {
		c.b.d.Engine.AgentCreated(ctx, c.run, id)
		c.b.d.Engine.Emit(c.run.UserID, "agents:changed", dyn.Map{"agentId": id})
	}
	return dyn.Ordered{
		{Key: "created", Value: true},
		{Key: "agent", Value: dyn.Ordered{{Key: "id", Value: result["id"]}, {Key: "slug", Value: result["slug"]}, {Key: "name", Value: result["displayName"]}}},
		{Key: "note", Value: "The user can see, change or archive it in their agent list. Hand it work with delegate_to_agent."},
	}, nil
}

func listSubagents(ctx context.Context, c *call) (any, error) {
	e, err := c.engine()
	if err == nil {
		var list any
		if list, err = e.ListSubagents(c.run.RunID); err == nil {
			return dyn.Map{"subagents": list}, nil
		}
	}
	return errResult("list_subagents failed for run " + c.run.RunID + ": " + err.Error()), nil
}

func orDefault(v any, fallback string) string {
	if dyn.Truthy(v) {
		return dyn.String(v)
	}
	return fallback
}

func waitSubagent(ctx context.Context, c *call) (any, error) {
	e, err := c.engine()
	if err == nil {
		var result any
		if result, err = e.WaitSubagent(ctx, c.run.RunID, str(c.args["handle"]), c.args["timeout_ms"]); err == nil {
			return result, nil
		}
		if ctx.Err() != nil {
			return nil, ctx.Err()
		}
	}
	return errResult("wait_subagent failed for run " + c.run.RunID + ", handle " + orDefault(c.args["handle"], "unknown") + ", timeout " + orDefault(c.args["timeout_ms"], "default") + ": " + err.Error()), nil
}

func cancelSubagent(ctx context.Context, c *call) (any, error) {
	e, err := c.engine()
	if err == nil {
		var result any
		if result, err = e.CancelSubagent(ctx, c.run.RunID, str(c.args["handle"])); err == nil {
			return result, nil
		}
	}
	return errResult("cancel_subagent failed for run " + c.run.RunID + ", handle " + orDefault(c.args["handle"], "unknown") + ": " + err.Error()), nil
}
