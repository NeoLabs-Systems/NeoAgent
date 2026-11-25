package handlers

import (
	"context"
	"encoding/json"
	"fmt"
	"slices"
	"strings"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/ai"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/tools"
)

// call is one tool call on its way through the handlers.
type call struct {
	b      *Backend
	run    *Run
	name   string
	args   dyn.Map
	stepID string
}

type handler func(ctx context.Context, c *call) (any, error)

// Backend runs tool calls (ai.ToolBackend).
type Backend struct {
	d        Deps
	handlers map[string]handler

	mu   sync.Mutex
	diag map[string]map[string]diagnosticState
}

var _ ai.ToolBackend = (*Backend)(nil)

// New builds the backend.
func New(d Deps) *Backend {
	if d.Now == nil {
		d.Now = time.Now
	}
	b := &Backend{d: d, diag: map[string]map[string]diagnosticState{}}
	b.handlers = map[string]handler{}
	for _, group := range []map[string]handler{
		shellHandlers, browserHandlers, deviceHandlers(), webHandlers, sharingHandlers,
		memoryHandlers, messagingHandlers, fileHandlers, codingHandlers, skillHandlers,
		controlHandlers, agentHandlers, taskHandlers, mcpHandlers, mediaHandlers, dataHandlers,
	} {
		for name, h := range group {
			b.handlers[name] = h
		}
	}
	return b
}

// Handles reports whether a built-in handler owns the tool.
func (b *Backend) Handles(name string) bool {
	_, ok := b.handlers[name]
	return ok
}

// ForgetRun drops what the backend kept for a finished run.
func (b *Backend) ForgetRun(runID string) {
	b.mu.Lock()
	delete(b.diag, runID)
	b.mu.Unlock()
}

// Execute runs one call (executeTool of tools/index.js). Run limits were
// already checked by the loop. The result is a JSON document; an error is a
// failure the tool did not report in its result, or the run's cancellation.
func (b *Backend) Execute(ctx context.Context, s *ai.Session, aiCall ai.Call, stepID string) (any, error) {
	run := b.runFor(s)
	args := aiCall.Arguments
	if args == nil {
		args = dyn.Map{}
	}
	result, err := b.execute(ctx, run, aiCall.Name, args, stepID, b.fileArgs(s, aiCall.Name))
	if err != nil {
		return nil, err
	}
	return normalize(result)
}

// fileArgs are the arguments of a tool that name a file in the agent's
// workspace (metadata fileArgs).
func (b *Backend) fileArgs(s *ai.Session, name string) []string {
	if b.d.Tools == nil {
		return nil
	}
	var def *tools.Definition
	if s != nil {
		for _, list := range [][]tools.Definition{s.Catalog, s.Tools} {
			for i := range list {
				if list[i].Name == name {
					def = &list[i]
					break
				}
			}
			if def != nil {
				break
			}
		}
	}
	return b.d.Tools.Meta(name, def).FileArgs
}

// ExecuteFor runs a call outside the loop (sub-agent setup, tests).
func (b *Backend) ExecuteFor(ctx context.Context, run *Run, name string, args dyn.Map, stepID string) (any, error) {
	if args == nil {
		args = dyn.Map{}
	}
	result, err := b.execute(ctx, run, name, args, stepID, b.fileArgs(nil, name))
	if err != nil {
		return nil, err
	}
	return normalize(result)
}

func (b *Backend) runFor(s *ai.Session) *Run {
	if b.d.Engine != nil {
		if run := b.d.Engine.Run(s.RunID); run != nil {
			return run
		}
	}
	return &Run{UserID: s.UserID, AgentID: s.AgentID, RunID: s.RunID, TriggerType: s.TriggerType, TriggerSource: s.TriggerSource}
}

func (b *Backend) execute(ctx context.Context, run *Run, name string, args dyn.Map, stepID string, fileArgs []string) (any, error) {
	if run.Public != nil {
		if refusal := publicRefusal(run.Public, name, args); refusal != "" {
			return dyn.Map{"error": refusal}, nil
		}
	}
	// The runtime replaced runaway streamed arguments with this marker.
	if discarded, ok := args["_discarded"].(string); ok {
		return dyn.Map{"success": false, "error": discarded}, nil
	}
	// Files the agent made are fetched from its computer into owned artifacts
	// before the tool reads them.
	if len(fileArgs) > 0 && b.d.StageFiles != nil {
		staged, err := b.d.StageFiles(ctx, run, args, fileArgs)
		if err != nil {
			if ctx.Err() != nil {
				return nil, ctx.Err()
			}
			return dyn.Map{"error": err.Error()}, nil
		}
		args = staged
	}
	c := &call{b: b, run: run, name: name, args: args, stepID: stepID}
	if err := b.acquireComputerControl(c); err != nil {
		return nil, err
	}

	if b.d.Integrations != nil {
		result, owned, err := b.d.Integrations.Execute(ctx, run, name, args)
		if err != nil {
			return nil, err
		}
		if owned {
			return result, nil
		}
	}
	if result, ok, err := b.integrated(ctx, c); ok || err != nil {
		return result, err
	}
	if h, ok := b.handlers[name]; ok {
		return h(ctx, c)
	}
	return b.external(ctx, c)
}

