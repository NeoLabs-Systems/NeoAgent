package tasks

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"math"
	"slices"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/mobilesync"
	"github.com/NeoLabs-Systems/neoagent/internal/tasks/jsv"
)

// ---- the schedule, manual and webhook triggers ------------------------------

var scheduleAdapter = Adapter{
	Type:  "schedule",
	Label: "Schedule",
	ConfigHint: `{ mode: "recurring", cronExpression: "m h dom mon dow" } or { mode: "one_time", runAt: ISO datetime }; ` +
		`cron fields and runAt values without an offset are read in the user's timezone; 5-field cron only (seconds unsupported)`,
	Validate: func(vc *validation, config *jsv.Object) (*jsv.Object, error) {
		mode := jsv.Trim(jsv.Text(config.Val("mode")))
		if mode == "" {
			mode = "recurring"
			if jsv.Truthy(config.Val("runAt")) || jsv.Truthy(config.Val("run_at")) {
				mode = "one_time"
			}
		}
		if mode != "recurring" && mode != "one_time" {
			return nil, errors.New(`Schedule trigger mode must be "recurring" or "one_time".`)
		}
		if mode == "one_time" {
			runAt, ok, err := normalizeRunAt(pick(config, "runAt", "run_at"), vc.timeZone)
			if err != nil {
				return nil, err
			}
			if !ok {
				return nil, errors.New("one_time schedule requires runAt")
			}
			return jsv.NewObject().Set("mode", mode).Set("runAt", runAt), nil
		}
		expression, err := normalizeCronExpression(pick(config, "cronExpression", "cron_expression"))
		if err != nil {
			return nil, err
		}
		// finishOnTime starts the run its measured average duration early so it
		// finishes at the scheduled time instead of starting then.
		return jsv.NewObject().Set("mode", mode).Set("cronExpression", expression).
			Set("finishOnTime", config.Val("finishOnTime") == true || config.Val("finish_on_time") == true), nil
	},
	Summarize: func(config *jsv.Object) string {
		if config.Val("mode") == "one_time" {
			if runAt := config.Val("runAt"); jsv.Truthy(runAt) {
				return "One-time at " + jsv.String(runAt)
			}
			return "One-time"
		}
		if expression := jsv.Trim(jsv.Text(config.Val("cronExpression"))); expression != "" {
			return expression
		}
		return "Recurring schedule"
	},
}

var manualAdapter = Adapter{
	Type:       "manual",
	Label:      "Manual Trigger",
	ConfigHint: "{} — runs only when the user presses Run",
	Validate:   func(*validation, *jsv.Object) (*jsv.Object, error) { return jsv.NewObject(), nil },
	Summarize:  func(*jsv.Object) string { return "Manual run only" },
}

var webhookAdapter = Adapter{
	Type:       "webhook",
	Label:      "Signed Webhook",
	ConfigHint: "{ sourceLabel? }",
	Validate: func(_ *validation, config *jsv.Object) (*jsv.Object, error) {
		label := jsv.Trim(jsv.Text(pick(config, "sourceLabel", "source_label")))
		return jsv.NewObject().Set("sourceLabel", orNil(label)), nil
	},
	Summarize: func(config *jsv.Object) string {
		if label := config.Val("sourceLabel"); jsv.Truthy(label) {
			return "Signed webhook from " + jsv.String(label)
		}
		return "Signed webhook"
	},
}

// ---- devices and the server's own events -----------------------------------

func coordinate(v any, limit float64, name string) (float64, error) {
	n, err := optionalNumber(v)
	if err != nil {
		return 0, err
	}
	f, ok := n.(float64)
	if !ok || math.Abs(f) > limit {
		return 0, fmt.Errorf("A valid %s is required.", name)
	}
	return f, nil
}

