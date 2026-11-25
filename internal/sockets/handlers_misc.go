package sockets

import (
	"context"
	"errors"
	"strings"

	"github.com/NeoLabs-Systems/neolabs-go/realtime"
)

func (c *client) mcpStatus(ev *realtime.Event) {
	agentID, err := c.agentFor(agentCandidate(ev.Object(0)))
	var status any
	if err == nil {
		status, err = c.srv.cfg.Services.MCP.Status(context.Background(), c.userID, agentID)
	}
	if err != nil {
		c.srv.log.Error("[WS] mcp:status failed", "userId", c.userID, "error", err)
		_ = c.sock.Emit("mcp:error", map[string]any{"message": "Unable to fetch MCP status.", "error": c.errorText(err)})
		return
	}
	_ = c.sock.Emit("mcp:status", status)
}

func (c *client) mcpTools(ev *realtime.Event) {
	data := ev.Object(0)
	agentID, err := c.agentFor(agentCandidate(data))
	var tools any
	if err == nil {
		if serverID := optionalString(data["serverId"], 256); serverID != "" {
			tools, err = c.srv.cfg.Services.MCP.ListTools(context.Background(), serverID, c.userID)
		} else {
			tools, err = c.srv.cfg.Services.MCP.AllTools(c.userID, agentID)
		}
	}
	if err != nil {
		c.srv.log.Error("[WS] mcp:tools failed", "userId", c.userID, "error", err)
		c.failWith("mcp:error", "error", err)
		return
	}
	_ = c.sock.Emit("mcp:tools", tools)
}

func (c *client) integrationsStatus(ev *realtime.Event) {
	integrations := c.srv.cfg.Services.Integrations
	agentID, err := c.agentFor(agentCandidate(ev.Object(0)))
	var providers any
	if err == nil {
		if integrations == nil {
			err = errors.New("Official integration manager is not available.")
		} else {
			providers, err = integrations.ListProviders(c.userID, agentID)
		}
	}
	if err != nil {
		c.srv.log.Error("[WS] integrations:status failed", "userId", c.userID, "error", err)
		c.failWith("error", "message", err)
		return
	}
	_ = c.sock.Emit("integrations:status", providers)
}

func (c *client) memoryRead(ev *realtime.Event) {
	mem := c.srv.cfg.Services.Memory
	agentID, err := c.agentFor(agentCandidate(ev.Object(0)))
	var memory, notes, logs any
	if err == nil {
		// readMemory and listDailyLogs are shared across the account's agents.
		memory, err = mem.Read(c.userID)
	}
	if err == nil {
		notes, err = mem.AssistantBehaviorNotes(c.userID, agentID)
	}
	if err == nil {
		logs, err = mem.DailyLogs(3, c.userID)
	}
	if err != nil {
		c.srv.log.Error("[WS] memory:read failed", "userId", c.userID, "error", err)
		c.failWith("error", "message", err)
		return
	}
	_ = c.sock.Emit("memory:data", map[string]any{
		"agentId": nullable(agentID), "memory": memory, "assistantBehaviorNotes": notes, "dailyLogs": logs,
	})
}

func (c *client) memorySearch(ev *realtime.Event) {
	data := ev.Object(0)
	query := ""
	if q, ok := data["query"].(string); ok {
		query = strings.TrimFunc(q, jsSpace)
	}
	if query == "" || utf16Len(query) > maxQueryChars {
		_ = c.sock.Emit("error", map[string]any{"message": "query must be 1-2000 characters"})
		return
	}
	agentID, err := c.agentFor(agentCandidate(data))
	var results any
	if err == nil {
		results, err = c.srv.cfg.Services.Memory.Search(context.Background(), query, c.userID, agentID)
	}
	if err != nil {
		c.srv.log.Error("[WS] memory:search failed", "userId", c.userID, "error", err)
		c.failWith("error", "message", err)
		return
	}
	_ = c.sock.Emit("memory:search_results", results)
}

// streamTarget is normalizeStreamPayload.
type streamTarget struct{ platform, deviceID string }

func streamPayload(raw map[string]any) (streamTarget, error) {
	platform := strings.ToLower(optionalString(raw["platform"], 32))
	if platform == "" {
		platform = "desktop"
	}
	switch platform {
	case "desktop", "android", "browser":
	default:
		return streamTarget{}, errors.New("platform must be desktop, android, or browser.")
	}
	deviceID := optionalString(firstTruthy(raw["deviceId"], raw["device_id"]), 256)
	if deviceID == "" && platform == "browser" {
		deviceID = "browser"
	}
	if deviceID == "" {
		return streamTarget{}, errors.New("deviceId is required.")
	}
	return streamTarget{platform, deviceID}, nil
}

func (c *client) streamSubscribe(ev *realtime.Event) {
	t, err := streamPayload(ev.Object(0))
	if err != nil {
		c.srv.log.Error("[WS] stream:subscribe failed", "userId", c.userID, "error", err)
		c.failWith("stream:error", "error", err)
		return
	}
	count := c.srv.streams.Subscribe(c.userID, t.deviceID, t.platform, c.sock.ID())
	_ = c.sock.Emit("stream:subscribed", map[string]any{"platform": t.platform, "deviceId": t.deviceID, "subscriberCount": count})
}

func (c *client) streamUnsubscribe(ev *realtime.Event) {
	t, err := streamPayload(ev.Object(0))
	if err != nil {
		c.srv.log.Error("[WS] stream:unsubscribe failed", "userId", c.userID, "error", err)
		c.failWith("stream:error", "error", err)
		return
	}
	count := c.srv.streams.Unsubscribe(c.userID, t.platform, t.deviceID, c.sock.ID())
	_ = c.sock.Emit("stream:unsubscribed", map[string]any{"platform": t.platform, "deviceId": t.deviceID, "subscriberCount": count})
}
