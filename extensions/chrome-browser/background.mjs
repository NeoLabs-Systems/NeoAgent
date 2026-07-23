import {
  EXTENSION_PROTOCOL_VERSION,
  MESSAGE_TYPES,
  createBrowserProtocol,
} from './protocol.mjs';
import { DEFAULT_SERVER_URL } from './config.mjs';
import { fetchJsonWithTimeout } from './http.mjs';

const STORAGE_KEYS = ['serverUrl', 'configuredServerUrl', 'token', 'pairingId', 'pairingSecret', 'approvalUrl', 'status', 'extensionName'];
let socket = null;
let reconnectTimer = null;
let connectPromise = null;
let connectionEpoch = 0;
let reconnectAttempt = 0;
let statusUpdateQueue = Promise.resolve();
let commandQueue = Promise.resolve();
const activeCommandControllers = new Map();
const pendingUrlValidations = new Map();
const DEFAULT_WS_CONNECT_TIMEOUT_MS = 10000;
const DEFAULT_URL_VALIDATION_TIMEOUT_MS = 6500;
const MAX_PENDING_URL_VALIDATIONS = 256;
const RECONNECT_BASE_DELAY_MS = 1000;
const RECONNECT_MAX_DELAY_MS = 60 * 1000;
const KEEPALIVE_ALARM_NAME = 'neoagent-extension-keepalive';
const KEEPALIVE_ALARM_MINUTES = 1;
const protocol = createBrowserProtocol(chrome, {
  validateUrl: requestUrlValidation,
});

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
  const raw = String(value || '').trim();
  if (!raw) return '';
  let parsed;
  try {
    parsed = new URL(raw);
  } catch {
    throw new Error('NeoAgent server URL is invalid.');
  }
  if (!['http:', 'https:'].includes(parsed.protocol)) {
    throw new Error('NeoAgent server URL must use http or https.');
  }
  if (parsed.username || parsed.password) {
    throw new Error('NeoAgent server URL must not contain credentials.');
  }
  parsed.search = '';
  parsed.hash = '';
  parsed.pathname = parsed.pathname.replace(/\/+$/, '');
  return parsed.toString().replace(/\/+$/, '');
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
  const url = new URL('api/browser-extension/ws', `${serverUrl}/`);
  url.protocol = url.protocol === 'https:' ? 'wss:' : 'ws:';
  // Token in the URL is required for the HTTP upgrade handshake; the browser
  // WebSocket API does not support custom headers. Ensure the server's access
  // log scrubs query strings on this path to avoid persisting the token.
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

async function updateStatus(status, expectedEpoch = null) {
  const task = statusUpdateQueue.catch(() => {}).then(async () => {
    if (expectedEpoch != null && expectedEpoch !== connectionEpoch) return;
    await setStorage({ status });
    await Promise.resolve(chrome.runtime.sendMessage({ type: 'status', status })).catch(() => {});
  });
  statusUpdateQueue = task.catch(() => {});
  return task;
}

function clearReconnectTimer() {
  clearTimeout(reconnectTimer);
  reconnectTimer = null;
}

function scheduleReconnect() {
  clearReconnectTimer();
  const exponentialDelay = Math.min(
    RECONNECT_MAX_DELAY_MS,
    RECONNECT_BASE_DELAY_MS * (2 ** Math.min(reconnectAttempt, 6)),
  );
  reconnectAttempt += 1;
  const jitterMs = Math.floor(exponentialDelay * Math.random() * 0.25);
  reconnectTimer = setTimeout(() => connect().catch(() => {}), exponentialDelay + jitterMs);
}

function ensureKeepaliveAlarm() {
  chrome.alarms?.create?.(KEEPALIVE_ALARM_NAME, {
    periodInMinutes: KEEPALIVE_ALARM_MINUTES,
  });
}

function rejectPendingUrlValidations(error, expectedSocket = null) {
  for (const entry of Array.from(pendingUrlValidations.values())) {
    if (!expectedSocket || entry.socket === expectedSocket) entry.reject(error);
  }
}