var geofenceAdapter = Adapter{
	Type:  "geofence_event",
	Label: "Location Geofence",
	ConfigHint: "{ label, latitude, longitude, radiusMeters?: 50-50000 (default 200), transition: enter|exit }; " +
		"needs location tracking on the phone",
	Validate: func(_ *validation, config *jsv.Object) (*jsv.Object, error) {
		transition := strings.ToLower(trimText(config.Val("transition"), 10))
		if transition == "" {
			transition = "enter"
		}
		if transition != "enter" && transition != "exit" {
			return nil, errors.New(`Geofence transition must be "enter" or "exit".`)
		}
		label := trimText(config.Val("label"), 120)
		if label == "" {
			label = "Place"
		}
		latitude, err := coordinate(config.Val("latitude"), 90, "latitude")
		if err != nil {
			return nil, err
		}
		longitude, err := coordinate(config.Val("longitude"), 180, "longitude")
		if err != nil {
			return nil, err
		}
		radius := boundedInteger(coalesce(config, "radiusMeters", "radius_meters"), 200, 50, 50000)
		return jsv.NewObject().Set("label", label).Set("latitude", latitude).Set("longitude", longitude).
			Set("radiusMeters", float64(radius)).Set("transition", transition), nil
	},
	Summarize: func(config *jsv.Object) string {
		verb := "Arriving at"
		if config.Val("transition") == "exit" {
			verb = "Leaving"
		}
		return summaryParts(verb, config.Val("label"), jsv.String(config.Val("radiusMeters"))+" m")
	},
	Event: &EventSpec{
		Source: "runtime", Name: "geofence",
		Matches: func(config *jsv.Object, event map[string]any, task taskRow) bool {
			return jsv.Number(event["fenceId"]) == float64(task.ID) && event["transition"] == config.Val("transition")
		},
		ToPayload: func(event map[string]any, config *jsv.Object) Payload {
			name := "geofence_entered"
			if event["transition"] == "exit" {
				name = "geofence_exited"
			}
			return Payload{
				Fingerprint: fmt.Sprintf("geofence:%s:%s:%s", jsv.String(event["fenceId"]), jsv.String(event["transition"]), jsv.String(event["occurredAt"])),
				Timestamp:   str(event["occurredAt"]),
				Context: jsv.NewObject().Set("triggerEvent", jsv.NewObject().
					Set("provider", "location").Set("event", name).Set("label", config.Val("label")).
					Set("latitude", event["latitude"]).Set("longitude", event["longitude"]).Set("occurredAt", event["occurredAt"])),
			}
		},
	},
}

// notificationFingerprint identifies the notification rather than the
// delivery: a phone that retries sends identical fields.
func notificationFingerprint(event map[string]any) string {
	list := []any{event["appPackage"], event["title"], event["body"], event["actionTaken"]}
	sum := sha256.Sum256([]byte(jsv.Stringify(list)))
	return "notification:" + hex.EncodeToString(sum[:])[:32]
}

var androidNotificationAdapter = Adapter{
	Type:       "android_notification_received",
	Label:      "Android Notification Received",
	ConfigHint: `{ appPackage?: e.g. "com.whatsapp" }`,
	Validate: func(_ *validation, config *jsv.Object) (*jsv.Object, error) {
		return jsv.NewObject().Set("appPackage", trimText(pick(config, "appPackage", "app_package"), 200)), nil
	},
	Summarize: func(config *jsv.Object) string {
		parts := []string{"Android Notification"}
		if pkg := config.Val("appPackage"); jsv.Truthy(pkg) {
			parts = append(parts, "app: "+jsv.String(pkg))
		}
		return strings.Join(parts, " · ")
	},
	Event: &EventSpec{
		Source: "runtime", Name: "android_notification",
		Matches: func(config *jsv.Object, event map[string]any, _ taskRow) bool {
			pkg := config.Val("appPackage")
			return !jsv.Truthy(pkg) || pkg == event["appPackage"]
		},
		ToPayload: func(event map[string]any, _ *jsv.Object) Payload {
			return Payload{
				Fingerprint: notificationFingerprint(event),
				Timestamp:   str(event["receivedAt"]),
				Context: jsv.NewObject().Set("triggerEvent", jsv.NewObject().
					Set("provider", "android_notification").Set("appPackage", event["appPackage"]).
					Set("title", event["title"]).Set("body", event["body"]).Set("actionTaken", event["actionTaken"])),
			}
		},
	},
}

func matchingRecords(config *jsv.Object, event map[string]any) []mobilesync.HealthRecord {
	records, _ := event["records"].([]mobilesync.HealthRecord)
	above, below := config.Val("above"), config.Val("below")
	var out []mobilesync.HealthRecord
	for _, r := range records {
		if mobilesync.NormalizeMetricType(r.MetricType) != config.Val("metricType") {
			continue
		}
		if above == nil && below == nil {
			out = append(out, r)
			continue
		}
		if r.NumericValue == nil {
			continue
		}
		v := *r.NumericValue
		if (above == nil || v > jsv.Number(above)) && (below == nil || v < jsv.Number(below)) {
			out = append(out, r)
		}
	}
	return out
}

