#!/usr/bin/env node
'use strict';

// Runs the harness eval set and prints what it measured.
//   npm run eval:harness                      scripted cases, no keys needed
//   npm run eval:harness -- --update-baseline stores the result as the new baseline
//   npm run eval:harness -- --live --model provider::id --repeat 3
// Live runs compare harness versions only when model and settings stay the same.
const fs = require('fs');
const path = require('path');

const { runLiveCases, runScriptedCases } = require('../test/harness_eval/runner');
const { checkGate } = require('../test/harness_eval/gate');

const BASELINE_FILE = path.join(__dirname, '../test/harness_eval/baseline.json');

function argument(name) {
  const index = process.argv.indexOf(`--${name}`);
  return index === -1 ? null : process.argv[index + 1];
}

function has(name) {
  return process.argv.includes(`--${name}`);
}

function loadEnvFile(file) {
  if (!file) return {};
  return Object.fromEntries(
    fs.readFileSync(file, 'utf8').split('\n')
      .map((line) => line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$/))
      .filter(Boolean)
      .map(([, key, value]) => [key, value.replace(/^["']|["']$/g, '')]),
  );
}

function printReport({ results, summary }) {
  for (const entry of results) {
    const attempts = entry.attempts ? ` ${entry.passes}/${entry.attempts}` : '';
    console.log(`${entry.ok ? 'pass' : 'FAIL'}${attempts}  ${entry.id}${entry.detail ? `  (${entry.detail})` : ''}`);
  }
  console.log(`\n${JSON.stringify(summary, null, 2)}`);
}

async function main() {
  const live = has('live');
  const filter = argument('only');
  const only = filter ? (evalCase) => evalCase.id.includes(filter) || evalCase.category === filter : null;
  const report = live
    ? await runLiveCases({
      modelId: argument('model'),
      repeat: Math.max(1, Number(argument('repeat')) || 1),
      only,
      env: loadEnvFile(argument('env-file')),
    })
    : await runScriptedCases({ only });
  printReport(report);

  if (has('json-out')) fs.writeFileSync(argument('json-out'), JSON.stringify(report, null, 2));
  if (has('update-baseline')) {
    if (only || report.results.some((entry) => !entry.ok)) throw new Error('A baseline requires the complete passing eval set.');
    const previous = fs.existsSync(BASELINE_FILE) ? JSON.parse(fs.readFileSync(BASELINE_FILE, 'utf8')) : {};
    fs.writeFileSync(BASELINE_FILE, `${JSON.stringify({ tolerance: previous.tolerance || {}, ...report.summary }, null, 2)}\n`);
    console.log(`\nBaseline stored in ${path.relative(process.cwd(), BASELINE_FILE)}`);
    return;
  }
  const baseline = !live && !only && fs.existsSync(BASELINE_FILE)
    ? JSON.parse(fs.readFileSync(BASELINE_FILE, 'utf8'))
    : null;
  const verdict = checkGate(report.summary, baseline);
  if (!verdict.ok) {
    console.error('\nRegression gate failed:', JSON.stringify(verdict.failures, null, 2));
    process.exitCode = 1;
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}).finally(() => {
  // The server modules the eval loads keep timers running.
  setTimeout(() => process.exit(process.exitCode || 0), 100).unref();
});
