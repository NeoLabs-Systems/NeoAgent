'use strict';

// Asking a signed-in account for its password or a 2FA code again is
// throttled per account, whatever address the tries come from; sign-in is
// counted apart and stays open.

const assert = require('node:assert/strict');
const { after, before, describe, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../helpers/db');
const { createTestApp, loginAs } = require('../helpers/app');
const { agent } = require('../helpers/supertest');

describe('password and code confirmations', () => {
  let ctx;
  let app;

  before(() => {
    ctx = createTestRuntime();
    app = createTestApp().app;
  });

  after(() => teardownTestRuntime(ctx));

  test('are throttled per account, whatever the address', async () => {
    const user = await createTestUser(ctx.db, { username: 'confirm_user' });
    const sessions = [agent(app), agent(app)];
    for (const session of sessions) await loginAs(session, user);
    const change = (index, currentPassword) => sessions[index % 2].put('/api/account/password')
      .set('X-Forwarded-For', `203.0.113.${index + 1}`)
      .send({ currentPassword, newPassword: 'Another-Long-Passphrase-91' });

    for (let i = 0; i < 5; i += 1) {
      const wrong = await change(i, `wrong-${i}`).expect(401);
      assert.match(wrong.body.error, /Current password is incorrect/);
    }
    // From the 5th failure on the next try waits, even with the right password.
    const locked = await change(5, user.password).expect(429);
    assert.equal(locked.body.code, 'LOGIN_LOCKED');
    assert.ok(locked.body.retryAfter >= 1);
    assert.equal(locked.headers['retry-after'], String(locked.body.retryAfter));

    // Counted apart from sign-in: the owner can still sign in.
    await loginAs(agent(app), user);
    // Once the wait is over a right password goes through and clears the count.
    ctx.db.prepare('UPDATE login_failures SET failed_at_ms = failed_at_ms - 60000 WHERE account_key = ?')
      .run(`confirm:user:${user.userId}`);
    await sessions[0].post('/api/account/2fa/setup').send({ currentPassword: user.password }).expect(200);
    const left = ctx.db.prepare('SELECT COUNT(*) AS count FROM login_failures WHERE account_key = ? AND kind = ?')
      .get(`confirm:user:${user.userId}`, 'password').count;
    assert.equal(left, 0);
  });

  test('wrong 2FA codes count toward the same limit', async () => {
    const user = await createTestUser(ctx.db, { username: 'confirm_code_user' });
    const session = agent(app);
    await loginAs(session, user);
    // 2FA is off here, so any code passes the code check; turning it on
    // through the service gives a real one to get wrong.
    const twoFactor = require('../../server/services/account/two_factor');
    const { generateSync } = require('otplib');
    const setup = await twoFactor.beginSetup(user.userId, user.password);
    await twoFactor.enable(user.userId, generateSync({ secret: setup.manualKey, strategy: 'totp', digits: 6, period: 30 }));

    // Nine wrong codes two minutes ago: a wrong code now is the tenth, which
    // locks. (Checking a code against the recovery codes takes seconds, so
    // sending them all would only wait out the short delays in between.)
    const insert = ctx.db.prepare('INSERT INTO login_failures (account_key, kind, failed_at_ms) VALUES (?, ?, ?)');
    for (let i = 0; i < 9; i += 1) insert.run(`confirm:user:${user.userId}`, 'second_factor', Date.now() - 120000 + i);
    await session.post('/api/account/2fa/recovery-codes')
      .set('X-Forwarded-For', '198.51.100.1')
      .send({ currentPassword: user.password, code: '000000' })
      .expect(401);
    const locked = await session.post('/api/account/2fa/recovery-codes')
      .set('X-Forwarded-For', '198.51.100.2')
      .send({ currentPassword: user.password, code: '000000' })
      .expect(429);
    assert.equal(locked.body.code, 'LOGIN_LOCKED');
    assert.match(locked.body.error, /wrong passwords or codes/);
  });
});
