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

  assert.match(prompt, /WARMTH WITH BACKBONE/);
  assert.match(prompt, /Use lowercase when the user does\. Do not force lowercase/i);
  assert.match(prompt, /not a customer-service representative/i);
  assert.match(prompt, /CHANNEL RESPONSE GUIDE: Text like a natural contact/i);
  assert.match(prompt, /A conversation ending does not require reopening it/i);
  assert.doesNotMatch(prompt, /Poke-energy/i);
  assert.doesNotMatch(prompt, /You are not a servile assistant/);
});

test('persona prompt stays identity-neutral and defines the full messaging contract', () => {
  assert.ok(BASELINE_PERSONA_PROMPT.length > 9000);
  assert.doesNotMatch(BASELINE_PERSONA_PROMPT, /\bPoke\b/);
  assert.match(BASELINE_PERSONA_PROMPT, /CONTRASTIVE CALIBRATION/);
  assert.match(BASELINE_PERSONA_PROMPT, /Do not evade these lines with slightly altered corporate synonyms/i);
  assert.match(BASELINE_PERSONA_PROMPT, /A conversation ending does not require reopening it/i);
});

test('execution rules still ban fabricated completion and require real tool evidence', async () => {
  const sections = await buildSystemPromptSections(null, { triggerSource: 'web' }, memoryManager);
  const prompt = [sections.stable, sections.dynamic].join('\n\n');

  assert.match(prompt, /Never invent facts, capabilities, tool results, or completion status/i);
  assert.match(prompt, /Never end a turn by only promising work/i);
  assert.match(prompt, /Independent reads, searches, and safe lookups should be batched/i);
  assert.match(prompt, /TASKS, DRAFTS, AND TOOL WORK/);
});
