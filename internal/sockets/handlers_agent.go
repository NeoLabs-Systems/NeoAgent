package sockets

import (
	"context"
	"encoding/json"
	"errors"

	"github.com/NeoLabs-Systems/neolabs-go/publicerr"
	"github.com/NeoLabs-Systems/neolabs-go/realtime"
	"github.com/google/uuid"
)

const (
	maxAgentTaskChars = 50000
	maxMessageChars   = 12000
	maxQueryChars     = 2000
	webSource         = "web"
)

// handlers is the table of client events, by name.
func (c *client) handlers() map[string]handler {
	h := map[string]handler{
		"agent:run":            {c.agentRun, false},
		"agent:abort":          {c.agentAbort, false},
		"agent:history":        {c.agentHistory, false},
		"agent:run_detail":     {c.agentRunDetail, false},
		"messaging:connect":    {c.messagingConnect, true},
		"messaging:disconnect": {c.messagingDisconnect, true},
		"messaging:send":       {c.messagingSend, true},
		"messaging:status":     {c.messagingStatus, false},
		"voice:call_accept":    {c.voiceCallAccept, true},
		"voice:call_decline":   {c.voiceCallDecline, false},
		"voice:session_open":   {c.voiceSessionOpen, true},
		"mcp:status":           {c.mcpStatus, true},
		"mcp:tools":            {c.mcpTools, true},
		"integrations:status":  {c.integrationsStatus, false},
		"memory:read":          {c.memoryRead, false},
		"memory:search":        {c.memorySearch, true},
		"stream:subscribe":     {c.streamSubscribe, false},
		"stream:unsubscribe":   {c.streamUnsubscribe, true},
	}
	for name, v := range c.voiceSessionEvents() {
		h[name] = v
	}
	return h
}

// publicCode is publicErrorCode: an error's code, when it is one clients may see.
func publicCode(err error) string {
	var coded interface{ ErrorCode() string }
	if errors.As(err, &coded) {
		return publicerr.PublicCode(coded.ErrorCode())
	}
	return ""
}

func rateLimitOf(err error) any {
	var limited interface{ RateLimit() any }
	if errors.As(err, &limited) {
		return limited.RateLimit()
	}
	return nil
}

// runErrorPayload is the payload of run:error for a failed agent:run.
type runErrorPayload struct {
	RunID          *string `json:"runId"`
	Error          string  `json:"error"`
	Code           string  `json:"code,omitempty"`
	RateLimit      any     `json:"rateLimit,omitempty"`
	ConversationID *string `json:"conversationId"`
}

