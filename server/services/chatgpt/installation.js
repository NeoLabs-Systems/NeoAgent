'use strict';

const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const { DATA_DIR, ensurePrivateFile } = require('../../../runtime/paths');

// One NeoAgent install is one ChatGPT app registration: a stable host id
// sent on every authorization, plus the client id OpenAI issues the first
// time anyone on this install signs in. Every account here reuses both.
const INSTALLATION_FILE = path.join(DATA_DIR, 'chatgpt-host.json');

function readFile() {
  try {
    const parsed = JSON.parse(fs.readFileSync(INSTALLATION_FILE, 'utf8'));
    return parsed && typeof parsed === 'object' ? parsed : {};
  } catch {
    return {};
  }
}

function writeFile(value) {
  fs.mkdirSync(path.dirname(INSTALLATION_FILE), { recursive: true });
  fs.writeFileSync(INSTALLATION_FILE, `${JSON.stringify(value, null, 2)}\n`, { mode: 0o600 });
  ensurePrivateFile(INSTALLATION_FILE);
}

function getInstallation() {
  const current = readFile();
  if (typeof current.hostId === 'string' && current.hostId.startsWith('urn:uuid:')) {
    return {
      hostId: current.hostId,
      clientId: typeof current.clientId === 'string' ? current.clientId : '',
    };
  }
  const installation = { hostId: `urn:uuid:${crypto.randomUUID()}`, clientId: '' };
  writeFile(installation);
  return installation;
}

function saveClientId(clientId) {
  const installation = getInstallation();
  if (installation.clientId === clientId) return;
  writeFile({ ...installation, clientId });
}

module.exports = {
  getInstallation,
  saveClientId,
};
