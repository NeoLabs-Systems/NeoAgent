'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const { test } = require('node:test');

const {
  MAC_QEMU_HYPERVISOR_ENTITLEMENTS,
  ensureMacQemuHypervisorSignature,
  hasMacHypervisorEntitlement,
} = require('../../../lib/qemu_mac_sign');

test('the QEMU entitlement plist requests the macOS hypervisor', () => {
  assert.match(MAC_QEMU_HYPERVISOR_ENTITLEMENTS, /com\.apple\.security\.hypervisor/);
  assert.match(MAC_QEMU_HYPERVISOR_ENTITLEMENTS, /<true\/>/);
});

test('hypervisor entitlement checks are macOS-only', () => {
  assert.equal(hasMacHypervisorEntitlement(''), false);
  if (process.platform !== 'darwin') {
    assert.equal(hasMacHypervisorEntitlement('/usr/bin/qemu-system-x86_64'), false);
    assert.equal(ensureMacQemuHypervisorSignature('/usr/bin/qemu-system-x86_64'), false);
    return;
  }
  const brew = '/opt/homebrew/bin/qemu-system-aarch64';
  if (fs.existsSync(brew)) assert.equal(hasMacHypervisorEntitlement(brew), true);
  assert.equal(hasMacHypervisorEntitlement('/tmp/definitely-not-qemu'), false);
});
