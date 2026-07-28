'use strict';

const assert = require('node:assert/strict');
const { after, before, describe, test } = require('node:test');
const express = require('express');
const { generateSync } = require('otplib');

const {
  createTestRuntime,
  createTestUser,
  teardownTestRuntime,
} = require('../helpers/db');
const { agent, request } = require('../helpers/supertest');
const { createMemorySessionMiddleware } = require('../helpers/app');

describe('admin 2fa policy', () => {
  let ctx;
  let app;

  before(() => {
    ctx = createTestRuntime();
    process.env.ADMIN_USERNAME = 'admin';
    process.env.ADMIN_PASSWORD = 'Password123!';

    const { validateOrigin } = require('../../server/config/origins');
    const { applyHttpMiddleware } = require('../../server/http/middleware');
    const { registerApiRoutes } = require('../../server/http/routes');
    const { registerErrorHandler } = require('../../server/http/errors');
    const adminRouter = require('../../server/routes/admin');

    app = express();
    app.locals.httpRuntimeConfig = {
      secureCookies: false,
      trustProxy: true,
      publicUrl: null,
    };
    applyHttpMiddleware(app, {
      secureCookies: false,
      trustProxy: true,
      sessionMiddleware: createMemorySessionMiddleware(),
      validateOrigin,
    });
    registerApiRoutes(app);
    app.use('/admin', adminRouter);
    registerErrorHandler(app);
  });

  after(() => {
    teardownTestRuntime(ctx);
  });

  test('admin login requires 2FA setup when admin 2FA is not configured', async () => {
    const res = await request(app)
      .post('/admin/api/login')
      .send({
        username: 'admin',
        password: 'Password123!',
      })
      .expect(200);

    assert.equal(res.body.requiresTwoFactorSetup, true);
    assert.ok(res.body.setup?.manualKey);
    assert.ok(res.body.setup?.qrDataUrl);
  });

  test('user and admin authentication remain independent in the shared browser session', async () => {
    const user = await createTestUser(ctx.db, { username: 'admin_session_user' });
    const replacementUser = await createTestUser(ctx.db, {
      username: 'admin_session_replacement',
    });
    const client = agent(app);

    await client
      .post('/api/auth/login')
      .send({ username: user.username, password: user.password })
      .expect(200);

    const adminLogin = await client
      .post('/admin/api/login')
      .send({ username: 'admin', password: 'Password123!' })
      .expect(200);
    const manualKey = adminLogin.body.setup?.manualKey;
    assert.ok(manualKey);

    await client
      .post('/admin/api/login/2fa/setup/enable')
      .send({
        code: generateSync({
          strategy: 'totp',
          secret: manualKey,
          digits: 6,
          period: 30,
        }),
      })
      .expect(200);

    await client.get('/api/auth/me').expect(200);
    await client.get('/admin/api/settings').expect(200);

    await client
      .post('/api/auth/login')
      .send({
        username: replacementUser.username,
        password: replacementUser.password,
      })
      .expect(200);
    const currentUser = await client.get('/api/auth/me').expect(200);
    assert.equal(currentUser.body.user.username, replacementUser.username);
    await client.get('/admin/api/settings').expect(200);

    await client.post('/admin/api/logout').expect(200);
    await client.get('/api/auth/me').expect(200);
    await client.get('/admin/api/settings').expect(401);

    await client
      .post('/admin/api/login')
      .send({ username: 'admin', password: 'Password123!' })
      .expect(200);
    await client
      .post('/admin/api/2fa/verify')
      .send({
        code: generateSync({
          strategy: 'totp',
          secret: manualKey,
          digits: 6,
          period: 30,
        }),
      })
      .expect(200);
    await client.post('/api/auth/logout').expect(200);
    await client.get('/api/auth/me').expect(401);
    await client.get('/admin/api/settings').expect(200);
  });
});
