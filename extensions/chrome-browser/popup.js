const statusEl = document.querySelector('#status');
const statusDotEl = document.querySelector('#statusDot');
const serverUrlEl = document.querySelector('#serverUrl');
const extensionNameEl = document.querySelector('#extensionName');
const serverLabelEl = document.querySelector('#serverLabel');
const messageEl = document.querySelector('#message');
const settingsEl = document.querySelector('#settings');
const stepLabelEl = document.querySelector('#stepLabel');
const flowTitleEl = document.querySelector('#flowTitle');
const flowDescriptionEl = document.querySelector('#flowDescription');
const primaryActionEl = document.querySelector('#primaryAction');
const secondaryActionEl = document.querySelector('#secondaryAction');
const disconnectEl = document.querySelector('#disconnect');
const checkUpdateEl = document.querySelector('#checkUpdate');
const downloadEl = document.querySelector('#download');

const STATUS_LABELS = {
  connected: 'Connected',
  connecting: 'Connecting...',
  paired: 'Paired',
  approval_pending: 'Waiting for approval',
  disconnected: 'Disconnected',
  not_paired: 'Not paired',
};

let currentState = {};
let pendingActions = 0;

function send(type, payload = {}) {
  return chrome.runtime.sendMessage({ type, ...payload }).then((response) => {
    if (!response?.ok) throw new Error(response?.error || 'Extension action failed.');
    return response.result;
  });
}

function effectiveServerUrl() {
  return String(
    serverUrlEl.value ||
    currentState.serverUrl ||
    currentState.configuredServerUrl ||
    '',
  ).trim();
}

function setMessage(text, tone = '') {
  messageEl.textContent = text || '';
  if (tone) {
    messageEl.dataset.tone = tone;
  } else {
    delete messageEl.dataset.tone;
  }
}

function setBusy(isBusy, label = 'Working...') {
  if (isBusy) {
    pendingActions += 1;
  } else {
    pendingActions = Math.max(0, pendingActions - 1);
  }
  const busy = pendingActions > 0;

  [primaryActionEl, secondaryActionEl, disconnectEl, checkUpdateEl, downloadEl].forEach((button) => {
    if (!button || button.hidden) return;
    if (busy) {
      if (!Object.prototype.hasOwnProperty.call(button.dataset, 'wasDisabled')) {
        button.dataset.wasDisabled = button.disabled ? 'true' : 'false';
      }
      button.disabled = true;
    } else if (button.dataset.wasDisabled) {
      button.disabled = button.dataset.wasDisabled === 'true';
      delete button.dataset.wasDisabled;
    }
  });

  if (busy) {
    document.body.dataset.busy = 'true';
    if (!messageEl.textContent) {
      setMessage(label, 'success');
    }
  } else {
    delete document.body.dataset.busy;
    if (messageEl.dataset.tone === 'success' && messageEl.textContent === label) {
      setMessage('');
    }
  }
}

function setAction(button, { label, action, hidden = false, disabled = false }) {
  button.textContent = label;
  button.dataset.action = action;
  button.hidden = hidden;
  button.disabled = disabled;
}

function updateFlow() {
  const status = currentState.status || 'not_paired';
  const serverUrl = effectiveServerUrl();
  const hasServerUrl = Boolean(serverUrl);
  const hasToken = Boolean(currentState.token || currentState.tokenId);
  const approvalUrl = currentState.approvalUrl || '';

  if (!hasServerUrl) {
    stepLabelEl.textContent = 'Step 1 of 3';
    flowTitleEl.textContent = 'Add your NeoAgent server';
    flowDescriptionEl.textContent = 'Paste the web address from NeoAgent before starting the browser pairing.';
    setAction(primaryActionEl, { label: 'Add server URL', action: 'openSettings' });
    setAction(secondaryActionEl, { label: '', action: '', hidden: true });
    settingsEl.open = true;
    return;
  }

  if (status === 'approval_pending') {
    stepLabelEl.textContent = 'Step 2 of 3';
    flowTitleEl.textContent = 'Approve in NeoAgent';
    flowDescriptionEl.textContent = 'Use the NeoAgent tab that opened, approve this browser, then return here.';
    setAction(primaryActionEl, { label: 'I approved it', action: 'claimPairing' });
    setAction(secondaryActionEl, {
      label: 'Open approval tab',
      action: 'openApproval',
      hidden: !approvalUrl,
    });
    return;
  }

  if (status === 'connected') {
    stepLabelEl.textContent = 'Ready';
    flowTitleEl.textContent = 'This browser is connected';
    flowDescriptionEl.textContent = 'Open NeoAgent and use the Devices tab when you want this browser controlled.';
    setAction(primaryActionEl, { label: 'Open NeoAgent', action: 'openApp' });
    setAction(secondaryActionEl, { label: '', action: '', hidden: true });
    return;
  }

  if (hasToken && status === 'disconnected') {
    stepLabelEl.textContent = 'Reconnect';
    flowTitleEl.textContent = 'Connection paused';
    flowDescriptionEl.textContent = 'Reconnect this browser to the NeoAgent server, or open NeoAgent first.';
    setAction(primaryActionEl, { label: 'Reconnect browser', action: 'connect' });
    setAction(secondaryActionEl, { label: 'Open NeoAgent', action: 'openApp' });
    return;
  }

  if (hasToken || status === 'paired' || status === 'connecting') {
    stepLabelEl.textContent = 'Step 3 of 3';
    flowTitleEl.textContent = 'Finish connection';
    flowDescriptionEl.textContent = 'The extension is paired. Open NeoAgent once the status changes to connected.';
    setAction(primaryActionEl, {
      label: status === 'connecting' ? 'Connecting...' : 'Open NeoAgent',
      action: 'openApp',
      disabled: status === 'connecting',
    });
    setAction(secondaryActionEl, { label: '', action: '', hidden: true });
    return;
  }

  stepLabelEl.textContent = 'Step 1 of 3';
  flowTitleEl.textContent = 'Start browser pairing';
  flowDescriptionEl.textContent = 'Open NeoAgent, approve this extension, then come back to finish.';
  setAction(primaryActionEl, { label: 'Start pairing', action: 'startPairing' });
  setAction(secondaryActionEl, { label: '', action: '', hidden: true });
}

