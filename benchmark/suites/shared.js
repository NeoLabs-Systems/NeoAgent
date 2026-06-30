'use strict';

const path = require('node:path');
const { readJson, readJsonLines, writeJson, writeText, exists, executeCommand, commandExists } = require('../utils');

async function writeSuiteManifest(manifestPath, suite) {
  await writeJson(manifestPath, suite);
}

function missingPrerequisiteResult(suite, reason, model = null, caseId = '__suite__') {
  return {
    suiteId: suite.id,
    suiteLabel: suite.label,
    benchmarkType: suite.benchmarkType,
    modelDriven: suite.modelDriven === true,
    caseId,
    status: 'blocked',
    score: null,
    reason,
    provider: model?.provider || null,
    modelId: model?.id || null,
    priceTier: model?.priceTier || null,
    latencyMs: 0,
    tokenUsage: null,
    estimatedCostUsd: null,
    finalResponse: '',
    runId: null,
    artifactRefs: [],
    requiredSignalCoverage: null,
    metadata: {},
  };
}

function buildSignalCoverage(requiredSignals, events) {
  const observed = new Set((events || []).map((event) => event.eventType));
  const required = Array.isArray(requiredSignals) ? requiredSignals : [];
  const missing = required.filter((signal) => !observed.has(signal));
  return {
    required,
    observed: [...observed].sort(),
    missing,
    satisfied: missing.length === 0,
  };
}

function safeJsonParse(value) {
  try {
    return JSON.parse(value);
  } catch {
    return null;
  }
}

function scoreJsonFieldEquals(finalResponse, judge = {}) {
  const parsed = safeJsonParse(finalResponse);
  if (!parsed || typeof parsed !== 'object') {
    return { passed: false, score: 0, reason: 'Final response was not valid JSON.' };
  }
  const actual = parsed[judge.field];
  const passed = actual === judge.value;
  return {
    passed,
    score: passed ? 1 : 0,
    reason: passed ? '' : `Expected ${judge.field}=${JSON.stringify(judge.value)}.`,
  };
}

function scoreJsonArrayIncludesAll(finalResponse, judge = {}) {
  const parsed = safeJsonParse(finalResponse);
  if (!parsed || typeof parsed !== 'object') {
    return { passed: false, score: 0, reason: 'Final response was not valid JSON.' };
  }
  const values = Array.isArray(parsed[judge.field]) ? parsed[judge.field].map(String) : [];
  const missing = (judge.values || []).filter((value) => !values.includes(String(value)));
  return {
    passed: missing.length === 0,
    score: missing.length === 0 ? 1 : 0,
    reason: missing.length === 0 ? '' : `Missing required values: ${missing.join(', ')}.`,
  };
}

function scoreResponseRegex(finalResponse, judge = {}) {
  const regex = new RegExp(judge.pattern, judge.flags || '');
  const passed = regex.test(String(finalResponse || ''));
  return {
    passed,
    score: passed ? 1 : 0,
    reason: passed ? '' : `Final response did not match ${judge.pattern}.`,
  };
}

function evaluateStructuredJudge(finalResponse, judge = {}) {
  switch (judge.type) {
    case 'json_field_equals':
      return scoreJsonFieldEquals(finalResponse, judge);
    case 'json_array_includes_all':
      return scoreJsonArrayIncludesAll(finalResponse, judge);
    case 'response_regex':
      return scoreResponseRegex(finalResponse, judge);
    case 'response_present':
      return {
        passed: String(finalResponse || '').trim().length > 0,
        score: String(finalResponse || '').trim().length > 0 ? 1 : 0,
        reason: String(finalResponse || '').trim().length > 0 ? '' : 'Final response was empty.',
      };
    default:
      return { passed: true, score: 1, reason: '' };
  }
}

async function cloneRepoIfMissing(repoUrl, repoDir) {
  if (!repoUrl) return { cloned: false, skipped: true };
  if (await exists(repoDir)) return { cloned: false, skipped: true };
  const parentDir = path.dirname(repoDir);
  await executeCommand(`mkdir -p ${shellEscape(parentDir)}`);
  const result = await executeCommand(
    `git clone --depth 1 ${shellEscape(repoUrl)} ${shellEscape(repoDir)}`,
  );
  if (!result.ok) {
    throw new Error(result.stderr || result.stdout || `Failed to clone ${repoUrl}`);
  }
  return { cloned: true, skipped: false };
}

function shellEscape(value) {
  return `'${String(value).replace(/'/g, `'\\''`)}'`;
}

async function runExternalSuiteCommand({ suite, command, env, outputPath }) {
  const result = await executeCommand(command, { cwd: suite.repoDir || process.cwd(), env });
  if (!result.ok) {
    throw new Error(result.stderr || result.stdout || `${suite.label} runner failed.`);
  }
  if (!(await exists(outputPath))) {
    throw new Error(`${suite.label} runner did not produce ${outputPath}.`);
  }
  return readJson(outputPath);
}

module.exports = {
  buildSignalCoverage,
  cloneRepoIfMissing,
  commandExists,
  evaluateStructuredJudge,
  exists,
  missingPrerequisiteResult,
  readJson,
  readJsonLines,
  runExternalSuiteCommand,
  shellEscape,
  writeSuiteManifest,
  writeText,
};
