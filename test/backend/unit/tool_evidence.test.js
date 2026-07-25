'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  classifyToolExecution,
  deriveEvidenceSource,
  gatheredNewEvidence,
  isSubstantiveProgressEvidence,
  isSubstantiveProgressToolName,
  summarizeProgressToolExecutions,
  summarizeToolExecutions,
  summarizeAvailableTools,
  inferToolFailureMessage,
  buildAutonomousRecoveryContext,
  assessResearchAdequacy,
  resolveResearchIntensity,
  extractResearchTargets,
} = require('../../../server/services/ai/toolEvidence');
const {
  isReadOnlyToolCall,
} = require('../../../server/services/ai/loop/tool_dispatch');

function toolCall(name, args = {}) {
  return {
    function: {
      name,
      arguments: JSON.stringify(args),
    },
  };
}

test('deriveEvidenceSource maps each tool family to its bucket', () => {
  const cases = {
    browser_click: 'browser',
    android_shell: 'android',
    mcp_call_tool: 'mcp',
    memory_recall: 'memory',
    session_search: 'memory',
    web_search: 'search',
    http_request: 'http',
    read_file: 'files',
    write_file: 'files',
    execute_command: 'command',
    create_skill: 'skills',
    create_task: 'tasks',
    update_ai_widget: 'tasks',
    send_message: 'messaging',
    make_call: 'messaging',
    read_health_data: 'data',
    analyze_image: 'vision',
    spawn_subagent: 'subagent',
    some_unknown_tool: 'tool',
  };
  for (const [name, expected] of Object.entries(cases)) {
    assert.equal(deriveEvidenceSource(name), expected, `${name} -> ${expected}`);
  }
});

test('deriveEvidenceSource respects rule precedence over substring overlap', () => {
  // 'browser_' prefix wins even though the name also contains 'skill'.
  assert.equal(deriveEvidenceSource('browser_skill_probe'), 'browser');
  // 'memory_' prefix wins over the later 'subagent' substring rule.
  assert.equal(deriveEvidenceSource('memory_subagent_sync'), 'memory');
});

test('classifyToolExecution tags evidence source, relevance, and state change', () => {
  const readClass = classifyToolExecution('read_file', { path: '/tmp/x' }, { content: 'ok' });
  assert.equal(readClass.evidenceSource, 'files');
  assert.equal(readClass.evidenceRelevant, true);
  assert.equal(readClass.stateChanged, false);
  assert.equal(readClass.ok, true);

  const writeClass = classifyToolExecution('write_file', { path: '/tmp/x' }, { success: true });
  assert.equal(writeClass.stateChanged, true);

  const browserClass = classifyToolExecution('browser_click', {}, { success: true });
  assert.equal(browserClass.evidenceSource, 'browser');
  assert.equal(browserClass.stateChanged, true);
});

test('official integration access metadata drives evidence and state classification', () => {
  const notionRead = classifyToolExecution(
    'notion_search',
    { query: 'roadmap' },
    { results: [{ id: 'page-1' }] },
    '',
    { name: 'notion_search', access: 'read' },
  );
  assert.equal(notionRead.evidenceSource, 'integration');
  assert.equal(notionRead.evidenceRelevant, true);
  assert.equal(notionRead.stateChanged, false);
  assert.equal(gatheredNewEvidence(notionRead, { unchangedCount: 1 }), true);
  assert.equal(gatheredNewEvidence(notionRead, { unchangedCount: 2 }), false);

  const notionWrite = classifyToolExecution(
    'notion_create_page',
    {},
    { id: 'page-2' },
    '',
    { name: 'notion_create_page', access: 'write' },
  );
  assert.equal(notionWrite.evidenceSource, 'integration');
  assert.equal(notionWrite.stateChanged, true);

  const dynamicRead = classifyToolExecution(
    'notion_api_request',
    { method: 'GET' },
    { results: [] },
    '',
    { name: 'notion_api_request', access: 'dynamic_http_method' },
  );
  const dynamicWrite = classifyToolExecution(
    'notion_api_request',
    { method: 'PATCH' },
    { id: 'page-3' },
    '',
    { name: 'notion_api_request', access: 'dynamic_http_method' },
  );
  assert.equal(dynamicRead.stateChanged, false);
  assert.equal(dynamicWrite.stateChanged, true);
});

