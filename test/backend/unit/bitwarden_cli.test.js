'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');

const {
  BitwardenCli,
  persistedSessionPath,
} = require('../../../server/services/credentials/bitwarden_cli');

test('Bitwarden master password and session remain process inputs and never appear in status', async (t) => {
  const calls = [];
  const dataDirectory = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-bitwarden-'));
  const cli = new BitwardenCli({
    cliScript: '/fake/bw.js',
    dataDirectory,
    async runner(command, args, options) {
      calls.push({ command, args, env: options.env });
      return 'opaque-session-key';
    },
  });
  t.after(async () => {
    await cli.shutdown();
    fs.rmSync(dataDirectory, { recursive: true, force: true });
  });

  const status = await cli.unlock(1, 'agent-1', 'master-password', 12);
  assert.equal(status.unlocked, true);
  assert.equal(status.idleTimeoutMinutes, 12);
  assert.equal(JSON.stringify(status).includes('master-password'), false);
  assert.equal(JSON.stringify(status).includes('opaque-session-key'), false);
  assert.equal(calls[0].args.includes('master-password'), false);
  assert.equal(calls[0].env.NEOAGENT_BITWARDEN_MASTER_PASSWORD, 'master-password');
  assert.equal(calls[0].env.SESSION_SECRET, undefined);
});

test('Bitwarden password login persists only an encrypted session and survives restart', async (t) => {
  const previousSecret = process.env.SESSION_SECRET;
  process.env.SESSION_SECRET = 'bitwarden-persistence-test-secret';
  const userId = `test-${process.pid}-${Date.now()}`;
  const agentId = 'persistent-agent';
  const dataDirectory = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-bitwarden-'));
  t.after(async () => {
    if (previousSecret === undefined) delete process.env.SESSION_SECRET;
    else process.env.SESSION_SECRET = previousSecret;
    fs.rmSync(dataDirectory, { recursive: true, force: true });
  });
  const calls = [];
  const cli = new BitwardenCli({
    cliScript: '/fake/bw.js',
    dataDirectory,
    async runner(command, args, options) {
      calls.push({ command, args, env: options.env });
      if (args.includes('status')) {
        return JSON.stringify({ status: 'unauthenticated', userEmail: null });
      }
      if (args.includes('login')) return 'persistent-session-key';
      return '';
    },
  });

  const connected = await cli.unlock(
    userId,
    agentId,
    'master-password',
    30,
    {
      config: {
        serverUrl: 'https://vault.bitwarden.com',
        email: 'person@example.test',
      },
      persistSession: true,
    },
  );
  assert.equal(connected.unlocked, true);
  assert.equal(connected.persistent, true);
  const persisted = fs.readFileSync(
    persistedSessionPath(userId, agentId, dataDirectory),
    'utf8',
  );
  assert.equal(persisted.includes('master-password'), false);
  assert.equal(persisted.includes('persistent-session-key'), false);
  assert.equal(calls.some((call) => call.args.includes('master-password')), false);
  assert.equal(
    calls.find((call) => call.args.includes('login'))
      .env.NEOAGENT_BITWARDEN_MASTER_PASSWORD,
    'master-password',
  );
  await cli.shutdown();

  const restarted = new BitwardenCli({
    cliScript: '/fake/bw.js',
    dataDirectory,
    async runner() {
      return '';
    },
  });
  assert.equal(restarted.getStatus(userId, agentId).unlocked, true);
  assert.equal(restarted.getStatus(userId, agentId).persistent, true);
  await restarted.lock(userId, agentId);
  assert.equal(
    fs.existsSync(persistedSessionPath(userId, agentId, dataDirectory)),
    false,
  );
  await restarted.shutdown();
});

test('existing Bitwarden API-key setups remain usable as a login fallback', async (t) => {
  const calls = [];
  const dataDirectory = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-bitwarden-'));
  const cli = new BitwardenCli({
    cliScript: '/fake/bw.js',
    dataDirectory,
    async runner(command, args, options) {
      calls.push({ command, args, env: options.env });
      if (args.includes('status')) {
        return JSON.stringify({ status: 'unauthenticated' });
      }
      if (args.includes('unlock')) return 'legacy-session-key';
      return '';
    },
  });
  t.after(async () => {
    await cli.shutdown();
    fs.rmSync(dataDirectory, { recursive: true, force: true });
  });

  const status = await cli.unlock(1, 'legacy-agent', 'master-password', 30, {
    config: {
      serverUrl: 'https://vault.bitwarden.com',
      email: 'person@example.test',
      clientId: 'legacy-client-id',
      clientSecret: 'legacy-client-secret',
    },
  });
  assert.equal(status.unlocked, true);
  const apiLogin = calls.find((call) => call.args.includes('--apikey'));
  assert.equal(apiLogin.env.BW_CLIENTID, 'legacy-client-id');
  assert.equal(apiLogin.env.BW_CLIENTSECRET, 'legacy-client-secret');
  assert.equal(apiLogin.args.includes('legacy-client-secret'), false);
  assert.equal(
    calls.find((call) => call.args.includes('unlock'))
      .env.NEOAGENT_BITWARDEN_MASTER_PASSWORD,
    'master-password',
  );
});
