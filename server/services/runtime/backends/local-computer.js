'use strict';

const { DesktopProvider } = require('../../desktop/provider');
const {
  DESKTOP_COMMANDS,
  DesktopCompanionUnavailableError,
} = require('../../desktop/protocol');

function parsePathname(value) {
  return new URL(String(value || '/'), 'http://local.neoagent');
}

function normalizeWorkspacePath(value, fallback = '') {
  const normalized = String(value ?? fallback).trim().replace(/\\/g, '/');
  if (normalized === '/home/neo/workspace') return '';
  if (normalized.startsWith('/home/neo/workspace/')) {
    return normalized.slice('/home/neo/workspace/'.length);
  }
  return normalized || fallback;
}

function normalizeWorkspaceRoot(value) {
  const trimmed = String(value ?? '').trim();
  return trimmed || null;
}

class LocalComputerBrowserProvider {
  constructor(backend, userId, options = {}) {
    this.backend = backend;
    this.userId = userId;
    this.desktop = backend.getDesktopProviderForUser(userId);
    this.headless = false;
    this.lastUrl = null;
    this.signal = options.signal || null;
  }

  async launch() {
    await this.backend.assertConnected(this.userId);
    return { success: true, launched: true, local: true };
  }

  async closeBrowser() {
    return { success: true, launched: true, local: true };
  }

  async navigate(url, options = {}) {
    const result = await this.backend.dispatch(
      this.userId,
      DESKTOP_COMMANDS.OPEN_URI,
      { uri: url },
      options,
    );
    this.lastUrl = String(url);
    return { ...result, url: this.lastUrl, local: true };
  }

  click(_selector, _text, _screenshot = true, options = {}) {
    const error = new Error('Semantic selectors are unavailable on the local desktop. Observe the screen and use coordinate control.');
    error.code = 'LOCAL_BROWSER_SEMANTIC_CONTROL_UNAVAILABLE';
    error.recoverable = true;
    error.options = options;
    throw error;
  }

  extract() {
    const error = new Error('DOM extraction is unavailable on the local desktop. Use screen observation or the shell.');
    error.code = 'LOCAL_BROWSER_DOM_UNAVAILABLE';
    error.recoverable = true;
    throw error;
  }

  evaluate() {
    const error = new Error('Browser JavaScript execution is unavailable on the local desktop. Use visible desktop control.');
    error.code = 'LOCAL_BROWSER_DOM_UNAVAILABLE';
    error.recoverable = true;
    throw error;
  }

  clickPoint(x, y, _screenshot = true, options = {}) {
    return this.desktop.clickPoint(x, y, options);
  }

  type(_selector, text, options = {}) {
    return this.desktop.typeText(text, options);
  }

  fill(selector, value, options = {}) {
    return this.type(selector, value, options);
  }

  executeJS(code, options = {}) {
    return this.evaluate(code, options);
  }

  extractContent(options = {}) {
    return this.extract(undefined, undefined, false, options);
  }

  typeText(text, options = {}) {
    return this.desktop.typeText(text, options);
  }

  pressKey(key, _screenshot = true, options = {}) {
    return this.desktop.pressKey(key, options);
  }

  scroll(deltaX, deltaY, _screenshot = true, options = {}) {
    return this.desktop.scroll({ deltaX, deltaY, ...options });
  }

  screenshot(options = {}) {
    return this.desktop.screenshot(options);
  }

  async screenshotJpeg(_quality = 80, options = {}) {
    const result = await this.desktop.screenshot(options);
    if (!result?.fullPath) throw new Error('Local computer screenshot is unavailable.');
    return require('fs').readFileSync(result.fullPath);
  }

  async isLaunched() {
    return this.backend.isConnected(this.userId);
  }

  async getPageCount() {
    return this.backend.isConnected(this.userId) ? 1 : 0;
  }

  async getPageInfo() {
    const status = await this.desktop.getStatus();
    const selected = status.devices?.find((device) => device.deviceId === status.selectedDeviceId);
    return {
      url: this.lastUrl,
      title: selected?.metadata?.frontmostWindowTitle || selected?.label || 'Local computer',
      local: true,
    };
  }

  async getCookies() { return []; }
  async setHeadless() { return { success: true }; }
}

class LocalComputerBackend {
  constructor(options = {}) {
    this.registry = options.registry;
    this.artifactStore = options.artifactStore || null;
    this.vmManager = {
      instances: new Map(),
      getStatus: (userId) => this.getStatus(userId),
      hasVm: (userId) => this.isConnected(userId),
      hasTrackedVm: (userId) => this.isConnected(userId),
      killVm: (userId) => this.pause(userId, true),
      sleepVm: (userId) => this.pause(userId, true),
      shutdown: async () => {},
    };
  }

  isConnected(userId) {
    return Boolean(this.registry?.isConnected(userId));
  }

