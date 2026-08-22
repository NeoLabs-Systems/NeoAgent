'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const { test } = require('node:test');

const {
  createTestRuntime,
  createTestUser,
  teardownTestRuntime,
} = require('../../helpers/db');

test('Teach Mode creates an active adaptive skill and purges encrypted raw data', async () => {
  const ctx = createTestRuntime();
  let service;
  try {
    const user = await createTestUser(ctx.db);
    const {
      buildSynthesisTimeline,
      TeachService,
      decryptJson,
    } = require('../../../server/services/teach/service');
    const leases = new Map();
    const screenshot = Buffer.from('test-png-content').toString('base64');
    const runtimeManager = {
      acquireControl(userId, ownerType, ownerId) {
        const lease = leases.get(String(userId));
        if (lease && (lease.ownerType !== ownerType || lease.ownerId !== ownerId)) {
          throw new Error('lease conflict');
        }
        const next = { ownerType, ownerId };
        leases.set(String(userId), next);
        return next;
      },
      releaseControl(userId, ownerId) {
        const lease = leases.get(String(userId));
        if (!lease || lease.ownerId !== ownerId) return false;
        leases.delete(String(userId));
        return true;
      },
      async requestComputer(_userId, method, pathname) {
        if (method === 'GET' && pathname === '/teach/context') {
          return {
            activeWindow: 'Chromium',
            sensitiveInputActive: false,
            accessibility: [{ role: 'button', name: 'Export' }],
            shellEvents: [],
            files: [{ path: 'report.csv', size: 12, modifiedAt: '2026-08-13T10:00:00Z' }],
          };
        }
        if (method === 'POST' && pathname === '/desktop/screenshot') {
          return { path: '/tmp/teach.png' };
        }
        if (method === 'POST' && pathname === '/files/read') {
          return { content: screenshot };
        }
        throw new Error(`Unexpected guest request: ${method} ${pathname}`);
      },
      async getBrowserProviderForUser() {
        return {
          async evaluate(script) {
            return script.includes('input,textarea') ? false : [];
          },
          async getPageInfo() {
            return { title: 'Reports', url: 'https://example.test/reports' };
          },
          async extractContent() {
            return { text: 'Reports Export' };
          },
        };
      },
    };
    const agentEngine = {
      async inferStructured() {
        return {
          parsed: {
            approved: true,
            skill: {
              name: 'export-report',
              description: 'Export the current report.',
              trigger: 'Use when exporting a report for a selected period through the reports interface.',
              category: 'computer',
              workflowKey: 'export-report',
              requiredInputs: ['Report period'],
              steps: [
                'Inspect the reports view and activate Export using semantic UI information.',
                'Choose the requested period and verify that the report file appears.',
              ],
              verification: ['The requested report exists in the workspace.'],
              pitfalls: ['Reinspect the page and locate Export again if the report state changes.'],
            },
          },
        };
      },
    };
    const { SkillRunner } = require('../../../server/services/ai/toolRunner');
    const { SkillLearningService } = require('../../../server/services/skills/learning_service');
    const skillRunner = new SkillRunner();
    await skillRunner.loadSkills();
    const skillLearningService = new SkillLearningService({ skillRunner, agentEngine });

    service = new TeachService({
      runtimeManager,
      skillLearningService,
      imageAnalyzer: async () => ({ description: 'Chromium shows the Reports page and an Export button.' }),
    });
    const started = await service.start(user.userId, { goal: 'Export a report for a chosen period' });
    const session = service.sessions.get(started.id);
    assert.ok(session);

    await service.record(user.userId, {
      type: 'text-input',
      value: 'never-store-this-secret',
    });
    const encrypted = fs.readFileSync(session.filePath);
    assert.equal(encrypted.includes(Buffer.from('never-store-this-secret')), false);
    const decrypted = decryptJson(session.key, encrypted);
    assert.equal(decrypted.events.at(-1).value, '[runtime input]');
    assert.deepEqual(service.serialize(session).timeline.at(-1), {
      sequence: 2,
      type: 'text-input',
      atMs: session.events.at(-1).atMs,
    });
    assert.equal('position' in buildSynthesisTimeline([{
      sequence: 1,
      type: 'pointer',
      atMs: 10,
      position: { x: 50, y: 70 },
    }])[0], false);

    const result = await service.stop(user.userId, started.id);
    assert.equal(result.success, true);
    assert.equal(result.skill, 'export-report');
    assert.equal(service.sessions.size, 0);
    assert.equal(fs.existsSync(session.filePath), false);
    assert.equal(leases.size, 0);

    const skill = ctx.db.prepare(
      'SELECT enabled, auto_created, metadata FROM skills WHERE user_id = ? AND name = ?',
    ).get(user.userId, 'export-report');
    assert.equal(skill.enabled, 1);
    assert.equal(skill.auto_created, 1);
    const metadata = JSON.parse(skill.metadata);
    assert.equal(metadata.source, 'learned');
    assert.equal(metadata.category, 'computer');
    assert.equal(metadata.learning.origin, 'computer-demonstration');
    assert.equal(metadata.learning.managed, true);
    const version = ctx.db.prepare(
      'SELECT version, status, content_md FROM agent_skill_versions WHERE skill_id = (SELECT id FROM skills WHERE user_id = ? AND name = ?)',
    ).get(user.userId, 'export-report');
    assert.equal(version.version, 1);
    assert.equal(version.status, 'validated');
    assert.match(version.content_md, /normal NeoAgent loop/);
    assert.doesNotMatch(version.content_md, /never-store-this-secret/);
  } finally {
    service?.shutdown();
    teardownTestRuntime(ctx);
  }
});