function requestUrlValidation(url, options = {}) {
  const ws = socket;
  if (!ws || ws.readyState !== WebSocket.OPEN) {
    return Promise.reject(new Error('NeoAgent browser security validation is unavailable.'));
  }
  if (pendingUrlValidations.size >= MAX_PENDING_URL_VALIDATIONS) {
    return Promise.reject(new Error('Too many browser URL validations are pending.'));
  }

  const id = crypto.randomUUID();
  const signal = options.signal || null;
  return new Promise((resolve, reject) => {
    let settled = false;
    let timer = null;
    const cleanup = () => {
      clearTimeout(timer);
      signal?.removeEventListener('abort', onAbort);
      pendingUrlValidations.delete(id);
    };
    const finish = (callback, value) => {
      if (settled) return;
      settled = true;
      cleanup();
      callback(value);
    };
    const onAbort = () => finish(
      reject,
      signal.reason instanceof Error
        ? signal.reason
        : new Error('Browser URL validation was aborted.'),
    );
    const entry = {
      socket: ws,
      resolve: (allowed) => finish(resolve, allowed === true),
      reject: (error) => finish(reject, error),
    };
    timer = setTimeout(() => {
      entry.reject(new Error('Browser URL validation timed out.'));
    }, DEFAULT_URL_VALIDATION_TIMEOUT_MS);
    if (signal?.aborted) {
      onAbort();
      return;
    }
    signal?.addEventListener('abort', onAbort, { once: true });
    pendingUrlValidations.set(id, entry);
    if (!sendSocketMessage(ws, {
      type: MESSAGE_TYPES.URL_VALIDATION_REQUEST,
      version: EXTENSION_PROTOCOL_VERSION,
      id,
      url: String(url || ''),
    })) {
      entry.reject(new Error('Browser URL validation could not be sent.'));
    }
  });
}

async function handleSocketDisconnected(ws, socketEpoch) {
  if (socket !== ws || socketEpoch !== connectionEpoch) return;
  socket = null;
  const disconnectedEpoch = ++connectionEpoch;
  try {
    if (ws.readyState !== WebSocket.CLOSED) ws.close();
  } catch {}
  for (const controller of activeCommandControllers.values()) {
    controller.abort(new Error('NeoAgent browser connection closed.'));
  }
  activeCommandControllers.clear();
  rejectPendingUrlValidations(new Error('NeoAgent browser connection closed.'), ws);
  const { token } = await getStorage(['token']);
  if (connectionEpoch !== disconnectedEpoch || socket) return;
  if (!token) {
    await updateStatus('not_paired', disconnectedEpoch);
    return;
  }
  await updateStatus('disconnected', disconnectedEpoch);
  if (connectionEpoch === disconnectedEpoch && !socket) scheduleReconnect();
}

