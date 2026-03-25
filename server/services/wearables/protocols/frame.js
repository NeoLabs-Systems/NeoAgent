'use strict';

const WearableProtocol = require('./base');

/**
 * Frame Protocol
 * Audio format: MP3
 */
class FrameProtocol extends WearableProtocol {
    get id() {
        return 'frame';
    }

    get name() {
        return 'Frame';
    }

    get mimeType() {
        return 'audio/mp3';
    }

    get characteristics() {
        return {
            service: '7A230001-5475-A6A4-654C-8431F6AD49C4',
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

module.exports = new FrameProtocol();