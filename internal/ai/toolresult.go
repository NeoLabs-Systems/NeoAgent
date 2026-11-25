package ai

import (
	"fmt"
	"math"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/textx"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/tools"
)

// ClampText cuts text to max UTF-16 units and says how long it was.
func ClampText(text any, max int) string {
	str := dyn.Str(text)
	if textx.Len(str) <= max {
		return str
	}
	return fmt.Sprintf("%s\n...[truncated, %d chars total]", textx.Head(str, max), textx.Len(str))
}

// LineExcerpt keeps the first lines of a text, cut to maxChars.
func LineExcerpt(text any, maxLines, maxChars int) string {
	str := textx.Trim(dyn.Str(text))
	if str == "" {
		return ""
	}
	lines := strings.Split(str, "\n")
	if len(lines) > maxLines {
		lines = lines[:maxLines]
	}
	return ClampText(strings.Join(lines, "\n"), maxChars)
}

// ToRetainedText is the retained copy of a cut payload, read back by
// read_artifact line ranges: text keeps its own lines and over-long lines are
// split, so every part of the payload sits in a range that fits one result.
func ToRetainedText(payload any) string {
	text, ok := payload.(string)
	if !ok {
		text = dyn.StringifyIndent(payload)
	}
	lines := strings.Split(text, "\n")
	for i, line := range lines {
		var parts []string
		for textx.Len(line) > 1000 {
			parts = append(parts, textx.Head(line, 1000))
			line = textx.Slice(line, 1000, textx.Len(line))
		}
		lines[i] = strings.Join(append(parts, line), "\n")
	}
	return strings.Join(lines, "\n")
}

// RetainedResult says where the full copy of a cut result was kept.
type RetainedResult struct {
	ArtifactID string
	TotalLines int
}

// ResultOptions bound a compacted tool result.
type ResultOptions struct {
	SoftLimit, HardLimit int
	// RetainFullResult saves a payload that did not fit; it returns nil when it cannot.
	RetainFullResult func(payload any) *RetainedResult
}

func floorMul(n int, factor float64) int { return int(math.Floor(float64(n) * factor)) }

func clampEnvelope(envelope dyn.Ordered, hardLimit int) string {
	raw := dyn.Stringify(envelope)
	if textx.Len(raw) <= hardLimit {
		return raw
	}
	trimmed := append(dyn.Ordered(nil), envelope...)
	clampField := func(key string, limit int) {
		if v := trimmed.Get(key); dyn.Truthy(v) {
			trimmed = trimmed.Set(key, ClampText(v, limit))
		}
	}
	clampField("summary", max(200, hardLimit-300))
	clampField("stdout", max(160, hardLimit-400))
	clampField("stderr", max(120, hardLimit-400))
	clampField("content", max(160, hardLimit-400))
	clampField("excerpt", max(160, hardLimit-400))
	clampField("result", max(160, hardLimit-400))
	fallback := dyn.Stringify(trimmed)
	if textx.Len(fallback) <= hardLimit {
		return fallback
	}
	return ClampText(fallback, hardLimit)
}

func simpleStatusEnvelope(toolName string, result any, softLimit int) dyn.Ordered {
	status := "ok"
	if dyn.Get(result, "success") == false || dyn.Truthy(dyn.Get(result, "error")) {
		status = "error"
	}
	var count any
	if results, ok := dyn.Get(result, "results").([]any); ok {
		count = len(results)
	}
	inner := dyn.Ordered{
		{Key: "id", Value: dyn.Get(result, "id")},
		{Key: "key", Value: dyn.Get(result, "key")},
		{Key: "deleted", Value: dyn.Get(result, "deleted")},
		{Key: "sent", Value: dyn.Get(result, "sent")},
		{Key: "count", Value: count},
	}.Trim()
	return dyn.Ordered{
		{Key: "tool", Value: toolName},
		{Key: "status", Value: status},
		{Key: "message", Value: ClampText(or(dyn.Get(result, "message"), dyn.Get(result, "error")), floorMul(softLimit, 0.45))},
		{Key: "result", Value: ClampText(dyn.Stringify(inner), floorMul(softLimit, 0.35))},
	}.Trim()
}

// or is JavaScript's a || b: b whenever a is falsy, even if b is too.
func or(values ...any) any {
	for _, v := range values[:len(values)-1] {
		if dyn.Truthy(v) {
			return v
		}
	}
	return values[len(values)-1]
}

