'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  createTestRuntime,
  createTestUser,
  teardownTestRuntime,
} = require('../../helpers/db');

test('uncategorized external tools require approval by default', async (t) => {
  const ctx = createTestRuntime();
  t.after(() => teardownTestRuntime(ctx));

  const { ToolPolicyService } = require('../../../server/services/security/tool_policy_service');
  const { getCategoryForTool } = require('../../../server/services/security/tool_categories');
  const user = await createTestUser(ctx.db);
  const service = new ToolPolicyService();

  assert.equal(getCategoryForTool('notion_create_page', {}), 'external');
  assert.equal(service.getPolicy(user.userId, 'notion_create_page', {}), 'require_approval');

  const policies = service.getPolicies(user.userId);
  assert.equal(policies.external, 'require_approval');
});

test('known built-in read-only tools remain allowed without being misclassified as external', async (t) => {
  const ctx = createTestRuntime();
  t.after(() => teardownTestRuntime(ctx));

  const { ToolPolicyService } = require('../../../server/services/security/tool_policy_service');
  const { getCategoryForTool } = require('../../../server/services/security/tool_categories');
  const user = await createTestUser(ctx.db);
  const service = new ToolPolicyService();

  assert.equal(getCategoryForTool('http_request', { method: 'GET' }), null);
  assert.equal(service.getPolicy(user.userId, 'http_request', { method: 'GET' }), 'allow');

  assert.equal(getCategoryForTool('http_request', { method: 'POST' }), 'network_write');
  assert.equal(service.getPolicy(user.userId, 'http_request', { method: 'POST' }), 'require_approval');
});

test('credential use is approval-gated while protected submit and cancel remain available', async (t) => {
  const ctx = createTestRuntime();
  t.after(() => teardownTestRuntime(ctx));

  const { ToolPolicyService } = require('../../../server/services/security/tool_policy_service');
  const { getCategoryForTool } = require('../../../server/services/security/tool_categories');
  const user = await createTestUser(ctx.db);
  const service = new ToolPolicyService();

  assert.equal(getCategoryForTool('credential_fill_browser', {}), 'credential_use');
  assert.equal(getCategoryForTool('credential_http_request', {}), 'credential_use');
  assert.equal(service.getPolicy(user.userId, 'credential_fill_browser', {}), 'require_approval');
  assert.equal(getCategoryForTool('credential_submit_browser', {}), null);
  assert.equal(getCategoryForTool('credential_cancel_browser', {}), null);
});
