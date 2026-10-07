'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { clientRunOptions } = require('../../../server/utils/client_run_options');
const { jsonForInlineScript } = require('../../../server/utils/security');

test('client run options keep the chat fields and drop server-only ones', () => {
  assert.deepEqual(clientRunOptions({
    agentId: 'main',
    conversationId: 'conv-1',
    mediaAttachments: [{ type: 'image', path: '/etc/passwd' }],
    parentTrust: { taintSources: [] },
    bypassUserRateLimits: true,
    workspaceRoot: '/tmp',
    triggerSource: 'voice_live',
    audience: 'owner',
  }), {
    agentId: 'main',
    conversationId: 'conv-1',
  });
  assert.deepEqual(clientRunOptions(null), {});
  assert.deepEqual(clientRunOptions(['agentId']), {});
});

test('inline script JSON cannot close the script element', () => {
  const encoded = jsonForInlineScript({ error: '</script><script>alert(1)</script>' });
  assert.equal(encoded.includes('</'), false);
  assert.match(encoded, /\\u003c/);
  assert.equal(JSON.parse(encoded).error, '</script><script>alert(1)</script>');
});
