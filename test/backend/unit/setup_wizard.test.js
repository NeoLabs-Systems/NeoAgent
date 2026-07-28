'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const { runSetupWizard } = require('../../../lib/setup/wizard');

test('setup wizard supports back, skip, resume, and non-secret transitions', async () => {
  const visited = [];
  const transitions = [];
  let providerVisits = 0;
  let integrationVisits = 0;
  const result = await runSetupWizard({
    startSectionId: 'providers',
    completedSections: ['core'],
    runSection: async (section) => {
      visited.push(section.id);
      if (section.id === 'providers') {
        providerVisits += 1;
        return providerVisits === 1 ? { action: 'next' } : { action: 'skip' };
      }
      if (section.id === 'integrations') {
        integrationVisits += 1;
        return integrationVisits === 1 ? { action: 'back' } : { action: 'next' };
      }
      return { action: 'next' };
    },
    onTransition: async (state) => transitions.push(state),
  });

  assert.deepEqual(visited, [
    'providers',
    'integrations',
    'providers',
    'integrations',
    'voice',
    'review',
  ]);
  assert.deepEqual(result.completedSections, ['core', 'integrations', 'voice']);
  assert.deepEqual(result.skippedSections, ['providers']);
  assert.equal(
    transitions.some((state) => Object.hasOwn(state, 'apiKey')),
    false,
  );
});

test('setup wizard cancellation has a stable code', async () => {
  await assert.rejects(
    runSetupWizard({
      runSection: async () => ({ action: 'cancel' }),
    }),
    (error) => error.code === 'SETUP_CANCELLED',
  );
});