func publicRefusal(scope *PublicScope, name string, args dyn.Map) string {
	if !scope.ToolNames[name] {
		return fmt.Sprintf("%s is not available when answering a public %s thread.", name, scope.Platform)
	}
	if name == "send_message" {
		if dyn.Truthy(args["media_path"]) {
			return "Attachments cannot be sent into a public thread."
		}
		platform := strings.TrimSpace(orString(args["platform"], scope.Platform))
		to := strings.TrimSpace(orString(args["to"], scope.ChatID))
		if platform != scope.Platform || to != scope.ChatID {
			return fmt.Sprintf("Replies from this run can only go to %s %s.", scope.Platform, scope.ChatID)
		}
	}
	return ""
}

func (b *Backend) acquireComputerControl(c *call) error {
	if b.d.Runtime == nil || b.d.Tools == nil {
		return nil
	}
	prereq := b.d.Tools.Meta(c.name, nil).Prerequisites
	if !slices.Contains(prereq, "computer") && !slices.Contains(prereq, "desktop") {
		return nil
	}
	id := c.run.RunID
	if id == "" {
		id = c.stepID
	}
	if id == "" {
		id = c.run.AgentID
	}
	return b.d.Runtime.AcquireControl(c.run.UserID, "agent", id, c.run.DeviceTarget)
}

// external runs a name the built-in registry does not own: MCP servers first,
// then skills, then a recoverable unknown-tool answer.
func (b *Backend) external(ctx context.Context, c *call) (any, error) {
	if b.d.MCP != nil {
		result, found, err := b.d.MCP.CallByName(ctx, c.run.UserID, c.run.AgentID, c.name, c.args)
		if err != nil {
			if ctx.Err() != nil {
				return nil, ctx.Err()
			}
			return dyn.Ordered{{Key: "error", Value: err.Error()}, {Key: "tool", Value: c.name}, {Key: "source", Value: "mcp"}}, nil
		}
		if found {
			return result, nil
		}
	}
	if b.d.Skills != nil {
		result, found, err := b.d.Skills.Execute(ctx, c.run, c.name, c.args)
		if err != nil {
			return nil, err
		}
		if found {
			return result, nil
		}
	}
	var suggestions []string
	if b.d.Engine != nil && c.run.RunID != "" {
		if found, err := b.d.Engine.SearchTools(ctx, c.run.RunID, c.name, nil); err == nil {
			for _, item := range dyn.List(dyn.Get(asMap(found), "results")) {
				if name := dyn.Str(dyn.Get(item, "name")); name != "" {
					suggestions = append(suggestions, name)
				}
			}
		}
	}
	recovery := "Use search_tools with a capability description, activate the result with activate_tools, then retry with the exact name."
	if len(suggestions) > 0 {
		recovery = "Closest available tools: " + strings.Join(suggestions, ", ") + ". Activate what you need with activate_tools, then retry with the exact name."
	}
	return dyn.Ordered{
		{Key: "error", Value: "Unknown tool: " + c.name + ". It is not part of this run's toolset."},
		{Key: "recovery", Value: recovery},
	}, nil
}

// normalize turns a result into plain JSON values (dyn.Map, []any, float64,
// string, bool, nil), the shape the loop's result shaping reads.
func normalize(v any) (any, error) {
	if v == nil {
		return nil, nil
	}
	raw, err := json.Marshal(v)
	if err != nil {
		return nil, err
	}
	var out any
	if err := json.Unmarshal(raw, &out); err != nil {
		return nil, err
	}
	return out, nil
}

// asMap reads a result of any Go shape as a JSON object.
func asMap(v any) dyn.Map {
	if m, ok := v.(dyn.Map); ok {
		return m
	}
	out, err := normalize(v)
	if err != nil {
		return nil
	}
	m, _ := out.(dyn.Map)
	return m
}

func errResult(msg string) dyn.Map { return dyn.Map{"error": msg} }

// failure is a caught exception: {error: message}, unless the run was
// cancelled.
func failure(ctx context.Context, err error) (any, error) {
	if ctx.Err() != nil {
		return nil, ctx.Err()
	}
	return errResult(err.Error()), nil
}

// orString is `value || fallback` read as a string.
func orString(v any, fallback string) string {
	if dyn.Truthy(v) {
		return dyn.String(v)
	}
	return fallback
}

// str is String(v ?? ”).
func str(v any) string {
	if v == nil {
		return ""
	}
	return dyn.String(v)
}

// spread is {...base, ...extra} with base's keys first.
func spread(base any, extra dyn.Ordered) dyn.Ordered {
	out := dyn.Ordered{}
	m := asMap(base)
	for _, k := range dyn.SortedKeys(m) {
		out = append(out, dyn.KV{Key: k, Value: m[k]})
	}
	for _, kv := range extra {
		out = out.Set(kv.Key, kv.Value)
	}
	return out
}
