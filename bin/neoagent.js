#!/usr/bin/env node

const crypto = require('crypto');
const { runCLI } = require('../lib/manager');

runCLI(process.argv.slice(2)).catch((err) => {
  if (process.argv.includes('--json') && !err.setupEventEmitted) {
    const argumentError = new Set([
      'SETUP_PROFILE_CONFLICT',
      'SETUP_REQUIRED_VALUE_MISSING',
    ]).has(err.code);
    process.stdout.write(`${JSON.stringify({
      schemaVersion: 1,
      runId: crypto.randomUUID(),
      profile: process.argv.includes('--full') ? 'full' : 'quick',
      stage: 'prepare',
      state: 'failed',
      error: {
        code: err.code || 'SETUP_FAILED',
        retryable: !argumentError,
        action: argumentError ? 'fix-input' : 'retry',
        detail: err.message,
      },
    })}\n`);
  } else if (!process.argv.includes('--json')) {
    console.error(`[neoagent] ${err.message}`);
  }
  process.exit(1);
});
