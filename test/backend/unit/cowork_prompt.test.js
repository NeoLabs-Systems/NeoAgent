'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  buildCoworkAnalysisInstructions,
  buildCoworkExecutionGuidance,
  buildCoworkOperatingContract,
  workspaceFolderName,
} = require('../../../server/services/cowork/prompt');
const { buildSystemPromptSections } = require('../../../server/services/ai/systemPrompt');
const { buildAnalysisPrompt, buildExecutionGuidance } = require('../../../server/services/ai/taskAnalysis');

const memoryManager = {
  async buildContext() {
    return '';
  },
};

const COWORK_ONLY_PHRASES = [
  /COWORK WORKSPACE/,
  /CHANNEL: cowork/,
  /already-open project folder/,
  /The open folder is the source/,
  /attached project folder/,
  /attached workspace/,
];

test('workspace folder name uses the last path segment', () => {
  assert.equal(workspaceFolderName('/Users/neo/Projects/Neotastisch-Portfolio'), 'Neotastisch-Portfolio');
  assert.equal(workspaceFolderName('C:\\Users\\neo\\Neotastisch-Portfolio\\'), 'Neotastisch-Portfolio');
  assert.equal(workspaceFolderName(''), null);
});

test('cowork operating contract is workspace-first and does not ask for a URL', () => {
  const prompt = buildCoworkOperatingContract({
    triggerSource: 'cowork',
    workspaceRoot: '/Users/neo/Projects/Neotastisch-Portfolio',
    deviceTarget: 'local',
    interactionMode: 'agent',
  });

  assert.match(prompt, /COWORK WORKSPACE/);
  assert.match(prompt, /already-open project folder/);
  assert.match(prompt, /Do not ask for a URL/);
  assert.match(prompt, /Open folder: Neotastisch-Portfolio/);
  assert.match(prompt, /AGENT MODE/);
  assert.match(prompt, /Edit the workspace now/);
  assert.match(prompt, /Computer: this device/);
  assert.match(prompt, /WORKFLOW/);
  assert.match(prompt, /list_directory\("\."\)/);
  assert.match(prompt, /Shared chat attachments/);
  assert.match(prompt, /do not clone or remotely rediscover code already present/i);
  assert.match(prompt, /Do not permanently delete files unless requested/);
  assert.match(prompt, /material user-owned choice or destructive scope/);
  assert.doesNotMatch(prompt, /PLAN MODE/);
  assert.equal(buildCoworkOperatingContract({ triggerSource: 'web' }), '');
  assert.equal(buildCoworkOperatingContract({ triggerSource: 'messaging' }), '');
  assert.equal(buildCoworkOperatingContract({}), '');
});

test('cowork plan mode stays inspect-only', () => {
  const prompt = buildCoworkOperatingContract({
    triggerSource: 'cowork',
    interactionMode: 'plan',
  });
  assert.match(prompt, /PLAN MODE/);
  assert.match(prompt, /Do not run shell commands/);
  assert.match(prompt, /default NeoAgent workspace/);
  assert.doesNotMatch(prompt, /AGENT MODE/);
});

test('cowork system prompt includes the attached folder and channel style', async () => {
  const sections = await buildSystemPromptSections(null, {
    triggerSource: 'cowork',
    workspaceRoot: '/Users/neo/Projects/Neotastisch-Portfolio',
    deviceTarget: 'local',
    interactionMode: 'agent',
  }, memoryManager);
  const prompt = [sections.stable, sections.dynamic].join('\n\n');

  assert.match(prompt, /COWORK WORKSPACE/);
  assert.match(prompt, /Neotastisch-Portfolio/);
  assert.match(prompt, /CHANNEL: cowork/);
  assert.match(prompt, /WORKFLOW/);
  assert.doesNotMatch(prompt, /CHANNEL: short paragraphs/);
});

test('cowork task analysis prefers file tools over web research', () => {
  const prompt = buildAnalysisPrompt({
    triggerSource: 'cowork',
    tools: [
      { name: 'list_directory', description: 'List workspace files.' },
      { name: 'web_search', description: 'Search the web.' },
    ],
  });
  assert.match(prompt, /attached project folder/);
  assert.match(prompt, /never "direct_answer"/);
  assert.match(prompt, /Prefer workspace inspection\/edit tools/);
  assert.match(prompt, /do not ask for a URL/);
  assert.deepEqual(
    buildCoworkAnalysisInstructions({ triggerSource: 'web' }),
    [],
  );
  assert.deepEqual(
    buildCoworkAnalysisInstructions({ triggerSource: 'messaging' }),
    [],
  );
});

test('cowork execution guidance tells the model to edit the attached folder', () => {
  const prompt = buildExecutionGuidance({
    triggerSource: 'cowork',
    analysis: {
      mode: 'execute',
      goal: 'Revamp the portfolio.',
      success_criteria: ['The local files are updated.'],
    },
  });
  assert.match(prompt, /attached workspace/);
  assert.match(prompt, /make the requested edits now/);
  assert.match(prompt, /Verify changed state from disk/);
  assert.deepEqual(
    buildCoworkExecutionGuidance({ triggerSource: 'messaging' }),
    [],
  );
});

test('web, messaging, and voice prompts stay free of cowork-only rules', async () => {
  for (const triggerSource of ['web', 'messaging', 'voice_live']) {
    const sections = await buildSystemPromptSections(null, { triggerSource }, memoryManager);
    const prompt = [sections.stable, sections.dynamic].join('\n\n');
    for (const phrase of COWORK_ONLY_PHRASES) {
      assert.doesNotMatch(prompt, phrase, `${phrase} leaked into ${triggerSource}`);
    }
    assert.doesNotMatch(prompt, /File-by-file GitHub API calls are slow and hit rate limits fast/);
    assert.doesNotMatch(prompt, /If a Cowork session already has a project folder open/);
  }
});

test('non-cowork analysis and execution prompts stay free of cowork-only rules', () => {
  for (const triggerSource of [undefined, 'web', 'messaging', 'voice_live']) {
    const analysis = buildAnalysisPrompt({
      triggerSource,
      tools: [{ name: 'web_search', description: 'Search the web.' }],
    });
    const guidance = buildExecutionGuidance({
      triggerSource,
      analysis: {
        mode: 'execute',
        goal: 'Look into this.',
        success_criteria: ['Answer the question.'],
      },
    });
    for (const phrase of COWORK_ONLY_PHRASES) {
      assert.doesNotMatch(analysis, phrase, `${phrase} leaked into ${triggerSource} analysis`);
      assert.doesNotMatch(guidance, phrase, `${phrase} leaked into ${triggerSource} guidance`);
    }
  }
});
