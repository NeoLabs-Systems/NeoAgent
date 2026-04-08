const statusEl = document.querySelector('#status');
const serverUrlEl = document.querySelector('#serverUrl');
const messageEl = document.querySelector('#message');

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
  statusEl.textContent = `Status: ${state.status || 'not_paired'}`;
  if (state.serverUrl) serverUrlEl.value = state.serverUrl;
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
    const result = await send('checkForUpdates');
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
    await send('openDownload');
  } catch (error) {
    setMessage(error.message);
  }
});

chrome.runtime.onMessage.addListener((message) => {
  if (message?.type === 'status') refresh().catch(() => {});
});

refresh().catch((error) => setMessage(error.message));
