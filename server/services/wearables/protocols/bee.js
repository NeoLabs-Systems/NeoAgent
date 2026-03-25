'use strict';

const WearableProtocol = require('./base');

/**
 * Bee Protocol
 * Audio format: MP3
 */
class BeeProtocol extends WearableProtocol {
    get id() {
        return 'bee';
    }

    get name() {
        return 'Bee';
    }

    get mimeType() {
        return 'audio/mp3';
    }

    get characteristics() {
        return {
            service: '03d5d5c4-a86c-11ee-9d89-8f2089a49e7e',
        };
    }

    parseAudioPayload(rawPayload, context = {}) {
        if (!Buffer.isBuffer(rawPayload) || rawPayload.length === 0) {
            return null;
        }
        return rawPayload;
    }

    extractBatteryLevel(rawPayload, context = {}) {
        return null;
    }

    async processOfflineSync(fileBuffer) {
        return fileBuffer;
    }
}

module.exports = new BeeProtocol();