async function connectOnce() {
  const startingEpoch = connectionEpoch;
  const { token, serverUrl: storedServerUrl } = await getStorage(['token', 'serverUrl']);
  if (startingEpoch !== connectionEpoch) return { connected: false, cancelled: true };
  const serverUrl = normalizeServerUrl(storedServerUrl) || configuredServerUrl();
  if (!serverUrl || !token) {
    await updateStatus('not_paired', startingEpoch);
    return { connected: false };
  }
  if (socket && socket.readyState === WebSocket.OPEN) {
    return { connected: true };
  }
  if (socket && socket.readyState === WebSocket.CONNECTING) {
    return { connected: false, connecting: true };
  }
  const staleSocket = socket;
  socket = null;
  if (staleSocket) {
    rejectPendingUrlValidations(new Error('NeoAgent browser connection was replaced.'), staleSocket);
    try { staleSocket.close(); } catch {}
  }
  clearReconnectTimer();

  const socketEpoch = ++connectionEpoch;
  let ws;
  try {
    ws = new WebSocket(websocketUrl(serverUrl, token));
  } catch (error) {
    await updateStatus('disconnected', socketEpoch);
    scheduleReconnect();
    throw error;
  }
  socket = ws;
  const ready = new Promise((resolve, reject) => {
    let settled = false;
    const finish = (callback, value) => {
      if (settled) return;
      settled = true;
      clearTimeout(connectTimeout);
      callback(value);
    };
    const disconnect = (error, logLabel) => {
      finish(reject, error);
      handleSocketDisconnected(ws, socketEpoch).catch((disconnectError) => {
        console.error(logLabel, disconnectError);
      });
    };
    const connectTimeout = setTimeout(() => {
      disconnect(
        new Error(`NeoAgent browser connection timed out after ${DEFAULT_WS_CONNECT_TIMEOUT_MS}ms.`),
        'NeoAgent connection timeout handling failed',
      );
    }, DEFAULT_WS_CONNECT_TIMEOUT_MS);

    ws.addEventListener('open', () => {
      if (socket !== ws || socketEpoch !== connectionEpoch) {
        try { ws.close(); } catch {}
        finish(reject, new Error('NeoAgent browser connection was superseded.'));
        return;
      }
      reconnectAttempt = 0;
      updateStatus('connected', socketEpoch).catch((error) => {
        console.error('NeoAgent connected status update failed', error);
      });
      finish(resolve, { connected: true });
    });
    ws.addEventListener('close', () => {
      disconnect(
        new Error('NeoAgent browser connection closed before it was ready.'),
        'NeoAgent disconnect handling failed',
      );
    });
    ws.addEventListener('error', () => {
      disconnect(
        new Error('NeoAgent browser connection failed.'),
        'NeoAgent socket error handling failed',
      );
    });
    ws.addEventListener('message', (event) => {
      handleSocketMessage(ws, event.data).catch((error) => {
        console.error('NeoAgent command handling failed', error);
      });
    });
  });
  // The socket can fail while the storage status write is still pending. Attach
  // a handler immediately; returning `ready` below still preserves rejection.
  ready.catch(() => {});

  await updateStatus('connecting', socketEpoch).catch((error) => {
    console.error('NeoAgent connecting status update failed', error);
  });
  return ready;
}

function connect() {
  if (socket?.readyState === WebSocket.OPEN) {
    return Promise.resolve({ connected: true });
  }
  if (connectPromise) return connectPromise;
  const pending = connectOnce();
  connectPromise = pending;
  pending.then(
    () => { if (connectPromise === pending) connectPromise = null; },
    () => { if (connectPromise === pending) connectPromise = null; },
  );
  return pending;
}

function sendSocketMessage(ws, message) {
  if (socket !== ws || ws.readyState !== WebSocket.OPEN) return false;
  try {
    ws.send(JSON.stringify(message));
    return true;
  } catch {
    return false;
  }
}

async function handleSocketMessage(ws, raw) {
  let message;
  try {
    message = JSON.parse(raw);
  } catch {
    return;
  }
  if (!message || !message.id) {
    return;
  }
  if (message.type === MESSAGE_TYPES.URL_VALIDATION_RESULT) {
    const pending = pendingUrlValidations.get(String(message.id));
    if (!pending || pending.socket !== ws) return;
    pending.resolve(
      Number(message.version) === EXTENSION_PROTOCOL_VERSION
      && message.allowed === true,
    );
    return;
  }
  if (message.type !== MESSAGE_TYPES.COMMAND) return;
  if (message.version != null && Number(message.version) !== EXTENSION_PROTOCOL_VERSION) {
    sendSocketMessage(ws, {
      type: MESSAGE_TYPES.RESULT,
      version: EXTENSION_PROTOCOL_VERSION,
      id: message.id,
      ok: false,
      error: `Unsupported protocol version: ${message.version}`,
    });
    return;
  }

  if (message.command === 'cancelCommand') {
    const commandId = String(message.payload?.commandId || '');
    const controller = activeCommandControllers.get(commandId);
    controller?.abort(new Error('Browser command cancelled by NeoAgent.'));
    sendSocketMessage(ws, {
      type: MESSAGE_TYPES.RESULT,
      version: EXTENSION_PROTOCOL_VERSION,
      id: message.id,
      ok: true,
      result: { success: Boolean(controller), commandId },
    });
    return;
  }

  const controller = new AbortController();
  activeCommandControllers.set(message.id, controller);
  const execute = () => protocol.run(message.command, message.payload || {}, {
    signal: controller.signal,
  });
  const queued = commandQueue.then(execute, execute);
  commandQueue = queued.catch(() => {});
  try {
    const result = await queued;
    sendSocketMessage(ws, {
      type: MESSAGE_TYPES.RESULT,
      version: EXTENSION_PROTOCOL_VERSION,
      id: message.id,
      ok: true,
      result,
    });
  } catch (error) {
    sendSocketMessage(ws, {
      type: MESSAGE_TYPES.RESULT,
      version: EXTENSION_PROTOCOL_VERSION,
      id: message.id,
      ok: false,
      error: error?.message || String(error),
    });
  } finally {
    if (activeCommandControllers.get(message.id) === controller) {
      activeCommandControllers.delete(message.id);
    }
  }
}

