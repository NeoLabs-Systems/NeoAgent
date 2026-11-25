package ai

import (
	"regexp"
	"strconv"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/textx"
)

// Turns a test run's output into what a coding agent needs: did it pass, how
// many failed, and which ones and why. The whole log stays reachable as an
// artifact.

var testCommand = regexp.MustCompile(`(^|[\s;&|(/])(npm\s+(run\s+)?test|yarn\s+test|pnpm\s+test|bun\s+test|node\s+--test|jest|vitest|mocha|pytest|py\.test|python3?\s+-m\s+(pytest|unittest)|rspec|go\s+test|cargo\s+(test|nextest)|flutter\s+test|dart\s+test|phpunit|gradle\w*\s+test|mvn\s+\S*\s*test|ctest|make\s+(test|check))\b`)

const (
	maxTestFailures   = 20
	maxFailureMessage = 220
)

// IsTestCommand reports whether a command runs a test suite.
func IsTestCommand(command string) bool { return testCommand.MatchString(command) }

var (
	terminalCodes = regexp.MustCompile("\x1b\\[[0-9;]*[A-Za-z]")
)

func stripTerminalCodes(text string) string {
	return strings.ReplaceAll(terminalCodes.ReplaceAllString(text, ""), "\r", "")
}

func clampFailure(text string) string {
	value := textx.Collapse(text)
	if textx.Len(value) > maxFailureMessage {
		return textx.Head(value, maxFailureMessage) + "..."
	}
	return value
}

// testNumber is a count a runner printed, or -1 when it printed none.
func firstNumber(text string, pattern *regexp.Regexp) int {
	m := pattern.FindStringSubmatch(text)
	if m == nil {
		return -1
	}
	n, _ := strconv.Atoi(m[1])
	return n
}

// sumNumbers adds every match: `npm test` often chains runs, and each prints
// its own summary. Reading only the first one calls a run green when a later
// one failed. It returns -1 when nothing matched.
func sumNumbers(text string, pattern *regexp.Regexp) int {
	total := -1
	for _, m := range pattern.FindAllStringSubmatch(text, -1) {
		n, _ := strconv.Atoi(m[1])
		if total < 0 {
			total = 0
		}
		total += n
	}
	return total
}

type testFailure struct {
	test, file, location, message string
	hasMessage                    bool
}

func (f testFailure) toMap() dyn.Ordered {
	o := dyn.Ordered{{Key: "test", Value: f.test}}
	if f.file != "" {
		o = append(o, dyn.KV{Key: "file", Value: f.file})
	}
	if f.location != "" {
		o = append(o, dyn.KV{Key: "location", Value: f.location})
	}
	if f.hasMessage {
		o = append(o, dyn.KV{Key: "message", Value: f.message})
	}
	return o
}

type testReport struct {
	runner         string
	passed, failed int
	failures       []testFailure
}

var (
	specFailingHeader = regexp.MustCompile(`(?m)^✖ failing tests:`)
	specTestsLine     = regexp.MustCompile(`(?m)^ℹ tests \d`)
	specFailure       = regexp.MustCompile(`(?:test at ([^\n]+)\n)?✖ ([^\n]+?)(?: \(\d+(?:\.\d+)?ms\))?\n((?:[ \t]*\n|[ \t]+[^\n]*\n)*)`)
	stackLine         = regexp.MustCompile(`^(at |\{|code:|generatedMessage:)`)
	locationSuffix    = regexp.MustCompile(`:\d+:\d+$`)
	locationNumbers   = regexp.MustCompile(`:(\d+:\d+)$`)
)

