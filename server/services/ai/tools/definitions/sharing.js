'use strict';

const { getTerminalEnv, TERMINAL_ENV_HOST } = require('../../../../utils/deployment');

// Sharing web pages from the computer. Offered only with a guest computer and
// while the owner allows sharing, so with the setting off the model never sees it.
function sharingAvailable(options = {}) {
  if (options.userId == null || getTerminalEnv() === TERMINAL_ENV_HOST) return false;
  return require('../../../web_shares/shares').isWebSharingEnabled(options.userId);
}

module.exports = [
  {
    name: 'share_web_page',
    availableWhen: sharingAvailable,
    group: 'web', access: 'write', sideEffect: 'external', stateScope: 'external', latencyClass: 'local', untrusted: false,
    persistent: true, egress: true,
    prerequisites: ['computer'],
    capabilities: ['share', 'publish', 'web', 'page', 'url', 'host', 'preview'],
    // Publishing exposes the page to anyone with the link; listing and
    // stopping only narrow what is exposed.
    policy: {
      category: 'network_write',
      categoryFor: (args) => (String(args.action || '') === 'share' ? 'network_write' : null),
    },
    whenToUse: [
      'a web app or page you started on your computer should be opened by the user or others in a browser',
    ],
    whenNotToUse: [
      'a file the user should receive (send it as an attachment instead)',
      'anything private: everyone with the link can open the page',
    ],
    description: 'Publish a web app running on your computer at a public link on this server, /<username>/<name>/, and get the link to pass on. '
      + 'share: the app must already answer on that port inside your computer; sharing the same name again points it at the new port. '
      + 'The link works only while your computer and the app run. stop: take a page offline. list: pages shared now.',
    parameters: {
      type: 'object',
      properties: {
        action: { type: 'string', enum: ['share', 'stop', 'list'] },
        name: { type: 'string', description: 'For share: a short title; it becomes the address (letters, digits and dashes). For stop: the shared name or link slug.' },
        port: { type: 'integer', description: 'For share: the port the app listens on inside your computer.' },
      },
      required: ['action'],
    },
  },
];
