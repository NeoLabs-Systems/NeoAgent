package repotools

import (
	"context"
	"math"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/ai"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
)

// run_tests (run_tests.js): run a project's tests, keep the whole log as an
// artifact, report counts and failures. A failing test is a result; error is
// only set when no test could run or the run was cut off.

const (
	testDefaultTimeout = 10 * time.Minute
	testMaxTimeout     = 30 * time.Minute
	tailLines          = 40
	tailChars          = 3000
	maxParsedLogBytes  = 16 * 1024 * 1024
)

// LogStore keeps a test log and reads a saved one back.
type LogStore interface {
	// SaveLog stores a short run's combined output and returns the artifact id.
	SaveLog(ctx context.Context, content []byte, runID, stepID string) (string, error)
	// ReadLog is the text of a saved log, or ok=false when it is missing or
	// larger than limit bytes.
	ReadLog(ctx context.Context, artifactID string, limit int64) (string, bool)
}

func boundedTimeout(value any) time.Duration {
	t := math.Floor(jsNumber(value))
	if value == nil || math.IsNaN(t) || math.IsInf(t, 0) || t <= 0 {
		return testDefaultTimeout
	}
	return min(time.Duration(t)*time.Millisecond, testMaxTimeout)
}

func outputTail(text string) string {
	lines := strings.Split(trimEndJS(ai.StripTerminalCodes(text)), "\n")
	if len(lines) > tailLines {
		lines = lines[len(lines)-tailLines:]
	}
	joined := strings.Join(lines, "\n")
	if n := lenUTF16(joined); n > tailChars {
		return sliceUTF16Tail(joined, tailChars)
	}
	return joined
}

// sliceUTF16Tail is s.slice(-n) counted in UTF-16 units.
func sliceUTF16Tail(s string, n int) string {
	total := lenUTF16(s)
	skip := total - n
	units := 0
	for i, r := range s {
		if units >= skip {
			return s[i:]
		}
		if r > 0xFFFF {
			units += 2
		} else {
			units++
		}
	}
	return ""
}

func outcomeOf(report dyn.Ordered, result dyn.Map) string {
	if dyn.Truthy(result["timedOut"]) || dyn.Truthy(result["killed"]) {
		return "interrupted"
	}
	failed, _ := dyn.Float(normalizeNumber(report.Get("failed")))
	if report != nil && failed > 0 {
		return "failed"
	}
	if !exitedZero(result["exitCode"]) {
		return "failed"
	}
	if report != nil {
		return "passed"
	}
	return "unknown"
}

// exitedZero is `result.exitCode === 0`.
func exitedZero(v any) bool {
	f, ok := dyn.Float(normalizeNumber(v))
	return ok && f == 0
}

func normalizeNumber(v any) any {
	switch x := v.(type) {
	case int:
		return float64(x)
	case int64:
		return float64(x)
	}
	return v
}

func outcomeNote(outcome string, report dyn.Ordered, result dyn.Map) string {
	if dyn.Truthy(result["timedOut"]) {
		return "The run timed out, so the results are partial."
	}
	if dyn.Truthy(result["killed"]) {
		return "The run was stopped, so the results are partial."
	}
	if report == nil {
		if exitedZero(result["exitCode"]) {
			return "The command succeeded but printed no test counts, so whether any test ran is unknown."
		}
		return "The command failed before printing test counts; see output_tail."
	}
	failed, _ := dyn.Float(normalizeNumber(report.Get("failed")))
	if outcome == "failed" && failed == 0 {
		return "The runner reported no failures, but the command exited " + dyn.String(result["exitCode"]) + "; see output_tail."
	}
	return ""
}

