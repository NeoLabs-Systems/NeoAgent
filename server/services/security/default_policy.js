'use strict';

// What each category of tool needs from the owner when no policy row exists.
// Its own module so tool definitions can name the categories without loading
// the registry that is built from them.
const DEFAULT_POLICY = Object.freeze({
  shell: 'require_approval',
  file_write: 'require_approval',
  android_privileged: 'require_approval',
  desktop_control: 'require_approval',
  browser_privileged: 'require_approval',
  credential_use: 'require_approval',
  network_write: 'require_approval',
  user_contact: 'require_approval',
  skill_mutation: 'deny',
  agent_creation: 'require_approval',
  external: 'require_approval',
});

module.exports = { DEFAULT_POLICY };
