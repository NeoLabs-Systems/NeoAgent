'use strict';

class WearableProtocol {
  /**
   * The unique identifier for this protocol (e.g., 'friend', 'omi')
   */
  get id() {
    throw new Error('Not implemented');
  }

  /**
   * The human readable name of the device or protocol.
   */
  get name() {
    throw new Error('Not implemented');
  }

  /**
   * The MIME type of the audio that this protocol produces after parsing.
   * e.g., 'audio/wav', 'audio/opus'
   */
  get mimeType() {
    return 'application/octet-stream';
  }

  /**
   * Parse a raw byte payload received from the device via BLE.
   * Returns a Buffer containing the parsed/transcoded audio data, or null if the payload
   * is not audio content (e.g., control messages).
   * 
   * @param {Buffer} rawPayload 
   * @returns {Buffer|null}
   */
  parseAudioPayload(rawPayload) {
    return rawPayload; // By default, assume the payload is already valid audio bytes
  }

  /**
   * Extracts battery level (0-100) from a raw payload if applicable.
   * If the payload does not contain battery info, return null.
   * 
   * @param {Buffer} rawPayload 
   * @returns {number|null}
   */
  extractBatteryLevel(rawPayload) {
    return null; 
  }

  /**
   * Process a full offline sync file uploaded from the device.
   * Returns a Buffer ready to be sent to the transcription service.
   * 
   * @param {Buffer} fileBuffer 
   * @returns {Promise<Buffer>}
   */
  async processOfflineSync(fileBuffer) {
    return fileBuffer;
  }
}

module.exports = WearableProtocol;
