'use strict';

const WearableProtocol = require('./base');

/**
 * Omi / OpenGlass Protocol
 * Standard PCM audio streaming at 16kHz
 */
class OmiProtocol extends WearableProtocol {
    get id() {
        return 'omi';
    }

    get name() {
        return 'Omi / OpenGlass';
    }

    get mimeType() {
        return 'audio/wav';
    }

    get characteristics() {
        return {
            audioData: '19b10001-e8f2-537e-4f6c-d104768a1214',
            audioCodec: '19b10002-e8f2-537e-4f6c-d104768a1214',
            imageData: '19b10005-e8f2-537e-4f6c-d104768a1214',
            timeSync: '19b10030-e8f2-537e-4f6c-d104768a1214',
        };
    }

    parseAudioPayload(rawPayload, context = {}) {
        if (!Buffer.isBuffer(rawPayload) || rawPayload.length === 0) {
            return null;
        }
        return rawPayload;
    }

    extractBatteryLevel(rawPayload, context = {}) {
        // Omi doesn't embed battery in audio stream
        return null;
    }

    async processOfflineSync(fileBuffer) {
        return fileBuffer;
    }
}

module.exports = new OmiProtocol();