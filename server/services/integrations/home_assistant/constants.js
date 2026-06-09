'use strict';

const HOME_ASSISTANT_PROVIDER_KEY = 'home_assistant';

const HOME_ASSISTANT_APP = {
  id: 'home_assistant',
  label: 'Home Assistant',
  description: 'Connect one Home Assistant instance for states and service calls.',
};

const HOME_ASSISTANT_TOOL_DEFINITIONS = [
  {
    appId: HOME_ASSISTANT_APP.id,
    name: 'home_assistant_get_config',
    access: 'read',
    description: 'Get basic configuration for the connected Home Assistant instance.',
    parameters: { type: 'object', properties: {} },
  },
  {
    appId: HOME_ASSISTANT_APP.id,
    name: 'home_assistant_list_states',
    access: 'read',
    description: 'List Home Assistant entity states. Use entity_domain to narrow results such as light, sensor, switch, climate, or automation.',
    parameters: {
      type: 'object',
      properties: {
        entity_domain: {
          type: 'string',
          description: 'Optional entity domain prefix before the dot, for example light or sensor.',
        },
        limit: { type: 'number', description: 'Maximum number of states to return, default 100.' },
      },
    },
  },
  {
    appId: HOME_ASSISTANT_APP.id,
    name: 'home_assistant_get_state',
    access: 'read',
    description: 'Get one Home Assistant entity state by entity_id.',
    parameters: {
      type: 'object',
      properties: {
        entity_id: { type: 'string', description: 'Home Assistant entity ID, for example light.kitchen.' },
      },
      required: ['entity_id'],
    },
  },
  {
    appId: HOME_ASSISTANT_APP.id,
    name: 'home_assistant_call_service',
    access: 'write',
    description: 'Call a Home Assistant service such as light.turn_on or script.turn_on.',
    parameters: {
      type: 'object',
      properties: {
        domain: { type: 'string', description: 'Service domain, for example light, switch, climate, script, or automation.' },
        service: { type: 'string', description: 'Service name, for example turn_on, turn_off, toggle, set_temperature, or reload.' },
        service_data: { type: 'object', description: 'Optional Home Assistant service payload.' },
      },
      required: ['domain', 'service'],
    },
  },
  {
    appId: HOME_ASSISTANT_APP.id,
    name: 'home_assistant_api_request',
    access: 'dynamic_http_method',
    description: 'Make an authenticated Home Assistant REST API request under /api for advanced operations.',
    parameters: {
      type: 'object',
      properties: {
        method: { type: 'string', description: 'HTTP method: GET, POST, PUT, PATCH, or DELETE.' },
        path: { type: 'string', description: 'Path under the same Home Assistant origin. Must start with /api/.' },
        query: { type: 'object', description: 'Optional query parameters.' },
        body: { type: 'object', description: 'Optional JSON request body.' },
      },
      required: ['method', 'path'],
    },
  },
];

const toolAppMap = new Map(HOME_ASSISTANT_TOOL_DEFINITIONS.map((tool) => [tool.name, tool.appId]));

module.exports = {
  HOME_ASSISTANT_APP,
  HOME_ASSISTANT_PROVIDER_KEY,
  HOME_ASSISTANT_TOOL_DEFINITIONS,
  toolAppMap,
};
