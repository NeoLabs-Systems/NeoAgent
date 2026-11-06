'use strict';

// Every built-in tool's schema and metadata. This is data only, so the security
// policy, the run trust record, and the harness can all read one source.
const BUILT_IN_DEFINITIONS = [
  ...require('./shell'),
  ...require('./browser'),
  ...require('./desktop'),
  ...require('./android'),
  ...require('./web'),
  ...require('./memory'),
  ...require('./messaging'),
  ...require('./files'),
  ...require('./coding'),
  ...require('./skills'),
  ...require('./control'),
  ...require('./agents'),
  ...require('./tasks'),
  ...require('./mcp'),
  ...require('./media'),
  ...require('./data'),
];

// integrated_tools/ owns these schemas and pulls in heavy dependencies, so only
// their metadata lives here.
const INTEGRATED_TOOL_TRAITS = {
  generate_slide_deck: {
    group: 'media', access: 'write', sideEffect: 'artifact', latencyClass: 'slow', repeatable: true,
    capabilities: ['slides', 'presentation', 'deck'],
    policy: { external: true },
  },
  generate_video_with_remotion: {
    group: 'media', access: 'write', sideEffect: 'artifact', latencyClass: 'slow', repeatable: true,
    capabilities: ['video', 'render'],
    policy: { external: true },
  },
  detect_synthid_watermark: {
    fileArgs: ['image_path'],
    group: 'media', access: 'read', latencyClass: 'remote',
    capabilities: ['image', 'watermark', 'synthid'],
    policy: { external: true },
  },
  settings_read: {
    group: 'config', access: 'read', stateScope: 'config', latencyClass: 'local', untrusted: false,
    capabilities: ['settings', 'configuration'],
  },
  settings_update: {
    persistent: true,
    group: 'config', access: 'write', sideEffect: 'config', stateScope: 'config', latencyClass: 'local', untrusted: false,
    capabilities: ['settings', 'configuration'],
  },
  settings_link: {
    group: 'config', access: 'read', stateScope: 'config', latencyClass: 'instant', untrusted: false,
    capabilities: ['settings', 'link'],
  },
};

module.exports = { BUILT_IN_DEFINITIONS, INTEGRATED_TOOL_TRAITS };
