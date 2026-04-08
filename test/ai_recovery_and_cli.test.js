const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');

const runtimeRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-ai-recovery-'));
process.env.NEOAGENT_HOME = path.join(runtimeRoot, 'home');
process.env.NEOAGENT_DATA_DIR = path.join(runtimeRoot, 'data');
process.env.NEOAGENT_AGENT_DATA_DIR = path.join(runtimeRoot, 'agent-data');

const { AgentEngine } = require('../server/services/ai/engine');
const { compactToolResult } = require('../server/services/ai/toolResult');
const { CLIExecutor } = require('../server/services/cli/executor');

test('blank messaging recovery falls back to concrete work and blocker summary', async () => {
  const engine = new AgentEngine({});
  const provider = {
    chat: async () => ({
      content: '',
      usage: { totalTokens: 1 },
    }),
  };

  const recovered = await engine.recoverBlankMessagingReply({
    userId: 1,
    runId: 'run-recovery-test',
    messages: [{ role: 'user', content: 'Please make a demo video with manim.' }],
    provider,
    model: 'MiniMax-M2.7',
    providerName: 'minimax',
    options: {},
    stepIndex: 4,
    failedStepCount: 1,
    toolExecutions: [
      {
        toolName: 'read_file',
        ok: false,
        error: 'ENOENT: no such file or directory',
        summary: compactToolResult(
          'read_file',
          { path: '/app/skills/manim-video/SKILL.md' },
          { error: 'ENOENT: no such file or directory' },
        ),
      },
      {
        toolName: 'execute_command',
        ok: true,
        error: '',
        summary: compactToolResult(
          'execute_command',
          { command: 'python3 -m pip install manim 2>&1 | tail -5' },
          {
            exitCode: 0,
            stdout: 'ERROR: Failed building wheel for pycairo',
            stderr: '',
            killed: false,
            timedOut: false,
            durationMs: 1200,
            cwd: '/Users/neo',
          },
        ),
      },
    ],
  });

  assert.match(recovered.content, /I checked files and ran shell commands/i);
  assert.match(recovered.content, /pycairo|building wheel/i);
  assert.doesNotMatch(recovered.content, /Please send the request again/i);
  assert.doesNotMatch(recovered.content, /final reply did not render correctly/i);
});

test('cli executor preserves pipeline failures', async () => {
  const executor = new CLIExecutor();
  const result = await executor.execute('false | cat');

  assert.notEqual(result.exitCode, 0);
});
