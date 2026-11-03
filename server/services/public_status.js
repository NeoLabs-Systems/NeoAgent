'use strict';

const db = require('../db/database');
const { getRuntimeValidation } = require('./runtime/validation');

function component(group, name, status, description) {
  return { group, name, status, description };
}

function dbIsReachable() {
  try {
    db.prepare('SELECT 1 AS ok').get();
    return true;
  } catch {
    return false;
  }
}

function overallStatus(components) {
  if (components.some((item) => item.status === 'unavailable')) return 'unavailable';
  if (components.some((item) => item.status === 'degraded')) return 'degraded';
  return 'operational';
}

function buildPublicStatus(app) {
  const runtimeValidation = getRuntimeValidation(app?.locals?.runtimeManager);
  const runtimeReady = Boolean(runtimeValidation?.ready);
  const storageReady = dbIsReachable();
  const hasMessaging = Boolean(app?.locals?.messagingManager);
  const hasIntegrations = Boolean(app?.locals?.integrationManager);
  const hasMcp = Boolean(app?.locals?.mcpClient);
  const hasComputer = Boolean(app?.locals?.runtimeManager?.computerBackend);
  const hasMemory = Boolean(app?.locals?.memoryManager);
  const hasAi = Boolean(app?.locals?.agentEngine);

  const components = [
    component('Core', 'Web App & API', 'operational', 'The web server is responding to requests.'),
    component('Core', 'Accounts & Sessions', 'operational', 'Account routes are available; individual sign-ins are not tested.'),
    component(
      'Automation',
      'Agent Runtime',
      runtimeReady ? 'operational' : 'degraded',
      runtimeReady ? 'Runtime checks are passing.' : 'Runtime is reachable, but one or more host capabilities need attention.'
    ),
    component(
      'Automation',
      'AI Gateway',
      hasAi ? 'operational' : 'degraded',
      hasAi ? 'AI routing is ready. Provider connections are configured per deployment or user.' : 'The AI routing service is starting or unavailable.'
    ),
    component(
      'Devices',
      'Browser & Desktop Control',
      hasComputer ? 'operational' : 'degraded',
      hasComputer ? 'The unified cloud computer provider is ready.' : 'The cloud computer provider is not initialized.'
    ),
    component(
      'Communication',
      'Messaging Bridges',
      hasMessaging ? 'operational' : 'degraded',
      hasMessaging ? 'Messaging bridge manager is online.' : 'Messaging bridge manager is not initialized.'
    ),
    component(
      'Communication',
      'Integrations & OAuth',
      hasIntegrations && hasMcp ? 'operational' : 'degraded',
      hasIntegrations && hasMcp ? 'Integration and MCP services are available.' : 'Some integration plumbing is not initialized.'
    ),
    component(
      'Automation', 'Tasks & Scheduling',
      app?.locals?.taskRuntime ? 'operational' : 'degraded',
      app?.locals?.taskRuntime ? 'Task scheduling service is initialized.' : 'Task scheduling service is not initialized.'
    ),
    component(
      'Communication', 'Voice Runtime',
      app?.locals?.voiceRuntimeManager ? 'operational' : 'degraded',
      app?.locals?.voiceRuntimeManager ? 'Voice runtime is initialized.' : 'Voice runtime is not initialized.'
    ),
    component(
      'Data',
      'Storage & Memory',
      storageReady && hasMemory ? 'operational' : 'unavailable',
      storageReady && hasMemory ? 'Database and memory services are responding.' : 'Storage or memory services are not responding.'
    ),
  ];

  const status = overallStatus(components);
  return {
    product: 'NeoAgent',
    status,
    updatedAt: new Date().toISOString(),
    refreshAfterSeconds: 60,
    note: status === 'operational'
      ? 'All monitored services are operational.'
      : 'One or more monitored services need attention.',
    components,
  };
}

module.exports = {
  buildPublicStatus,
};
