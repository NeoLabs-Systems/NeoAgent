package sockets

import (
	"context"
	"strings"

	"github.com/NeoLabs-Systems/neolabs-go/realtime"
)

func (c *client) messagingFail(op string, err error) {
	c.srv.log.Error("[WS] "+op+" failed", "userId", c.userID, "error", err)
	c.failWith("messaging:error", "error", err)
}

func (c *client) messagingError(message string) {
	_ = c.sock.Emit("messaging:error", map[string]any{"error": message})
}

// platformOf is the lower-cased platform name of a payload.
func platformOf(data map[string]any) string {
	return strings.ToLower(optionalString(data["platform"], 64))
}

func (c *client) messagingConnect(ev *realtime.Event) {
	data := ev.Object(0)
	platform := platformOf(data)
	if platform == "" {
		c.messagingError("platform is required")
		return
	}
	agentID, err := c.agentFor(agentCandidate(data))
	if err != nil {
		c.messagingFail("messaging:connect", err)
		return
	}
	c.srv.log.Info("[WS] messaging:connect requested", "userId", c.userID, "platform", platform)
	result, err := c.srv.cfg.Services.Messaging.Connect(context.Background(), c.userID, platform, asObject(data["config"]), agentID)
	if err != nil {
		c.messagingFail("messaging:connect", err)
		return
	}
	_ = c.sock.Emit("messaging:connect_result", result)
}

func (c *client) messagingDisconnect(ev *realtime.Event) {
	data := ev.Object(0)
	platform := platformOf(data)
	if platform == "" {
		c.messagingError("platform is required")
		return
	}
	agentID, err := c.agentFor(agentCandidate(data))
	if err != nil {
		c.messagingFail("messaging:disconnect", err)
		return
	}
	c.srv.log.Info("[WS] messaging:disconnect requested", "userId", c.userID, "platform", platform)
	result, err := c.srv.cfg.Services.Messaging.Disconnect(context.Background(), c.userID, platform, agentID)
	if err != nil {
		c.messagingFail("messaging:disconnect", err)
		return
	}
	_ = c.sock.Emit("messaging:disconnect_result", result)
}

func (c *client) messagingSend(ev *realtime.Event) {
	data := ev.Object(0)
	platform := platformOf(data)
	to := optionalString(data["to"], 512)
	content, _ := data["content"].(string)
	switch {
	case platform == "":
		c.messagingError("platform is required")
		return
	case to == "":
		c.messagingError("recipient is required")
		return
	case content == "" || utf16Len(content) > maxMessageChars:
		c.messagingError("content must be 1-12000 characters")
		return
	}
	agentID, err := c.agentFor(agentCandidate(data))
	if err != nil {
		c.messagingFail("messaging:send", err)
		return
	}
	c.srv.log.Info("[WS] messaging:send requested", "userId", c.userID, "platform", platform, "to", to, "contentLength", utf16Len(content))
	result, err := c.srv.cfg.Services.Messaging.Send(context.Background(), c.userID, platform, to, content, agentID, optionalString(data["mediaPath"], 1024))
	if err != nil {
		c.messagingFail("messaging:send", err)
		return
	}
	_ = c.sock.Emit("messaging:sent", result)
}

func (c *client) messagingStatus(ev *realtime.Event) {
	agentID, err := c.agentFor(agentCandidate(ev.Object(0)))
	var statuses any
	if err == nil {
		statuses, err = c.srv.cfg.Services.Messaging.Statuses(c.userID, agentID)
	}
	if err != nil {
		c.messagingFail("messaging:status", err)
		return
	}
	_ = c.sock.Emit("messaging:status", statuses)
}
