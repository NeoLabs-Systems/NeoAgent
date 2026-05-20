const DESKTOP_COMPANION_WS_PATH = '/api/desktop/ws';

const DESKTOP_COMMANDS = Object.freeze({
  GET_STATUS: 'getStatus',
  CAPTURE_FRAME: 'captureFrame',
  STREAM_START: 'startStream',
  STREAM_STOP: 'stopStream',
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

const FRAME_TYPE_VIDEO = 0x01;
const MAX_DESKTOP_STREAM_FRAME_BYTES = 8 * 1024 * 1024;

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

function parseBinaryFrame(buffer) {
  if (
    !Buffer.isBuffer(buffer)
    || buffer.length <= 10
    || buffer.length > MAX_DESKTOP_STREAM_FRAME_BYTES
    || buffer[0] !== FRAME_TYPE_VIDEO
  ) {
    return null;
  }
  const jpeg = buffer.subarray(10);
  const hasJpegMarkers = jpeg.length >= 4
    && jpeg[0] === 0xff
    && jpeg[1] === 0xd8
    && jpeg[jpeg.length - 2] === 0xff
    && jpeg[jpeg.length - 1] === 0xd9;
  if (!hasJpegMarkers) return null;
  return {
    seq: buffer.readUInt32BE(1),
    ts: buffer.readUInt32BE(5),
    flags: buffer.readUInt8(9),
    jpeg,
  };
}

module.exports = {
  DESKTOP_COMPANION_WS_PATH,
  DESKTOP_COMMANDS,
  FRAME_TYPE_VIDEO,
  MAX_DESKTOP_STREAM_FRAME_BYTES,
  DesktopCompanionUnavailableError,
  DesktopCompanionSelectionError,
  createDesktopCommandMessage,
  parseBinaryFrame,
  parseDesktopMessage,
};