func specFailures(text string) []testFailure {
	var failures []testFailure
	parts := specFailingHeader.Split(text, -1)
	if len(parts) < 2 {
		return nil
	}
	for _, part := range parts[1:] {
		section := specTestsLine.Split(part, 2)[0]
		for _, m := range specFailure.FindAllStringSubmatch(section, -1) {
			location := textx.Trim(m[1])
			var message []string
			for _, line := range strings.Split(m[3], "\n") {
				line = textx.Trim(line)
				if line == "" {
					continue
				}
				if stackLine.MatchString(line) {
					break
				}
				message = append(message, line)
			}
			f := testFailure{test: clampFailure(m[2]), message: clampFailure(strings.Join(message, " ")), hasMessage: true}
			if location != "" {
				f.file = locationSuffix.ReplaceAllString(location, "")
				if n := locationNumbers.FindStringSubmatch(location); n != nil {
					f.location = n[1]
				}
			}
			failures = append(failures, f)
		}
	}
	return failures
}

var (
	tapNotOk      = regexp.MustCompile(`^([ \t]*)not ok \d+ - ([^\n]+)$`)
	tapLocation   = regexp.MustCompile(`(?m)^\s*location: '?(.+?):(\d+:\d+)'?\s*$`)
	tapScalar     = regexp.MustCompile(`(?m)^([ \t]*)error: \|-?[ \t]*\n`)
	tapPlain      = regexp.MustCompile(`(?m)^\s*error: ([^\n|][^\n]*)`)
	tapFailType   = regexp.MustCompile(`(?m)^\s*failureType: '?(\w+)'?`)
	blankLine     = regexp.MustCompile(`^[ \t]*$`)
	relayedFailed = map[string]bool{"subtestsFailed": true, "cancelledByParent": true}
)

// tapBlocks finds each "not ok" line and the indented lines that follow it,
// which JavaScript matched with a backreference to the line's own indent.
func tapBlocks(text string) (blocks []struct{ title, body string }) {
	lines := strings.Split(text, "\n")
	// Only lines followed by a newline are complete; the last element is the remainder.
	complete := len(lines) - 1
	indented := func(line, indent string) bool {
		return strings.HasPrefix(line, indent) && len(line) > len(indent) && (line[len(indent)] == ' ' || line[len(indent)] == '\t') || blankLine.MatchString(line)
	}
	for i := 0; i < complete; i++ {
		m := tapNotOk.FindStringSubmatch(lines[i])
		if m == nil {
			continue
		}
		var body strings.Builder
		j := i + 1
		for ; j < complete && indented(lines[j], m[1]); j++ {
			body.WriteString(lines[j] + "\n")
		}
		blocks = append(blocks, struct{ title, body string }{m[2], body.String()})
		i = j - 1
	}
	return blocks
}

func scalarError(block string) (string, bool) {
	loc := tapScalar.FindStringSubmatchIndex(block)
	if loc == nil {
		return "", false
	}
	indent := block[loc[2]:loc[3]]
	var out strings.Builder
	for _, line := range strings.SplitAfter(block[loc[1]:], "\n") {
		if line == "" {
			break
		}
		trimmed := strings.TrimSuffix(line, "\n")
		if strings.HasPrefix(trimmed, indent) && len(trimmed) > len(indent) && (trimmed[len(indent)] == ' ' || trimmed[len(indent)] == '\t') || blankLine.MatchString(trimmed) {
			out.WriteString(line)
			continue
		}
		break
	}
	return out.String(), true
}

func tapFailures(text string) []testFailure {
	var direct, relayed []testFailure
	for _, block := range tapBlocks(text) {
		f := testFailure{test: clampFailure(block.title), hasMessage: true}
		if m := tapLocation.FindStringSubmatch(block.body); m != nil {
			f.file, f.location = m[1], m[2]
		}
		if scalar, ok := scalarError(block.body); ok {
			f.message = clampFailure(scalar)
		} else if m := tapPlain.FindStringSubmatch(block.body); m != nil {
			f.message = clampFailure(m[1])
		}
		kind := ""
		if m := tapFailType.FindStringSubmatch(block.body); m != nil {
			kind = m[1]
		}
		if relayedFailed[kind] {
			relayed = append(relayed, f)
		} else {
			direct = append(direct, f)
		}
	}
	if len(direct) > 0 {
		return direct
	}
	return relayed
}

