'use strict';

const MAX_SCREENSHOT_BYTES = 20 * 1024 * 1024;
const PNG_SIGNATURE = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

function imageError(message, code = 'INVALID_IMAGE_PAYLOAD') {
  const error = new Error(message);
  error.code = code;
  return error;
}

function detectImage(buffer) {
  if (
    buffer.length >= 24
    && buffer.subarray(0, PNG_SIGNATURE.length).equals(PNG_SIGNATURE)
    && buffer.subarray(12, 16).toString('ascii') === 'IHDR'
  ) {
    const width = buffer.readUInt32BE(16);
    const height = buffer.readUInt32BE(20);
    if (!width || !height || width > 32768 || height > 32768 || width * height > 150_000_000) {
      throw imageError('Screenshot PNG has invalid or unsafe dimensions.');
    }
    return { contentType: 'image/png', extension: 'png', width, height };
  }
  if (
    buffer.length >= 4
    && buffer[0] === 0xff
    && buffer[1] === 0xd8
    && buffer[buffer.length - 2] === 0xff
    && buffer[buffer.length - 1] === 0xd9
  ) {
    return { contentType: 'image/jpeg', extension: 'jpg', width: null, height: null };
  }
  throw imageError('Screenshot payload is not a valid PNG or JPEG image.');
}

function validateImageBuffer(value, options = {}) {
  const buffer = Buffer.isBuffer(value) ? value : Buffer.from(value || []);
  const maxBytes = Math.max(1024, Number(options.maxBytes) || MAX_SCREENSHOT_BYTES);
  if (!buffer.length) throw imageError('Screenshot payload is empty.');
  if (buffer.length > maxBytes) {
    throw imageError(
      `Screenshot payload exceeds the ${maxBytes}-byte limit.`,
      'IMAGE_PAYLOAD_TOO_LARGE',
    );
  }
  const detected = detectImage(buffer);
  const allowedTypes = Array.isArray(options.allowedTypes) && options.allowedTypes.length
    ? new Set(options.allowedTypes.map((type) => String(type).toLowerCase()))
    : null;
  if (allowedTypes && !allowedTypes.has(detected.contentType)) {
    throw imageError(`Screenshot type ${detected.contentType} is not allowed.`);
  }
  return { buffer, ...detected };
}

function decodeBase64Image(value, options = {}) {
  const text = String(value || '');
  if (!text) throw imageError('Screenshot payload is empty.');
  let declaredType = null;
  let encoded = text;
  if (text.startsWith('data:')) {
    const match = text.match(/^data:image\/(png|jpeg|jpg);base64,([A-Za-z0-9+/]*={0,2})$/i);
    if (!match) throw imageError('Screenshot data URL is malformed or uses an unsupported type.');
    declaredType = match[1].toLowerCase() === 'png' ? 'image/png' : 'image/jpeg';
    encoded = match[2];
  }
  if (!encoded || encoded.length % 4 === 1 || !/^[A-Za-z0-9+/]*={0,2}$/.test(encoded)) {
    throw imageError('Screenshot base64 payload is malformed.');
  }
  const maxBytes = Math.max(1024, Number(options.maxBytes) || MAX_SCREENSHOT_BYTES);
  const padding = encoded.endsWith('==') ? 2 : (encoded.endsWith('=') ? 1 : 0);
  const estimatedBytes = Math.floor(encoded.length * 3 / 4) - padding;
  if (estimatedBytes > maxBytes) {
    throw imageError(
      `Screenshot payload exceeds the ${maxBytes}-byte limit.`,
      'IMAGE_PAYLOAD_TOO_LARGE',
    );
  }
  const buffer = Buffer.from(encoded, 'base64');
  if (buffer.toString('base64').replace(/=+$/, '') !== encoded.replace(/=+$/, '')) {
    throw imageError('Screenshot base64 payload is malformed.');
  }
  const validated = validateImageBuffer(buffer, { ...options, maxBytes });
  if (declaredType && declaredType !== validated.contentType) {
    throw imageError('Screenshot data URL type does not match its image bytes.');
  }
  return validated;
}

module.exports = {
  MAX_SCREENSHOT_BYTES,
  decodeBase64Image,
  validateImageBuffer,
};
