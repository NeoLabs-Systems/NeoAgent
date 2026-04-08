const BROWSER_EXTENSION_WS_PATH = '/api/browser-extension/ws';

const EXTENSION_COMMANDS = Object.freeze({
  LAUNCH: 'launch',
  NAVIGATE: 'navigate',
  CLICK: 'click',
  CLICK_POINT: 'clickPoint',
  TYPE: 'type',
  TYPE_TEXT: 'typeText',
  PRESS_KEY: 'pressKey',
  SCROLL: 'scroll',
  EXTRACT: 'extract',
  EVALUATE: 'evaluate',
  SCREENSHOT: 'screenshot',
  CLOSE: 'close',
  GET_PAGE_INFO: 'getPageInfo',
});

class ExtensionBrowserUnavailableError extends Error {
  constructor(message = 'Extension browser not connected.') {
    super(message);
    this.name = 'ExtensionBrowserUnavailableError';
    this.code = 'EXTENSION_BROWSER_NOT_CONNECTED';
  }
}

function createCommandMessage(id, command, payload = {}) {
  return {
    type: 'command',
    id,
    command,
    payload,
  };
}

function parseExtensionMessage(data) {
  const raw = Buffer.isBuffer(data) ? data.toString('utf8') : String(data || '');
  if (!raw) return null;
  const parsed = JSON.parse(raw);
  return parsed && typeof parsed === 'object' ? parsed : null;
}

module.exports = {
  BROWSER_EXTENSION_WS_PATH,
  EXTENSION_COMMANDS,
  ExtensionBrowserUnavailableError,
  createCommandMessage,
  parseExtensionMessage,
};
