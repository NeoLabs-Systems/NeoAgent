'use strict';

const APP = { id: 'tailnet', label: 'Tailnet', description: 'Reach explicitly granted peer services through your dedicated Tailscale node.', scopes: [] };
const targetProperties = {
  peer_id: { type: 'string', description: 'Exact peer ID from tailscale_list_peers.' },
  port: { type: 'integer', minimum: 1, maximum: 65535, description: 'Granted service port.' },
};
const TOOLS = [
  { appId: APP.id, name: 'tailscale_list_peers', access: 'read', description: 'List peers visible to this connection, with granted service operations.', parameters: { type: 'object', properties: {} } },
  { appId: APP.id, name: 'tailscale_ping', access: 'read', description: 'Check TCP reachability of a granted peer service.', parameters: { type: 'object', properties: targetProperties, required: ['peer_id', 'port'] } },
  {
    appId: APP.id, name: 'tailscale_request', access: 'write',
    description: 'Call an explicitly granted HTTP operation on a peer service. Requires read/write access even for GET, because arbitrary services may change state on GET.',
    parameters: {
      type: 'object', required: ['peer_id', 'port', 'path'], properties: {
        ...targetProperties,
        scheme: { type: 'string', enum: ['http', 'https'], description: 'Granted scheme, default https.' },
        method: { type: 'string', enum: ['GET', 'HEAD', 'OPTIONS', 'POST', 'PUT', 'PATCH', 'DELETE'] },
        path: { type: 'string', description: 'Exact granted path including query string.' },
        headers: { type: 'object', additionalProperties: { type: 'string' } },
        body: { type: 'string', description: 'Optional request body, at most 512 KiB.' },
      },
    },
  },
];

module.exports = { APP, TOOLS };