test('official integration access metadata safely enables parallel read batches', () => {
  assert.equal(
    isReadOnlyToolCall(
      toolCall('google_workspace_gmail_get_thread', { thread_id: 'thread-1' }),
      { access: 'read' },
    ),
    true,
  );
  assert.equal(
    isReadOnlyToolCall(
      toolCall('google_workspace_gmail_send_email', { to: ['person@example.test'] }),
      { access: 'write' },
    ),
    false,
  );
  assert.equal(
    isReadOnlyToolCall(
      toolCall('notion_api_request', { method: 'GET', path: '/v1/users' }),
      { access: 'dynamic_http_method' },
    ),
    true,
  );
  assert.equal(
    isReadOnlyToolCall(
      toolCall('notion_api_request', { method: 'PATCH', path: '/v1/pages/page-1' }),
      { access: 'dynamic_http_method' },
    ),
    false,
  );

  const { AgentEngine } = require('../../../server/services/ai/loop/agent_engine_core');
  const engine = new AgentEngine(null);
  assert.equal(
    engine.isReadOnlyToolCall(toolCall('notion_search'), { access: 'read' }),
    true,
  );
});

test('new MCP and device reads count as evidence without pretending they mutate state', () => {
  const mcpRead = classifyToolExecution(
    'linear_search_issues',
    { query: 'reliability' },
    { issues: [{ id: 'ENG-1' }] },
  );
  assert.equal(mcpRead.evidenceRelevant, true);
  assert.equal(mcpRead.stateChanged, false);
  assert.equal(gatheredNewEvidence(mcpRead, { unchangedCount: 1 }), true);

  const androidRead = classifyToolExecution('android_screenshot', {}, { image: 'artifact' });
  const desktopRead = classifyToolExecution('desktop_observe', {}, { tree: [] });
  assert.equal(androidRead.stateChanged, false);
  assert.equal(desktopRead.stateChanged, false);
  assert.equal(androidRead.evidenceRelevant, true);
  assert.equal(desktopRead.evidenceRelevant, true);

  assert.equal(classifyToolExecution('android_tap', {}, { success: true }).stateChanged, true);
  assert.equal(classifyToolExecution('desktop_click', {}, { success: true }).stateChanged, true);
  assert.equal(classifyToolExecution('think', {}, { thought: 'still thinking' }).evidenceRelevant, false);
});

test('classifyToolExecution derives failure from execute_command exit code', () => {
  const failed = classifyToolExecution('execute_command', { command: 'x' }, {
    exitCode: 1,
    stderr: 'command not found',
  });
  assert.equal(failed.ok, false);
  assert.match(failed.error, /command not found/);
});

test('classifyToolExecution marks read-only execute_command as non-state-changing', () => {
  const readOnly = classifyToolExecution('execute_command', {
    command: 'curl -s https://api.github.com/repos/NeoLabs-Systems/NeoAgent/issues/91 | python3 -m json.tool | head -80',
  }, {
    stdout: '{"title":"Issue"}',
    exitCode: 0,
  });
  assert.equal(readOnly.stateChanged, false);

  const stateChanging = classifyToolExecution('execute_command', {
    command: 'git checkout -b chore/remove-widget && npm test',
  }, {
    stdout: 'ok',
    exitCode: 0,
  });
  assert.equal(stateChanging.stateChanged, true);
});

test('classifyToolExecution does not mark failed write attempts as state changes', () => {
  const successfulGithubWrite = classifyToolExecution('github_create_or_update_file', {
    owner_repo: 'NeoLabs-Systems/NeoAgent',
  }, {
    content: { path: 'README.md' },
  });
  assert.equal(successfulGithubWrite.ok, true);
  assert.equal(successfulGithubWrite.stateChanged, true);

  const failedWrite = classifyToolExecution('github_create_or_update_file', {
    owner_repo: 'NeoLabs-Systems/NeoAgent',
  }, {
    error: 'content is not valid',
  });
  assert.equal(failedWrite.ok, false);
  assert.equal(failedWrite.stateChanged, false);

  const failedCommand = classifyToolExecution('execute_command', {
    command: 'git push origin task-branch',
  }, {
    exitCode: 128,
    stderr: 'fatal: could not read Username',
  });
  assert.equal(failedCommand.ok, false);
  assert.equal(failedCommand.stateChanged, false);
});

