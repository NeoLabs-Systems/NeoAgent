'use strict';

const PROVIDER_KEY = 'tailscale';
const APP = {
  id: 'tailnet',
  label: 'Tailnet',
  description: 'Machines on this Tailscale network, reachable over their 100.x addresses.',
};

const TRIMMED_PEER_FIELDS = [
  'ID', 'HostName', 'DNSName', 'OS', 'Online', 'TailscaleIPs', 'Tags',
  'ExitNode', 'ExitNodeOption', 'PrimaryRoutes', 'UserID',
  'Created', 'LastSeen', 'RxBytes', 'TxBytes',
];

const TOOLS = [
  {
    appId: APP.id,
    name: 'tailscale_list_peers',
    access: 'read',
    description: 'List the machines on the Tailscale network this NeoAgent server is joined to, with their 100.x addresses, OS, online state and tags. Use it before reaching any of them.',
    parameters: {
      type: 'object',
      properties: {
        include_offline: {
          type: 'boolean',
          description: 'Include peers that Tailscale reports offline. Default false.',
        },
      },
    },
  },
  {
    appId: APP.id,
    name: 'tailscale_request',
    access: 'dynamic_http_method',
    description: 'Make an HTTP request to a machine on the tailnet. The host must be a peer of the connected tailnet or a Tailscale IP; paths may be absolute (/health) or full URLs on the same host. Only advertise a host when a hostname, IP and port are given.',
    parameters: {
      type: 'object',
      properties: {
        host: {
          type: 'string',
          description: 'Peer hostname, MagicDNS name, or 100.x Tailscale IP, optionally with :port. For example nas, nas.tailnet-name.ts.net, or 100.64.0.12:8080.',
        },
        method: {
          type: 'string',
          description: 'HTTP method: GET, POST, PUT, PATCH, DELETE, or HEAD. Default GET.',
        },
        path: {
          type: 'string',
          description: 'Path to request on that host, starting with /. Default /.',
        },
        scheme: {
          type: 'string',
          description: 'http or https. Default http.',
        },
        headers: {
          type: 'object',
          description: 'Optional request headers. Host, connection, and content-length are ignored.',
        },
        body: {
          type: 'string',
          description: 'Optional request body, sent as-is.',
        },
        timeout_ms: {
          type: 'number',
          description: 'Request timeout in milliseconds, 100 to 120000. Default 30000.',
        },
      },
      required: ['host'],
    },
  },
  {
    appId: APP.id,
    name: 'tailscale_ping',
    access: 'read',
    description: 'Check whether a tailnet peer answers on a TCP port from this server. Reports reachability and latency; it does not run the tailscale ping command.',
    parameters: {
      type: 'object',
      properties: {
        host: { type: 'string', description: 'Peer hostname or 100.x Tailscale IP.' },
        port: { type: 'number', description: 'TCP port to connect to, 1 to 65535. Default 22.' },
        timeout_ms: { type: 'number', description: 'Connect timeout in milliseconds, 100 to 15000. Default 3000.' },
      },
      required: ['host'],
    },
  },
];

const toolAppMap = new Map(TOOLS.map((tool) => [tool.name, tool.appId]));

module.exports = {
  APP,
  PROVIDER_KEY,
  TOOLS,
  TRIMMED_PEER_FIELDS,
  toolAppMap,
};
