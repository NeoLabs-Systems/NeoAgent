'use strict';

const { decryptValue } = require('../secrets');
const { homeAssistantRequest, normalizeHomeAssistantBaseUrl, requireText, trimText } = require('./network');

async function fetchHomeAssistantConfig(credentials) {
  return homeAssistantRequest(credentials, { method: 'GET', path: '/api/config' });
}

function parseCredentials(connection) {
  try {
    return JSON.parse(decryptValue(connection?.credentials_json || '{}') || '{}');
  } catch {
    return {};
  }
}

function connectionCredentials(connection) {
  const credentials = parseCredentials(connection);
  return {
    baseUrl: normalizeHomeAssistantBaseUrl(credentials.baseUrl),
    token: requireText(credentials.token, 'Home Assistant token'),
  };
}

function filterStates(states, args = {}) {
  const domain = trimText(args.entity_domain).toLowerCase();
  const limit = Math.max(1, Math.min(Number(args.limit) || 100, 500));
  const filtered = Array.isArray(states)
    ? states.filter((state) => !domain || String(state?.entity_id || '').toLowerCase().startsWith(`${domain}.`))
    : [];
  return filtered.slice(0, limit).map((state) => ({
    entity_id: state.entity_id || null,
    state: state.state || null,
    attributes: state.attributes || {},
    last_changed: state.last_changed || null,
    last_updated: state.last_updated || null,
  }));
}

function validateServiceSegment(value, label) {
  const text = requireText(value, label).toLowerCase();
  if (!/^[a-z0-9_]+$/.test(text)) {
    throw new Error(`${label} must contain only lowercase letters, numbers, and underscores.`);
  }
  return text;
}

async function executeHomeAssistantTool(toolName, args, connection) {
  const credentials = connectionCredentials(connection);

  switch (toolName) {
    case 'home_assistant_get_config':
      return { result: await fetchHomeAssistantConfig(credentials) };
    case 'home_assistant_list_states':
      return {
        result: filterStates(
          await homeAssistantRequest(credentials, { method: 'GET', path: '/api/states' }),
          args,
        ),
      };
    case 'home_assistant_get_state':
      return {
        result: await homeAssistantRequest(credentials, {
          method: 'GET',
          path: `/api/states/${encodeURIComponent(requireText(args.entity_id, 'entity_id'))}`,
        }),
      };
    case 'home_assistant_call_service': {
      const domain = validateServiceSegment(args.domain, 'domain');
      const service = validateServiceSegment(args.service, 'service');
      const serviceData = args.service_data && typeof args.service_data === 'object' && !Array.isArray(args.service_data)
        ? args.service_data
        : {};
      return {
        result: await homeAssistantRequest(credentials, {
          method: 'POST',
          path: `/api/services/${domain}/${service}`,
          body: serviceData,
        }),
      };
    }
    case 'home_assistant_api_request':
      return {
        result: await homeAssistantRequest(credentials, {
          method: args.method,
          path: requireText(args.path, 'path'),
          query: args.query && typeof args.query === 'object' ? args.query : {},
          body: args.body && typeof args.body === 'object' ? args.body : undefined,
        }),
      };
    default:
      return null;
  }
}

module.exports = {
  executeHomeAssistantTool,
  fetchHomeAssistantConfig,
  parseCredentials,
};