func recordTime(r mobilesync.HealthRecord) string {
	for _, t := range []*string{r.RecordedAt, r.EndTime, r.StartTime} {
		if t != nil && *t != "" {
			return *t
		}
	}
	return ""
}

func orNilString(s *string) any {
	if s == nil {
		return nil
	}
	return *s
}

// A phone sync carries many samples; a task runs once per sync, on the newest
// sample that matches.
var healthMetricAdapter = Adapter{
	Type:  "health_metric_recorded",
	Label: "Health Metric Recorded",
	ConfigHint: "{ metricType: e.g. heart_rate|steps|weight|sleep_session, above?: number, below?: number }; " +
		"arrives with each phone health sync",
	Validate: func(_ *validation, config *jsv.Object) (*jsv.Object, error) {
		metric, err := requiredText(pick(config, "metricType", "metric_type"), 80, "Health metric type is required.")
		if err != nil {
			return nil, err
		}
		above, err := optionalNumber(config.Val("above"))
		if err != nil {
			return nil, err
		}
		below, err := optionalNumber(config.Val("below"))
		if err != nil {
			return nil, err
		}
		return jsv.NewObject().Set("metricType", mobilesync.NormalizeMetricType(metric)).Set("above", above).Set("below", below), nil
	},
	Summarize: func(config *jsv.Object) string {
		return summaryParts("Health", config.Val("metricType"), when(config.Val("above") != nil, "above "+str(config.Val("above"))),
			when(config.Val("below") != nil, "below "+str(config.Val("below"))))
	},
	Event: &EventSpec{
		Source: "runtime", Name: "health_sync",
		Matches: func(config *jsv.Object, event map[string]any, _ taskRow) bool {
			return len(matchingRecords(config, event)) > 0
		},
		ToPayload: func(event map[string]any, config *jsv.Object) Payload {
			matches := matchingRecords(config, event)
			slices.SortStableFunc(matches, func(a, b mobilesync.HealthRecord) int { return strings.Compare(recordTime(a), recordTime(b)) })
			latest := matches[len(matches)-1]
			stamp := recordTime(latest)
			if stamp == "" {
				stamp = str(event["syncedAt"])
			}
			var value any
			if latest.NumericValue != nil {
				value = *latest.NumericValue
			}
			return Payload{
				Fingerprint: "health:" + str(config.Val("metricType")) + ":" + latest.RecordID,
				Timestamp:   stamp,
				Context: jsv.NewObject().Set("triggerEvent", jsv.NewObject().
					Set("provider", "health").Set("event", "metric_recorded").Set("metricType", config.Val("metricType")).
					Set("value", value).Set("text", orNilString(latest.TextValue)).Set("unit", orNilString(latest.Unit)).
					Set("recordedAt", orNil(recordTime(latest))).Set("matchingSamples", float64(len(matches)))),
			}
		},
	},
}

var wearableAdapter = Adapter{
	Type:       "wearable_connection_changed",
	Label:      "Wearable Connected or Disconnected",
	ConfigHint: "{ transition: connected|disconnected }",
	Validate: func(_ *validation, config *jsv.Object) (*jsv.Object, error) {
		transition := strings.ToLower(trimText(config.Val("transition"), 20))
		if transition == "" {
			transition = "disconnected"
		}
		if transition != "connected" && transition != "disconnected" {
			return nil, errors.New(`Wearable transition must be "connected" or "disconnected".`)
		}
		return jsv.NewObject().Set("transition", transition), nil
	},
	Summarize: func(config *jsv.Object) string { return summaryParts("Wearable", config.Val("transition")) },
	Event: &EventSpec{
		Source: "wearable", Name: "connection_changed",
		Matches: func(config *jsv.Object, event map[string]any, _ taskRow) bool {
			return config.Val("transition") == event["transition"]
		},
		ToPayload: func(event map[string]any, _ *jsv.Object) Payload {
			return Payload{
				Fingerprint: fmt.Sprintf("wearable:%s:%s:%s", jsv.String(event["deviceId"]), jsv.String(event["transition"]), jsv.String(event["occurredAt"])),
				Timestamp:   str(event["occurredAt"]),
				Context: jsv.NewObject().Set("triggerEvent", jsv.NewObject().
					Set("provider", "wearable").Set("event", event["transition"]).
					Set("deviceId", event["deviceId"]).Set("deviceLabel", event["deviceLabel"])),
			}
		},
	},
}