async function openUrl(url, missingMessage) {
  if (!url) throw new Error(missingMessage);
  await chrome.tabs.create({ url, active: true });
}

async function runAction(action) {
  switch (action) {
    case 'openSettings':
      settingsEl.open = true;
      serverUrlEl.focus();
      return;
    case 'startPairing':
      await send('startPairing', { serverUrl: effectiveServerUrl() });
      await refresh();
      setMessage('Approve this browser in the opened NeoAgent tab, then return here.', 'success');
      return;
    case 'claimPairing':
      await send('claimPairing');
      await refresh();
      setMessage('Connected.', 'success');
      return;
    case 'connect':
      await send('connect');
      await refresh();
      setMessage('Reconnecting to NeoAgent...', 'success');
      return;
    case 'openApproval':
      await openUrl(currentState.approvalUrl, 'No approval tab is available. Start pairing again.');
      return;
    case 'openApp':
      await openUrl(effectiveServerUrl(), 'NeoAgent server URL required.');
      return;
    default:
      return;
  }
}

async function refresh() {
  currentState = await send('getState');
  const hasToken = Boolean(currentState.token || currentState.tokenId);
  const status = !hasToken && currentState.status === 'disconnected'
    ? 'not_paired'
    : (currentState.status || 'not_paired');
  const serverUrl = currentState.serverUrl || currentState.configuredServerUrl || '';
  currentState = { ...currentState, status };

  statusEl.textContent = STATUS_LABELS[status] || status;
  statusDotEl.dataset.status = status;
  serverLabelEl.textContent = serverUrl
    ? `Server: ${serverUrl}`
    : 'No server URL yet.';

  if (serverUrl && document.activeElement !== serverUrlEl) {
    serverUrlEl.value = serverUrl;
  }
  const extensionName = currentState.extensionName || 'Chrome Extension';
  if (document.activeElement !== extensionNameEl) {
    extensionNameEl.value = extensionName;
  }
  if (!serverUrl) {
    settingsEl.open = true;
  }

  updateFlow();
}

function bindAsyncClick(element, handler) {
  element.addEventListener('click', async () => {
    try {
      setMessage('');
      setBusy(true);
      await handler();
    } catch (error) {
      setMessage(error.message, 'error');
    } finally {
      setBusy(false);
      updateFlow();
    }
  });
}

serverUrlEl.addEventListener('input', updateFlow);
extensionNameEl.addEventListener('input', async () => {
  const name = String(extensionNameEl.value || '').trim();
  try {
    await send('saveExtensionName', { extensionName: name });
  } catch (err) {
    console.error('Failed to save extension name', err);
  }
});

bindAsyncClick(primaryActionEl, () => runAction(primaryActionEl.dataset.action));
bindAsyncClick(secondaryActionEl, () => runAction(secondaryActionEl.dataset.action));
bindAsyncClick(disconnectEl, async () => {
  await send('disconnect');
  await refresh();
  setMessage('Disconnected.', 'success');
});
bindAsyncClick(checkUpdateEl, async () => {
  const result = await send('checkForUpdates', { serverUrl: effectiveServerUrl() });
  setMessage(
    result.updateAvailable
      ? `Update available: ${result.currentVersionName || result.currentVersion} -> ${result.latestVersionName || result.latestVersion}.`
      : `Current version ${result.currentVersionName || result.currentVersion} is up to date.`,
    result.updateAvailable ? '' : 'success',
  );
});
bindAsyncClick(downloadEl, async () => {
  await send('openDownload', { serverUrl: effectiveServerUrl() });
});

chrome.runtime.onMessage.addListener((message) => {
  if (message?.type === 'status') refresh().catch(() => {});
});

refresh().catch((error) => setMessage(error.message, 'error'));
