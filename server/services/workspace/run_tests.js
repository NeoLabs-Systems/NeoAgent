'use strict';

const fs = require('fs');
const { readTestReport, stripTerminalCodes } = require('../ai/test_output');
const { commandError, enterScript, locationError, parseSections, workspaceRelative } = require('./workspace_shell');
const { detectProjectTests } = require('./repo_inspect');

const DEFAULT_TIMEOUT_MS = 10 * 60 * 1000;
const MAX_TIMEOUT_MS = 30 * 60 * 1000;
const TAIL_LINES = 40;
const TAIL_CHARS = 3000;
const MAX_PARSED_LOG_BYTES = 16 * 1024 * 1024;

function boundedTimeout(value) {
  const timeout = Math.floor(Number(value));
  return Number.isFinite(timeout) && timeout > 0 ? Math.min(timeout, MAX_TIMEOUT_MS) : DEFAULT_TIMEOUT_MS;
}

function outputTail(text) {
  const lines = stripTerminalCodes(text).trimEnd().split('\n').slice(-TAIL_LINES).join('\n');
  return lines.length > TAIL_CHARS ? lines.slice(-TAIL_CHARS) : lines;
}

// The whole log is kept whatever the outcome. A long run was already saved by the
// runtime; only a short one is still ours to save.
async function keepLog(store, context, result, combined) {
  if (result.outputArtifact?.artifactId) return { id: result.outputArtifact.artifactId, saved: true };
  if (typeof store?.createBufferArtifact !== 'function') return { saved: false };
  try {
    const artifact = await store.createBufferArtifact(context.userId, {
      kind: 'command-output',
      backend: 'computer',
      extension: 'log',
      contentType: 'text/plain; charset=utf-8',
      filenameBase: 'test-run',
      content: Buffer.from(combined),
      metadata: { runId: context.runId || null, stepId: context.stepId || null },
    });
    return { id: artifact.artifactId, saved: true };
  } catch (error) {
    return { saved: false, error: String(error?.message || error) };
  }
}

// A truncated preview can lose failures from the middle of a long log, while the
// artifact has them all.
function fullLogText(store, context, result, artifactId) {
  if (!result.truncated || !artifactId) return null;
  try {
    const artifact = store.getArtifactForUser(context.userId, artifactId);
    if (!artifact || Number(artifact.byte_size) > MAX_PARSED_LOG_BYTES) return null;
    return fs.readFileSync(artifact.storage_path, 'utf8');
  } catch {
    return null;
  }
}

function outcomeOf(report, result) {
  if (result.timedOut || result.killed) return 'interrupted';
  if (report?.failed > 0) return 'failed';
  if (result.exitCode !== 0) return 'failed';
  return report ? 'passed' : 'unknown';
}

function outcomeNote(outcome, report, result) {
  if (result.timedOut) return 'The run timed out, so the results are partial.';
  if (result.killed) return 'The run was stopped, so the results are partial.';
  if (!report) {
    return result.exitCode === 0
      ? 'The command succeeded but printed no test counts, so whether any test ran is unknown.'
      : 'The command failed before printing test counts; see output_tail.';
  }
  if (outcome === 'failed' && report.failed === 0) {
    return `The runner reported no failures, but the command exited ${result.exitCode}; see output_tail.`;
  }
  return '';
}

/**
 * Runs a project's tests and returns the counts and the failures, with the log
 * in an artifact. A failing test is a result, not a tool failure, so `error` is
 * only set when no test could be run or the run was cut off.
 */
async function runProjectTests(shell, args = {}, context = {}) {
  let command = String(args.command ?? '').trim();
  let detectedFrom = null;
  if (!command) {
    const detection = await detectProjectTests(shell, args.cwd);
    if (detection.error) return { error: detection.error };
    if (!detection.test) {
      return { error: 'No test command could be detected here. Pass command, or cwd if the project is in a subdirectory.' };
    }
    ({ command } = detection.test);
    detectedFrom = detection.test.source;
  }

  // Watch modes and colors are for people. The command itself is the last line, so
  // the script's exit code is its exit code. This call was approved as a shell command,
  // which can go anywhere, so a project cloned outside the workspace can be tested.
  const script = [...enterScript(args.cwd, { anywhere: true }), 'CI=1; NO_COLOR=1; export CI NO_COLOR', command].join('\n');
  const result = await shell.run(script, { timeout: boundedTimeout(args.timeout) });
  const location = locationError(parseSections(result?.stdout), args.cwd);
  if (location) return { error: location };
  if (result?.error) return { error: commandError(result), command };

  const combined = [result.stdout, result.stderr].filter(Boolean).join('\n');
  const log = await keepLog(context.artifactStore, context, result, combined);
  const fullLog = fullLogText(context.artifactStore, context, result, log.id);
  const report = readTestReport(fullLog === null ? { stdout: result.stdout, stderr: result.stderr } : { stdout: fullLog });
  const outcome = outcomeOf(report, result);
  const note = outcomeNote(outcome, report, result);
  const showTail = !report || (outcome !== 'passed' && report.failed === 0);

  return {
    status: outcome,
    command,
    ...(detectedFrom ? { detected_from: detectedFrom } : {}),
    cwd: workspaceRelative(args.cwd),
    exitCode: result.exitCode,
    durationMs: result.durationMs,
    ...(report ? { test_result: report } : {}),
    ...(note ? { note } : {}),
    ...(showTail ? { output_tail: outputTail(combined) } : {}),
    ...(log.id ? { log_artifact_id: log.id } : {}),
    ...(log.error ? { log_error: log.error } : {}),
    ...(result.timedOut ? { timedOut: true, error: note } : {}),
    ...(result.killed && !result.timedOut ? { killed: true, error: note } : {}),
  };
}

module.exports = { runProjectTests };