// resultCompactor carries what one compaction run shares between its helpers.
type resultCompactor struct {
	cutPayload any
	cut        bool
}

// excerpt clamps a value's text; a value that did not fit is remembered so the
// caller can keep it whole.
func (c *resultCompactor) excerpt(value any, maxChars int) string {
	raw, ok := value.(string)
	if !ok {
		raw = dyn.Stringify(value)
	}
	if textx.Len(raw) > maxChars {
		c.cutPayload, c.cut = value, true
	}
	return ClampText(raw, maxChars)
}

func (c *resultCompactor) markCut(payload any) { c.cutPayload, c.cut = payload, true }

// CompactToolResult cuts a tool result down to what goes back into the model's
// context. The caller's loop policy owns the budget: a result cut short here is
// re-fetched in slices by the model, which costs far more than the characters.
// What the model is not shown stays reachable: a model that only sees the cut
// tends to report the missing part as absent and stop, so the value that did not
// fit is retained in full when the caller can.
func (s *Shaper) CompactToolResult(toolName string, toolArgs dyn.Map, toolResult any, options ResultOptions) string {
	softLimit := max(500, orInt(options.SoftLimit, 1800))
	hardLimit := max(softLimit, orInt(options.HardLimit, 3200))
	if toolArgs == nil {
		toolArgs = dyn.Map{}
	}
	c := &resultCompactor{}
	shape := s.Tools.Meta(toolName, nil).ResultShape
	if shape == "" {
		shape = toolName
	}
	res := func(keys ...string) any { return dyn.Get(toolResult, keys...) }
	args := func(key string) any { return toolArgs[key] }
	soft := func(f float64) int { return floorMul(softLimit, f) }

	var envelope dyn.Ordered
	switch shape {
	case "command":
		envelope = c.command(toolName, toolArgs, toolResult, softLimit)
	case "artifact":
		content := textx.Trim(dyn.Str(res("content")))
		limit := soft(0.8)
		over := textx.Len(content) > limit
		var note any
		if over {
			note = "The requested lines did not all fit and the end of this range is cut. Read a narrower line range to see it."
		}
		envelope = dyn.Ordered{
			{Key: "tool", Value: toolName},
			{Key: "artifactId", Value: or(res("artifactId"), args("artifact_id"))},
			{Key: "contentType", Value: res("contentType")},
			{Key: "byteSize", Value: res("byteSize")},
			{Key: "binary", Value: res("binary") == true},
			{Key: "rangeShown", Value: res("rangeShown")},
			{Key: "matches", Value: res("matches")},
			{Key: "totalLines", Value: res("totalLines")},
			{Key: "truncated", Value: res("truncated") == true || over},
			{Key: "note", Value: note},
			{Key: "content", Value: ClampText(content, limit)},
			{Key: "error", Value: res("error")},
		}.Trim()
	case "file":
		var raw any
		if s, ok := toolResult.(string); ok {
			raw = s
		} else if v := res("content"); v != nil {
			raw = v
		} else {
			raw = ""
		}
		content := dyn.String(raw)
		limit := soft(0.85)
		truncated := res("truncated") == true || strings.Contains(content, "...[truncated") || textx.Len(textx.Trim(content)) > limit
		var note any
		if truncated {
			note = "Only part of the file was returned. Read a narrower line range to recover the omitted content."
		}
		envelope = dyn.Ordered{
			{Key: "tool", Value: toolName},
			{Key: "error", Value: res("error")},
			{Key: "path", Value: args("path")},
			{Key: "startLine", Value: args("start_line")},
			{Key: "endLine", Value: args("end_line")},
			{Key: "rangeShown", Value: res("rangeShown")},
			{Key: "totalLines", Value: res("totalLines")},
			{Key: "truncated", Value: truncated},
			{Key: "note", Value: note},
			{Key: "content", Value: ClampText(textx.Trim(content), limit)},
		}.Trim()
	case "files":
		sources := dyn.List(res("results"))
		limit := int(math.Floor(float64(softLimit) * 0.85 / float64(max(1, len(sources)))))
		wasTruncated := func(item any) bool {
			return dyn.Get(item, "truncated") == true || textx.Len(textx.Trim(dyn.Str(dyn.Get(item, "content")))) > limit
		}
		truncated := res("truncated") == true
		for _, item := range sources {
			truncated = truncated || wasTruncated(item)
		}
		var note any
		if truncated {
			note = "Only part of the requested file set was returned. Split the request or read individual files and narrower line ranges."
		}
		results := make([]any, len(sources))
		for i, item := range sources {
			results[i] = dyn.Ordered{
				{Key: "path", Value: or(dyn.Get(item, "path"), dyn.Get(item, "requestedPath"))},
				{Key: "requestedPath", Value: dyn.Get(item, "requestedPath")},
				{Key: "rangeShown", Value: dyn.Get(item, "rangeShown")},
				{Key: "truncated", Value: wasTruncated(item)},
				{Key: "error", Value: dyn.Get(item, "error")},
				{Key: "content", Value: ClampText(textx.Trim(dyn.Str(dyn.Get(item, "content"))), limit)},
			}.Trim()
		}
		envelope = dyn.Ordered{
			{Key: "tool", Value: toolName},
			{Key: "count", Value: or(res("count"), 0)},
			{Key: "truncated", Value: truncated},
			{Key: "note", Value: note},
			{Key: "results", Value: results},
		}.Trim()
	case "file_range":
		envelope = dyn.Ordered{
			{Key: "tool", Value: toolName},
			{Key: "status", Value: errorOrOK(toolResult)},
			{Key: "path", Value: or(res("path"), args("path"))},
			{Key: "startLine", Value: or(res("startLine"), args("start_line"))},
			{Key: "endLine", Value: or(res("endLine"), args("end_line"))},
			{Key: "replacedLines", Value: res("replacedLines")},
			{Key: "insertedLines", Value: res("insertedLines")},
			{Key: "totalLines", Value: res("totalLines")},
			{Key: "error", Value: res("error")},
		}.Trim()
	case "file_search":
		matches := dyn.List(res("matches"))
		count := or(res("count"), len(matches))
		maxMatches := max(6, softLimit/200)
		countN, _ := dyn.Int(count)
		truncated := res("truncated") == true || countN > maxMatches || len(matches) > maxMatches
		var note any
		if dyn.Truthy(res("note")) || truncated {
			note = or(res("note"), "Only the first matches are shown. Narrow the path or search pattern, or read the matched files around the relevant lines.")
		}
		shown := matches
		if len(shown) > maxMatches {
			shown = shown[:maxMatches]
		}
		items := make([]any, len(shown))
		for i, match := range shown {
			items[i] = dyn.Ordered{
				{Key: "file", Value: dyn.Get(match, "file")},
				{Key: "line", Value: dyn.Get(match, "line")},
				{Key: "content", Value: ClampText(dyn.Get(match, "content"), 160)},
			}.Trim()
		}
		envelope = dyn.Ordered{
			{Key: "tool", Value: toolName},
			{Key: "error", Value: res("error")},
			{Key: "count", Value: count},
			{Key: "truncated", Value: truncated},
			{Key: "note", Value: note},
			{Key: "matches", Value: items},
		}.Trim()
	case "page_extract":
		envelope = dyn.Ordered{
			{Key: "tool", Value: toolName},
			{Key: "task_relevance", Value: res("task_relevance")},
			{Key: "selector", Value: or(args("selector"), "body")},
			{Key: "attribute", Value: or(args("attribute"), "innerText")},
			{Key: "excerpt", Value: c.excerpt(or(res("result"), res("content"), toolResult), soft(0.85))},
		}.Trim()
	case "video_extract":
		transcript := textx.Trim(dyn.Str(res("transcript")))
		preview := LineExcerpt(transcript, 6, soft(0.35))
		if preview != transcript {
			c.markCut(transcript)
		}
		frame := dyn.Ordered{
			{Key: "url", Value: res("frameImage", "url")},
			{Key: "source", Value: res("frameImage", "source")},
		}.Trim()
		envelope = dyn.Ordered{
			{Key: "tool", Value: toolName},
			{Key: "platform", Value: res("platform")},
			{Key: "sourceUrl", Value: res("sourceUrl")},
			{Key: "resolvedUrl", Value: res("resolvedUrl")},
			{Key: "title", Value: ClampText(res("title"), soft(0.25))},
			{Key: "description", Value: ClampText(res("description"), soft(0.25))},
			{Key: "transcriptSource", Value: res("transcriptSource")},
			{Key: "transcriptPreview", Value: preview},
			{Key: "frameImage", Value: frame},
			{Key: "setupReady", Value: res("setup", "ready")},
			{Key: "warningCount", Value: len(dyn.List(res("warnings")))},
			{Key: "errorCount", Value: len(dyn.List(res("errors")))},
		}.Trim()
	case "device_ui":
		preview := or(res("preview"), []any{})
		envelope = dyn.Ordered{
			{Key: "tool", Value: toolName},
			{Key: "serial", Value: res("serial")},
			{Key: "nodeCount", Value: res("nodeCount")},
			{Key: "screenshotPath", Value: res("screenshotPath")},
			{Key: "uiDumpPath", Value: res("uiDumpPath")},
			{Key: "preview", Value: ClampText(textx.Head(dyn.Stringify(preview), soft(0.55)), soft(0.55))},
		}.Trim()
	case "device_apps":
		packages := dyn.List(res("packages"))
		if len(packages) > 20 {
			c.markCut(res("packages"))
		}
		first := packages
		if len(first) > 20 {
			first = first[:20]
		}
		names := make([]string, len(first))
		for i, p := range first {
			names[i] = dyn.String(p)
		}
		envelope = dyn.Ordered{
			{Key: "tool", Value: toolName},
			{Key: "serial", Value: res("serial")},
			{Key: "count", Value: res("count")},
			{Key: "preview", Value: LineExcerpt(strings.Join(names, "\n"), 20, soft(0.6))},
		}.Trim()
	case "device_shell":
		envelope = dyn.Ordered{
			{Key: "tool", Value: toolName},
			{Key: "serial", Value: res("serial")},
			{Key: "command", Value: args("command")},
			{Key: "screenshotPath", Value: res("screenshotPath")},
			{Key: "excerpt", Value: c.excerpt(or(res("stdout"), res("result"), toolResult), soft(0.85))},
		}.Trim()
	case "http":
		headers := dyn.Ordered{
			{Key: "contentType", Value: or(res("headers", "content-type"), res("headers", "Content-Type"))},
			{Key: "contentLength", Value: or(res("headers", "content-length"), res("headers", "Content-Length"))},
		}.Trim()
		envelope = dyn.Ordered{
			{Key: "tool", Value: toolName},
			{Key: "task_relevance", Value: res("task_relevance")},
			{Key: "status", Value: res("status")},
			{Key: "headers", Value: headers},
			{Key: "excerpt", Value: c.excerpt(or(res("body"), toolResult), soft(0.85))},
		}.Trim()
	case "task_list":
		taskList := dyn.List(res("tasks"))
		if len(taskList) > 8 {
			c.markCut(res("tasks"))
		}
		var count, tasks any
		if n, ok := res("count").(float64); ok {
			count = n
		} else if _, ok := res("tasks").([]any); ok {
			count = len(taskList)
		}
		if _, ok := res("tasks").([]any); ok {
			shown := taskList
			if len(shown) > 8 {
				shown = shown[:8]
			}
			items := make([]any, len(shown))
			for i, task := range shown {
				o := dyn.Ordered{
					{Key: "id", Value: dyn.Get(task, "id")},
					{Key: "name", Value: dyn.Get(task, "name")},
					{Key: "triggerType", Value: dyn.Get(task, "triggerType")},
					{Key: "triggerSummary", Value: dyn.Get(task, "triggerSummary")},
					{Key: "enabled", Value: dyn.Get(task, "enabled")},
				}.Trim()
				if model := dyn.Get(task, "model"); dyn.Truthy(model) {
					o = append(o, dyn.KV{Key: "model", Value: model})
				}
				items[i] = o
			}
			tasks = items
		}
		envelope = dyn.Ordered{
			{Key: "tool", Value: toolName},
			{Key: "status", Value: errorOrOK(toolResult)},
			{Key: "message", Value: ClampText(or(res("message"), res("error")), soft(0.3))},
			{Key: "count", Value: count},
			{Key: "tasks", Value: tasks},
		}.Trim()
	case "sent_message":
		status := errorOrOK(toolResult)
		if dyn.Truthy(res("skipped")) {
			status = "skipped"
		}
		var success, skipped, sent, suppressed any
		if b, ok := res("success").(bool); ok {
			success = b
		}
		if res("skipped") == true {
			skipped = true
		}
		if b, ok := res("sent").(bool); ok {
			sent = b
		}
		if res("suppressed") == true {
			suppressed = true
		}
		var count any
		if results, ok := res("results").([]any); ok {
			count = len(results)
		}
		inner := dyn.Ordered{
			{Key: "id", Value: res("id")}, {Key: "key", Value: res("key")}, {Key: "deleted", Value: res("deleted")}, {Key: "count", Value: count},
		}.Trim()
		envelope = dyn.Ordered{
			{Key: "tool", Value: toolName},
			{Key: "status", Value: status},
			{Key: "platform", Value: args("platform")},
			{Key: "to", Value: args("to")},
			{Key: "success", Value: success},
			{Key: "skipped", Value: skipped},
			{Key: "sent", Value: sent},
			{Key: "suppressed", Value: suppressed},
			{Key: "message", Value: ClampText(or(res("message"), res("reason"), res("error")), soft(0.45))},
			{Key: "result", Value: ClampText(dyn.Stringify(inner), soft(0.3))},
		}.Trim()
	case "interim":
		status := "error"
		if res("sent") == true {
			status = "ok"
		}
		if dyn.Truthy(res("skipped")) {
			status = "skipped"
		}
		envelope = dyn.Ordered{
			{Key: "tool", Value: toolName},
			{Key: "status", Value: status},
			{Key: "kind", Value: or(res("kind"), args("kind"))},
			{Key: "expectsReply", Value: res("expectsReply") == true || res("waitingForUser") == true},
			{Key: "message", Value: ClampText(or(res("content"), args("content"), res("reason"), ""), soft(0.55))},
		}.Trim()
	case "status":
		envelope = simpleStatusEnvelope(toolName, toolResult, softLimit)
	case "subagent_started":
		envelope = dyn.Ordered{
			{Key: "tool", Value: toolName},
			{Key: "handle", Value: res("handle")},
			{Key: "childRunId", Value: res("childRunId")},
			{Key: "status", Value: res("status")},
			{Key: "summary", Value: ClampText(or(res("task"), res("error"), ""), soft(0.55))},
		}.Trim()
	case "subagents":
		status := res("status")
		if !dyn.Truthy(status) {
			if _, ok := res("subagents").([]any); ok {
				status = "ok"
			} else {
				status = ""
			}
		}
		var count any
		if list, ok := res("subagents").([]any); ok {
			count = len(list)
		}
		inner := dyn.Ordered{
			{Key: "handle", Value: res("handle")}, {Key: "childRunId", Value: res("childRunId")}, {Key: "timedOut", Value: res("timedOut")},
			{Key: "count", Value: count}, {Key: "error", Value: res("error")}, {Key: "result", Value: res("result")},
		}.Trim()
		envelope = dyn.Ordered{
			{Key: "tool", Value: toolName},
			{Key: "status", Value: status},
			{Key: "summary", Value: ClampText(dyn.Stringify(inner), soft(0.6))},
		}.Trim()
	case "google_workspace_calendar_list_events", "microsoft_365_calendar_list_events":
		envelope = calendarEnvelope(toolName, toolArgs, toolResult)
	case "bounded":
		// A tool that already keeps its result small says so, and it goes through as it is.
		envelope = dyn.Ordered{{Key: "tool", Value: toolName}}
		if m := dyn.Obj(toolResult); m != nil {
			for _, key := range dyn.SortedKeys(m) {
				envelope = envelope.Set(key, m[key])
			}
		}
		envelope = envelope.Trim()
	default:
		envelope = dyn.Ordered{
			{Key: "tool", Value: toolName},
			{Key: "summary", Value: c.excerpt(toolResult, soft(0.9))},
		}.Trim()
	}

	// An envelope over the hard limit is cut as a whole, whatever its fields.
	if !c.cut && textx.Len(dyn.Stringify(envelope)) > hardLimit {
		c.markCut(toolResult)
	}
	if c.cut && options.RetainFullResult != nil {
		if retained := options.RetainFullResult(c.cutPayload); retained != nil {
			// Ahead of the payload, so a hard cut of the envelope cannot drop it.
			full := dyn.Ordered{
				{Key: "tool", Value: envelope.Get("tool")},
				{Key: "full_result", Value: dyn.Ordered{
					{Key: "artifact_id", Value: retained.ArtifactID},
					{Key: "total_lines", Value: retained.TotalLines},
					{Key: "note", Value: "Only part of this result is shown. The complete result is saved: search it with read_artifact query, or read it by line range, before treating anything as missing. Do not run the call again for it."},
				}},
			}
			for _, kv := range envelope {
				full = full.Set(kv.Key, kv.Value)
			}
			envelope = full
		}
	}
	return clampEnvelope(envelope, hardLimit)
}

