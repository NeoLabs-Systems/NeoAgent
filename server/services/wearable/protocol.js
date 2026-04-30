'use strict';

const WEARABLE_WS_PATH = '/api/wearable/ws';

const CLIENT_MESSAGE_TYPES = new Set([
  'wearable:hello',
  'voice:session_open',
  'voice:input_start',
  'voice:audio_chunk',
  'voice:input_commit',
  'voice:interrupt',
  'voice:session_close',
]);

function parseWearableMessage(data) {
  const text = Buffer.isBuffer(data) ? data.toString('utf8') : String(data || '');
  const parsed = JSON.parse(text);
  if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
    throw new Error('Wearable message must be a JSON object.');
  }
  const type = String(parsed.type || '').trim();
  if (!type) {
    throw new Error('Wearable message type is required.');
  }
  return {
    ...parsed,
    type,
  };
}

function isWearableHello(message) {
  return message?.type === 'wearable:hello';
}

function isSupportedClientMessageType(type) {
  return CLIENT_MESSAGE_TYPES.has(String(type || '').trim());
}

module.exports = {
  CLIENT_MESSAGE_TYPES,
  WEARABLE_WS_PATH,
  isSupportedClientMessageType,
  isWearableHello,
  parseWearableMessage,
};
