'use strict';

const { decryptValue } = require('../secrets');
const { trimText } = require('../../../utils/text');
const { TRIMMED_PEER_FIELDS } = require('./constants');
const { readTailscaleStatus } = require('./client');
const {
  isTailscaleAddress,
  parseHostTarget,
  peersFromStatus,
  probeTcp,
  resolveTailnetTarget,
  tailscaleRequest,
} = require('./network');

function parseCredentials(connection) {
  try {
    const parsed = JSON.parse(decryptValue(connection?.credentials_json || '{}') || '{}');
    return parsed && typeof parsed === 'object' ? parsed : {};
  } catch {
    return {};
  }
}

function listStrings(value) {
  if (Array.isArray(value)) return value.map((item) => trimText(item)).filter(Boolean);
  if (value && typeof value === 'object') return Object.values(value).map((item) => trimText(item)).filter(Boolean);
  return [];
}

function trimPeer(peer) {
  const trimmed = {};
  for (const field of TRIMMED_PEER_FIELDS) {
    if (peer[field] === undefined) continue;
    trimmed[field] = peer[field];
  }
  trimmed.TailscaleIPs = listStrings(peer.TailscaleIPs);
  const tags = listStrings(peer.Tags);
  if (tags.length > 0) trimmed.Tags = tags;
  const routes = listStrings(peer.PrimaryRoutes);
  if (routes.length > 0) trimmed.PrimaryRoutes = routes;
  return trimmed;
}

function describeTailnet(status) {
  const self = status && typeof status.Self === 'object' && status.Self !== null ? status.Self : {};
  const currentTailnet = status?.CurrentTailnet && typeof status.CurrentTailnet === 'object'
    ? status.CurrentTailnet
    : null;
  return {
    backendState: trimText(status?.BackendState) || null,
    magicDnsSuffix: trimText(status?.MagicDNSSuffix) || trimText(currentTailnet?.MagicDNSSuffix) || null,
    currentTailnet: currentTailnet
      ? {
        name: trimText(currentTailnet.Name) || null,
        magicDnsEnabled: currentTailnet.MagicDNSEnabled === true,
      }
      : null,
    self: {
      hostName: trimText(self.HostName) || null,
      dnsName: trimText(self.DNSName) || null,
      os: trimText(self.OS) || null,
      tailscaleIPs: listStrings(self.TailscaleIPs),
      online: self.Online === true,
    },
  };
}

function listPeers(status, args = {}) {
  const includeOffline = args.include_offline === true;
  const peers = peersFromStatus(status)
    .filter((peer) => includeOffline || peer.Online === true)
    .map(trimPeer)
    .sort((left, right) => String(left.HostName || '').localeCompare(String(right.HostName || '')));
  return {
    tailnet: describeTailnet(status),
    count: peers.length,
    peers,
  };
}

async function executeTailscaleTool(toolName, args, connection, options = {}) {
  const credentials = parseCredentials(connection);
  const signal = options.signal || null;
  // Every tool needs the peer list: tailscale_request and tailscale_ping use it
  // to refuse hosts that are not on this tailnet, and reading it is also the
  // cheapest proof that the node is still up.
  const status = await readTailscaleStatus({
    signal,
    socketPaths: credentials.socketPath ? [credentials.socketPath] : undefined,
    timeoutMs: credentials.statusTimeoutMs,
  });

  switch (toolName) {
    case 'tailscale_list_peers':
      return { result: listPeers(status, args) };
    case 'tailscale_request':
      return { result: await tailscaleRequest(status, args, { signal }) };
    case 'tailscale_ping': {
      const host = trimText(args.host);
      if (!host) throw new Error('host is required.');
      const port = Number(args.port) || 22;
      if (!Number.isInteger(port) || port < 1 || port > 65535) {
        throw new Error('port must be a whole number from 1 to 65535.');
      }
      const parts = { ...parseHostTarget(host), port };
      const target = await resolveTailnetTarget(parts, status, { signal });
      const probe = await probeTcp(parts, target.address, target.family, {
        timeoutMs: args.timeout_ms,
      });
      return {
        result: {
          host: parts.hostname,
          address: isTailscaleAddress(target.address) ? target.address : null,
          port,
          ...probe,
        },
      };
    }
    default:
      return null;
  }
}

module.exports = {
  describeTailnet,
  executeTailscaleTool,
  listPeers,
  parseCredentials,
};
