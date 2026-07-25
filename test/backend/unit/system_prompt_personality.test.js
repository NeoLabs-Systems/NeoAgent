'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  buildSystemPromptSections,
} = require('../../../server/services/ai/systemPrompt');

const memoryManager = {
  async buildContext() {
    return '';
  },
};

test('default personality sounds like a favorite contact, not a helpdesk bot', async () => {
  const sections = await buildSystemPromptSections(null, { triggerSource: 'messaging' }, memoryManager);
  const prompt = [sections.stable, sections.dynamic].join('\n\n');

  assert.match(prompt, /favorite contact/i);
  assert.match(prompt, /text-native/i);
  assert.match(prompt, /Kill the customer-service register/i);
  assert.match(prompt, /CHANNEL RESPONSE GUIDE: Messaging replies should feel like a favorite contact texting back/i);
  assert.match(prompt, /good favorite-contact energy/i);
  assert.match(prompt, /bad casual opener: "Hello! How can I assist you today\?"/);
  assert.doesNotMatch(prompt, /You are not a servile assistant/);
});

test('execution rules still ban fabricated completion and require real tool evidence', async () => {
  const sections = await buildSystemPromptSections(null, { triggerSource: 'web' }, memoryManager);
  const prompt = [sections.stable, sections.dynamic].join('\n\n');

  assert.match(prompt, /Never invent facts, capabilities, tool results, or completion status/i);
  assert.match(prompt, /Never end a turn by only promising work/i);
  assert.match(prompt, /Independent reads, searches, and safe lookups should be batched/i);
  assert.match(prompt, /good favorite-contact energy/i);
});
