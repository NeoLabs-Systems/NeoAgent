'use strict';

const { LocalVmExecutionBackend } = require('./backends/local-vm');
const { DockerVMManager } = require('./docker-vm-manager');
const { getRuntimeSettings } = require('./settings');
const { ExtensionBrowserProvider } = require('../browser/extension/provider');
const { AndroidController } = require('../android/controller');

// Resource defaults for Docker VMs (overridable via env).
const DEFAULT_VM_MEMORY_MB = Number(process.env.NEOAGENT_VM_MEMORY_MB ?? 2048);
const DEFAULT_VM_CPUS = Number(process.env.NEOAGENT_VM_CPUS ?? 2);

class RuntimeManager {
  constructor(options = {}) {
    this.browserExtensionRegistry = options.browserExtensionRegistry || null;

    const browserVmManager = options.browserVmManager || new DockerVMManager({
      runtimeProfile: 'browser_cli',
      image: 'mcr.microsoft.com/playwright:v1.44.0-focal',
      memoryMb: DEFAULT_VM_MEMORY_MB,
      cpus: DEFAULT_VM_CPUS,
    });
    this.browserBackend = new LocalVmExecutionBackend({
      runtimeProfile: 'browser_cli',
      vmManager: browserVmManager,
      artifactStore: options.artifactStore,
    });

    this.artifactStore = options.artifactStore || null;

    this.getExtensionBrowserProvider = options.getExtensionBrowserProvider
      || ((userId) => new ExtensionBrowserProvider({
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
    return this.browserBackend;
  }

  async executeCommand(userId, command, options = {}) {
    const backend = this.resolveBackend(userId, 'browser_cli');
    return backend.executeCommand(userId, command, options);
  }

  hasVmForUser(userId, capability = 'browser') {
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
    if (userId == null || String(userId).trim() === '') {
      throw new Error('Android provider requires a user ID.');
    }
    return new AndroidController({
      userId: String(userId).trim(),
      artifactStore: this.artifactStore,
    });
  }

  async isGuestAgentReadyForUser(userId, timeoutMs = 1000, capability = 'browser') {
    if (typeof this.browserBackend?.isGuestAgentReadyForUser !== 'function') {
      return false;
    }
    return this.browserBackend.isGuestAgentReadyForUser(userId, timeoutMs);
  }

  async shutdown() {
    await Promise.allSettled([
      this.browserBackend?.shutdown?.(),
    ]);
  }
}

module.exports = {
  RuntimeManager,
};