func orInt(value, fallback int) int {
	if value == 0 {
		return fallback
	}
	return value
}

func errorOrOK(result any) string {
	if dyn.Get(result, "success") == false || dyn.Truthy(dyn.Get(result, "error")) {
		return "error"
	}
	return "ok"
}

func (c *resultCompactor) command(toolName string, toolArgs dyn.Map, result any, softLimit int) dyn.Ordered {
	res := func(key string) any { return dyn.Get(result, key) }
	command := dyn.Str(toolArgs["command"])
	// A readable test report replaces the log: the failures are what the next
	// step needs, and the whole log stays in its artifact.
	testResult := ParseTestOutput(command, dyn.Str(res("stdout")), dyn.Str(res("stderr")))
	outputShare := 1.0
	if testResult != nil {
		outputShare = 0.15
	}
	status := "ok"
	switch {
	case dyn.Truthy(res("timedOut")):
		status = "timed_out"
	case commandFailureMessage(result) != "":
		status = "error"
	}
	var errText any
	if dyn.Truthy(res("error")) {
		errText = ClampText(dyn.String(res("error")), 800)
	}
	exit, hasExit := res("exitCode").(float64)
	note := ""
	switch {
	case dyn.Truthy(res("timedOut")):
		note = "Command timed out. Treat the output as partial; if it needs longer, run it again with a larger timeout, otherwise narrow it."
	case dyn.Truthy(res("killed")):
		note = "Command was killed. Treat the output as partial."
	case res("exitCode") != nil && !(hasExit && exit == 0):
		note = "Command exited non-zero. Output may be partial; later segments of a chained shell command may not have run."
	}
	var test any
	if testResult != nil {
		test = testResult
	}
	killed := dyn.Truthy(res("killed"))
	return dyn.Ordered{
		{Key: "tool", Value: toolName},
		{Key: "status", Value: status},
		// Why it did not run: a refusal or a failed start has no output to read.
		{Key: "error", Value: errText},
		{Key: "command", Value: ClampText(command, floorMul(softLimit, 0.28))},
		{Key: "exitCode", Value: res("exitCode")},
		{Key: "cwd", Value: or(res("cwd"), toolArgs["cwd"])},
		{Key: "killed", Value: killed},
		{Key: "timedOut", Value: dyn.Truthy(res("timedOut"))},
		{Key: "signal", Value: res("signal")},
		{Key: "durationMs", Value: res("durationMs")},
		{Key: "stdoutBytes", Value: res("stdoutBytes")},
		{Key: "stderrBytes", Value: res("stderrBytes")},
		{Key: "truncated", Value: res("truncated") == true},
		{Key: "outputArtifact", Value: res("outputArtifact")},
		{Key: "artifactError", Value: res("artifactError")},
		{Key: "note", Value: note},
		{Key: "test_result", Value: test},
		{Key: "stdout", Value: ClampText(textx.Trim(dyn.Str(res("stdout"))), floorMul(softLimit, 0.6*outputShare))},
		{Key: "stderr", Value: ClampText(textx.Trim(dyn.Str(res("stderr"))), floorMul(softLimit, 0.25*outputShare))},
	}.Trim()
}