func nullable(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

// nullString is a TEXT column value: NULL for "".
func nullString(s string) any {
	if s == "" {
		return nil
	}
	return s
}

// webMeta and steeringMeta are the metadata JSON of a stored web message.
type webMeta struct {
	Platform string `json:"platform"`
}

type steeringMeta struct {
	Platform string  `json:"platform"`
	Steering bool    `json:"steering"`
	AgentID  *string `json:"agentId"`
}

func (c *client) insertUserMessage(ctx context.Context, agentID, runID, conversationID, task string, meta any) error {
	raw, err := json.Marshal(meta)
	if err != nil {
		return err
	}
	_, err = c.srv.cfg.DB.W.ExecContext(ctx,
		`INSERT INTO conversation_history (
			user_id, agent_id, agent_run_id, conversation_id, role, content, metadata
		) VALUES (?, ?, ?, ?, 'user', ?, ?)`,
		c.userID, nullString(agentID), nullString(runID), nullString(conversationID), task, string(raw))
	return err
}

func (c *client) agentRun(ev *realtime.Event) {
	ctx := context.Background()
	svc := c.srv.cfg.Services
	data := ev.Object(0)
	options := asObject(data["options"])
	task, _ := data["task"].(string)
	requestedConversationID := optionalString(options["conversationId"], 128)
	var runID string // known before the run starts so a failure is attributed to its run

	fail := func(err error) {
		c.srv.log.Error("[WS] agent:run failed", "userId", c.userID, "error", err)
		_ = c.sock.Emit("run:error", runErrorPayload{
			RunID:          nullable(runID),
			Error:          c.errorText(err),
			Code:           publicCode(err),
			RateLimit:      rateLimitOf(err),
			ConversationID: nullable(requestedConversationID),
		})
	}

	if requestedConversationID != "" {
		if err := svc.Conversations.AssertOwned(c.userID, requestedConversationID); err != nil {
			fail(err)
			return
		}
	}
	// {...options, agentId: data.agentId}: the top-level agentId wins and the
	// options' own agentId is ignored.
	agentID, err := c.agentFor(firstTruthy(data["agentId"], options["agent_id"]))
	if err != nil {
		fail(err)
		return
	}
	if task == "" {
		c.srv.log.Warn("[WS] agent:run rejected: invalid task payload", "userId", c.userID)
		_ = c.sock.Emit("error", map[string]any{"message": "Task must be a non-empty string"})
		return
	}
	if utf16Len(task) > maxAgentTaskChars {
		c.srv.log.Warn("[WS] agent:run rejected: task too long", "userId", c.userID)
		_ = c.sock.Emit("error", map[string]any{"message": "Message too long (max 50,000 characters)"})
		return
	}

	go func() {
		defer func() {
			if recovered := recover(); recovered != nil {
				c.srv.log.Error("[WS] handler panicked", "event", "agent:run", "userId", c.userID, "panic", recovered)
			}
		}()
		if svc.Commands != nil {
			res, err := svc.Commands.Dispatch(ctx, task, c.userID, agentID, webSource, c.sock.ID())
			if err != nil {
				fail(err)
				return
			}
			if res.Handled {
				for _, e := range res.Events {
					payload := e.Payload
					if payload == nil {
						payload = map[string]any{}
					}
					_ = c.sock.Emit(e.Name, payload)
				}
				content := res.Content
				if content == "" {
					content = "Done."
				}
				_ = c.sock.Emit("run:complete", map[string]any{"content": content})
				return
			}
		}

		if active, ok := svc.Engine.FindSteerableRun(c.userID, webSource); ok {
			queued := svc.Engine.EnqueueSteering(active.RunID, task, SteerOptions{
				Platform: webSource, ConversationID: active.ConversationID, SocketID: c.sock.ID(),
			})
			if queued {
				owner := active.AgentID
				if owner == "" {
					owner = agentID
				}
				if err := c.insertUserMessage(ctx, owner, active.RunID, active.ConversationID, task,
					steeringMeta{Platform: webSource, Steering: true, AgentID: nullable(agentID)}); err != nil {
					fail(err)
				}
				return
			}
		}

		window, err := svc.Chat.EnsureSettings(c.userID, agentID)
		if err != nil {
			fail(err)
			return
		}
		conversationID := requestedConversationID
		if conversationID == "" {
			if conversationID, err = svc.Conversations.DefaultWebID(c.userID, agentID); err != nil {
				fail(err)
				return
			}
		}
		if err := c.insertUserMessage(ctx, agentID, "", conversationID, task, webMeta{Platform: webSource}); err != nil {
			fail(err)
			return
		}
		chat, err := svc.Chat.WebContext(c.userID, window, agentID)
		if err != nil {
			fail(err)
			return
		}
		prior := priorMessages(chat.Recent, task, window)

		runID = uuid.NewString()
		result, err := svc.Engine.Run(ctx, c.userID, task, RunOptions{
			RunID: runID, AgentID: agentID, ConversationID: conversationID, TriggerSource: webSource,
			PriorMessages: prior, PriorSummary: chat.Summary,
			Client: clientRunOptions(options),
		})
		if err != nil {
			fail(err)
			return
		}
		c.srv.log.Info("[WS] agent:run completed", "userId", c.userID, "socketId", c.sock.ID(), "runId", result.RunID)
		if err := svc.Chat.StoreWebReply(c.userID, agentID, conversationID, result); err != nil {
			fail(err)
		}
	}()
}

// clientRunOptions is what a client may set when it starts a run: the other
// keys of its options (attachment paths, trust, trigger source, ...) are
// chosen by the server.
func clientRunOptions(options map[string]any) map[string]any {
	picked := map[string]any{}
	for _, key := range []string{"agentId", "agent_id", "conversationId"} {
		if v, ok := options[key]; ok {
			picked[key] = v
		}
	}
	return picked
}

// priorMessages is recentMessages without the task just stored, last `window`
// of them (Array.prototype.slice(-window): a window of 0 keeps all).
func priorMessages(recent []map[string]any, task string, window int) []map[string]any {
	kept := make([]map[string]any, 0, len(recent))
	for _, m := range recent {
		if role, _ := m["role"].(string); role == "user" {
			if content, _ := m["content"].(string); content == task {
				continue
			}
		}
		kept = append(kept, m)
	}
	start := len(kept) - window
	if window <= 0 {
		start = -window
	}
	return kept[min(max(start, 0), len(kept)):]
}

func (c *client) agentAbort(ev *realtime.Event) {
	data := ev.Object(0)
	runID := optionalString(data["runId"], 128)
	c.srv.log.Warn("[WS] agent:abort received", "userId", c.userID, "runId", runID)
	if err := c.srv.cfg.Services.Engine.Abort(runID, c.userID); err != nil {
		c.srv.log.Error("[WS] agent:abort failed", "userId", c.userID, "error", err)
		c.failWith("error", "message", err)
		return
	}
	_ = c.sock.Emit("agent:aborted", map[string]any{"runId": nullable(runID)})
}

func (c *client) agentHistory(ev *realtime.Event) {
	ctx := context.Background()
	data := ev.Object(0)
	fail := func(err error) {
		c.srv.log.Error("[WS] agent:history failed", "userId", c.userID, "error", err)
		c.failWith("error", "message", err)
	}
	agentID, err := c.agentFor(agentCandidate(data))
	if err != nil {
		fail(err)
		return
	}
	limit := boundedInt(data, "limit", 20, 1, 100)
	runs, err := queryRows(ctx, c.srv.cfg.DB.R,
		`SELECT * FROM agent_runs WHERE user_id = ? AND agent_id = ? ORDER BY created_at DESC LIMIT ?`,
		c.userID, nullString(agentID), limit)
	if err != nil {
		fail(err)
		return
	}
	records := c.srv.cfg.Services.Access.RunRecordsForUser(c.userID, RunRecords{Runs: runs})
	_ = c.sock.Emit("agent:history", map[string]any{"agentId": nullable(agentID), "runs": records.Runs})
}

// runDetailPayload is `{...runRecordsForUser(...), history}`; fields a caller
// of runRecordsForUser did not pass are left out like undefined in JSON.
type runDetailPayload struct {
	Run     any              `json:"run"`
	Steps   []map[string]any `json:"steps"`
	Events  []any            `json:"events"`
	History []map[string]any `json:"history"`
}

func (c *client) agentRunDetail(ev *realtime.Event) {
	ctx := context.Background()
	svc := c.srv.cfg.Services
	data := ev.Object(0)
	runID := optionalString(data["runId"], 128)
	if runID == "" {
		_ = c.sock.Emit("error", map[string]any{"message": "runId is required"})
		return
	}
	fail := func(err error) {
		c.srv.log.Error("[WS] agent:run_detail failed", "userId", c.userID, "error", err)
		c.failWith("error", "message", err)
	}
	db := c.srv.cfg.DB.R
	runs, err := queryRows(ctx, db, `SELECT * FROM agent_runs WHERE id = ? AND user_id = ?`, runID, c.userID)
	if err != nil {
		fail(err)
		return
	}
	if len(runs) == 0 {
		// Do not leak steps/history/events of a run the user does not own:
		// they are keyed only by run id, so the ownership check is the gate.
		_ = c.sock.Emit("agent:run_detail", runDetailPayload{Steps: []map[string]any{}, Events: []any{}, History: []map[string]any{}})
		return
	}
	steps, err := queryRows(ctx, db, `SELECT * FROM agent_steps WHERE run_id = ? ORDER BY step_index ASC`, runID)
	if err != nil {
		fail(err)
		return
	}
	history, err := queryRows(ctx, db,
		`SELECT * FROM conversation_history WHERE agent_run_id = ? AND user_id = ? ORDER BY created_at ASC`, runID, c.userID)
	if err != nil {
		fail(err)
		return
	}
	events, err := svc.RunEvents.List(ctx, runID)
	if err != nil {
		fail(err)
		return
	}
	rec := svc.Access.RunRecordsForUser(c.userID, RunRecords{Run: runs[0], Steps: steps, Events: events})
	_ = c.sock.Emit("agent:run_detail", runDetailPayload{Run: rec.Run, Steps: rec.Steps, Events: rec.Events, History: history})
}
