const db = require('../../db/database');
const { BasePlatform } = require('./base');
const { wearableDeviceAuth } = require('../wearables/device_auth');

class WaveshareWearablePlatform extends BasePlatform {
  constructor(config = {}) {
    super('waveshare_wearable', config);
    this.supportsGroups = false;
    this.supportsMedia = false;
    this.supportsVoice = false;
    this.status = 'disconnected';
  }

  async connect() {
    this.status = 'connected';
    this.emit('connected');
  }

  async disconnect() {
    this.status = 'disconnected';
    this.emit('disconnected', { reason: 'manual' });
  }

  async sendMessage() {
    this.emit('message_sent');
    return { queued: true };
  }

  getAuthInfo() {
    return {
      label: this.config?.deviceLabel || 'Wearable provisioning enabled',
    };
  }

  listDevices(userId, options = {}) {
    return wearableDeviceAuth.listDevicesForUser(userId, options);
  }
}

module.exports = { WaveshareWearablePlatform };