var (
	nodePass      = regexp.MustCompile(`(?m)^(?:ℹ|#) pass (\d+)`)
	nodeFail      = regexp.MustCompile(`(?m)^(?:ℹ|#) fail (\d+)`)
	nodeCancelled = regexp.MustCompile(`(?m)^(?:ℹ|#) cancelled (\d+)`)
)

func parseNodeTest(text string) *testReport {
	passed, failed := sumNumbers(text, nodePass), sumNumbers(text, nodeFail)
	if passed < 0 && failed < 0 {
		return nil
	}
	// A test that timed out or lost its hook is cancelled, not failed, yet it did not pass.
	cancelled := max(sumNumbers(text, nodeCancelled), 0)
	failures := specFailures(text)
	// Without a terminal node:test defaults to TAP, and a tool's shell has none.
	if len(failures) == 0 {
		failures = tapFailures(text)
	}
	return &testReport{runner: "node:test", passed: max(passed, 0), failed: max(failed, 0) + cancelled, failures: failures}
}

var (
	jestLine     = regexp.MustCompile(`(?m)^Tests:\s+(.+)$`)
	failedCount  = regexp.MustCompile(`(\d+) failed`)
	passedCount  = regexp.MustCompile(`(\d+) passed`)
	jestFailure  = regexp.MustCompile(`(?m)^\s*●\s+(.+)\n\n?\s*([^\n]+)`)
	jestLocation = regexp.MustCompile(`\(?([\w./@-]+\.\w+):(\d+):\d+\)?`)
)

func parseJest(text string) *testReport {
	line := jestLine.FindStringSubmatch(text)
	if line == nil {
		return nil
	}
	report := &testReport{runner: "jest", failed: max(firstNumber(line[1], failedCount), 0), passed: max(firstNumber(line[1], passedCount), 0)}
	for _, m := range jestFailure.FindAllStringSubmatchIndex(text, -1) {
		f := testFailure{test: clampFailure(text[m[2]:m[3]]), message: clampFailure(text[m[4]:m[5]]), hasMessage: true}
		if loc := jestLocation.FindStringSubmatch(text[m[0]:]); loc != nil {
			f.file, f.location = loc[1], loc[2]
		}
		report.failures = append(report.failures, f)
	}
	return report
}

var (
	vitestLine    = regexp.MustCompile(`(?m)^\s*Tests\s+(.+)$`)
	vitestFailure = regexp.MustCompile(`(?m)^\s*FAIL\s+(.+)\n\s*([^\n]+)`)
)

func parseVitest(text string) *testReport {
	line := vitestLine.FindStringSubmatch(text)
	if line == nil {
		return nil
	}
	report := &testReport{runner: "vitest", failed: max(firstNumber(line[1], failedCount), 0), passed: max(firstNumber(line[1], passedCount), 0)}
	for _, m := range vitestFailure.FindAllStringSubmatch(text, -1) {
		report.failures = append(report.failures, testFailure{test: clampFailure(m[1]), message: clampFailure(m[2]), hasMessage: true})
	}
	return report
}

var (
	pytestLine    = regexp.MustCompile(`(?m)^=+ (.*\b(?:passed|failed|error|errors|no tests ran)\b.*) =+$`)
	errorsCount   = regexp.MustCompile(`(\d+) errors?`)
	pytestFailure = regexp.MustCompile(`(?m)^(?:FAILED|ERROR) ([^\s:]+)(?:::(\S+))?(?: - (.*))?$`)
)

