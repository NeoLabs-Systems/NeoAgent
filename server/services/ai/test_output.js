'use strict';

// Turns a test run's output into what a coding agent needs: did it pass, how many
// failed, and which ones and why. The whole log stays reachable as an artifact.
const TEST_COMMAND = /(^|[\s;&|(/])(npm\s+(run\s+)?test|yarn\s+test|pnpm\s+test|bun\s+test|node\s+--test|jest|vitest|mocha|pytest|py\.test|python3?\s+-m\s+(pytest|unittest)|rspec|go\s+test|cargo\s+(test|nextest)|flutter\s+test|dart\s+test|phpunit|gradle\w*\s+test|mvn\s+\S*\s*test|ctest|make\s+(test|check))\b/;

const MAX_FAILURES = 20;
const MAX_MESSAGE_CHARS = 220;

function isTestCommand(command) {
  return TEST_COMMAND.test(String(command || ''));
}

function stripTerminalCodes(text) {
  // Colors and control sequences only cost tokens.
  // eslint-disable-next-line no-control-regex
  return String(text || '').replace(/\u001b\[[0-9;]*[A-Za-z]/g, '').replace(/\r/g, '');
}

function clamp(text) {
  const value = String(text || '').replace(/\s+/g, ' ').trim();
  return value.length > MAX_MESSAGE_CHARS ? `${value.slice(0, MAX_MESSAGE_CHARS)}...` : value;
}

function firstNumber(text, pattern) {
  const match = text.match(pattern);
  return match ? Number(match[1]) : null;
}

// `npm test` often chains runs, and each prints its own summary. Reading only the
// first one calls a run green when a later one failed.
function sumNumbers(text, pattern) {
  let total = null;
  for (const match of text.matchAll(pattern)) total = (total || 0) + Number(match[1]);
  return total;
}

function specFailures(text) {
  const failures = [];
  for (const part of text.split(/^✖ failing tests:/m).slice(1)) {
    const section = part.split(/^ℹ tests \d/m)[0];
    for (const match of section.matchAll(/(?:test at ([^\n]+)\n)?✖ ([^\n]+?)(?: \(\d+(?:\.\d+)?ms\))?\n((?:[ \t]*\n|[ \t]+[^\n]*\n)*)/g)) {
      const location = String(match[1] || '').trim();
      // The message is what comes before the stack and the error's properties.
      const message = [];
      for (const line of match[3].split('\n').map((entry) => entry.trim()).filter(Boolean)) {
        if (/^(at |\{|code:|generatedMessage:)/.test(line)) break;
        message.push(line);
      }
      failures.push({
        test: clamp(match[2]),
        ...(location ? { file: location.replace(/:\d+:\d+$/, ''), location: location.match(/:(\d+:\d+)$/)?.[1] } : {}),
        message: clamp(message.join(' ')),
      });
    }
  }
  return failures;
}

// A parent suite only says a child failed, and a child stopped by its parent says
// nothing either, so both give way to whatever actually went wrong.
const RELAYED_TAP_FAILURES = new Set(['subtestsFailed', 'cancelledByParent']);

function tapFailures(text) {
  const direct = [];
  const relayed = [];
  for (const match of text.matchAll(/^([ \t]*)not ok \d+ - ([^\n]+)\n((?:\1[ \t]+[^\n]*\n|[ \t]*\n)*)/gm)) {
    const block = match[3];
    const location = block.match(/^\s*location: '?(.+?):(\d+:\d+)'?\s*$/m);
    const scalar = block.match(/^([ \t]*)error: \|-?[ \t]*\n((?:\1[ \t]+[^\n]*\n|[ \t]*\n)*)/m);
    const plain = block.match(/^\s*error: ([^\n|][^\n]*)/m);
    const type = block.match(/^\s*failureType: '?(\w+)'?/m)?.[1];
    (RELAYED_TAP_FAILURES.has(type) ? relayed : direct).push({
      test: clamp(match[2]),
      ...(location ? { file: location[1], location: location[2] } : {}),
      message: clamp(scalar ? scalar[2] : plain?.[1]),
    });
  }
  return direct.length ? direct : relayed;
}

function parseNodeTest(text) {
  const passed = sumNumbers(text, /^(?:ℹ|#) pass (\d+)/gm);
  const failed = sumNumbers(text, /^(?:ℹ|#) fail (\d+)/gm);
  if (passed === null && failed === null) return null;
  // A test that timed out or lost its hook is cancelled, not failed, yet it did not pass.
  const cancelled = sumNumbers(text, /^(?:ℹ|#) cancelled (\d+)/gm) || 0;
  const spec = specFailures(text);
  // Without a terminal node:test defaults to TAP, and a tool's shell has none.
  const failures = spec.length ? spec : tapFailures(text);
  return { runner: 'node:test', passed: passed || 0, failed: (failed || 0) + cancelled, failures };
}

function parseJest(text) {
  const line = text.match(/^Tests:\s+(.+)$/m);
  if (!line) return null;
  const failed = firstNumber(line[1], /(\d+) failed/) || 0;
  const passed = firstNumber(line[1], /(\d+) passed/) || 0;
  const failures = [];
  for (const match of text.matchAll(/^\s*●\s+(.+)\n\n?\s*([^\n]+)/gm)) {
    const location = text.slice(match.index).match(/\(?([\w./@-]+\.\w+):(\d+):\d+\)?/);
    failures.push({
      test: clamp(match[1]),
      ...(location ? { file: location[1], location: location[2] } : {}),
      message: clamp(match[2]),
    });
  }
  return { runner: 'jest', passed, failed, failures };
}

function parseVitest(text) {
  const line = text.match(/^\s*Tests\s+(.+)$/m);
  if (!line) return null;
  const failed = firstNumber(line[1], /(\d+) failed/) || 0;
  const passed = firstNumber(line[1], /(\d+) passed/) || 0;
  const failures = [];
  for (const match of text.matchAll(/^\s*FAIL\s+(.+)\n\s*([^\n]+)/gm)) {
    failures.push({ test: clamp(match[1]), message: clamp(match[2]) });
  }
  return { runner: 'vitest', passed, failed, failures };
}

function parsePytest(text) {
  const line = text.match(/^=+ (.*\b(?:passed|failed|error|errors|no tests ran)\b.*) =+$/m);
  if (!line) return null;
  const failed = (firstNumber(line[1], /(\d+) failed/) || 0) + (firstNumber(line[1], /(\d+) errors?/) || 0);
  const passed = firstNumber(line[1], /(\d+) passed/) || 0;
  const failures = [];
  for (const match of text.matchAll(/^(?:FAILED|ERROR) ([^\s:]+)(?:::(\S+))?(?: - (.*))?$/gm)) {
    failures.push({ test: clamp(match[2] || match[1]), file: match[1], message: clamp(match[3]) });
  }
  return { runner: 'pytest', passed, failed, failures };
}

// Package lines end in a time or a bracket, which is what keeps TAP's "ok 1 - adds"
// and a diff's "--- a/file" from being read as a Go run.
const GO_PACKAGE_LINE = /^(?:ok|FAIL|\?)\s+\S+\s+(?:\(cached\)|[\d.]+s|\[[^\]]+\])/m;

function parseGoTest(text) {
  if (!GO_PACKAGE_LINE.test(text) && !/^\s*--- (?:PASS|FAIL|SKIP): /m.test(text)) return null;
  const failures = [];
  for (const match of text.matchAll(/^\s*--- FAIL: (\S+).*\n(?:\s*([\w./-]+\.go):(\d+): ([^\n]*))?/gm)) {
    failures.push({
      test: clamp(match[1]),
      ...(match[2] ? { file: match[2], location: match[3] } : {}),
      message: clamp(match[4]),
    });
  }
  const passed = (text.match(/^\s*--- PASS:/gm) || []).length + (text.match(/^ok\s+\S+\s+(?:\(cached\)|[\d.]+s)/gm) || []).length;
  const failed = failures.length || (text.match(/^FAIL\s+\S+/gm) || []).length;
  return { runner: 'go test', passed, failed, failures };
}

function parseCargo(text) {
  // One line per crate, and the first is often a library with no tests at all.
  const passed = sumNumbers(text, /^test result: \w+\. (\d+) passed; \d+ failed/gm);
  if (passed === null) return null;
  const failed = sumNumbers(text, /^test result: \w+\. \d+ passed; (\d+) failed/gm);
  const failures = [...text.matchAll(/^test (\S+) \.\.\. FAILED$/gm)].map((match) => ({ test: clamp(match[1]) }));
  return { runner: 'cargo test', passed, failed, failures };
}

function parseMocha(text) {
  const passed = firstNumber(text, /^\s*(\d+) passing/m);
  const failed = firstNumber(text, /^\s*(\d+) failing/m);
  // Mocha leaves out the passing line when nothing passed.
  if (passed === null && failed === null) return null;
  const failures = [];
  for (const match of text.matchAll(/^\s+\d+\) (.+)\n(?:\s+.*\n)*?\s+(\w*Error: [^\n]+)/gm)) {
    failures.push({ test: clamp(match[1]), message: clamp(match[2]) });
  }
  return { runner: 'mocha', passed: passed || 0, failed: failed || 0, failures };
}

function parseRspec(text) {
  const line = text.match(/^(\d+) examples?, (\d+) failures?/m);
  if (!line) return null;
  const failed = Number(line[2]);
  const failures = [...text.matchAll(/^rspec (\S+?)(?::(\d+))? # (.+)$/gm)].map((match) => ({
    test: clamp(match[3]),
    file: match[1],
    ...(match[2] ? { location: match[2] } : {}),
  }));
  return { runner: 'rspec', passed: Number(line[1]) - failed, failed, failures };
}

function parseDart(text) {
  const matches = [...text.matchAll(/\+(\d+)(?: -(\d+))?:/g)];
  if (!matches.length || !/(All tests passed!|Some tests failed)/.test(text)) return null;
  const last = matches[matches.length - 1];
  const failures = [...text.matchAll(/^\d\d:\d\d \+\d+(?: -\d+)?: (.+) \[E\]$/gm)].map((match) => ({ test: clamp(match[1]) }));
  return { runner: 'dart test', passed: Number(last[1]), failed: Number(last[2] || 0), failures };
}

const PARSERS = [parseNodeTest, parseJest, parseVitest, parsePytest, parseCargo, parseGoTest, parseMocha, parseRspec, parseDart];

/**
 * The report a runner printed, or null when it printed none. A report that counts
 * nothing is null too: no test file found, every test skipped, or prose such as
 * "Tests passed" that only looks like a summary. Calling that "0 failed, 0 passed"
 * would read as a clean run when nothing was checked.
 */
function readTestReport({ stdout, stderr }) {
  const text = stripTerminalCodes(`${stdout || ''}\n${stderr || ''}`);
  for (const parser of PARSERS) {
    const parsed = parser(text);
    if (!parsed || parsed.passed + parsed.failed + parsed.failures.length === 0) continue;
    const { failures, ...counts } = parsed;
    return {
      ...counts,
      summary: `${counts.failed} failed, ${counts.passed} passed`,
      failures: failures.slice(0, MAX_FAILURES),
      failures_omitted: Math.max(0, failures.length - MAX_FAILURES),
    };
  }
  return null;
}

/**
 * Null unless this was a test command whose report we can read, so ordinary
 * command output is never mistaken for a test result.
 */
function parseTestOutput({ command, stdout, stderr }) {
  return isTestCommand(command) ? readTestReport({ stdout, stderr }) : null;
}

module.exports = {
  isTestCommand,
  parseTestOutput,
  readTestReport,
  stripTerminalCodes,
};
