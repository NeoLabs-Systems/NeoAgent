package wiring

import (
	"context"
	"fmt"
	"sort"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/mcpserver"
	"github.com/NeoLabs-Systems/neoagent/internal/messaging"
	"github.com/NeoLabs-Systems/neoagent/internal/runtime"
)

// capabilityHealth reports the capabilities that need the model's attention
// (capabilityHealth.js summarizeCapabilityHealth): only a configured one that
// is unhealthy or degraded gets a line. Command, files, memory, search, skills
// and tasks are healthy whenever configured; Android reads a snapshot that
// never carries a start error; integrations are reported with the
// connected-integration line instead.
type capabilityHealth struct {
	computer  *runtime.Manager
	messaging *messaging.Manager
	mcp       *mcpserver.Manager
}

func (c capabilityHealth) Summary(ctx context.Context, userID int64, agentID, triggerSource, platform, deviceTarget string) string {
	var lines []string
	if line := c.browser(userID, deviceTarget); line != "" {
		lines = append(lines, line)
	}
	if line := c.messagingLine(ctx, userID, agentID, platform); line != "" {
		lines = append(lines, line)
	}
	if line := c.mcpLine(userID, agentID); line != "" {
		lines = append(lines, line)
	}
	return strings.Join(lines, "\n")
}

func (c capabilityHealth) browser(userID int64, deviceTarget string) string {
	if c.computer == nil {
		return ""
	}
	snapshot, err := c.computer.CapabilitySnapshot(userKey(userID), deviceTarget)
	if err != nil || snapshot == nil {
		return ""
	}
	var computer map[string]any
	snapshot.Decode("computer", &computer)
	if fmt.Sprint(computer["state"]) != "error" {
		return ""
	}
	summary := "Cloud computer failed to start."
	for _, key := range []string{"error", "lastError"} {
		if s, ok := computer[key].(string); ok && s != "" {
			summary = s
			break
		}
	}
	return "browser: unhealthy - " + summary
}

// messagingLine: the platform this run's message came through is proof it
// works right now, whatever a snapshot taken mid-reconnect says.
func (c capabilityHealth) messagingLine(ctx context.Context, userID int64, agentID, source string) string {
	if c.messaging == nil {
		return ""
	}
	statuses := map[string]string{}
	for name, v := range c.messaging.GetAllStatuses(ctx, userID, agentID) {
		status := "unknown"
		if m, ok := v.(map[string]any); ok {
			if s, ok := m["status"].(string); ok && s != "" {
				status = s
			}
		}
		statuses[name] = status
	}
	return messagingSummary(statuses, source)
}

func messagingSummary(statuses map[string]string, source string) string {
	if source != "" {
		statuses[source] = "connected"
	}
	if len(statuses) == 0 {
		return ""
	}
	names := make([]string, 0, len(statuses))
	for name := range statuses {
		names = append(names, name)
	}
	sort.Strings(names)
	connected, degraded := 0, false
	var parts []string
	for _, name := range names {
		status := statuses[name]
		parts = append(parts, name+": "+status)
		if status == "connected" {
			connected++
		}
		if s := strings.ToLower(status); s == "error" || s == "disconnected" {
			degraded = true
		}
	}
	if source != "" {
		parts = append(parts, "this conversation is on "+source)
	}
	healthy := connected > 0
	if healthy && !degraded {
		return ""
	}
	state := "unhealthy"
	if healthy {
		state = "degraded"
	}
	return "messaging: " + state + " - " + strings.Join(parts, "; ")
}

func (c capabilityHealth) mcpLine(userID int64, agentID string) string {
	if c.mcp == nil {
		return ""
	}
	statuses := c.mcp.Status(userID, agentID)
	if len(statuses) == 0 {
		return ""
	}
	running, degraded := 0, false
	for _, s := range statuses {
		if s.Status == "running" {
			running++
		} else if s.Status != "" {
			degraded = true
		}
	}
	healthy := running > 0
	if healthy && !degraded {
		return ""
	}
	state := "unhealthy"
	if healthy {
		state = "degraded"
	}
	return fmt.Sprintf("mcp: %s - %d/%d MCP servers are running.", state, running, len(statuses))
}
