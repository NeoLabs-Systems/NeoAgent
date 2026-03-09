#!/usr/bin/env node

const { runCLI } = require('../lib/manager');

runCLI(process.argv.slice(2)).catch((err) => {
  console.error(`[neoagent] ${err.message}`);
  process.exit(1);
});
