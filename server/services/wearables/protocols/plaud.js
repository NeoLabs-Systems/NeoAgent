'use strict';

const WearableProtocol = require('./base');

/**
 * Plaud Note Protocol
 * Uses custom notification format with 9-byte header
 * Audio format: OPUS in MP4 container
 */
class PlaudProtocol extends WearableProtocol {
    get id() {
        return 'plaud';
    }

    get name() {
        return 'Plaud Note';
    }

    get mimeType() {
        return 'audio/mp4';
    }

    get characteristics() {
        return {
            service: '00001910-0000-1000-8000-00805f9b34fb',
            notify: '00002bb0-0000-1000-8000-00805f9b34fb',
            write: '00002bb1-0000-1000-8000-00805f9b34fb',
        };
    }

    parseAudioPayload(rawPayload, context = {}) {
        // Plaud format: [command(1)][sessionId(4)][position(4)][length(1)][data...]
        // Audio data packets have command = 2
        if (!Buffer.isBuffer(rawPayload) || rawPayload.length < 9) {
            return null;
        }

        // Check if it's an audio data packet (command = 2)
        if (rawPayload[0] !== 2) {
            return null;
        }

        const position = this._bytesToInt32(rawPayload.subarray(4, 8));
        if (position === 0xFFFFFFFF) {
            return null; // End marker
        }

        const length = rawPayload[8];
        if (rawPayload.length < 9 + length) {
            return null;
        }

        return rawPayload.subarray(9, 9 + length);
    }

    extractBatteryLevel(rawPayload, context = {}) {
        // Battery response format: [isCharging(1)][level(1)]
        if (Buffer.isBuffer(rawPayload) && rawPayload.length >= 2) {
            const level = rawPayload[1];
            if (level >= 0 && level <= 100) {
                return level;
            }
        }
        return null;
    }

    _bytesToInt32(bytes) {
        return bytes[0] | (bytes[1] << 8) | (bytes[2] << 16) | (bytes[3] << 24);
    }

    async processOfflineSync(fileBuffer) {
        // Plaud files are already in MP4 format
        return fileBuffer;
    }
}

module.exports = new PlaudProtocol();