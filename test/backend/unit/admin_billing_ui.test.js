'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { test } = require('node:test');

const billingScriptPath = path.join(__dirname, '../../../server/admin/billing.js');

test('admin billing script checks billing setup before billing data routes', () => {
  const source = fs.readFileSync(billingScriptPath, 'utf8');
  const loadBillingStart = source.indexOf('async function loadBilling()');
  const plansFetch = source.indexOf("fetch('/admin/api/billing/plans')");
  const enabledCheck = source.indexOf('if (!(await refreshBillingNav()))');

  assert.notEqual(loadBillingStart, -1);
  assert.notEqual(plansFetch, -1);
  assert.ok(enabledCheck > loadBillingStart);
  assert.ok(enabledCheck < plansFetch);
});

test('admin billing startup does not probe disabled billing plan routes', () => {
  const source = fs.readFileSync(billingScriptPath, 'utf8');
  const loadBillingStart = source.indexOf('async function loadBilling()');
  const beforeLoadBilling = source.slice(0, loadBillingStart);

  assert.doesNotMatch(beforeLoadBilling, /\/admin\/api\/billing\/plans/);
  assert.match(beforeLoadBilling, /\/admin\/api\/config\/billing-setup/);
});
