'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  buildSystemPromptSections,
} = require('../../../server/services/ai/systemPrompt');
const {
  buildPersonaPrompt,
} = require('../../../server/services/behavior/modules/persona_prompt');

const memoryManager = {
  async buildContext() {
    return '';
  },
  getAssistantBehaviorNotes() {
    return 'keep replies short; dry humor ok';
  },
  getAssistantSelfState() {
    return {
      identity: {
        voice: {
          notes: ['user likes short dry pushback'],
        },
      },
      focus: {},
    };
  },
  getCoreMemory() {
    return {
      ai_personality: 'de/en mix is fine',
    };
  },
};

test('the persona is principles, not a rulebook, and differs only by medium', () => {
  const text = buildPersonaPrompt('Sam');
  const voice = buildPersonaPrompt('Sam', { medium: 'voice' });
  // Intentionally lightweight — long hardcoded style manuals fight natural voice.
  assert.ok(text.length < 3500);
  assert.match(text, /you're texting with Sam/);
  assert.match(voice, /you're on a live voice call with Sam/);
  assert.match(voice, /no emojis, lists, or markdown/);
  assert.doesNotMatch(text, /\[NO RESPONSE\]/);
  assert.doesNotMatch(text, /casual_preferred/);
});

test('default messaging prompt stays natural and memory-led', async () => {
  const sections = await buildSystemPromptSections(null, { triggerSource: 'messaging' }, memoryManager);
  const prompt = [sections.stable, sections.dynamic].join('\n\n');

  assert.match(prompt, /you're texting with/);
  assert.match(prompt, /friend in their phone/i);
  assert.match(prompt, /CHANNEL: text like a contact/i);
  assert.doesNotMatch(prompt, /\bPoke\b/);
  assert.doesNotMatch(prompt, /How can I help you\?/);
  assert.doesNotMatch(prompt, /strictly lowercase/i);
});

test('living style notes inject without enum knobs', async () => {
  const sections = await buildSystemPromptSections(1, { triggerSource: 'messaging', agentId: 'main' }, memoryManager);
  const dynamic = String(sections.dynamic || '');
  assert.match(dynamic, /Assistant Behavior Notes/);
  assert.match(dynamic, /keep replies short/i);
  assert.match(dynamic, /Living Style Notes|user likes short dry pushback|de\/en mix/i);
  assert.doesNotMatch(dynamic, /humor: dry \(/);
  assert.doesNotMatch(dynamic, /casing: casual_preferred/);
});

test('fresh sessions do not invent a hardcoded voice seed', async () => {
  const bareMemory = {
    async buildContext() {
      return '';
    },
  };
  const sections = await buildSystemPromptSections(null, { triggerSource: 'messaging' }, bareMemory);
  const dynamic = String(sections.dynamic || '');
  assert.doesNotMatch(dynamic, /casual_preferred/);
  assert.doesNotMatch(dynamic, /favorite-contact/);
  assert.doesNotMatch(dynamic, /sass: medium/);
});

test('execution rules still ban fabricated completion and require real tool evidence', async () => {
  const sections = await buildSystemPromptSections(null, { triggerSource: 'web' }, memoryManager);
  const prompt = [sections.stable, sections.dynamic].join('\n\n');

  assert.match(prompt, /Never invent facts, capabilities, tool results, or completion status/i);
  assert.match(prompt, /write your answer as a plain reply without calling a tool/i);
  assert.match(prompt, /Never end with only a promise of work/i);
  assert.ok(prompt.length < 10_000, `general system prompt is bloated (${prompt.length} chars)`);
});

test('web chat stays on the general channel and does not inherit cowork workspace rules', async () => {
  const sections = await buildSystemPromptSections(null, { triggerSource: 'web' }, memoryManager);
  const prompt = [sections.stable, sections.dynamic].join('\n\n');

  assert.match(prompt, /CHANNEL: short paragraphs/);
  assert.doesNotMatch(prompt, /COWORK WORKSPACE/);
  assert.doesNotMatch(prompt, /CHANNEL: cowork/);
  assert.doesNotMatch(prompt, /ORIENT FIRST/);
  assert.doesNotMatch(prompt, /If a Cowork session already has a project folder open/);
});
