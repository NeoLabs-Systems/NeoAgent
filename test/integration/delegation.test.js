'use strict';

const assert = require('node:assert/strict');
const { after, before, describe, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../helpers/db');
const { createTestApp, loginAs } = require('../helpers/app');
const { agent } = require('../helpers/supertest');

function permissionMap(entries) {
  return Object.fromEntries(entries.map((entry) => [entry.key, entry]));
}

describe('delegated permissions', () => {
  let ctx;
  let app;
  let admin;
  let owner;
  let lead;
  let member;
  let access;

  const clients = new Map();

  // One signed-in client per account: the login route is rate limited.
  async function signIn(user) {
    if (!clients.has(user.username)) {
      const client = agent(app);
      await loginAs(client, user);
      clients.set(user.username, client);
    }
    return clients.get(user.username);
  }

  async function invite(client, body) {
    const res = await client.post('/api/delegation/invites').send(body).expect(201);
    assert.match(res.body.link, /\/app\/\?invite=[A-Za-z0-9_-]+$/);
    return res.body.link;
  }

  before(async () => {
    ctx = createTestRuntime();
    app = createTestApp().app;
    // The first account on a fresh install becomes admin via the schema trigger.
    owner = await createTestUser(ctx.db, { username: 'owner' });
    lead = await createTestUser(ctx.db, { username: 'lead' });
    member = await createTestUser(ctx.db, { username: 'member' });
    access = {
      admin: require('../../server/services/access/admin'),
      delegations: require('../../server/services/access/delegations'),
      permissions: require('../../server/services/access/permissions'),
    };
    admin = await signIn(owner);
  });

  after(() => teardownTestRuntime(ctx));

  test('first account is admin, later accounts are not, and the flag is in the user payload', async () => {
    const ownerStatus = await admin.get('/api/auth/status').expect(200);
    assert.equal(ownerStatus.body.user.isAdmin, true);

    const leadClient = await signIn(lead);
    const leadStatus = await leadClient.get('/api/auth/status').expect(200);
    assert.equal(leadStatus.body.user.isAdmin, false);
    // Building a team needs no admin rights; only the server-wide audit does.
    await leadClient.get('/api/delegation/audit').expect(403);
  });

  test('invite links are hashed, scoped, single-use, and need a confirmation step', async () => {
    const link = await invite(admin, {
      label: 'Lead',
      permissions: ['shell', 'file_write'],
      expiresInHours: 24,
      maxUses: 1,
    });
    const token = new URL(link).searchParams.get('invite');
    const stored = ctx.db.prepare('SELECT token_hash FROM delegation_invites').all();
    assert.ok(stored.every((row) => row.token_hash !== token), 'raw token must never be stored');

    const leadClient = await signIn(lead);
    const preview = await leadClient.post('/api/delegation/invites/preview').send({ link }).expect(200);
    assert.equal(preview.body.issuer.username, 'owner');
    assert.deepEqual(preview.body.permissions, ['shell', 'file_write']);
    assert.equal(preview.body.singleUse, true);
    // Preview alone changes nothing.
    assert.equal((await leadClient.get('/api/delegation').expect(200)).body.managedBy, null);

    const redeemed = await leadClient.post('/api/delegation/invites/redeem').send({ link }).expect(200);
    assert.equal(redeemed.body.managedBy.manager.username, 'owner');
    const leadPerms = permissionMap(redeemed.body.permissions);
    assert.equal(leadPerms.shell.allowed, true);
    assert.equal(leadPerms.network_write.allowed, false);
    assert.equal(leadPerms.network_write.setBy.username, 'owner');

    const memberClient = await signIn(member);
    const reused = await memberClient.post('/api/delegation/invites/redeem').send({ link }).expect(410);
    assert.equal(reused.body.code, 'INVITE_USED');

    const managing = (await admin.get('/api/delegation').expect(200)).body.managing;
    assert.deepEqual(Object.keys(managing[0].user).sort(), ['displayName', 'id', 'username']);
  });

  test('invalid, revoked, and over-scoped links report distinct errors', async () => {
    const memberClient = await signIn(member);
    const invalid = await memberClient.post('/api/delegation/invites/preview')
      .send({ link: 'https://example.com/app/?invite=nope' })
      .expect(404);
    assert.equal(invalid.body.code, 'INVITE_INVALID');

    const link = await invite(admin, { permissions: ['shell'], expiresInHours: null, maxUses: null });
    const summary = (await admin.get('/api/delegation').expect(200)).body;
    const reusable = summary.invites.find((entry) => entry.maxUses === null && entry.status === 'active');
    await admin.delete(`/api/delegation/invites/${reusable.id}`).expect(200);
    const revoked = await memberClient.post('/api/delegation/invites/preview').send({ link }).expect(410);
    assert.equal(revoked.body.code, 'INVITE_REVOKED');

    const unknown = await admin.post('/api/delegation/invites')
      .send({ permissions: ['admin'], expiresInHours: null, maxUses: 1 })
      .expect(400);
    assert.equal(unknown.body.code, 'INVITE_SCOPE_UNKNOWN');
  });

  test('upstream managers override downstream grants along the chain (A > B > C)', async () => {
    // The lead is an ordinary account: managing a teammate needs no admin.
    const leadClient = await signIn(lead);

    const overScoped = await leadClient.post('/api/delegation/invites')
      .send({ permissions: ['shell', 'network_write'], expiresInHours: null, maxUses: 1 })
      .expect(403);
    assert.equal(overScoped.body.code, 'INVITE_SCOPE');

    const link = await invite(leadClient, {
      permissions: ['shell', 'file_write'],
      expiresInHours: null,
      maxUses: 1,
    });
    const memberClient = await signIn(member);
    const redeemed = await memberClient.post('/api/delegation/invites/redeem').send({ link }).expect(200);
    assert.deepEqual(
      redeemed.body.managedBy.chain.map((user) => user.username),
      ['lead', 'owner'],
    );
    let memberPerms = permissionMap(redeemed.body.permissions);
    assert.equal(memberPerms.shell.allowed, true);
    assert.equal(memberPerms.network_write.setBy.username, 'owner');

    // The lead can take away what it handed out...
    let leadView = await leadClient.put(`/api/delegation/managing/${member.userId}/permissions`)
      .send({ permission: 'file_write', allowed: false })
      .expect(200);
    let asManaged = permissionMap(leadView.body.managing[0].permissions);
    assert.equal(asManaged.file_write.allowed, false);
    assert.equal(asManaged.file_write.editable, true);
    assert.equal(asManaged.file_write.setBy.username, 'lead');
    assert.equal(asManaged.network_write.editable, false);

    // ...but when the owner takes shell away from the lead, it is gone for the
    // member too, labelled as the owner's decision, and the lead can't restore it.
    await admin.put(`/api/delegation/managing/${lead.userId}/permissions`)
      .send({ permission: 'shell', allowed: false })
      .expect(200);
    memberPerms = permissionMap((await memberClient.get('/api/delegation').expect(200)).body.permissions);
    assert.equal(memberPerms.shell.allowed, false);
    assert.equal(memberPerms.shell.setBy.username, 'owner');
    const escalation = await leadClient.put(`/api/delegation/managing/${member.userId}/permissions`)
      .send({ permission: 'shell', allowed: true })
      .expect(403);
    assert.equal(escalation.body.code, 'PERMISSION_NOT_HELD');
    leadView = await leadClient.get('/api/delegation').expect(200);
    asManaged = permissionMap(leadView.body.managing[0].permissions);
    assert.equal(asManaged.shell.editable, false);

    // Restoring it upstream brings back the lead's original grant downstream.
    await admin.put(`/api/delegation/managing/${lead.userId}/permissions`)
      .send({ permission: 'shell', allowed: true })
      .expect(200);
    assert.equal(access.permissions.isPermitted(member.userId, 'shell'), true);
  });

  test('a manager denial blocks the tool even when the account allows everything itself', async () => {
    const { globalHooks } = require('../../server/services/ai/hooks');
    const { registerToolSecurityHooks } = require('../../server/services/security/tool_security_hook');
    const permissive = {
      getSecurityMode: () => 'allow_all',
      getPolicy: () => 'allow',
    };
    registerToolSecurityHooks(permissive, { hasSessionGrant: () => true });
    try {
      const blocked = await globalHooks.run('before_tool_call', {
        toolName: 'execute_command',
        toolArgs: {},
        userId: member.userId,
        runId: 'run-test',
      });
      assert.equal(blocked.block, undefined, 'shell is currently allowed for the member');

      const edited = await globalHooks.run('before_tool_call', {
        toolName: 'write_file',
        toolArgs: {},
        userId: member.userId,
        runId: 'run-test',
      });
      assert.equal(edited.block, true);
      assert.equal(edited.blocked_by, 'delegation');

      // Every file-writing tool counts, not just write_file.
      const ranged = await globalHooks.run('before_tool_call', {
        toolName: 'replace_file_range',
        toolArgs: {},
        userId: member.userId,
        runId: 'run-test',
      });
      assert.equal(ranged.blocked_by, 'delegation');

      // A malformed method must not slip a POST past the network_write lock.
      const malformed = await globalHooks.run('before_tool_call', {
        toolName: 'http_request',
        toolArgs: { url: 'https://example.com', method: ['POST'] },
        userId: member.userId,
        runId: 'run-test',
      });
      assert.equal(malformed.block, true);
      assert.equal(malformed.blocked_by, 'delegation');
    } finally {
      for (const id of ['tool-delegation-check', 'tool-policy-check', 'tool-approval-gate']) {
        globalHooks.deregister('before_tool_call', id);
      }
    }
  });

  test('cycles and over-long chains are rejected', async () => {
    // owner manages lead; owner joining under lead would close a loop.
    const leadClient = await signIn(lead);
    const loopLink = await invite(leadClient, { permissions: ['shell'], expiresInHours: null, maxUses: 1 });
    const loop = await admin.post('/api/delegation/invites/redeem').send({ link: loopLink }).expect(409);
    assert.equal(loop.body.code, 'DELEGATION_CYCLE');

    const chain = [];
    for (let index = 0; index < access.permissions.MAX_CHAIN_DEPTH + 1; index += 1) {
      chain.push(await createTestUser(ctx.db, { username: `depth_${index}` }));
    }
    for (let index = 1; index < chain.length; index += 1) {
      const issuer = await signIn(chain[index - 1]);
      const link = await invite(issuer, { permissions: ['shell'], expiresInHours: null, maxUses: 1 });
      const joiner = await signIn(chain[index]);
      await joiner.post('/api/delegation/invites/redeem').send({ link }).expect(200);
    }
    const tooDeepIssuer = chain[chain.length - 1];
    const extra = await createTestUser(ctx.db, { username: 'depth_extra' });
    const issuer = await signIn(tooDeepIssuer);
    const link = await invite(issuer, { permissions: ['shell'], expiresInHours: null, maxUses: 1 });
    const joiner = await signIn(extra);
    const tooDeep = await joiner.post('/api/delegation/invites/redeem').send({ link }).expect(409);
    assert.equal(tooDeep.body.code, 'DELEGATION_TOO_DEEP');
  });

  test('deleting a manager hands its accounts upward; admin changes leave teams alone', async () => {
    const { eraseUserData } = require('../../server/services/account/erasure');
    const middle = await createTestUser(ctx.db, { username: 'middle' });
    const leaf = await createTestUser(ctx.db, { username: 'leaf' });

    const middleClient = await signIn(middle);
    await middleClient.post('/api/delegation/invites/redeem')
      .send({ link: await invite(admin, { permissions: ['shell'], expiresInHours: null, maxUses: 1 }) })
      .expect(200);
    const leafClient = await signIn(leaf);
    await leafClient.post('/api/delegation/invites/redeem')
      .send({ link: await invite(middleClient, { permissions: ['shell'], expiresInHours: null, maxUses: null }) })
      .expect(200);

    // Admin is about the server, not the team: granting and revoking it moves no one.
    access.admin.grantAdmin('middle', { source: 'test' });
    access.admin.revokeAdmin('middle', { source: 'test' });
    assert.equal(access.delegations.getDelegation(leaf.userId).manager_user_id, middle.userId);

    eraseUserData(middle.userId);
    assert.equal(access.delegations.getDelegation(leaf.userId).manager_user_id, owner.userId);
    const middleInvites = ctx.db.prepare(
      "SELECT COUNT(*) AS n FROM delegation_invites WHERE issuer_user_id = ? AND revoked_at IS NULL",
    ).get(middle.userId);
    assert.equal(middleInvites.n, 0, 'a deleted manager’s links stop working');

    const audit = (await admin.get('/api/delegation/audit').expect(200)).body.entries;
    const actions = new Set(audit.map((entry) => entry.action));
    for (const action of ['admin.grant', 'admin.revoke', 'invite.create', 'invite.revoke', 'delegation.create', 'delegation.reattach']) {
      assert.ok(actions.has(action), `audit log records ${action}`);
    }
  });

  test('a managed account can leave, and a manager can release', async () => {
    const leaf = await createTestUser(ctx.db, { username: 'leaver' });
    const leafClient = await signIn(leaf);
    await leafClient.post('/api/delegation/invites/redeem')
      .send({ link: await invite(admin, { permissions: [], expiresInHours: null, maxUses: 1 }) })
      .expect(200);
    assert.equal(access.permissions.isPermitted(leaf.userId, 'shell'), false);
    const left = await leafClient.post('/api/delegation/leave').expect(200);
    assert.equal(left.body.managedBy, null);
    assert.equal(access.permissions.isPermitted(leaf.userId, 'shell'), true);
    await leafClient.post('/api/delegation/leave').expect(404);

    await leafClient.post('/api/delegation/invites/redeem')
      .send({ link: await invite(admin, { permissions: [], expiresInHours: null, maxUses: 1 }) })
      .expect(200);
    await admin.delete(`/api/delegation/managing/${leaf.userId}`).expect(200);
    assert.equal(access.delegations.getDelegation(leaf.userId), null);
  });

  test('one account can hold only a bounded number of open links', async () => {
    const spammer = await createTestUser(ctx.db, { username: 'spammer' });
    const client = await signIn(spammer);
    for (let index = 0; index < 25; index += 1) {
      await invite(client, { permissions: [], expiresInHours: 1, maxUses: 1 });
    }
    const over = await client.post('/api/delegation/invites')
      .send({ permissions: [], expiresInHours: 1, maxUses: 1 })
      .expect(429);
    assert.equal(over.body.code, 'INVITE_LIMIT');
  });

  test('NEOAGENT_ADMIN_USERS reserves listed names and never undoes a CLI revoke', async () => {
    // A listed name without an account would turn whoever registers it into
    // an admin on the next start, so registration refuses it.
    process.env.NEOAGENT_ADMIN_USERS = 'reserved_admin';
    try {
      const res = await agent(app).post('/api/auth/register').send({
        username: 'reserved_admin',
        email: 'reserved@example.com',
        password: 'AutonomousPass1!',
      });
      assert.equal(res.status, 409);
    } finally {
      delete process.env.NEOAGENT_ADMIN_USERS;
    }

    access.admin.grantAdmin('leaver', { source: 'cli' });
    access.admin.revokeAdmin('leaver', { source: 'cli' });
    const result = access.admin.applyEnvAdminGrants({ NEOAGENT_ADMIN_USERS: 'leaver' });
    assert.deepEqual(result.revoked, ['leaver']);
    const leaverId = ctx.db.prepare('SELECT id FROM users WHERE username = ?').get('leaver').id;
    assert.equal(access.admin.isAdminUser(leaverId), false);
  });

  test('an admin cannot delete their own account', async () => {
    const res = await admin.post('/api/account/delete').send({ confirmUsername: 'owner' }).expect(403);
    assert.equal(res.body.code, 'ADMIN_SELF_DELETE');
  });
});
