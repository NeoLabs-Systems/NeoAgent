'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { buildWorkerEnv } = require('../../../server/services/cli/shell_worker_pool');

test('buildWorkerEnv keeps shell-safe variables and strips server secrets', () => {
  const workerEnv = buildWorkerEnv({
    HOME: '/Users/neo',
    PATH: '/usr/bin:/bin',
    SHELL: '/bin/zsh',
    TMPDIR: '/tmp/neo',
    TERM: 'xterm-256color',
    LANG: 'en_US.UTF-8',
    USER: 'neo',
    SESSION_SECRET: 'top-secret',
    OPENAI_API_KEY: 'sk-secret',
    ADMIN_PASSWORD: 'super-secret',
    NODE_ENV: 'production',
  });

  assert.equal(workerEnv.HOME, '/Users/neo');
  assert.equal(workerEnv.PATH, '/usr/bin:/bin');
  assert.equal(workerEnv.SHELL, '/bin/zsh');
  assert.equal(workerEnv.TERM, 'xterm-256color');
  assert.equal(workerEnv.SESSION_SECRET, undefined);
  assert.equal(workerEnv.OPENAI_API_KEY, undefined);
  assert.equal(workerEnv.ADMIN_PASSWORD, undefined);
  assert.equal(workerEnv.NODE_ENV, undefined);
});

test('buildWorkerEnv allows explicit extra pass-through variables only', () => {
  const workerEnv = buildWorkerEnv(
    {
      HOME: '/Users/neo',
      PATH: '/usr/bin:/bin',
      SAFE_CUSTOM_VAR: 'keep-me',
      SECRET_CUSTOM_VAR: 'drop-me',
    },
    ['SAFE_CUSTOM_VAR'],
  );

  assert.equal(workerEnv.SAFE_CUSTOM_VAR, 'keep-me');
  assert.equal(workerEnv.SECRET_CUSTOM_VAR, undefined);
});