test('classifyToolExecution treats success=false and skipped as errors', () => {
  assert.equal(classifyToolExecution('send_message', {}, { success: false, reason: 'no chat' }).error, 'no chat');
  assert.equal(classifyToolExecution('send_message', {}, { skipped: true }).error, 'Tool reported skipped outcome.');
});

test('summarizeToolExecutions renders a numbered status list', () => {
  const text = summarizeToolExecutions([
    { toolName: 'read_file', evidenceSource: 'files', ok: true, summary: 'read 10 lines' },
    { toolName: 'execute_command', evidenceSource: 'command', ok: false, error: 'boom', summary: '' },
  ]);
  assert.match(text, /1\. read_file \[files\] ok :: read 10 lines/);
  assert.match(text, /2\. execute_command \[command\] error=boom/);
});

test('progress evidence excludes communication and meta-only tool activity', () => {
  assert.equal(isSubstantiveProgressToolName('send_message'), false);
  assert.equal(isSubstantiveProgressToolName('send_interim_update'), false);
  assert.equal(isSubstantiveProgressToolName('notify_user'), false);
  assert.equal(isSubstantiveProgressToolName('think'), false);
  assert.equal(isSubstantiveProgressToolName('read_file'), true);

  const sentReply = classifyToolExecution('send_message', { content: 'done' }, { success: true });
  const thought = classifyToolExecution('think', { thought: 'considering' }, { thought: 'considering' });
  const inspectedFile = classifyToolExecution('read_file', { path: 'server/index.js' }, { content: 'ok' });

  assert.equal(isSubstantiveProgressEvidence(sentReply), false);
  assert.equal(isSubstantiveProgressEvidence(thought), false);
  assert.equal(isSubstantiveProgressEvidence(inspectedFile), true);

  const summary = summarizeProgressToolExecutions([sentReply, thought, inspectedFile]);
  assert.doesNotMatch(summary, /send_message/);
  assert.doesNotMatch(summary, /think/);
  assert.match(summary, /read_file/);
});

test('summarizeAvailableTools excludes a tool and caps the list', () => {
  const tools = Array.from({ length: 30 }, (_, i) => ({ name: `tool_${i}` }));
  const summary = summarizeAvailableTools(tools, { exclude: 'tool_0' });
  assert.ok(!summary.includes('tool_0'));
  assert.equal(summary.split(', ').length, 24);
});

test('inferToolFailureMessage surfaces http and command failures', () => {
  assert.equal(inferToolFailureMessage('read_file', { error: 'denied' }), 'denied');
  assert.match(
    inferToolFailureMessage('http_request', { status: 503, body: 'unavailable' }),
    /status 503: unavailable/,
  );
  assert.equal(inferToolFailureMessage('read_file', { content: 'fine' }), '');
});

test('buildAutonomousRecoveryContext references the last failure and alternatives', () => {
  const context = buildAutonomousRecoveryContext({
    err: { message: 'run aborted' },
    toolExecutions: [{ toolName: 'web_search', ok: false, error: 'rate limited' }],
    tools: [{ name: 'web_search' }, { name: 'http_request' }],
    userMessage: 'find the weather',
    visibleMessageSent: true,
  });
  assert.match(context, /failed on tool: web_search/);
  assert.match(context, /Concrete failure: rate limited/);
  assert.match(context, /Other available tools in this run: http_request/);
  assert.match(context, /user-facing message was already sent/);
});


test('research intensity stays none for local implementation work without external evidence needs', () => {
  const intensity = resolveResearchIntensity({
    mode: 'plan_execute',
    complexity: 'complex',
    autonomy_level: 'high',
    completion_confidence_required: 'high',
    verification_need: 'light',
    freshness_risk: 'none',
    planning_depth: 'deep',
    goal: 'Implement the pause/resume fix in the agent loop',
    success_criteria: ['Write the code', 'Run the unit tests'],
    suggested_tools: ['read_file', 'edit_file', 'execute_command'],
  });
  assert.equal(intensity, 'none');
});

