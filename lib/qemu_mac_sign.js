'use strict';

const crypto = require('crypto');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

const MAC_QEMU_HYPERVISOR_ENTITLEMENTS = `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.hypervisor</key>
  <true/>
</dict>
</plist>
`;

function codesign(args) {
  const result = spawnSync('codesign', args, {
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
    windowsHide: true,
  });
  if (result.error || result.status !== 0) {
    throw new Error(String(result.stderr || result.stdout || result.error?.message || 'codesign failed').trim());
  }
  return `${result.stdout || ''}${result.stderr || ''}`;
}

function hasMacHypervisorEntitlement(binary) {
  if (process.platform !== 'darwin' || !binary) return false;
  const result = spawnSync('codesign', ['--display', '--entitlements', '-', binary], {
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
    windowsHide: true,
  });
  const output = `${result.stdout || ''}${result.stderr || ''}`;
  return output.includes('com.apple.security.hypervisor');
}

function signMacQemuBinary(binary, { hypervisor = false } = {}) {
  if (process.platform !== 'darwin') return;
  if (!hypervisor) {
    codesign(['--force', '--sign', '-', binary]);
    return;
  }
  const entitlements = path.join(
    os.tmpdir(),
    `neoagent-qemu-${process.pid}-${crypto.randomBytes(6).toString('hex')}.entitlements`,
  );
  fs.writeFileSync(entitlements, MAC_QEMU_HYPERVISOR_ENTITLEMENTS);
  try {
    codesign(['--force', '--sign', '-', '--entitlements', entitlements, binary]);
  } finally {
    fs.rmSync(entitlements, { force: true });
  }
}

function ensureMacQemuHypervisorSignature(binary) {
  if (process.platform !== 'darwin' || !binary) return false;
  if (hasMacHypervisorEntitlement(binary)) return false;
  try {
    signMacQemuBinary(binary, { hypervisor: true });
  } catch {
    return false;
  }
  return hasMacHypervisorEntitlement(binary);
}

module.exports = {
  MAC_QEMU_HYPERVISOR_ENTITLEMENTS,
  ensureMacQemuHypervisorSignature,
  hasMacHypervisorEntitlement,
  signMacQemuBinary,
};
