const statusEl = document.querySelector('#status');
const statusDotEl = document.querySelector('#statusDot');
const serverUrlEl = document.querySelector('#serverUrl');
const serverLabelEl = document.querySelector('#serverLabel');
const messageEl = document.querySelector('#message');
const advancedEl = document.querySelector('.advanced');

const STATUS_LABELS = {
  connected: 'Connected',
  connecting: 'Connecting...',
  paired: 'Paired',
  approval_pending: 'Waiting for approval',
  disconnected: 'Disconnected',
  not_paired: 'Not paired',
};

function send(type, payload = {}) {
  return chrome.runtime.sendMessage({ type, ...payload }).then((response) => {
    if (!response?.ok) throw new Error(response?.error || 'Extension action failed.');
    return response.result;
  });
}

function setMessage(text) {
  messageEl.textContent = text || '';
}

async function refresh() {
  const state = await send('getState');
  const status = state.status || 'not_paired';
  const serverUrl = state.serverUrl || state.configuredServerUrl || '';
  statusEl.textContent = STATUS_LABELS[status] || status;
  statusDotEl.dataset.status = status;
  serverLabelEl.textContent = serverUrl
    ? `Server: ${serverUrl}`
    : 'No server bundled. Open Advanced server URL.';
  if (serverUrl) serverUrlEl.value = serverUrl;
  advancedEl.open = !serverUrl;
}

document.querySelector('#pair').addEventListener('click', async () => {
  try {
    setMessage('');
    await send('startPairing', { serverUrl: serverUrlEl.value });
    await refresh();
    setMessage('Log in and approve the extension in the opened NeoAgent tab.');
  } catch (error) {
    setMessage(error.message);
  }
});

document.querySelector('#claim').addEventListener('click', async () => {
  try {
    setMessage('');
    await send('claimPairing');
    await refresh();
    setMessage('Connected.');
  } catch (error) {
    setMessage(error.message);
  }
});

document.querySelector('#disconnect').addEventListener('click', async () => {
  try {
    setMessage('');
    await send('disconnect');
    await refresh();
  } catch (error) {
    setMessage(error.message);
  }
});

document.querySelector('#checkUpdate').addEventListener('click', async () => {
  try {
    setMessage('');
    const result = await send('checkForUpdates', { serverUrl: serverUrlEl.value });
    setMessage(
      result.updateAvailable
        ? `Update available: ${result.currentVersion} -> ${result.latestVersion}.`
        : `Current version ${result.currentVersion} is up to date.`,
    );
  } catch (error) {
    setMessage(error.message);
  }
});

document.querySelector('#download').addEventListener('click', async () => {
  try {
    setMessage('');
    await send('openDownload', { serverUrl: serverUrlEl.value });
  } catch (error) {
    setMessage(error.message);
  }
});

chrome.runtime.onMessage.addListener((message) => {
  if (message?.type === 'status') refresh().catch(() => {});
});

refresh().catch((error) => setMessage(error.message));
