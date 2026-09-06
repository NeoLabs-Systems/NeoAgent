'use strict';

// An unknown tool call must come back as a recoverable instruction (closest
// real tool names + how to activate them), not as a bare dead-end error the
// model can only repeat until the run gives up.

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { executeTool } = require('../../../server/services/ai/tools');
const { isInternalToolingFailure } = require('../../../server/services/ai/messagingFallback');

function stubEngine() {
  return {
    mcpManager: null,
    skillRunner: null,
    searchToolsForRun: (runId, query) => ({
      success: true,
      query,
      results: [
        { name: 'web_search', description: 'Search the web', source: 'built-in', active: false },
        { name: 'search_files', description: 'Search workspace files', source: 'built-in', active: true },
      ],
    }),
  };
}

test('an unknown tool call returns catalog suggestions instead of a dead end', async () => {
  const result = await executeTool('search', { query: 'canteen menu' }, {
    userId: 'user-1',
    agentId: 'main',
    runId: 'run-1',
  }, stubEngine());

  assert.match(result.error, /Unknown tool: search/);
  assert.match(result.recovery, /web_search/);
  assert.match(result.recovery, /activate_tools/);
});

test('unknown-tool recovery degrades gracefully without an active run', async () => {
  const engine = stubEngine();
  engine.searchToolsForRun = () => { throw new Error('Run is not active.'); };

  const result = await executeTool('search', {}, {
    userId: 'user-1',
    agentId: 'main',
    runId: 'run-x',
  }, engine);

  assert.match(result.error, /Unknown tool: search/);
  assert.match(result.recovery, /search_tools/);
});

test('unknown-tool errors are summarized as internal issues in user-facing fallbacks', () => {
  assert.equal(isInternalToolingFailure('{ "error": "Unknown tool: search" }'), true);
});
