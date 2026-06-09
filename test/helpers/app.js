'use strict';

const express = require('express');
const session = require('express-session');

const { createFakeAppLocals } = require('./fakes');

function createMemorySessionMiddleware() {
  return session({
    secret: process.env.SESSION_SECRET || 'test-secret-32-chars-long-for-suite',
    name: 'neoagent.sid',
    resave: false,
    saveUninitialized: false,
    proxy: true,
    cookie: {
      maxAge: 7 * 24 * 60 * 60 * 1000,
      httpOnly: true,
      sameSite: 'lax',
      secure: false,
    },
  });
}

function createTestApp(options = {}) {
  const { validateOrigin } = require('../../server/config/origins');
  const { applyHttpMiddleware } = require('../../server/http/middleware');
  const { registerApiRoutes } = require('../../server/http/routes');
  const { registerErrorHandler } = require('../../server/http/errors');
  const { MemoryManager } = require('../../server/services/memory/manager');

  const app = express();
  app.disable('x-powered-by');
  app.locals.httpRuntimeConfig = {
    secureCookies: false,
    trustProxy: true,
    publicUrl: null,
  };
  Object.assign(app.locals, createFakeAppLocals(), options.locals || {});
  if (!app.locals.memoryManager) {
    app.locals.memoryManager = new MemoryManager();
  }
  const sessionMiddleware = options.sessionMiddleware || createMemorySessionMiddleware();
  applyHttpMiddleware(app, {
    secureCookies: false,
    trustProxy: true,
    sessionMiddleware,
    validateOrigin,
  });
  registerApiRoutes(app);
  registerErrorHandler(app);
  return { app, sessionMiddleware };
}

async function loginAs(requestAgent, user) {
  const res = await requestAgent
    .post('/api/auth/login')
    .send({ username: user.username, password: user.password });
  if (res.statusCode !== 200) {
    throw new Error(`Login failed for ${user.username}: ${res.statusCode} ${res.text}`);
  }
  return res;
}

module.exports = {
  createMemorySessionMiddleware,
  createTestApp,
  loginAs,
};
