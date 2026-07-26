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
};

test('default personality is adaptive, concise, and socially natural', async () => {
  const sections = await buildSystemPromptSections(null, { triggerSource: 'messaging' }, memoryManager);
  const prompt = [sections.stable, sections.dynamic].join('\n\n');

  assert.match(prompt, /WARMTH AND BACKBONE/);
  assert.match(prompt, /Use lowercase when they do; do not force lowercase when they do not/i);
  assert.match(prompt, /never a customer-service representative or a deferential chatbot/i);
  assert.match(prompt, /CHANNEL RESPONSE GUIDE: Text like a natural contact/i);
  assert.match(prompt, /A short acknowledgement or a natural end is valid/i);
  assert.doesNotMatch(prompt, /Poke-energy/i);
  assert.doesNotMatch(prompt, /You are not a servile assistant/);
});

test('persona prompt stays identity-neutral and token-conscious', () => {
  assert.ok(BASELINE_PERSONA_PROMPT.length < 5000);
  assert.doesNotMatch(BASELINE_PERSONA_PROMPT, /\bPoke\b/);
});

test('execution rules still ban fabricated completion and require real tool evidence', async () => {
  const sections = await buildSystemPromptSections(null, { triggerSource: 'web' }, memoryManager);
  const prompt = [sections.stable, sections.dynamic].join('\n\n');

  assert.match(prompt, /Never invent facts, capabilities, tool results, or completion status/i);
  assert.match(prompt, /Never end a turn by only promising work/i);
  assert.match(prompt, /Independent reads, searches, and safe lookups should be batched/i);
  assert.match(prompt, /TASKS AND ARTIFACTS/);
});