func parsePytest(text string) *testReport {
	line := pytestLine.FindStringSubmatch(text)
	if line == nil {
		return nil
	}
	report := &testReport{runner: "pytest", failed: max(firstNumber(line[1], failedCount), 0) + max(firstNumber(line[1], errorsCount), 0), passed: max(firstNumber(line[1], passedCount), 0)}
	for _, m := range pytestFailure.FindAllStringSubmatch(text, -1) {
		report.failures = append(report.failures, testFailure{test: clampFailure(firstNonEmpty(m[2], m[1])), file: m[1], message: clampFailure(m[3]), hasMessage: true})
	}
	return report
}

var (
	goPackageLine = regexp.MustCompile(`(?m)^(?:ok|FAIL|\?)\s+\S+\s+(?:\(cached\)|[\d.]+s|\[[^\]]+\])`)
	goResultLine  = regexp.MustCompile(`(?m)^\s*--- (?:PASS|FAIL|SKIP): `)
	goFailure     = regexp.MustCompile(`(?m)^\s*--- FAIL: (\S+).*\n(?:\s*([\w./-]+\.go):(\d+): ([^\n]*))?`)
	goPassLine    = regexp.MustCompile(`(?m)^\s*--- PASS:`)
	goOkLine      = regexp.MustCompile(`(?m)^ok\s+\S+\s+(?:\(cached\)|[\d.]+s)`)
	goFailPackage = regexp.MustCompile(`(?m)^FAIL\s+\S+`)
)

func parseGoTest(text string) *testReport {
	if !goPackageLine.MatchString(text) && !goResultLine.MatchString(text) {
		return nil
	}
	report := &testReport{runner: "go test"}
	for _, m := range goFailure.FindAllStringSubmatch(text, -1) {
		f := testFailure{test: clampFailure(m[1]), message: clampFailure(m[4]), hasMessage: true}
		if m[2] != "" {
			f.file, f.location = m[2], m[3]
		}
		report.failures = append(report.failures, f)
	}
	report.passed = len(goPassLine.FindAllString(text, -1)) + len(goOkLine.FindAllString(text, -1))
	report.failed = len(report.failures)
	if report.failed == 0 {
		report.failed = len(goFailPackage.FindAllString(text, -1))
	}
	return report
}

var (
	cargoPassed  = regexp.MustCompile(`(?m)^test result: \w+\. (\d+) passed; \d+ failed`)
	cargoFailed  = regexp.MustCompile(`(?m)^test result: \w+\. \d+ passed; (\d+) failed`)
	cargoFailure = regexp.MustCompile(`(?m)^test (\S+) \.\.\. FAILED$`)
)

func parseCargo(text string) *testReport {
	// One line per crate, and the first is often a library with no tests at all.
	passed := sumNumbers(text, cargoPassed)
	if passed < 0 {
		return nil
	}
	report := &testReport{runner: "cargo test", passed: passed, failed: max(sumNumbers(text, cargoFailed), 0)}
	for _, m := range cargoFailure.FindAllStringSubmatch(text, -1) {
		report.failures = append(report.failures, testFailure{test: clampFailure(m[1])})
	}
	return report
}

var (
	mochaPassing = regexp.MustCompile(`(?m)^\s*(\d+) passing`)
	mochaFailing = regexp.MustCompile(`(?m)^\s*(\d+) failing`)
	mochaFailure = regexp.MustCompile(`(?m)^\s+\d+\) (.+)\n(?:\s+.*\n)*?\s+(\w*Error: [^\n]+)`)
)

func parseMocha(text string) *testReport {
	passed, failed := firstNumber(text, mochaPassing), firstNumber(text, mochaFailing)
	// Mocha leaves out the passing line when nothing passed.
	if passed < 0 && failed < 0 {
		return nil
	}
	report := &testReport{runner: "mocha", passed: max(passed, 0), failed: max(failed, 0)}
	for _, m := range mochaFailure.FindAllStringSubmatch(text, -1) {
		report.failures = append(report.failures, testFailure{test: clampFailure(m[1]), message: clampFailure(m[2]), hasMessage: true})
	}
	return report
}

