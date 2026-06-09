'use strict';

const { LocalVmExecutionBackend } = require('./backends/local-vm');
const { DockerVMManager } = require('./docker-vm-manager');
const { getRuntimeSettings } = require('./settings');
const { ExtensionBrowserProvider } = require('../browser/extension/provider');
const { AndroidController } = require('../android/controller');
const { DesktopProvider } = require('../desktop/provider');

// Resource defaults for Docker VMs (overridable via env).
const DEFAULT_VM_MEMORY_MB = Number(process.env.NEOAGENT_VM_MEMORY_MB ?? 2048);
const DEFAULT_VM_CPUS = Number(process.env.NEOAGENT_VM_CPUS ?? 2);

class RuntimeManager {
  constructor(options = {}) {
    this.browserExtensionRegistry = options.browserExtensionRegistry || null;
    this.desktopCompanionRegistry = options.desktopCompanionRegistry || null;

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
      || ((userId, providerOptions = {}) => new ExtensionBrowserProvider({
        registry: options.browserExtensionRegistry,
        artifactStore: options.artifactStore,
        userId,
        tokenId: providerOptions.tokenId || null,
      }));

    this.getDesktopCliProvider = options.getDesktopCliProvider
      || ((userId) => new DesktopProvider({
        registry: options.desktopCompanionRegistry,
        artifactStore: options.artifactStore,
        userId,
      }));
  }


  getSettings(userId) {
    return getRuntimeSettings(userId);
  }

  hasActiveExtensionBrowser(userId) {
    const settings = this.getSettings(userId);
    return Boolean(
      this.browserExtensionRegistry
      && typeof this.browserExtensionRegistry.isConnected === 'function'
      && this.browserExtensionRegistry.isConnected(userId, settings.browser_extension_token_id)
    );
  }

  hasActiveDesktopCompanion(userId) {
    return Boolean(
      this.desktopCompanionRegistry
      && typeof this.desktopCompanionRegistry.isConnected === 'function'
      && this.desktopCompanionRegistry.isConnected(userId)
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
      return this.getExtensionBrowserProvider(userId, {
        tokenId: settings.browser_extension_token_id,
      });
    }
    return this.browserBackend.getBrowserProviderForUser(userId);
  }

  async getCliProviderForUser(userId) {
    const settings = this.getSettings(userId);
    if (settings.cli_backend === 'desktop' && this.hasActiveDesktopCompanion(userId)) {
      const desktopProvider = this.getDesktopCliProvider(userId);
      const preferredDeviceId = settings.cli_desktop_device_id;
      if (preferredDeviceId) {
        desktopProvider.selectDevice(preferredDeviceId);
      }
      return {
        backend: 'desktop-companion',
        execute: (command, options = {}) => desktopProvider.executeCommand(command, options),
        executeInteractive: (command, inputs = [], options = {}) => desktopProvider.executeCommand(command, { ...options, inputs }),
        kill: () => Promise.resolve(false),
      };
    }
    const executor = await this.browserBackend.getCommandExecutorForUser(userId);
    return { ...executor, backend: 'vm' };
  }

  async executeCliCommand(userId, command, options = {}) {
    const provider = await this.getCliProviderForUser(userId);
    const result = await (options.pty === true && provider.executeInteractive
      ? provider.executeInteractive(command, options.inputs || [], options)
      : provider.execute(command, options));
    return { ...result, backend: provider.backend };
  }

  getActiveBrowserBackend(userId) {
    const settings = this.getSettings(userId);
    if (settings.browser_backend === 'extension' && this.hasActiveExtensionBrowser(userId)) {
      return 'extension';
    }
    return 'vm';
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
