class HostExecutionBackend {
  constructor(options = {}) {
    this.cliExecutor = options.cliExecutor || null;
    this.getBrowserProvider = options.getBrowserProvider;
    this.getAndroidProvider = options.getAndroidProvider;
  }

  async executeCommand(_userId, command, options = {}) {
    if (!this.cliExecutor) {
      throw new Error('Host CLI executor is not available.');
    }
    if (options.pty) {
      return this.cliExecutor.executeInteractive(command, options.inputs || [], options);
    }
    return this.cliExecutor.execute(command, options);
  }

  async getBrowserProviderForUser(userId) {
    if (typeof this.getBrowserProvider !== 'function') {
      throw new Error('Missing getBrowserProvider in Host execution backend.');
    }
    return this.getBrowserProvider(userId);
  }

  async getAndroidProviderForUser(userId) {
    if (typeof this.getAndroidProvider !== 'function') {
      throw new Error('Missing getAndroidProvider in Host execution backend.');
    }
    return this.getAndroidProvider(userId);
  }

  async shutdown() {}
}

module.exports = {
  HostExecutionBackend,
};