func calendarEnvelope(toolName string, toolArgs dyn.Map, result any) dyn.Ordered {
	res := func(keys ...string) any { return dyn.Get(result, keys...) }
	var events []any
	if list, ok := res("events").([]any); ok {
		events = list
	} else {
		events = append(append([]any{}, dyn.List(res("timedEvents"))...), dyn.List(res("allDayEvents"))...)
	}
	var timed []any
	for _, e := range events {
		if !dyn.Truthy(dyn.Get(e, "allDay")) {
			timed = append(timed, e)
		}
	}
	_, hasUpcoming := res("upcomingTimedEvents").([]any)
	_, hasOngoing := res("ongoingTimedEvents").([]any)
	hasPartitions := hasUpcoming || hasOngoing
	upcoming, ongoing := timed, []any(nil)
	if hasPartitions {
		upcoming, ongoing = dyn.List(res("upcomingTimedEvents")), dyn.List(res("ongoingTimedEvents"))
	}
	var allDay []any
	if list, ok := res("allDayEvents").([]any); ok {
		allDay = list
	} else {
		for _, e := range events {
			if dyn.Truthy(dyn.Get(e, "allDay")) {
				allDay = append(allDay, e)
			}
		}
	}
	// The event id is what update/delete tools need; without it the model cannot
	// act on an event it just listed.
	digestTimed := func(event any) any {
		var location, status any
		if loc := dyn.Get(event, "location"); dyn.Truthy(loc) {
			location = ClampText(loc, 80)
		}
		if st := dyn.Get(event, "status"); dyn.Truthy(st) && st != "confirmed" {
			status = st
		}
		return dyn.Ordered{
			{Key: "id", Value: nilIfFalsy(dyn.Get(event, "id"))},
			{Key: "summary", Value: ClampText(or(dyn.Get(event, "summary"), "(no title)"), 140)},
			{Key: "start", Value: or(dyn.Get(event, "start"), nil)},
			{Key: "end", Value: or(dyn.Get(event, "end"), nil)},
			{Key: "location", Value: location},
			{Key: "status", Value: status},
		}.Trim()
	}
	window := dyn.Ordered{
		{Key: "timeMin", Value: or(res("queryWindow", "timeMin"), toolArgs["time_min"], toolArgs["timeMin"])},
		{Key: "timeMax", Value: or(res("queryWindow", "timeMax"), toolArgs["time_max"], toolArgs["timeMax"])},
	}.Trim()
	var queryWindow any
	if len(window) > 0 {
		queryWindow = window
	}
	numberOr := func(key string, fallback int) any {
		if n, ok := res(key).(float64); ok {
			return n
		}
		return fallback
	}
	digestAll := func(list []any, fn func(any) any) []any {
		out := make([]any, len(list))
		for i, e := range list {
			out[i] = fn(e)
		}
		return out
	}
	var onlyOmitted any
	if res("hasOnlyOmittedOverlaps") == true {
		onlyOmitted = true
	}
	return dyn.Ordered{
		{Key: "tool", Value: toolName},
		{Key: "windowMode", Value: res("windowMode")},
		{Key: "queryWindow", Value: queryWindow},
		{Key: "count", Value: numberOr("count", len(events))},
		{Key: "overlapCount", Value: res("overlapCount")},
		{Key: "omittedOngoingTimedCount", Value: res("omittedOngoingTimedCount")},
		{Key: "omittedAllDayCount", Value: res("omittedAllDayCount")},
		{Key: "hasOnlyOmittedOverlaps", Value: onlyOmitted},
		{Key: "timedCount", Value: numberOr("timedCount", len(timed))},
		{Key: "upcomingTimedCount", Value: numberOr("upcomingTimedCount", len(upcoming))},
		{Key: "ongoingTimedCount", Value: numberOr("ongoingTimedCount", len(ongoing))},
		{Key: "allDayCount", Value: numberOr("allDayCount", len(allDay))},
		{Key: "hasUpcomingTimedEvents", Value: res("hasUpcomingTimedEvents") == true || len(upcoming) > 0},
		{Key: "hasOngoingTimedEvents", Value: res("hasOngoingTimedEvents") == true || len(ongoing) > 0},
		{Key: "hasOnlyOngoingTimedEvents", Value: res("hasOnlyOngoingTimedEvents") == true || (len(upcoming) == 0 && len(ongoing) > 0)},
		{Key: "hasOnlyAllDayEvents", Value: res("hasOnlyAllDayEvents") == true || (len(timed) == 0 && len(allDay) > 0)},
		{Key: "upcomingTimed", Value: digestAll(upcoming, digestTimed)},
		{Key: "ongoingTimed", Value: digestAll(ongoing, digestTimed)},
		// All-day entries are usually birthdays / markers: names and dates suffice.
		{Key: "allDay", Value: digestAll(allDay, func(event any) any {
			return dyn.Ordered{
				{Key: "id", Value: nilIfFalsy(dyn.Get(event, "id"))},
				{Key: "summary", Value: ClampText(or(dyn.Get(event, "summary"), "(no title)"), 140)},
				{Key: "start", Value: or(dyn.Get(event, "start"), nil)},
				{Key: "end", Value: or(dyn.Get(event, "end"), nil)},
			}.Trim()
		})},
	}.Trim()
}

func nilIfFalsy(v any) any {
	if dyn.Truthy(v) {
		return v
	}
	return nil
}

// Shaper turns tool executions into what the model and the run record keep: cut
// results and classified evidence. It reads tool metadata from the registry.
type Shaper struct{ Tools *tools.Registry }
