const DESKTOP_COMPANION_WS_PATH = '/api/desktop/ws';

const DESKTOP_COMMANDS = Object.freeze({
  GET_STATUS: 'getStatus',
  CAPTURE_FRAME: 'captureFrame',
  OBSERVE: 'observe',
  CLICK: 'click',
  DRAG: 'drag',
  SCROLL: 'scroll',
  TYPE_TEXT: 'typeText',
  PRESS_KEY: 'pressKey',
  LAUNCH_APP: 'launchApp',
  LIST_DISPLAYS: 'listDisplays',
  SELECT_DISPLAY: 'selectDisplay',
  GET_TREE: 'getTree',
  PAUSE_CONTROL: 'pauseControl',
  EXECUTE_COMMAND: 'executeCommand',
  PING: 'ping',
});

class DesktopCompanionUnavailableError extends Error {
  constructor(message = 'Desktop companion is not connected.') {
    super(message);
    this.name = 'DesktopCompanionUnavailableError';
    this.code = 'DESKTOP_COMPANION_NOT_CONNECTED';
  }
}

class DesktopCompanionSelectionError extends Error {
  constructor(message = 'Multiple desktop companions are online. Select a device first.', details = null) {
    super(message);
    this.name = 'DesktopCompanionSelectionError';
    this.code = 'DESKTOP_COMPANION_SELECTION_REQUIRED';
    this.details = details;
  }
}

function createDesktopCommandMessage(id, command, payload = {}) {
  return {
    type: 'command',
    id,
    command,
    payload,
  };
}

function parseDesktopMessage(data) {
  const raw = Buffer.isBuffer(data) ? data.toString('utf8') : String(data || '');
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw);
    return parsed && typeof parsed === 'object' ? parsed : null;
  } catch {
    return null;
  }
}

module.exports = {
  DESKTOP_COMPANION_WS_PATH,
  DESKTOP_COMMANDS,
  DesktopCompanionUnavailableError,
  DesktopCompanionSelectionError,
  createDesktopCommandMessage,
  parseDesktopMessage,
};
