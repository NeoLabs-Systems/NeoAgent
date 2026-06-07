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

function createFakeWidgetService() {
  const byUser = new Map();
  let nextId = 1;
  function list(userId) {
    const key = String(userId);
    if (!byUser.has(key)) byUser.set(key, []);
    return byUser.get(key);
  }
  return {
    listLatestSnapshots() {
      return [];
    },
    listWidgets(userId) {
      return list(userId);
    },
    async createWidget(userId, input = {}) {
      const widget = {
        id: String(nextId++),
        name: input.name || 'Test widget',
        type: input.type || 'note',
        agentId: input.agentId || null,
      };
      list(userId).push(widget);
      return widget;
    },
    async updateWidget(userId, id, input = {}) {
      const widget = this.getWidget(userId, id);
      if (!widget) throw new Error('Widget not found');
      Object.assign(widget, input);
      return widget;
    },
    deleteWidget(userId, id) {
      const widgets = list(userId);
      const index = widgets.findIndex((item) => item.id === String(id));
      if (index === -1) throw new Error('Widget not found');
      widgets.splice(index, 1);
      return { success: true };
    },
    getWidget(userId, id) {
      return list(userId).find((item) => item.id === String(id)) || null;
    },
    async refreshWidget(userId, id) {
      return this.getWidget(userId, id);
    },
  };
}

function createFakeDesktopRegistry() {
  return {
    getStatus() {
      return { connected: false, onlineCount: 0, devices: [] };
    },
    getSelectedDeviceId() {
      return null;
    },
  };
}

function createFakeDesktopProvider(registry = createFakeDesktopRegistry()) {
  return {
    registry,
    getStatus: () => registry.getStatus(),
    listDevices: () => [],
    selectDevice: (deviceId) => ({ selectedDeviceId: deviceId }),
    screenshot: () => ({ imageBase64: '', mimeType: 'image/png' }),
    observe: () => ({ observations: [] }),
    clickPoint: () => ({ success: true }),
    mouseMove: () => ({ success: true }),
    drag: () => ({ success: true }),
    scroll: () => ({ success: true }),
    typeText: () => ({ success: true }),
    pressKey: () => ({ success: true }),
    launchApp: () => ({ success: true }),
    getDisplays: () => [],
    selectDisplay: () => ({ success: true }),
    revokeDevice: () => ({ success: true }),
    pauseDevice: () => ({ success: true }),
    getTree: () => ({ tree: null }),
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
  const desktopRegistry = createFakeDesktopRegistry();
  return {
    runtimeManager,
    mcpClient: createFakeMcpClient(),
    taskRuntime: createFakeTaskRuntime(),
    widgetService: createFakeWidgetService(),
    memoryIngestionService: createFakeMemoryIngestionService(),
    browserExtensionRegistry: {
      getStatus: () => ({ connected: false, onlineCount: 0, devices: [] }),
    },
    desktopCompanionRegistry: desktopRegistry,
    desktopProvider: createFakeDesktopProvider(desktopRegistry),
    getDesktopProviderForUser: () => createFakeDesktopProvider(desktopRegistry),
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
  createFakeDesktopProvider,
  createFakeMcpClient,
  createFakeRuntimeManager,
  createFakeTaskRuntime,
  createFakeWidgetService,
};
