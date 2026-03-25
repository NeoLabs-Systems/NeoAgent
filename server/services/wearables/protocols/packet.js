'use strict';

const WearableProtocol = require('./base');

/**
 * Protocol implementation for the Packet Wearable (PKT01_BLUE_26120842).
 * This device streams 16kHz Mono MP3 frames (32kbps) over BLE.
 */
class PacketProtocol extends WearableProtocol {
  get id() {
    return 'packet';
  }

  get name() {
    return 'Packet Wearable';
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
    // If we know this is the Audio TX characteristic, it's always audio.
    // If not specified, we attempt to check if it's NOT an ASCII command.
    if (context.characteristicUuid === this.characteristics.controlTx) {
      return null; // Control messages aren't audio
    }

    if (!Buffer.isBuffer(rawPayload) || rawPayload.length === 0) {
      return null;
    }

    // Spec: "Implementation Note: Just sequentially concatenate the raw payloads 
    // received from 0x002d notifications and save them with an .mp3 extension."
    return rawPayload;
  }

  extractBatteryLevel(rawPayload, context = {}) {
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
}

module.exports = new PacketProtocol();
