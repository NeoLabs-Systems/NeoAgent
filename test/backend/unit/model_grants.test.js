'use strict';

const assert = require('node:assert/strict');
const { afterEach, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

let ctx;

afterEach(() => {
  teardownTestRuntime(ctx);
  ctx = null;
});

test('a grant lifts the server-wide switch for that model only', () => {
  ctx = createTestRuntime();
  const { modelAccess } = require('../../../server/services/ai/model_grants');
  const premium = { id: 'anthropic::claude-opus', modelId: 'claude-opus', provider: 'anthropic' };
  const other = { id: 'openai::gpt-big', modelId: 'gpt-big', provider: 'openai' };
  const open = { id: 'openai::gpt-small', modelId: 'gpt-small', provider: 'openai' };
  const disabled = new Set([premium.id, other.id]);
  const granted = new Set([premium.id]);

  assert.deepEqual(modelAccess(premium, disabled, granted), { blocked: false, adminGranted: true });
  assert.deepEqual(modelAccess(other, disabled, granted), { blocked: true, adminGranted: false });
  assert.deepEqual(modelAccess(open, disabled, granted), { blocked: false, adminGranted: false });
  // Without a grant, a disabled model stays off; nothing is disabled, nothing to grant.
  assert.deepEqual(modelAccess(premium, disabled, null), { blocked: true, adminGranted: false });
  assert.deepEqual(modelAccess(premium, null, granted), { blocked: false, adminGranted: false });
});

test('admin grants are validated, stored per account, audited, and revocable', async () => {
  ctx = createTestRuntime();
  const admin = await createTestUser(ctx.db, { username: 'grant_admin' });
  const member = await createTestUser(ctx.db, { username: 'grant_member' });
  const other = await createTestUser(ctx.db, { username: 'grant_other' });
  const { getGrantedModelIds } = require('../../../server/services/ai/model_grants');
  const { getUserModelGrants, setUserModelGrants } = require('../../../server/services/admin/model_grants');
  const catalogIds = ['anthropic::claude-opus', 'openai::gpt-big'];
  const options = { actorUserId: admin.userId, catalogIds };

  assert.throws(
    () => setUserModelGrants(member.userId, ['anthropic::claude-opus', 'made::up'], options),
    (error) => error.status === 400 && /made::up/.test(error.message),
  );
  assert.throws(() => setUserModelGrants(member.userId, 'openai::gpt-big', options), (error) => error.status === 400);
  assert.throws(() => setUserModelGrants(99999, [], options), (error) => error.status === 404);

  setUserModelGrants(member.userId, ['anthropic::claude-opus', 'anthropic::claude-opus'], options);
  assert.deepEqual(getGrantedModelIds(member.userId), ['anthropic::claude-opus']);
  assert.deepEqual(getUserModelGrants(member.userId).modelIds, ['anthropic::claude-opus']);
  assert.deepEqual(getGrantedModelIds(other.userId), []);

  setUserModelGrants(member.userId, ['openai::gpt-big'], options);
  const events = ctx.db.prepare(
    "SELECT actor_user_id, subject_user_id, detail_json FROM access_audit_log WHERE action = 'account.models_changed' ORDER BY id",
  ).all();
  assert.equal(events.length, 2);
  assert.equal(events[1].actor_user_id, admin.userId);
  assert.equal(events[1].subject_user_id, member.userId);
  assert.deepEqual(JSON.parse(events[1].detail_json), {
    granted: ['openai::gpt-big'],
    revoked: ['anthropic::claude-opus'],
  });

  // Saving the same list again changes nothing and logs nothing.
  setUserModelGrants(member.userId, ['openai::gpt-big'], options);
  assert.equal(ctx.db.prepare("SELECT COUNT(*) AS n FROM access_audit_log WHERE action = 'account.models_changed'").get().n, 2);

  setUserModelGrants(member.userId, null, options);
  assert.deepEqual(getGrantedModelIds(member.userId), []);
  assert.equal(ctx.db.prepare('SELECT allowed_models FROM users WHERE id = ?').get(member.userId).allowed_models, null);
});
