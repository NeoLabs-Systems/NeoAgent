const { LocalVmExecutionBackend } = require('./backends/local-vm');
const { QemuVmManager } = require('./qemu');
const { getRuntimeSettings } = require('./settings');
const { ExtensionBrowserProvider } = require('../browser/extension/provider');

class RuntimeManager {
  constructor(options = {}) {
    this.browserExtensionRegistry = options.browserExtensionRegistry || null;
    this.vmBackend = new LocalVmExecutionBackend({
      vmManager: options.vmManager || new QemuVmManager(),
      artifactStore: options.artifactStore,
    });
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
    void requested;
    return this.vmBackend;
  }

  async executeCommand(userId, command, options = {}) {
    const backend = this.resolveBackend(userId, options.backend);
    return backend.executeCommand(userId, command, options);
  }

  async killCommand(userId, pid, reason = 'aborted') {
    return this.vmBackend.killCommand(userId, pid, reason);
  }

  async getCommandExecutorForUser(userId) {
    return this.vmBackend.getCommandExecutorForUser(userId);
  }

  async getBrowserProviderForUser(userId) {
    const settings = this.getSettings(userId);
    if (settings.browser_backend === 'extension' && this.hasActiveExtensionBrowser(userId)) {
      return this.getExtensionBrowserProvider(userId);
    }
    return this.vmBackend.getBrowserProviderForUser(userId);
  }

  async getAndroidProviderForUser(userId) {
    return this.vmBackend.getAndroidProviderForUser(userId);
  }

  async shutdown() {
    await Promise.allSettled([this.vmBackend.shutdown()]);
  }
}

module.exports = {
  RuntimeManager,
};
