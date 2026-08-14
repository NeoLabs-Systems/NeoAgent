'use strict';

function createFakeMcpClient() {
  const statuses = new Map();
  return {
    getStatus() {
      return Object.fromEntries(statuses);
    },
    async startServer(id) {
      statuses.set(Number(id), { status: 'running', toolCount: 0 });
      return { status: 'running', tools: [] };
    },
    async stopServer(id) {
      statuses.set(Number(id), { status: 'stopped', toolCount: 0 });
      return { status: 'stopped' };
    },
    async listTools() {
      return [];
    },
    getAllTools() {
      return [];
    },
    async callTool() {
      return { content: [] };
    },
    async finishOAuth() {
      return { success: true };
    },
  };
}

function createFakeRuntimeManager() {
  return {
    validation: { ready: true, issues: [] },
    getComputerStatus() {
      return { state: 'stopped', backend: 'qemu', control: null };
    },
    hasVmForUser() {
      return false;
    },
    async isGuestAgentReadyForUser() {
      return false;
    },
    async executeCommand() {
      return { exitCode: 0, stdout: 'health_check_ok\n', stderr: '' };
    },
    async getBrowserProviderForUser() {
      throw new Error('Browser controller is unavailable in tests.');
    },
    async getAndroidProviderForUser() {
      return {
        async getStatus() {
          return { bootstrapped: false, canBootstrap: true, devices: [], runtimeReady: true };
        },
        async listDevices() {
          return [];
        },
      };
    },
  };
}

function createFakeTaskRuntime() {
  const byUser = new Map();
  let nextId = 1;
  function list(userId) {
    const key = String(userId);
    if (!byUser.has(key)) byUser.set(key, []);
    return byUser.get(key);
  }
  return {
    listTasks(userId) {
      return list(userId);
    },
    getTriggerCatalog() {
      return [{ type: 'manual', label: 'Manual' }];
    },
    async createTask(userId, input = {}) {
      const task = {
        id: nextId++,
        name: input.name || 'Test task',
        enabled: input.enabled !== false,
        agentId: input.agentId || null,
      };
      list(userId).push(task);
      return task;
    },
    async updateTask(taskId, userId, input = {}) {
      const task = list(userId).find((item) => Number(item.id) === Number(taskId));
      if (!task) throw new Error('Task not found');
      Object.assign(task, input);
      return task;
    },
    deleteTask(taskId, userId) {
      const tasks = list(userId);
      const index = tasks.findIndex((item) => Number(item.id) === Number(taskId));
      if (index === -1) throw new Error('Task not found');
      tasks.splice(index, 1);
      return { success: true };
    },
    runTaskNow(taskId) {
      return { success: true, taskId: Number(taskId) };
    },
  };
}

function createFakeMemoryIngestionService() {
  return {
    getStatus() {
      return { state: 'running' };
    },
    listConnectionStatuses() {
      return [];
    },
    async ingestDocuments(_userId, documents) {
      return {
        status: 'completed',
        documentIds: documents.map((_, index) => index + 1),
        memoryIds: documents.map((_, index) => index + 1),
      };
    },
  };
}

function createFakeAppLocals() {
  const runtimeManager = createFakeRuntimeManager();
  return {
    runtimeManager,
    mcpClient: createFakeMcpClient(),
    taskRuntime: createFakeTaskRuntime(),
    memoryIngestionService: createFakeMemoryIngestionService(),
    authProviderManager: {
      listProviders: () => [],
      listUserProviders: () => [],
      unlinkProvider: () => ({ success: true }),
    },
    integrationManager: {
      listProviders: () => [],
      getProviderConfig: () => null,
      setProviderConfig: () => ({ success: true }),
      deleteProviderConfig: () => ({ success: true }),
    },
    messagingManager: {
      getAllStatuses: () => ({}),
      getStatus: () => ({}),
      getPlatformStatus: () => ({ connected: false }),
      connectPlatform: async () => ({ success: true }),
      disconnectPlatform: async () => ({ success: true }),
      logoutPlatform: async () => ({ success: true }),
      connect: async () => ({ success: true }),
      disconnect: async () => ({ success: true }),
      logout: async () => ({ success: true }),
      sendMessage: async () => ({ success: true }),
      listMessages: () => [],
    },
    agentEngine: {
      async run(_userId, task) {
        return { status: 'completed', content: `Echo: ${task}`, runId: 'test-run', totalTokens: 0 };
      },
      abort() {},
      findSteerableRunForUser() {
        return null;
      },
      enqueueSteering() {
        return false;
      },
    },
    multiStep: {
      async planAndExecute() {
        return { status: 'completed', steps: [] };
      },
    },
    commandRouter: {
      async dispatch() {
        return { handled: false };
      },
    },
    voiceRuntimeManager: {},
    socialVideoService: {
      async getHealthStatus() {
        return { ready: true, dependencies: {} };
      },
      async extractFromUrl() {
        return { platform: 'unknown', transcript: '', metadata: {}, setup: {} };
      },
    },
    socialReachService: {
      async getStatus() {
        return { platforms: [], generatedAt: new Date(0).toISOString() };
      },
      async read() {
        return { platform: 'web', content: '' };
      },
      async search() {
        return { platform: 'web', results: [] };
      },
      async importCookiesFromExtension() {
        return { platform: 'xueqiu', configured: true, count: 1 };
      },
      clearCookies(platform) {
        return { platform, configured: false, count: 0 };
      },
    },
    artifactStore: {
      getArtifact() {
        return null;
      },
    },
    logger: console,
  };
}

module.exports = {
  createFakeAppLocals,
  createFakeMcpClient,
  createFakeRuntimeManager,
  createFakeTaskRuntime,
};
