'use strict';

const WearableProtocol = require('./base');

/**
 * Limitless Protocol
 * Uses custom notification format
 * Audio format: OPUS in MP4 container
 */
class LimitlessProtocol extends WearableProtocol {
    get id() {
        return 'limitless';
    }

    get name() {
        return 'Limitless';
    }

    get mimeType() {
        return 'audio/mp4';
    }

    get characteristics() {
        return {
            service: '632de001-604c-446b-a80f-7963e950f3fb',
            tx: '632de002-604c-446b-a80f-7963e950f3fb',
            rx: '632de003-604c-446b-a80f-7963e950f3fb',
        };
    }

    parseAudioPayload(rawPayload, context = {}) {
        if (!Buffer.isBuffer(rawPayload) || rawPayload.length === 0) {
            return null;
        }
        return rawPayload;
    }

    extractBatteryLevel(rawPayload, context = {}) {
        // TODO: Determine battery format from Limitless protocol
        return null;
    }

    async processOfflineSync(fileBuffer) {
        return fileBuffer;
    }
}

module.exports = new LimitlessProtocol();