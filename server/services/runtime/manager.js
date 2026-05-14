const { LocalVmExecutionBackend } = require('./backends/local-vm');
const { QemuVmManager } = require('./qemu');
const { getRuntimeSettings } = require('./settings');
const { ExtensionBrowserProvider } = require('../browser/extension/provider');
const { AndroidController } = require('../android/controller');

class RuntimeManager {
  constructor(options = {}) {
    this.browserExtensionRegistry = options.browserExtensionRegistry || null;
    const browserVmManager = options.browserVmManager || new QemuVmManager({
      runtimeProfile: 'browser_cli',
      memoryMb: 2048,
      cpus: 2,
      warmup: false,
    });
    this.browserBackend = new LocalVmExecutionBackend({
      runtimeProfile: 'browser_cli',
      vmManager: browserVmManager,
      artifactStore: options.artifactStore,
    });
    this.androidControllers = new Map();
    this.getExtensionBrowserProvider = options.getExtensionBrowserProvider || ((userId) => new ExtensionBrowserProvider({
      registry: options.browserExtensionRegistry,
      artifactStore: options.artifactStore,
      userId,
    }));
  }

  getSettings(userId) {
    return getRuntimeSettings(userId);
  }

  hasActiveExtensionBrowser(userId) {
    return Boolean(
      this.browserExtensionRegistry
      && typeof this.browserExtensionRegistry.isConnected === 'function'
      && this.browserExtensionRegistry.isConnected(userId)
    );
  }

  resolveBackend(userId, requested) {
    void userId;
    return this.browserBackend;
  }

  async executeCommand(userId, command, options = {}) {
    const backend = this.resolveBackend(userId, 'browser_cli');
    return backend.executeCommand(userId, command, options);
  }

  hasVmForUser(userId, capability = 'browser') {
    if (capability === 'android') {
      return Boolean(this.androidControllers.get(String(userId || '').trim()));
    }
    return Boolean(this.browserBackend?.vmManager?.hasVm?.(userId));
  }

  async killCommand(userId, pid, reason = 'aborted') {
    return this.browserBackend.killCommand(userId, pid, reason);
  }

  async getCommandExecutorForUser(userId) {
    return this.browserBackend.getCommandExecutorForUser(userId);
  }

  async getBrowserProviderForUser(userId) {
    const settings = this.getSettings(userId);
    if (settings.browser_backend === 'extension' && this.hasActiveExtensionBrowser(userId)) {
      return this.getExtensionBrowserProvider(userId);
    }
    return this.browserBackend.getBrowserProviderForUser(userId);
  }

  async getAndroidProviderForUser(userId) {
    const key = String(userId || '').trim();
    if (!key) {
      throw new Error('Android provider requires a user ID.');
    }
    if (!this.androidControllers.has(key)) {
      this.androidControllers.set(key, new AndroidController({
        userId: key,
        runtimeBackend: 'host',
        artifactStore: null,
      }));
    }
    return this.androidControllers.get(key);
  }

  async isGuestAgentReadyForUser(userId, timeoutMs = 1000, capability = 'browser') {
    if (capability === 'android') {
      const controller = this.androidControllers.get(String(userId || '').trim());
      if (!controller || typeof controller.getStatus !== 'function') {
        return false;
      }
      try {
        const status = await controller.getStatus();
        return Boolean(status?.bootstrapped || status?.serial || status?.starting);
      } catch {
        return false;
      }
    }
    if (typeof this.browserBackend?.isGuestAgentReadyForUser !== 'function') {
      return false;
    }
    return this.browserBackend.isGuestAgentReadyForUser(userId, timeoutMs);
  }

  async shutdown() {
    await Promise.allSettled([
      this.browserBackend?.shutdown?.(),
      ...[...this.androidControllers.values()].map((controller) => controller?.stopEmulator?.().catch?.(() => {})),
    ]);
    this.androidControllers.clear();
  }
}

module.exports = {
  RuntimeManager,
};