// RunTests runs run_tests.
func RunTests(ctx context.Context, shell Shell, args dyn.Map, logs LogStore, runID, stepID string) (any, error) {
	command := ""
	if args["command"] != nil {
		command = strings.TrimSpace(dyn.String(args["command"]))
	}
	detectedFrom := ""
	if command == "" {
		test, failure, err := detectProjectTests(ctx, shell, args["cwd"])
		if err != nil {
			return nil, err
		}
		if failure != "" {
			return dyn.Map{"error": failure}, nil
		}
		if test == nil {
			return dyn.Map{"error": "No test command could be detected here. Pass command, or cwd if the project is in a subdirectory."}, nil
		}
		command, detectedFrom = test.command, test.source
	}
	script := append(enterScript(args["cwd"], true), "CI=1; NO_COLOR=1; export CI NO_COLOR", command)
	result, err := shell.Run(ctx, strings.Join(script, "\n"), boundedTimeout(args["timeout"]))
	if err != nil {
		return nil, err
	}
	if location := locationError(parseSections(result["stdout"]), args["cwd"]); location != "" {
		return dyn.Map{"error": location}, nil
	}
	if dyn.Truthy(result["error"]) {
		return dyn.Ordered{{Key: "error", Value: commandError(result)}, {Key: "command", Value: command}}, nil
	}

	stdout, stderr := dyn.Str(result["stdout"]), dyn.Str(result["stderr"])
	var parts []string
	for _, p := range []string{stdout, stderr} {
		if p != "" {
			parts = append(parts, p)
		}
	}
	combined := strings.Join(parts, "\n")

	logID, logErr, saved := "", "", false
	if id := dyn.Str(dyn.Get(result, "outputArtifact", "artifactId")); id != "" {
		logID, saved = id, true
	} else if logs != nil {
		if id, err := logs.SaveLog(ctx, []byte(combined), runID, stepID); err != nil {
			logErr = err.Error()
		} else {
			logID, saved = id, true
		}
	}
	var report dyn.Ordered
	fullLog, haveFull := "", false
	if dyn.Truthy(result["truncated"]) && saved && logID != "" && logs != nil {
		fullLog, haveFull = logs.ReadLog(ctx, logID, maxParsedLogBytes)
	}
	if haveFull {
		report = ai.ReadTestReport(fullLog, "")
	} else {
		report = ai.ReadTestReport(stdout, stderr)
	}
	outcome := outcomeOf(report, result)
	note := outcomeNote(outcome, report, result)
	failed, _ := dyn.Float(normalizeNumber(report.Get("failed")))
	showTail := report == nil || (outcome != "passed" && failed == 0)

	out := dyn.Ordered{{Key: "status", Value: outcome}, {Key: "command", Value: command}}
	if detectedFrom != "" {
		out = append(out, dyn.KV{Key: "detected_from", Value: detectedFrom})
	}
	out = append(out,
		dyn.KV{Key: "cwd", Value: WorkspaceRelative(args["cwd"])},
		dyn.KV{Key: "exitCode", Value: result["exitCode"]},
	)
	if v, ok := result["durationMs"]; ok {
		out = append(out, dyn.KV{Key: "durationMs", Value: v})
	}
	if report != nil {
		out = append(out, dyn.KV{Key: "test_result", Value: report})
	}
	if note != "" {
		out = append(out, dyn.KV{Key: "note", Value: note})
	}
	if showTail {
		out = append(out, dyn.KV{Key: "output_tail", Value: outputTail(combined)})
	}
	if logID != "" {
		out = append(out, dyn.KV{Key: "log_artifact_id", Value: logID})
	}
	if logErr != "" {
		out = append(out, dyn.KV{Key: "log_error", Value: logErr})
	}
	timedOut := dyn.Truthy(result["timedOut"])
	if timedOut {
		out = append(out, dyn.KV{Key: "timedOut", Value: true}, dyn.KV{Key: "error", Value: note})
	}
	if dyn.Truthy(result["killed"]) && !timedOut {
		out = append(out, dyn.KV{Key: "killed", Value: true}, dyn.KV{Key: "error", Value: note})
	}
	return out, nil
}
