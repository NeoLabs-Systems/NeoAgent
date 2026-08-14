'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  buildSystemPromptSections,
} = require('../../../server/services/ai/systemPrompt');
const {
  BASELINE_PERSONA_PROMPT,
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

test('baseline persona is short principles not a rulebook', () => {
  // Intentionally lightweight — long hardcoded style manuals fight natural voice.
  assert.ok(BASELINE_PERSONA_PROMPT.length < 3500);
  assert.ok(BASELINE_PERSONA_PROMPT.length > 400);
  assert.doesNotMatch(BASELINE_PERSONA_PROMPT, /\bPoke\b/);
  assert.doesNotMatch(BASELINE_PERSONA_PROMPT, /CONTRASTIVE CALIBRATION/);
  assert.doesNotMatch(BASELINE_PERSONA_PROMPT, /CASING \(ENCOURAGED/);
  assert.doesNotMatch(BASELINE_PERSONA_PROMPT, /casual_preferred/);
  assert.match(BASELINE_PERSONA_PROMPT, /durable style notes from memory/i);
  assert.match(BASELINE_PERSONA_PROMPT, /casual lowercase is fine/i);
  assert.match(BASELINE_PERSONA_PROMPT, /never force it/i);
  assert.match(BASELINE_PERSONA_PROMPT, /Generate original replies/i);
});

test('default messaging prompt stays natural and memory-led', async () => {
  const sections = await buildSystemPromptSections(null, { triggerSource: 'messaging' }, memoryManager);
  const prompt = [sections.stable, sections.dynamic].join('\n\n');

  assert.match(prompt, /MESSAGING VOICE/);
  assert.match(prompt, /capable friend with judgment/i);
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
  assert.match(prompt, /Never end a turn by only promising work/i);
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
