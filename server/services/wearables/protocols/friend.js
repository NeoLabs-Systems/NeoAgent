'use strict';

const WearableProtocol = require('./base');

/**
 * Friend Pendant Protocol
 * Uses LC3 codec at 16kHz with 30-byte frames
 * Packets contain 3 frames (90 bytes LC3 data + 5 bytes footer = 95 bytes total)
 */
class FriendProtocol extends WearableProtocol {
    get id() {
        return 'friend';
    }

    get name() {
        return 'Friend Pendant';
    }

    get mimeType() {
        return 'audio/lc3';
    }

    get characteristics() {
        return {
            service: '1a3fd0e7-b1f3-ac9e-2e49-b647b2c4f8da',
            audio: '01000000-1111-1111-1111-111111111111',
        };
    }

    parseAudioPayload(rawPayload, context = {}) {
        // Friend sends 95-byte packets: 90 bytes LC3 + 5 bytes footer
        // Strip the 5-byte footer to get LC3 audio data
        if (!Buffer.isBuffer(rawPayload) || rawPayload.length < 5) {
            return null;
        }

        // Check if this is the audio characteristic
        if (context.characteristicUuid === this.characteristics.audio) {
            // Strip 5-byte footer
            return rawPayload.subarray(0, rawPayload.length - 5);
        }

        return rawPayload;
    }

    extractBatteryLevel(rawPayload, context = {}) {
        // Friend doesn't report battery via BLE
        // Return default 90% as mentioned in Omi code
        return 90;
    }

    async processOfflineSync(fileBuffer) {
        // LC3 files are raw LC3 frames - concatenate directly
        return fileBuffer;
    }
}

module.exports = new FriendProtocol();