var (
	rspecLine    = regexp.MustCompile(`(?m)^(\d+) examples?, (\d+) failures?`)
	rspecFailure = regexp.MustCompile(`(?m)^rspec (\S+?)(?::(\d+))? # (.+)$`)
)

func parseRspec(text string) *testReport {
	line := rspecLine.FindStringSubmatch(text)
	if line == nil {
		return nil
	}
	total, _ := strconv.Atoi(line[1])
	failed, _ := strconv.Atoi(line[2])
	report := &testReport{runner: "rspec", passed: total - failed, failed: failed}
	for _, m := range rspecFailure.FindAllStringSubmatch(text, -1) {
		report.failures = append(report.failures, testFailure{test: clampFailure(m[3]), file: m[1], location: m[2]})
	}
	return report
}

var (
	dartProgress = regexp.MustCompile(`\+(\d+)(?: -(\d+))?:`)
	dartVerdict  = regexp.MustCompile(`(All tests passed!|Some tests failed)`)
	dartFailure  = regexp.MustCompile(`(?m)^\d\d:\d\d \+\d+(?: -\d+)?: (.+) \[E\]$`)
)

func parseDart(text string) *testReport {
	matches := dartProgress.FindAllStringSubmatch(text, -1)
	if len(matches) == 0 || !dartVerdict.MatchString(text) {
		return nil
	}
	last := matches[len(matches)-1]
	passed, _ := strconv.Atoi(last[1])
	failed, _ := strconv.Atoi(last[2])
	report := &testReport{runner: "dart test", passed: passed, failed: failed}
	for _, m := range dartFailure.FindAllStringSubmatch(text, -1) {
		report.failures = append(report.failures, testFailure{test: clampFailure(m[1])})
	}
	return report
}

var testParsers = []func(string) *testReport{parseNodeTest, parseJest, parseVitest, parsePytest, parseCargo, parseGoTest, parseMocha, parseRspec, parseDart}

// readTestReport is the report a runner printed, or nil when it printed none. A
// report that counts nothing is nil too: no test file found, every test
// skipped, or prose such as "Tests passed" that only looks like a summary.
// Calling that "0 failed, 0 passed" would read as a clean run when nothing was
// checked.
func readTestReport(stdout, stderr string) dyn.Ordered {
	text := stripTerminalCodes(stdout + "\n" + stderr)
	for _, parse := range testParsers {
		report := parse(text)
		if report == nil || report.passed+report.failed+len(report.failures) == 0 {
			continue
		}
		shown := report.failures
		if len(shown) > maxTestFailures {
			shown = shown[:maxTestFailures]
		}
		failures := make([]any, len(shown))
		for i, f := range shown {
			failures[i] = f.toMap()
		}
		return dyn.Ordered{
			{Key: "runner", Value: report.runner},
			{Key: "passed", Value: report.passed},
			{Key: "failed", Value: report.failed},
			{Key: "summary", Value: strconv.Itoa(report.failed) + " failed, " + strconv.Itoa(report.passed) + " passed"},
			{Key: "failures", Value: failures},
			{Key: "failures_omitted", Value: max(0, len(report.failures)-maxTestFailures)},
		}
	}
	return nil
}

// ParseTestOutput is nil unless the command was a test command whose report can
// be read, so ordinary command output is never mistaken for a test result.
func ParseTestOutput(command, stdout, stderr string) dyn.Ordered {
	if !IsTestCommand(command) {
		return nil
	}
	return readTestReport(stdout, stderr)
}

func firstNonEmpty(values ...string) string {
	for _, v := range values {
		if v != "" {
			return v
		}
	}
	return ""
}

// ReadTestReport is readTestReport: the counts and failures a test runner
// printed, or nil when its output names no tests.
func ReadTestReport(stdout, stderr string) dyn.Ordered { return readTestReport(stdout, stderr) }

// StripTerminalCodes drops colors, control sequences and carriage returns.
func StripTerminalCodes(text string) string { return stripTerminalCodes(text) }
