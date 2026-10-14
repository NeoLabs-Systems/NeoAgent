'use strict';

const assert = require('node:assert/strict');
const EventEmitter = require('node:events');
const path = require('node:path');
const { after, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

const ctx = createTestRuntime();
after(() => teardownTestRuntime(ctx));

test('WhatsApp connect ignores a client authDir and uses the account directory', async () => {
  const user = await createTestUser(ctx.db, { username: 'wa_authdir' });
  const { MessagingManager } = require('../../../server/services/messaging/manager');
  const { AGENT_DATA_DIR } = require('../../../runtime/paths');
  const manager = new MessagingManager({ to() { return { emit() {} }; } });
  let seen = null;
  manager.platformTypes = {
    ...manager.platformTypes,
    whatsapp: class extends EventEmitter {
      constructor(config) {
        super();
        seen = config.authDir;
      }
      async connect() {}
      async disconnect() {}
      getStatus() { return 'connecting'; }
    },
  };

  await manager.connectPlatform(user.userId, 'whatsapp', { authDir: '/tmp/not-this-account' });
  const agentId = manager._agentId(user.userId);
  const expected = path.join(
    AGENT_DATA_DIR,
    'messaging-auth',
    String(user.userId),
    String(agentId),
    'whatsapp',
  );
  assert.equal(seen, expected);
  manager.isShuttingDown = true;
});
