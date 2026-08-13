'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
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
    let inference = 0;
    const agentEngine = {
      async inferStructured() {
        inference += 1;
        if (inference === 1) {
          return {
            parsed: {
              name: 'export-report',
              description: 'Export the current report.',
              inputs: ['Report period'],
              steps: [
                'Open the reports view and locate the Export action by its accessible name.',
                'Choose the requested period and verify that the report file appears.',
              ],
              successCriteria: ['The requested report exists in the workspace.'],
              recovery: ['Refresh the report state and locate the Export action again.'],
              askUserWhen: ['The report period is missing.'],
            },
          };
        }
        return {
          parsed: {
            approved: true,
            revised: {
              name: 'export-report',
              description: 'Export the current report.',
              inputs: ['Report period'],
              steps: [
                'Inspect the reports view and activate Export using semantic UI information.',
                'Choose the requested period and verify that the report file appears.',
              ],
              successCriteria: ['The requested report exists in the workspace.'],
              recovery: ['Reinspect the page and retry the semantic Export action.'],
              askUserWhen: ['The report period is missing.'],
            },
          },
        };
      },
    };
    const skillRunner = {
      createSkill(userId, name, description, instructions, metadata) {
        const directory = path.join(ctx.dataDir, 'skills', String(userId), name);
        fs.mkdirSync(directory, { recursive: true });
        const filePath = path.join(directory, 'SKILL.md');
        fs.writeFileSync(filePath, instructions);
        ctx.db.prepare(
          `INSERT INTO skills (user_id, name, description, file_path, metadata, enabled, auto_created)
           VALUES (?, ?, ?, ?, ?, 1, 1)`,
        ).run(userId, name, description, filePath, JSON.stringify(metadata));
        return { success: true, name, path: filePath };
      },
      updateSkill() {
        throw new Error('Unexpected skill update');
      },
    };

    service = new TeachService({
      runtimeManager,
      agentEngine,
      skillRunner,
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
    assert.equal(JSON.parse(skill.metadata).teach_provenance.goal, 'Export a report for a chosen period');
    const version = ctx.db.prepare(
      'SELECT version, status, content_md FROM agent_skill_versions WHERE skill_id = (SELECT id FROM skills WHERE user_id = ? AND name = ?)',
    ).get(user.userId, 'export-report');
    assert.equal(version.version, 1);
    assert.equal(version.status, 'validated');
    assert.match(version.content_md, /normal NeoAgent agent loop/);
    assert.doesNotMatch(version.content_md, /never-store-this-secret/);
  } finally {
    service?.shutdown();
    teardownTestRuntime(ctx);
  }
});