  getStatus(userId) {
    const connection = this.registry?.getStatus(userId) || {
      connected: false,
      selectedDeviceId: null,
      devices: [],
    };
    const selected = connection.devices?.find(
      (device) => device.deviceId === connection.selectedDeviceId,
    ) || connection.devices?.find((device) => device.online);
    const appApprovals = selected?.permissions?.appApprovals || {};
    return {
      state: !connection.connected || selected?.paused ? 'stopped' : 'ready',
      provider: 'local',
      local: true,
      connected: connection.connected === true,
      selectedDeviceId: connection.selectedDeviceId || null,
      device: selected || null,
      permissions: selected?.permissions || {},
      appApprovals,
      pendingPermission: selected?.metadata?.pendingPermission || null,
      capabilities: ['desktop', 'browser', 'shell', 'files'],
    };
  }

  async assertConnected(userId) {
    if (!this.isConnected(userId)) {
      const error = new DesktopCompanionUnavailableError(
        'Open the NeoAgent desktop app and enable “This device”.',
      );
      error.status = 409;
      throw error;
    }
    return this.getStatus(userId);
  }

  dispatch(userId, command, payload = {}, options = {}) {
    return this.registry.dispatch(userId, null, command, payload, options);
  }

  async pause(userId, paused) {
    if (!this.isConnected(userId)) return this.getStatus(userId);
    const status = this.registry.getStatus(userId);
    if (status.selectedDeviceId) {
      await this.registry.pause(userId, status.selectedDeviceId, paused);
    }
    return this.getStatus(userId);
  }

  async getClientForUser(userId) {
    await this.assertConnected(userId);
    return {
      request: (method, pathname, body, options = {}) =>
        this.requestGuest(userId, method, pathname, body, options),
    };
  }

  async requestGuest(userId, method, pathname, body, options = {}) {
    await this.assertConnected(userId);
    const url = parsePathname(pathname);
    const normalizedMethod = String(method || 'GET').toUpperCase();
    const payload = body && typeof body === 'object' ? body : {};
    if (url.pathname === '/health') return { status: 'ok', provider: 'local' };
    const workspaceRoot = normalizeWorkspaceRoot(options.workspaceRoot);
    if (url.pathname === '/workspace/files' && normalizedMethod === 'GET') {
      return this.dispatch(userId, DESKTOP_COMMANDS.LIST_FILES, {
        path: normalizeWorkspacePath(url.searchParams.get('path'), '.'),
        workspaceRoot,
      }, options);
    }
    if (url.pathname === '/workspace/files/content' && normalizedMethod === 'GET') {
      return this.dispatch(userId, DESKTOP_COMMANDS.READ_FILE, {
        path: normalizeWorkspacePath(url.searchParams.get('path')),
        workspaceRoot,
      }, options);
    }
    if (url.pathname === '/workspace/files/content' && normalizedMethod === 'PUT') {
      return this.dispatch(userId, DESKTOP_COMMANDS.WRITE_FILE, {
        path: normalizeWorkspacePath(payload.path),
        content: payload.content,
        workspaceRoot,
      }, options);
    }
    if (url.pathname === '/workspace/files/download' && normalizedMethod === 'GET') {
      return this.dispatch(userId, DESKTOP_COMMANDS.READ_FILE, {
        path: normalizeWorkspacePath(url.searchParams.get('path')),
        encoding: 'base64',
        workspaceRoot,
      }, options);
    }
    if (url.pathname === '/workspace/search' && normalizedMethod === 'POST') {
      return this.dispatch(userId, DESKTOP_COMMANDS.SEARCH_FILES, {
        ...payload,
        path: normalizeWorkspacePath(payload.path, '.'),
        workspaceRoot,
      }, options);
    }
    throw Object.assign(new Error(`Unsupported local computer request: ${normalizedMethod} ${url.pathname}`), {
      code: 'LOCAL_COMPUTER_REQUEST_UNSUPPORTED',
      status: 400,
    });
  }

  executeCommand(userId, command, options = {}) {
    return this.getDesktopProviderForUser(userId).executeCommand(command, {
      ...options,
      cwd: options.cwd === '/home/neo/workspace' ? '__neoagent_workspace__' : options.cwd,
    });
  }

  async killCommand(userId, pid) {
    return this.dispatch(userId, DESKTOP_COMMANDS.CANCEL_COMMAND, { commandId: pid });
  }

  getCommandExecutorForUser(userId) {
    return {
      execute: (command, options = {}) => this.executeCommand(userId, command, options),
      executeInteractive: (command, inputs = [], options = {}) => this.executeCommand(
        userId,
        command,
        { ...options, inputs, pty: true },
      ),
      kill: (pid) => this.killCommand(userId, pid),
    };
  }

  getBrowserProviderForUser(userId, options = {}) {
    return Promise.resolve(new LocalComputerBrowserProvider(this, userId, options));
  }

  getDesktopProviderForUser(userId) {
    return new DesktopProvider({
      registry: this.registry,
      userId,
      artifactStore: this.artifactStore,
    });
  }

  touchActivity() {}
  async importWorkspaceArchive() { return { skipped: true, provider: 'local' }; }
  async isGuestAgentReadyForUser(userId) { return this.isConnected(userId); }
  async shutdown() {}
}

module.exports = {
  LocalComputerBackend,
  LocalComputerBrowserProvider,
  normalizeWorkspacePath,
};
