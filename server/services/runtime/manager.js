const { HostExecutionBackend } = require('./backends/host');
const { LocalVmExecutionBackend } = require('./backends/local-vm');
const { RemoteWorkerExecutionBackend } = require('./backends/remote');
const { QemuVmManager } = require('./qemu');
const { getRuntimeSettings } = require('./settings');

class UnsupportedExtensionBrowserProvider {
  constructor() {
    this.headless = false;
  }

  #unsupported() {
    return { error: 'Browser extension backend is planned but not implemented yet.' };
  }

  navigate() { return this.#unsupported(); }
  click() { return this.#unsupported(); }
  clickPoint() { return this.#unsupported(); }
  type() { return this.#unsupported(); }
  typeText() { return this.#unsupported(); }
  pressKey() { return this.#unsupported(); }
  scroll() { return this.#unsupported(); }
  extract() { return this.#unsupported(); }
  evaluate() { return this.#unsupported(); }
  screenshot() { return this.#unsupported(); }
  launch() { return this.#unsupported(); }
  closeBrowser() { return Promise.resolve({ success: true }); }
  fill() { return this.#unsupported(); }
  extractContent() { return this.#unsupported(); }
  executeJS() { return this.#unsupported(); }
  getPageInfo() { return Promise.resolve({ url: null, title: null, unsupported: true }); }
  isLaunched() { return false; }
  getPageCount() { return 0; }
  setHeadless() { return Promise.resolve({ success: false, unsupported: true }); }
}

class RuntimeManager {
  constructor(options = {}) {
    this.hostBackend = new HostExecutionBackend({
      cliExecutor: options.cliExecutor,
      getBrowserProvider: options.getHostBrowserProvider,
      getAndroidProvider: options.getHostAndroidProvider,
    });
    this.vmBackend = new LocalVmExecutionBackend({
      vmManager: options.vmManager || new QemuVmManager(),
      artifactStore: options.artifactStore,
    });
    this.remoteBackend = new RemoteWorkerExecutionBackend({
      getBaseUrl: (userId) => getRuntimeSettings(userId).remote_worker_base_url,
      getToken: (userId) => getRuntimeSettings(userId).remote_worker_token,
      artifactStore: options.artifactStore,
    });
  }

  getSettings(userId) {
    return getRuntimeSettings(userId);
  }

  resolveBackend(userId, requested) {
    const settings = this.getSettings(userId);
    const effective = requested || settings.runtime_backend;
    if (effective === 'vm') return this.vmBackend;
    if (effective === 'remote') return this.remoteBackend;
    return this.hostBackend;
  }

  async executeCommand(userId, command, options = {}) {
    const backend = this.resolveBackend(userId, options.backend);
    return backend.executeCommand(userId, command, options);
  }

  async getBrowserProviderForUser(userId) {
    const settings = this.getSettings(userId);
    if (settings.browser_backend === 'extension') {
      return new UnsupportedExtensionBrowserProvider();
    }
    const backend = this.resolveBackend(userId, settings.browser_backend === 'host' ? 'host' : settings.browser_backend);
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
      this.remoteBackend.shutdown(),
    ]);
  }
}

module.exports = {
  RuntimeManager,
};
