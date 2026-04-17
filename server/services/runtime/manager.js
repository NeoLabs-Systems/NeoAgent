const { HostExecutionBackend } = require('./backends/host');
const { LocalVmExecutionBackend } = require('./backends/local-vm');
const { QemuVmManager } = require('./qemu');
const { deriveCloudBrowserBackend, getRuntimeSettings } = require('./settings');
const { ExtensionBrowserProvider } = require('../browser/extension/provider');

class RuntimeManager {
  constructor(options = {}) {
    this.browserExtensionRegistry = options.browserExtensionRegistry || null;
    this.hostBackend = new HostExecutionBackend({
      cliExecutor: options.cliExecutor,
      getBrowserProvider: options.getHostBrowserProvider,
      getAndroidProvider: options.getHostAndroidProvider,
    });
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
    const settings = this.getSettings(userId);
    const effective = requested || settings.runtime_backend;
    if (effective === 'vm') return this.vmBackend;
    return this.hostBackend;
  }

  async executeCommand(userId, command, options = {}) {
    const backend = this.resolveBackend(userId, options.backend);
    return backend.executeCommand(userId, command, options);
  }

  async getBrowserProviderForUser(userId) {
    const settings = this.getSettings(userId);
    if (settings.browser_backend === 'extension' && this.hasActiveExtensionBrowser(userId)) {
      return this.getExtensionBrowserProvider(userId);
    }
    const browserBackend = settings.browser_backend === 'extension'
      ? deriveCloudBrowserBackend(settings)
      : settings.browser_backend;
    const backend = this.resolveBackend(userId, browserBackend === 'host' ? 'host' : browserBackend);
    return backend.getBrowserProviderForUser(userId);
  }

  async getAndroidProviderForUser(userId) {
    const settings = this.getSettings(userId);
    const backend = this.resolveBackend(userId, settings.android_backend);
    return backend.getAndroidProviderForUser(userId);
  }

  async shutdown() {
    await Promise.allSettled([
      this.hostBackend.shutdown(),
      this.vmBackend.shutdown(),
    ]);
  }
}

module.exports = {
  RuntimeManager,
};
