'use strict';

const db = require('../db/database');
const { getRuntimeValidation } = require('./runtime/validation');

function hasAnyAiProviderEnv() {
  const hasStandardProvider = [
    'OPENAI_API_KEY',
    'ANTHROPIC_API_KEY',
    'GOOGLE_API_KEY',
    'GEMINI_API_KEY',
    'OPENROUTER_API_KEY',
  ].some((name) => Boolean(String(process.env[name] || '').trim()));
  const hasCustomOpenAIProvider = Boolean(
    String(process.env.OPENAI_COMPATIBLE_API_KEY || '').trim()
    && String(process.env.OPENAI_COMPATIBLE_BASE_URL || '').trim(),
  );
  return hasStandardProvider || hasCustomOpenAIProvider;
}

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
  const hasAi = hasAnyAiProviderEnv();

  const components = [
    component('Core', 'Web App & API', 'operational', 'Requests are being served normally. Tiny victory parade withheld for focus.'),
    component('Core', 'Accounts & Sessions', 'operational', 'Sign-in and session plumbing are available.'),
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
      hasAi ? 'AI provider routing is configured.' : 'AI routing is available, but no public provider configuration is detected.'
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
      ? 'All systems are behaving. Suspiciously mature of them.'
      : 'A few systems want a moment. We are listening politely.',
    components,
  };
}

module.exports = {
  buildPublicStatus,
};
