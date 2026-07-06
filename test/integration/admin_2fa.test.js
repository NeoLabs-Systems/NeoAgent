'use strict';

const assert = require('node:assert/strict');
const { after, before, describe, test } = require('node:test');
const express = require('express');

const { createTestRuntime, teardownTestRuntime } = require('../helpers/db');
const { request } = require('../helpers/supertest');
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
});