test('multi-target research requires primary evidence for each named target before adequacy', () => {
  const analysis = {
    mode: 'execute',
    complexity: 'standard',
    autonomy_level: 'normal',
    completion_confidence_required: 'high',
    verification_need: 'required',
    freshness_risk: 'possible',
    planning_depth: 'light',
    goal: 'Look into AnoleX 3030-Evo Max, Genmitsu 3018 Pro, and SainSmart 3018',
    success_criteria: [
      'Compare AnoleX 3030-Evo Max',
      'Compare Genmitsu 3018 Pro',
      'Compare SainSmart 3018',
    ],
    research_targets: [
      'AnoleX 3030-Evo Max',
      'Genmitsu 3018 Pro',
      'SainSmart 3018',
    ],
    suggested_tools: ['web_search', 'browser_navigate', 'http_request'],
  };

  assert.equal(resolveResearchIntensity(analysis), 'deep');
  assert.deepEqual(
    extractResearchTargets('Compare "AnoleX 3030-Evo Max" and Genmitsu 3018 Pro'),
    ['AnoleX 3030-Evo Max', 'Genmitsu 3018 Pro'],
  );

  const onlySearch = assessResearchAdequacy({
    analysis,
    toolExecutions: [
      {
        toolName: 'web_search',
        ok: true,
        evidenceSource: 'search',
        evidenceRelevant: true,
        summary: 'search hits for AnoleX 3030-Evo Max',
        input: { query: 'AnoleX 3030-Evo Max specs' },
      },
    ],
  });
  assert.equal(onlySearch.intensity, 'deep');
  assert.equal(onlySearch.adequate, false);
  assert.ok(onlySearch.uncoveredTargets.includes('Genmitsu 3018 Pro'));
  assert.ok(onlySearch.uncoveredTargets.includes('SainSmart 3018'));
  assert.match(onlySearch.reason, /primary source|primary-source|Search snippets/i);

  const fullCoverage = assessResearchAdequacy({
    analysis,
    toolExecutions: [
      {
        toolName: 'web_search',
        ok: true,
        evidenceSource: 'search',
        evidenceRelevant: true,
        summary: 'search hits',
        input: { query: 'cnc routers comparison' },
      },
      {
        toolName: 'browser_navigate',
        ok: true,
        evidenceSource: 'browser',
        evidenceRelevant: true,
        summary: 'opened AnoleX product page',
        input: { url: 'https://example.test/anolex-3030-evo-max' },
      },
      {
        toolName: 'http_request',
        ok: true,
        evidenceSource: 'http',
        evidenceRelevant: true,
        summary: 'fetched Genmitsu 3018 Pro docs',
        input: { url: 'https://example.test/genmitsu-3018-pro' },
      },
      {
        toolName: 'browser_navigate',
        ok: true,
        evidenceSource: 'browser',
        evidenceRelevant: true,
        summary: 'opened SainSmart 3018 page',
        input: { url: 'https://example.test/sainsmart-3018' },
      },
    ],
  });
  assert.equal(fullCoverage.adequate, true);
  assert.equal(fullCoverage.coveredTargets.length, 3);
  assert.equal(fullCoverage.primaryCoveredTargets.length, 3);
});

test('completion judge keeps incomplete multi-target research in continue state', () => {
  const { enforceTerminalReplyDecision } = require('../../../server/services/ai/loop/completion_judge');
  const analysis = {
    mode: 'execute',
    completion_confidence_required: 'high',
    verification_need: 'required',
    freshness_risk: 'possible',
    goal: 'Look into AnoleX 3030-Evo Max and Genmitsu 3018 Pro',
    research_targets: ['AnoleX 3030-Evo Max', 'Genmitsu 3018 Pro'],
    success_criteria: ['Compare AnoleX 3030-Evo Max', 'Compare Genmitsu 3018 Pro'],
    suggested_tools: ['web_search', 'browser_navigate'],
  };
  const decision = enforceTerminalReplyDecision(
    { status: 'complete', reason: 'Looks good enough.' },
    'Die AnoleX ist solide und die Genmitsu ist der Standard.',
    {
      analysis,
      toolExecutions: [
        {
          toolName: 'web_search',
          ok: true,
          evidenceSource: 'search',
          evidenceRelevant: true,
          summary: 'snippets about AnoleX 3030-Evo Max',
          input: { query: 'AnoleX 3030-Evo Max' },
        },
      ],
    },
  );
  assert.equal(decision.status, 'continue');
  assert.match(decision.reason, /Need|primary|evidence|source/i);
});

