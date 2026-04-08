import { createBrowserProtocol } from './protocol.mjs';

const STORAGE_KEYS = ['serverUrl', 'token', 'pairingId', 'pairingSecret', 'approvalUrl', 'status'];
const protocol = createBrowserProtocol(chrome);
let socket = null;
let reconnectTimer = null;

function getStorage(keys = STORAGE_KEYS) {
  return chrome.storage.local.get(keys);
}

function setStorage(values) {
  return chrome.storage.local.set(values);
}

function removeStorage(keys) {
  return chrome.storage.local.remove(keys);
}

function normalizeServerUrl(value) {
  return String(value || '').trim().replace(/\/+$/, '');
}

function websocketUrl(serverUrl, token) {
  const url = new URL('/api/browser-extension/ws', serverUrl);
  url.protocol = url.protocol === 'https:' ? 'wss:' : 'ws:';
  url.searchParams.set('token', token);
  return url.toString();
}

function compareVersions(a, b) {
  const left = String(a || '0').split('.').map((part) => Number(part) || 0);
  const right = String(b || '0').split('.').map((part) => Number(part) || 0);
  const length = Math.max(left.length, right.length);
  for (let i = 0; i < length; i += 1) {
    const delta = (left[i] || 0) - (right[i] || 0);
    if (delta !== 0) return delta;
  }
  return 0;
}

async function updateStatus(status) {
  await setStorage({ status });
  chrome.runtime.sendMessage({ type: 'status', status }).catch(() => {});
}

async function connect() {
  const { serverUrl, token } = await getStorage(['serverUrl', 'token']);
  if (!serverUrl || !token) {
    await updateStatus('not_paired');
    return { connected: false };
  }
  if (socket && socket.readyState === WebSocket.OPEN) {
    return { connected: true };
  }
  if (socket) {
    try { socket.close(); } catch {}
  }

  socket = new WebSocket(websocketUrl(serverUrl, token));
  await updateStatus('connecting');

  socket.addEventListener('open', () => {
    updateStatus('connected');
  });
  socket.addEventListener('close', () => {
    updateStatus('disconnected');
    clearTimeout(reconnectTimer);
    reconnectTimer = setTimeout(() => connect().catch(() => {}), 5000);
  });
  socket.addEventListener('error', () => {
    updateStatus('disconnected');
  });
  socket.addEventListener('message', (event) => {
    handleSocketMessage(event.data).catch((error) => {
      console.error('NeoAgent command handling failed', error);
    });
  });

  return { connected: false };
}

async function handleSocketMessage(raw) {
  let message;
  try {
    message = JSON.parse(raw);
  } catch {
    return;
  }
  if (!message || message.type !== 'command' || !message.id) {
    return;
  }
  try {
    const result = await protocol.run(message.command, message.payload || {});
    socket?.send(JSON.stringify({ type: 'result', id: message.id, ok: true, result }));
  } catch (error) {
    socket?.send(JSON.stringify({
      type: 'result',
      id: message.id,
      ok: false,
      error: error?.message || String(error),
    }));
  }
}

async function startPairing(serverUrl) {
  const normalized = normalizeServerUrl(serverUrl);
  if (!normalized) throw new Error('NeoAgent server URL required.');
  const response = await fetch(`${normalized}/api/browser-extension/pairing/request`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ extensionName: 'NeoAgent Browser' }),
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(payload.error || `Pairing failed: ${response.status}`);
  await setStorage({
    serverUrl: normalized,
    pairingId: payload.pairingId,
    pairingSecret: payload.pairingSecret,
    approvalUrl: payload.approvalUrl,
    status: 'approval_pending',
  });
  await chrome.tabs.create({ url: payload.approvalUrl, active: true });
  return payload;
}

async function claimPairing() {
  const { serverUrl, pairingId, pairingSecret } = await getStorage(['serverUrl', 'pairingId', 'pairingSecret']);
  if (!serverUrl || !pairingId || !pairingSecret) {
    throw new Error('No pending pairing request.');
  }
  const response = await fetch(`${serverUrl}/api/browser-extension/pairing/${encodeURIComponent(pairingId)}/claim`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ pairingSecret, extensionName: 'NeoAgent Browser' }),
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(payload.error || `Claim failed: ${response.status}`);
  await setStorage({
    token: payload.token,
    tokenId: payload.tokenId,
    status: 'paired',
  });
  await removeStorage(['pairingId', 'pairingSecret', 'approvalUrl']);
  await connect();
  return payload;
}

async function disconnect() {
  clearTimeout(reconnectTimer);
  reconnectTimer = null;
  if (socket) {
    try { socket.close(); } catch {}
  }
  socket = null;
  await removeStorage(['token', 'tokenId', 'pairingId', 'pairingSecret', 'approvalUrl']);
  await updateStatus('not_paired');
}

async function checkForUpdates() {
  const { serverUrl } = await getStorage(['serverUrl']);
  if (!serverUrl) throw new Error('NeoAgent server URL required.');
  const response = await fetch(`${serverUrl}/api/browser-extension/latest`);
  const latest = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(latest.error || `Update check failed: ${response.status}`);
  const currentVersion = chrome.runtime.getManifest().version;
  return {
    currentVersion,
    latestVersion: latest.version || currentVersion,
    downloadUrl: latest.downloadUrl || `${serverUrl}/api/browser-extension/download`,
    updateAvailable: compareVersions(latest.version, currentVersion) > 0,
  };
}

async function openDownload() {
  const { serverUrl } = await getStorage(['serverUrl']);
  if (!serverUrl) throw new Error('NeoAgent server URL required.');
  await chrome.tabs.create({ url: `${serverUrl}/api/browser-extension/download`, active: true });
  return { success: true };
}

chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  const run = async () => {
    switch (message?.type) {
      case 'startPairing':
        return startPairing(message.serverUrl);
      case 'claimPairing':
        return claimPairing();
      case 'connect':
        return connect();
      case 'disconnect':
        return disconnect();
      case 'checkForUpdates':
        return checkForUpdates();
      case 'openDownload':
        return openDownload();
      case 'getState':
        return getStorage([...STORAGE_KEYS, 'tokenId']);
      default:
        return { error: 'unknown message' };
    }
  };
  run()
    .then((result) => sendResponse({ ok: true, result }))
    .catch((error) => sendResponse({ ok: false, error: error.message || String(error) }));
  return true;
});

connect().catch(() => {});
