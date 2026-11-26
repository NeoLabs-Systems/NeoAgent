package tasks

import (
	"context"
	"testing"

	"github.com/NeoLabs-Systems/neoagent/internal/mobilesync"
	"github.com/NeoLabs-Systems/neoagent/internal/tasks/jsv"
)

// Every event the server forwards reaches the task waiting for it, under the
// source names the wiring uses.
func TestForwardedEventsFireTheirTriggers(t *testing.T) {
	value := 130.0
	for _, c := range []struct {
		trigger, config, source, name string
		event                         map[string]any
	}{
		{"geofence_event", `{"transition":"enter"}`, "mobile", "geofence",
			map[string]any{"fenceId": int64(1), "transition": "enter", "occurredAt": "t"}},
		{"android_notification_received", `{"appPackage":"com.app"}`, "mobile", "android_notification",
			map[string]any{"appPackage": "com.app", "title": "hi", "receivedAt": "t"}},
		{"health_metric_recorded", `{"metricType":"heart_rate","above":100,"below":null}`, "mobilesync", "health_sync",
			map[string]any{"records": []mobilesync.HealthRecord{{MetricType: "heart_rate", RecordID: "r1", NumericValue: &value}}, "syncedAt": "t"}},
		{"messaging_member_joined", `{"platform":"discord","spaceId":"g"}`, "messaging", "member_joined",
			map[string]any{"platform": "discord", "spaceId": "g", "memberId": "m", "occurredAt": "t"}},
		{"messaging_member_left", `{"platform":"slack"}`, "messaging", "member_left",
			map[string]any{"platform": "slack", "spaceId": "g", "memberId": "m", "occurredAt": "t"}},
		{"messaging_reaction_added", `{"emoji":"+1"}`, "messaging", "reaction_added",
			map[string]any{"platform": "telegram", "chatId": "c", "emoji": "+1", "targetMessageId": "m", "timestamp": "t"}},
		{"messaging_platform_disconnected", `{"platform":"whatsapp"}`, "messaging", "platform_disconnected",
			map[string]any{"platform": "whatsapp", "reason": "logout", "occurredAt": "t"}},
		{"mcp_server_disconnected", `{"serverId":"7"}`, "mcp", "server_status",
			map[string]any{"serverId": int64(7), "status": "error", "previousStatus": "running", "changedAt": "t"}},
		{"wearable_connection_changed", `{"transition":"connected"}`, "wearable", "connection_changed",
			map[string]any{"deviceId": "d", "transition": "connected", "occurredAt": "t"}},
	} {
		t.Run(c.trigger, func(t *testing.T) {
			eng := &stubEngine{resp: RunResult{RunID: "run", Result: jsv.NewObject().Set("content", "ok")}}
			rt, db, _ := newTestRuntime(t, eng)
			if _, err := db.W.ExecContext(context.Background(), `INSERT INTO scheduled_tasks
				(id, user_id, agent_id, name, trigger_type, trigger_config, task_type, task_config, enabled)
				VALUES (1, 1, 'main', 'On event', ?, ?, 'agent_prompt', '{"prompt":"go"}', 1)`, c.trigger, c.config); err != nil {
				t.Fatal(err)
			}
			c.event["userId"] = int64(1)
			rt.HandleEvent(c.source, c.name, c.event)
			rt.Wait()
			if len(eng.runs) != 1 {
				t.Fatalf("runs = %d, want 1", len(eng.runs))
			}
		})
	}
}
