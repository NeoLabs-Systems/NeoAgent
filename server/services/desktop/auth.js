function isDesktopCompanionHello(message) {
  return Boolean(
    message
    && message.type === 'hello'
    && message.device
    && typeof message.device === 'object'
  );
}

function normalizeDesktopHello(message) {
  const device = message?.device && typeof message.device === 'object'
    ? message.device
    : {};
  return {
    deviceId: String(device.deviceId || '').trim(),
    activationId: String(device.activationId || '').trim(),
    label: String(device.label || '').trim(),
    hostname: String(device.hostname || '').trim(),
    platform: String(device.platform || '').trim(),
    platformVersion: String(device.platformVersion || '').trim(),
    appVersion: String(device.appVersion || '').trim(),
    companionEnabled: device.companionEnabled === true,
    paused: device.paused === true,
    permissions: device.permissions && typeof device.permissions === 'object'
      ? device.permissions
      : {},
    capabilities: device.capabilities && typeof device.capabilities === 'object'
      ? device.capabilities
      : {},
    displays: Array.isArray(device.displays) ? device.displays : [],
    activeDisplayId: String(device.activeDisplayId || '').trim(),
    metadata: device.metadata && typeof device.metadata === 'object'
      ? device.metadata
      : {},
  };
}

function assertDesktopHelloAuth({ sessionUserId, hello }) {
  if (!sessionUserId) {
    const error = new Error('Unauthorized');
    error.status = 401;
    throw error;
  }
  if (!hello) {
    const error = new Error('hello is required');
    error.status = 400;
    throw error;
  }
  if (!hello.companionEnabled) {
    const error = new Error('Companion mode is not enabled on this desktop app.');
    error.status = 403;
    throw error;
  }
  if (!hello.deviceId) {
    const error = new Error('deviceId is required.');
    error.status = 400;
    throw error;
  }
  if (!hello.activationId) {
    const error = new Error('activationId is required.');
    error.status = 400;
    throw error;
  }
}

module.exports = {
  assertDesktopHelloAuth,
  isDesktopCompanionHello,
  normalizeDesktopHello,
};
