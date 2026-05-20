import { createBrowserProtocol } from './protocol.mjs';
import { DEFAULT_SERVER_URL } from './config.mjs';

const STORAGE_KEYS = ['serverUrl', 'configuredServerUrl', 'token', 'pairingId', 'pairingSecret', 'approvalUrl', 'status'];
const protocol = createBrowserProtocol(chrome);
let socket = null;
let reconnectTimer = null;
let suppressSocketClose = false;
const DEFAULT_FETCH_TIMEOUT_MS = 10000;
const DEFAULT_WS_CONNECT_TIMEOUT_MS = 10000;
const EXTENSION_PROTOCOL_VERSION = 1;

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

function configuredServerUrl() {
  return normalizeServerUrl(DEFAULT_SERVER_URL);
}

async function resolveServerUrl(preferred) {
  const normalized = normalizeServerUrl(preferred);
  if (normalized) return normalized;
  const { serverUrl } = await getStorage(['serverUrl']);
  return normalizeServerUrl(serverUrl) || configuredServerUrl();
}

function websocketUrl(serverUrl, token) {
  const url = new URL('/api/browser-extension/ws', serverUrl);
  url.protocol = url.protocol === 'https:' ? 'wss:' : 'ws:';
  // Token in the URL is required for the HTTP upgrade handshake; the browser
  // WebSocket API does not support custom headers. Ensure the server's access
  // log scrubs query strings on this path to avoid persisting the token.
  url.searchParams.set('token', token);
  return url.toString();
}

async function fetchWithTimeout(url, options = {}, timeoutMs = DEFAULT_FETCH_TIMEOUT_MS) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(url, {
      ...options,
      signal: controller.signal,
    });
  } finally {
    clearTimeout(timer);
  }
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

function clearReconnectTimer() {
  clearTimeout(reconnectTimer);
  reconnectTimer = null;
}

async function handleSocketDisconnected(ws) {
  if (socket !== ws) {
    return;
  }
  socket = null;
  if (suppressSocketClose) {
    suppressSocketClose = false;
    return;
  }
  const { token } = await getStorage(['token']);
  if (!token) {
    await updateStatus('not_paired');
    return;
  }
  await updateStatus('disconnected');
  clearReconnectTimer();
  reconnectTimer = setTimeout(() => connect().catch(() => {}), 5000);
}

async function connect() {
  const { token } = await getStorage(['token']);
  const serverUrl = await resolveServerUrl();
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
  clearReconnectTimer();
  suppressSocketClose = false;

  const ws = new WebSocket(websocketUrl(serverUrl, token));
  socket = ws;
  await updateStatus('connecting');
  const connectTimeout = setTimeout(() => {
    if (socket === ws && ws.readyState !== WebSocket.OPEN) {
      try { ws.close(); } catch {}
    }
  }, DEFAULT_WS_CONNECT_TIMEOUT_MS);

  ws.addEventListener('open', () => {
    if (socket !== ws) return;
    clearTimeout(connectTimeout);
    updateStatus('connected');
  });
  ws.addEventListener('close', () => {
    clearTimeout(connectTimeout);
    handleSocketDisconnected(ws).catch((error) => {
      console.error('NeoAgent disconnect handling failed', error);
    });
  });
  ws.addEventListener('error', () => {
    clearTimeout(connectTimeout);
    handleSocketDisconnected(ws).catch((error) => {
      console.error('NeoAgent socket error handling failed', error);
    });
  });
  ws.addEventListener('message', (event) => {
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
  if (message.version != null && Number(message.version) !== EXTENSION_PROTOCOL_VERSION) {
    socket?.send(JSON.stringify({
      type: 'result',
      version: EXTENSION_PROTOCOL_VERSION,
      id: message.id,
      ok: false,
      error: `Unsupported protocol version: ${message.version}`,
    }));
    return;
  }
  try {
    const result = await protocol.run(message.command, message.payload || {});
    socket?.send(JSON.stringify({ type: 'result', version: EXTENSION_PROTOCOL_VERSION, id: message.id, ok: true, result }));
  } catch (error) {
    socket?.send(JSON.stringify({
      type: 'result',
      version: EXTENSION_PROTOCOL_VERSION,
      id: message.id,
      ok: false,
      error: error?.message || String(error),
    }));
  }
}

async function startPairing(serverUrl) {
  const normalized = await resolveServerUrl(serverUrl);
  if (!normalized) throw new Error('NeoAgent server URL required.');
  const response = await fetchWithTimeout(`${normalized}/api/browser-extension/pairing/request`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ extensionName: 'NeoAgent Browser' }),
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(payload.error || `Pairing failed: ${response.status}`);
  const approvalUrl = String(payload.approvalUrl || '');
  const approvalParsed = (() => { try { return new URL(approvalUrl); } catch { return null; } })();
  if (!approvalParsed || !['http:', 'https:'].includes(approvalParsed.protocol)) {
    throw new Error('Invalid approval URL returned by server.');
  }
  await setStorage({
    serverUrl: normalized,
    pairingId: payload.pairingId,
    pairingSecret: payload.pairingSecret,
    approvalUrl,
    status: 'approval_pending',
  });
  await chrome.tabs.create({ url: approvalUrl, active: true });
  return payload;
}

async function claimPairing() {
  const { serverUrl, pairingId, pairingSecret } = await getStorage(['serverUrl', 'pairingId', 'pairingSecret']);
  if (!serverUrl || !pairingId || !pairingSecret) {
    throw new Error('No pending pairing request.');
  }
  const response = await fetchWithTimeout(`${serverUrl}/api/browser-extension/pairing/${encodeURIComponent(pairingId)}/claim`, {
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
  clearReconnectTimer();
  suppressSocketClose = true;
  if (socket) {
    try { socket.close(); } catch {}
  }
  socket = null;
  await removeStorage(['token', 'tokenId', 'pairingId', 'pairingSecret', 'approvalUrl']);
  await updateStatus('not_paired');
}

async function checkForUpdates(preferredServerUrl) {
  const serverUrl = await resolveServerUrl(preferredServerUrl);
  if (!serverUrl) throw new Error('NeoAgent server URL required.');
  const response = await fetchWithTimeout(`${serverUrl}/api/browser-extension/latest`);
  const latest = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(latest.error || `Update check failed: ${response.status}`);
  const manifest = chrome.runtime.getManifest();
  const currentVersion = manifest.version;
  const currentVersionName = manifest.version_name || currentVersion;
  const latestVersion = latest.version || currentVersion;
  const latestVersionName = latest.versionName || latestVersion;
  return {
    currentVersion,
    currentVersionName,
    latestVersion,
    latestVersionName,
    downloadUrl: latest.downloadUrl || `${serverUrl}/api/browser-extension/download`,
    updateAvailable: compareVersions(latestVersion, currentVersion) > 0,
  };
}

async function openDownload(preferredServerUrl) {
  const serverUrl = await resolveServerUrl(preferredServerUrl);
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
        return checkForUpdates(message.serverUrl);
      case 'openDownload':
        return openDownload(message.serverUrl);
      case 'getState':
        return {
          ...(await getStorage([...STORAGE_KEYS, 'tokenId'])),
          configuredServerUrl: configuredServerUrl(),
        };
      default:
        return { error: 'unknown message' };
    }
  };
  run()
    .then((result) => sendResponse({ ok: true, result }))
    .catch((error) => sendResponse({ ok: false, error: error?.message || String(error) }));
  return true;
});

connect().catch(() => {});
