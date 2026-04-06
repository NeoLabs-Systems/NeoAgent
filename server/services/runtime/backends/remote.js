const { RuntimeHttpClient, VmAndroidProvider, VmBrowserProvider } = require('./local-vm');

class RemoteWorkerExecutionBackend {
  constructor(options = {}) {
    this.getBaseUrl = options.getBaseUrl;
    this.getToken = options.getToken;
    this.artifactStore = options.artifactStore || null;
  }

  async #clientForUser(userId) {
    const baseUrl = this.getBaseUrl(userId);
    if (!baseUrl) {
      throw new Error('Remote worker backend is not configured for this user.');
    }
    const client = new RuntimeHttpClient(baseUrl, this.getToken(userId));
    await client.waitForHealth({
      timeoutMs: Number(process.env.NEOAGENT_REMOTE_WORKER_TIMEOUT_MS || 30000),
      intervalMs: 1000,
    });
    return client;
  }

  async executeCommand(userId, command, options = {}) {
    return (await this.#clientForUser(userId)).request('POST', '/exec', {
      command,
      cwd: options.cwd,
      timeout: options.timeout,
      stdin_input: options.stdinInput,
      pty: options.pty === true,
      inputs: options.inputs || [],
    });
  }

  async getBrowserProviderForUser(userId) {
    return new VmBrowserProvider(await this.#clientForUser(userId), {
      userId,
      artifactStore: this.artifactStore,
    });
  }

  async getAndroidProviderForUser(userId) {
    return new VmAndroidProvider(await this.#clientForUser(userId), {
      userId,
      artifactStore: this.artifactStore,
    });
  }

  async shutdown() {}
}

module.exports = {
  RemoteWorkerExecutionBackend,
};
