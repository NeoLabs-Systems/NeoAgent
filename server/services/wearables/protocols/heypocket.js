'use strict';

const WearableProtocol = require('./base');

/**
 * Protocol implementation for the HeyPocket Device (PKT01_BLUE_26120842).
 * This device streams 16kHz Mono MP3 frames (32kbps) over BLE.
 */
class PacketProtocol extends WearableProtocol {
  get id() {
    return 'packet';
  }

  get name() {
    return 'HeyPocket Device';
  }

  get mimeType() {
    return 'audio/mpeg'; 
  }

  /**
   * Characteristics used by this protocol.
   */
  get characteristics() {
    return {
      controlRx: '001120a0-2233-4455-6677-88991234567a', // ...a2... (Control RX)
      controlTx: '001120a0-2233-4455-6677-88991234567b', // ...a3... (Control TX)
      audioTx: '001120a0-2233-4455-6677-889912345679' // ...a1... (Data TX)
    };
  }

  parseAudioPayload(rawPayload, context = {}) {
    if (!Buffer.isBuffer(rawPayload) || rawPayload.length === 0) {
      return null;
    }

    const characteristicUuid = this.#normalizeUuid(context?.characteristicUuid);
    const controlTx = this.#normalizeUuid(this.characteristics.controlTx);
    const controlRx = this.#normalizeUuid(this.characteristics.controlRx);
    const audioTx = this.#normalizeUuid(this.characteristics.audioTx);

    if (characteristicUuid && (characteristicUuid === controlTx || characteristicUuid === controlRx)) {
      return null;
    }

    if (characteristicUuid && characteristicUuid === audioTx) {
      return rawPayload;
    }

    if (this.#isAsciiControlMessage(rawPayload)) {
      return null;
    }

    // Spec: "Implementation Note: Just sequentially concatenate the raw payloads 
    // received from 0x002d notifications and save them with an .mp3 extension."
    return rawPayload;
  }

  extractBatteryLevel(rawPayload, context = {}) {
    if (!Buffer.isBuffer(rawPayload) || rawPayload.length === 0) {
      return null;
    }

    // Spec: "MCU&BAT&98"
    const text = rawPayload.toString('ascii');
    const match = text.match(/MCU&BAT&(\d+)/);
    if (match) {
      const level = parseInt(match[1], 10);
      if (!isNaN(level) && level >= 0 && level <= 100) {
        return level;
      }
    }
    return null;
  }

  async processOfflineSync(fileBuffer) {
    // Spec: "To reconstruct the audio file... just sequentially concatenate 
    // the raw payloads... Any compliant decoder will latch onto the FF F3 sync words."
    return fileBuffer;
  }

  #normalizeUuid(value) {
    if (typeof value !== 'string') {
      return null;
    }
    return value.trim().toLowerCase().replace(/-/g, '');
  }

  #isAsciiControlMessage(rawPayload) {
    if (rawPayload.length < 5) {
      return false;
    }

    const text = rawPayload.toString('ascii');
    if (!/^[\x20-\x7e\r\n\t]+$/.test(text)) {
      return false;
    }

    return /^(MCU|APP|BLE|SYS)&/.test(text.trim());
  }
}

module.exports = new PacketProtocol();
