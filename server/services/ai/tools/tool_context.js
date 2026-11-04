'use strict';

const { runFileDiagnostics } = require('../file_diagnostics');

function getRunState(engine, runId) {
  if (!runId) return null;
  return engine?.activeRuns?.get(runId) || null;
}

// What a tool handler can reach: the run's identity and lazily resolved services.
function createToolContext(toolName, context, engine, publicScope) {
  const {
    userId,
    agentId,
    runId,
    stepId,
    app,
    triggerSource,
    taskId,
    scheduledAt,
    allowMultipleProactiveMessages = false,
    signal = null,
    deviceTarget = null,
    workspaceRoot = null,
  } = context;
  const delivery = context.delivery || getRunState(engine, runId)?.delivery || null;
  const runtime = () => app?.locals?.runtimeManager || engine.runtimeManager || null;
  const bc = async () => {
    const manager = runtime();
    if (manager && typeof manager.getBrowserProviderForUser === 'function') {
      const backend = typeof manager.getActiveBrowserBackend === 'function'
        ? await Promise.resolve(manager.getActiveBrowserBackend(userId, { deviceTarget }))
        : 'vm';
      return {
        provider: await manager.getBrowserProviderForUser(userId, { signal, deviceTarget }),
        backend,
      };
    }
    throw new Error('Browser provider is unavailable. VM runtime is required.');
  };
  const ac = () => {
    const manager = runtime();
    if (manager && typeof manager.getAndroidProviderForUser === 'function') {
      return manager.getAndroidProviderForUser(userId);
    }
    throw new Error('Android provider is unavailable. VM runtime is required.');
  };
  const wc = () => app?.locals?.workspaceManager || engine.workspaceManager || null;
  const computerWorkspace = () => app?.locals?.computerWorkspaceManager || wc();
  const withFileDiagnostics = async (result, filePath) => {
    if (!result || result.success === false || result.error) return result;
    const runState = getRunState(engine, runId);
    if (runState && !runState.fileDiagnostics) runState.fileDiagnostics = {};
    const diagnostics = await runFileDiagnostics(runtime(), userId, filePath, {
      signal,
      deviceTarget,
      history: runState?.fileDiagnostics || null,
    });
    return diagnostics ? { ...result, diagnostics } : result;
  };
  const dc = () => {
    const scoped = app?.locals?.getDesktopProviderForUser;
    if (typeof scoped === 'function') {
      return scoped(userId, { deviceTarget });
    }
    return runtime()?.getDesktopProviderForUser?.(userId, { deviceTarget })
      || app?.locals?.desktopProvider
      || null;
  };
  const msg = () => app?.locals?.messagingManager || engine.messagingManager;
  const mcp = () => app?.locals?.mcpManager || app?.locals?.mcpClient || engine.mcpManager;
  const integrations = () => app?.locals?.integrationManager || null;
  const sk = () => app?.locals?.skillRunner || engine.skillRunner;
  const taskRuntime = () => app?.locals?.taskRuntime || engine.taskRuntime;
  const socialVideo = () => app?.locals?.socialVideoService || null;
  const socialReach = () => app?.locals?.socialReachService || null;
  const credentials = () => app?.locals?.credentialBroker || null;
  const artifactStore = app?.locals?.artifactStore || null;
  const agentCalls = () => app?.locals?.agentCallCoordinator || null;
  return {
    toolName,
    context,
    engine,
    publicScope,
    userId,
    agentId,
    runId,
    stepId,
    app,
    triggerSource,
    taskId,
    scheduledAt,
    delivery,
    allowMultipleProactiveMessages,
    signal,
    deviceTarget,
    workspaceRoot,
    runtime,
    bc,
    ac,
    wc,
    computerWorkspace,
    withFileDiagnostics,
    dc,
    msg,
    mcp,
    integrations,
    sk,
    taskRuntime,
    socialVideo,
    socialReach,
    credentials,
    artifactStore,
    agentCalls,
  };
}

module.exports = { createToolContext, getRunState };