async function startPairing(serverUrl) {
  const normalized = await resolveServerUrl(serverUrl);
  if (!normalized) throw new Error('NeoAgent server URL required.');
  const { extensionName } = await getStorage(['extensionName']);
  const nameToUse = String(extensionName || 'Chrome Extension').trim() || 'Chrome Extension';
  const { response, payload } = await fetchJsonWithTimeout(`${normalized}/api/browser-extension/pairing/request`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ extensionName: nameToUse }),
  });
  if (!response.ok) throw new Error(payload.error || `Pairing failed: ${response.status}`);
  if (!payload.pairingId || !payload.pairingSecret) {
    throw new Error('NeoAgent server returned an incomplete pairing response.');
  }
  const approvalUrl = String(payload.approvalUrl || '');
  const approvalParsed = (() => { try { return new URL(approvalUrl); } catch { return null; } })();
  const serverParsed = new URL(normalized);
  if (
    !approvalParsed
    || !['http:', 'https:'].includes(approvalParsed.protocol)
    || approvalParsed.origin !== serverParsed.origin
    || approvalParsed.username
    || approvalParsed.password
  ) {
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
  const { serverUrl, pairingId, pairingSecret, extensionName } = await getStorage(['serverUrl', 'pairingId', 'pairingSecret', 'extensionName']);
  if (!serverUrl || !pairingId || !pairingSecret) {
    throw new Error('No pending pairing request.');
  }
  const normalizedServerUrl = normalizeServerUrl(serverUrl);
  const nameToUse = String(extensionName || 'Chrome Extension').trim() || 'Chrome Extension';
  const { response, payload } = await fetchJsonWithTimeout(`${normalizedServerUrl}/api/browser-extension/pairing/${encodeURIComponent(pairingId)}/claim`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ pairingSecret, extensionName: nameToUse }),
  });
  if (!response.ok) throw new Error(payload.error || `Claim failed: ${response.status}`);
  if (!payload.token || !payload.tokenId) {
    throw new Error('NeoAgent server returned an incomplete pairing claim.');
  }
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
  reconnectAttempt = 0;
  const disconnectedEpoch = ++connectionEpoch;
  connectPromise = null;
  const previousSocket = socket;
  socket = null;
  if (previousSocket) {
    try { previousSocket.close(); } catch {}
  }
  for (const controller of activeCommandControllers.values()) {
    controller.abort(new Error('NeoAgent browser connection was disconnected.'));
  }
  activeCommandControllers.clear();
  rejectPendingUrlValidations(new Error('NeoAgent browser connection was disconnected.'));
  await removeStorage(['token', 'tokenId', 'pairingId', 'pairingSecret', 'approvalUrl']);
  await updateStatus('not_paired', disconnectedEpoch);
}

async function checkForUpdates(preferredServerUrl) {
  const serverUrl = await resolveServerUrl(preferredServerUrl);
  if (!serverUrl) throw new Error('NeoAgent server URL required.');
  const { response, payload: latest } = await fetchJsonWithTimeout(
    `${serverUrl}/api/browser-extension/latest`,
  );
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
      case 'saveExtensionName':
        await setStorage({ extensionName: message.extensionName });
        return { success: true };
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

chrome.alarms?.onAlarm?.addListener((alarm) => {
  if (alarm?.name !== KEEPALIVE_ALARM_NAME) return;
  connect().catch((error) => {
    console.error('NeoAgent keepalive reconnect failed', error);
  });
});

chrome.runtime.onStartup?.addListener(() => {
  ensureKeepaliveAlarm();
  connect().catch(() => {});
});

chrome.runtime.onInstalled?.addListener(() => {
  ensureKeepaliveAlarm();
  connect().catch(() => {});
});

ensureKeepaliveAlarm();
connect().catch(() => {});