// maxChainDepth is how many runs in a row tasks that trigger each other may
// take before the chain stops.
const maxChainDepth = 3

var taskRunFinishedAdapter = Adapter{
	Type:       "task_run_finished",
	Label:      "Another Task Finished",
	ConfigHint: `{ sourceTaskId, outcome?: any|succeeded|failed }; each run receives the other task's result or error`,
	Validate: func(vc *validation, config *jsv.Object) (*jsv.Object, error) {
		source := jsv.Number(coalesce(config, "sourceTaskId", "source_task_id"))
		if !jsv.IsInteger(source) || source <= 0 {
			return nil, errors.New("Choose the task whose runs should trigger this one.")
		}
		if vc.taskID != 0 && int64(source) == vc.taskID {
			return nil, errors.New("A task cannot be triggered by its own runs.")
		}
		outcome := strings.ToLower(trimText(config.Val("outcome"), 20))
		if outcome == "" {
			outcome = "any"
		}
		if !slices.Contains([]string{"any", "succeeded", "failed"}, outcome) {
			return nil, errors.New("Outcome must be one of: any, succeeded, failed.")
		}
		return jsv.NewObject().Set("sourceTaskId", source).Set("outcome", outcome), nil
	},
	Summarize: func(config *jsv.Object) string {
		outcome := ""
		if config.Val("outcome") != "any" {
			outcome = str(config.Val("outcome"))
		}
		return summaryParts("After task", "#"+idText(config.Val("sourceTaskId")), outcome)
	},
	Event: &EventSpec{
		Source: "runtime", Name: "task_run_finished",
		Matches: func(config *jsv.Object, event map[string]any, task taskRow) bool {
			return jsv.Number(event["taskId"]) == jsv.Number(config.Val("sourceTaskId")) &&
				jsv.Number(event["taskId"]) != float64(task.ID) &&
				jsv.Number(event["chainDepth"]) <= maxChainDepth &&
				(config.Val("outcome") == "any" || config.Val("outcome") == event["outcome"])
		},
		ToPayload: func(event map[string]any, _ *jsv.Object) Payload {
			id := event["runId"]
			if !jsv.Truthy(id) {
				id = event["finishedAt"]
			}
			return Payload{
				Fingerprint: fmt.Sprintf("task_run:%s:%s", jsv.String(event["taskId"]), jsv.String(id)),
				Timestamp:   str(event["finishedAt"]),
				Context: jsv.NewObject().Set("triggerEvent", jsv.NewObject().
					Set("provider", "tasks").Set("event", "task_run_finished").Set("taskId", event["taskId"]).
					Set("taskName", event["taskName"]).Set("outcome", event["outcome"]).Set("result", event["result"]).
					Set("error", event["error"]).Set("chainDepth", event["chainDepth"])),
			}
		},
	},
}

var phoneAlarmAdapter = Adapter{
	Type: "phone_alarm", Label: "Phone Alarm", ProviderKey: "phone", AppKey: "alarms",
	ConfigHint: "{ connectionId }; runs when the next shared Android alarm is due",
	Validate: func(vc *validation, config *jsv.Object) (*jsv.Object, error) {
		return vc.connectionConfig(config, "phone", "alarms")
	},
	Summarize: func(*jsv.Object) string { return "Phone alarm" },
	Poll: &Poll{
		Cursor: "ordered", Baseline: "now",
		InitialCheckpoint: func() string { return jsv.ISO(time.Now()) },
		FetchRows: func(tool ToolFunc, _ *jsv.Object, _ string, now time.Time) ([]Row, error) {
			result, err := tool("phone_list_alarms", nil)
			if err != nil {
				return nil, err
			}
			var rows []Row
			for _, alarm := range objects(dig(result, "alarms")) {
				due, ok := jsv.ParseDate(alarm.Val("time"))
				if !ok || due.After(now) {
					continue
				}
				at := jsv.String(alarm.Val("time"))
				rows = append(rows, Row{
					Fingerprint: at + "|alarm", Timestamp: at,
					Context: jsv.NewObject().Set("triggerEvent", jsv.NewObject().Set("provider", "phone").Set("event", "alarm").Set("time", alarm.Val("time"))),
				})
			}
			return sortRows(rows, byFingerprint), nil
		},
	},
}
