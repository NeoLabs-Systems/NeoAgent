'use strict';

const dns = require('node:dns').promises;
const http = require('node:http');
const https = require('node:https');
const net = require('node:net');
const { createAbortError } = require('../../../utils/abort');
const { requireText, trimText } = require('../../../utils/text');
const { waitForAbortableResult } = require('../http');

const DEFAULT_TIMEOUT_MS = 30000;
const MAX_TIMEOUT_MS = 120000;
const MAX_RESPONSE_BYTES = 512 * 1024;
const ALLOWED_METHODS = new Set(['GET', 'HEAD', 'OPTIONS', 'POST', 'PUT', 'PATCH', 'DELETE']);
const IGNORED_REQUEST_HEADERS = new Set(['host', 'connection', 'content-length', 'transfer-encoding']);
const HIDDEN_RESPONSE_HEADERS = new Set(['set-cookie', 'www-authenticate', 'proxy-authenticate']);

// Tailscale hands every node an address out of 100.64.0.0/10 or, on IPv6
// networks, fd7a:115c:a1e0::/48. Reaching anything else from this provider
// would be an SSRF escape from the tailnet it claims to be talking to.
function isTailscaleIpv4(hostname) {
  if (!net.isIPv4(hostname)) return false;
  const [a, b] = hostname.split('.').map(Number);
  return a === 100 && b >= 64 && b <= 127;
}

function isTailscaleIpv6(hostname) {
  const normalized = String(hostname || '').toLowerCase().replace(/^\[|\]$/g, '');
  if (!net.isIPv6(normalized)) return false;
  return normalized.startsWith('fd7a:115c:a1e0:');
}

function isTailscaleAddress(hostname) {
  return isTailscaleIpv4(hostname) || isTailscaleIpv6(hostname);
}

function normalizePort(value, fallback) {
  const text = trimText(value);
  if (!text) return fallback;
  const port = Number(text);
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error(`Port must be a whole number from 1 to 65535, not "${text}".`);
  }
  return port;
}

// A target is a bare host with an optional port. Full URLs are accepted so an
// agent can copy one from a browser, but only to pull the same three parts out.
function parseHostTarget(rawHost) {
  const value = requireText(rawHost, 'host');
  const withScheme = /^[a-z][a-z0-9+.-]*:\/\//i.test(value) ? value : null;
  if (withScheme) {
    let parsed;
    try {
      parsed = new URL(value);
    } catch {
      throw new Error(`"${value}" is not a valid URL.`);
    }
    if (!['http:', 'https:'].includes(parsed.protocol)) {
      throw new Error('Only http and https targets are allowed.');
    }
    const hostname = parsed.hostname.replace(/^\[|\]$/g, '');
    return {
      hostname,
      port: normalizePort(parsed.port, parsed.protocol === 'https:' ? 443 : 80),
      scheme: parsed.protocol.replace(':', ''),
    };
  }

  const match = value.match(/^\[([^\]]+)\](?::(\d+))?$/) || value.match(/^([^:/]+)(?::(\d+))?$/);
  if (!match) {
    throw new Error(`"${value}" is not a hostname or host:port.`);
  }
  const hostname = match[1].trim();
  if (!hostname || hostname.includes('/') || hostname.includes(' ')) {
    throw new Error(`"${value}" is not a hostname or host:port.`);
  }
  return { hostname, port: normalizePort(match[2], null), scheme: null };
}

// tailscaled serializes Status.Peer as an object keyed by node public key, so
// every reader goes through this one unwrap.
function peersFromStatus(status) {
  const peers = status && typeof status.Peer === 'object' && status.Peer !== null
    ? Object.values(status.Peer)
    : [];
  return peers.filter((peer) => peer && typeof peer === 'object');
}

function peerHostnames(status) {
  const names = new Set();
  const peers = peersFromStatus(status);
  for (const peer of peers) {
    if (!peer || typeof peer !== 'object') continue;
    for (const key of ['HostName', 'DNSName', 'MagicDNSName']) {
      const value = trimText(peer[key]).toLowerCase().replace(/\.$/, '');
      if (value) names.add(value);
    }
    for (const ip of Array.isArray(peer.TailscaleIPs) ? peer.TailscaleIPs : []) {
      const value = trimText(ip).toLowerCase();
      if (value) names.add(value);
    }
  }
  const self = status && typeof status.Self === 'object' ? status.Self : null;
  if (self) {
    for (const key of ['HostName', 'DNSName']) {
      const value = trimText(self[key]).toLowerCase().replace(/\.$/, '');
      if (value) names.add(value);
    }
    for (const ip of Array.isArray(self.TailscaleIPs) ? self.TailscaleIPs : []) {
      const value = trimText(ip).toLowerCase();
      if (value) names.add(value);
    }
  }
  return names;
}

function isKnownPeer(hostname, status) {
  const normalized = String(hostname || '').toLowerCase().replace(/\.$/, '');
  if (!normalized) return false;
  const names = peerHostnames(status);
  if (names.has(normalized)) return true;
  // MagicDNS gives every node <host>.<tailnet>.ts.net; the short name is what a
  // user types, so accept both spellings without enumerating the suffix.
  const shortName = normalized.split('.')[0];
  if (normalized.endsWith('.ts.net') && shortName) return names.has(shortName);
  return names.has(shortName);
}

async function resolveTailnetTarget(parts, status, options = {}) {
  const hostname = parts.hostname;
  if (isTailscaleAddress(hostname)) {
    if (!isKnownPeer(hostname, status)) {
      throw new Error(`${hostname} is a Tailscale address but not a peer of this tailnet. Call tailscale_list_peers first.`);
    }
    return { address: hostname, family: net.isIP(hostname) };
  }

  if (!isKnownPeer(hostname, status)) {
    throw new Error(
      `${hostname} is not a machine on this tailnet. Call tailscale_list_peers for the peers you can reach.`,
    );
  }

  let records;
  try {
    records = await waitForAbortableResult(
      dns.lookup(hostname, { all: true, verbatim: true }),
      options.signal,
    );
  } catch (error) {
    throw new Error(`Could not resolve ${hostname} on this tailnet: ${trimText(error?.message) || 'DNS lookup failed'}`);
  }
  const addresses = (Array.isArray(records) ? records : [records])
    .map((record) => ({
      address: String(record?.address || '').replace(/^\[|\]$/g, ''),
      family: Number(record?.family) || net.isIP(String(record?.address || '').replace(/^\[|\]$/g, '')),
    }))
    .filter((record) => record.address);
  if (addresses.length === 0) throw new Error(`Could not resolve ${hostname} on this tailnet.`);
  if (addresses.some((record) => !isTailscaleAddress(record.address))) {
    throw new Error(`${hostname} resolved outside the tailnet address range, so the request was refused.`);
  }
  return addresses[0];
}

function normalizeHeaders(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return {};
  const headers = {};
  for (const [rawName, rawValue] of Object.entries(value)) {
    const name = String(rawName || '').trim().toLowerCase();
    if (!name || rawValue == null || IGNORED_REQUEST_HEADERS.has(name)) continue;
    headers[name] = Array.isArray(rawValue)
      ? rawValue.map((item) => String(item))
      : String(rawValue);
  }
  return headers;
}

function sanitizeResponseHeaders(headers = {}) {
  const safe = {};
  for (const [name, value] of Object.entries(headers)) {
    const normalized = String(name || '').toLowerCase();
    if (!normalized || HIDDEN_RESPONSE_HEADERS.has(normalized)) continue;
    safe[normalized] = Array.isArray(value) ? value.join(', ') : String(value ?? '');
  }
  return safe;
}

function requestOnce(target, options = {}) {
  const requestImpl = target.scheme === 'https' ? https.request : http.request;
  const hostHeader = options.hostHeader || target.hostheader || target.address;
  const headers = { ...options.headers, host: hostHeader };
  const tlsHost = hostHeader.replace(/:\d+$/, '');
  if (options.body != null) {
    headers['content-length'] = String(Buffer.byteLength(options.body));
  }

  return new Promise((resolve, reject) => {
    let settled = false;
    const finish = (callback, value) => {
      if (settled) return;
      settled = true;
      callback(value);
    };
    const request = requestImpl(
      {
        protocol: `${target.scheme}:`,
        hostname: target.address,
        family: target.family,
        port: target.port,
        method: options.method,
        path: options.path,
        headers,
        maxHeaderSize: 32 * 1024,
        // SNI carries the peer's name, never its 100.x address: Tailscale serves
        // HTTPS certs for MagicDNS names only.
        servername: net.isIP(tlsHost) ? undefined : tlsHost,
        signal: options.signal,
      },
      (response) => {
        const chunks = [];
        let totalBytes = 0;
        let truncated = false;
        response.on('data', (chunkValue) => {
          if (settled) return;
          const chunk = Buffer.from(chunkValue);
          const remaining = MAX_RESPONSE_BYTES - totalBytes;
          if (remaining > 0) {
            chunks.push(chunk.subarray(0, remaining));
            totalBytes += Math.min(chunk.byteLength, remaining);
          }
          if (chunk.byteLength > remaining) {
            truncated = true;
            response.destroy();
          }
        });
        response.on('end', () => finish(resolve, {
          status: Number(response.statusCode) || 0,
          headers: response.headers,
          body: Buffer.concat(chunks, totalBytes).toString('utf8'),
          truncated,
        }));
        response.on('error', (error) => finish(reject, error));
      },
    );
    request.on('error', (error) => finish(reject, error));
    if (options.body != null) request.write(options.body);
    request.end();
  });
}

// Ports below 1024 are all plausible services on a tailnet (DNS, HTTP, SSH,
// rsync); nothing here is privileged in the sense that matters, because the
// tailnet is the boundary.
async function tailscaleRequest(status, args = {}, options = {}) {
  const parts = parseHostTarget(args.host);
  const method = String(args.method || 'GET').trim().toUpperCase() || 'GET';
  if (!ALLOWED_METHODS.has(method)) throw new Error(`Unsupported HTTP method: ${method}`);
  const scheme = trimText(args.scheme).toLowerCase() || parts.scheme || 'http';
  if (!['http', 'https'].includes(scheme)) throw new Error('scheme must be http or https.');

  const path = trimText(args.path) || '/';
  if (!path.startsWith('/')) throw new Error('path must start with /.');

  const timeoutMs = Math.max(
    100,
    Math.min(Number(args.timeout_ms) || DEFAULT_TIMEOUT_MS, MAX_TIMEOUT_MS),
  );
  const port = parts.port || (scheme === 'https' ? 443 : 80);
  const target = await resolveTailnetTarget(parts, status, { signal: options.signal });
  const hostHeader = port === (scheme === 'https' ? 443 : 80)
    ? parts.hostname
    : `${parts.hostname}:${port}`;

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  const onAbort = () => controller.abort();
  if (options.signal) options.signal.addEventListener('abort', onAbort, { once: true });

  try {
    const response = await requestOnce(
      { ...target, scheme, port },
      {
        method,
        path,
        headers: normalizeHeaders(args.headers),
        hostHeader,
        body: args.body != null && !['GET', 'HEAD'].includes(method) ? String(args.body) : null,
        signal: controller.signal,
      },
    );
    return {
      host: parts.hostname,
      url: `${scheme}://${hostHeader}${path}`,
      status: response.status,
      headers: sanitizeResponseHeaders(response.headers),
      body: response.truncated
        ? `${response.body}\n...[truncated at ${MAX_RESPONSE_BYTES} bytes]`
        : response.body,
      truncated: response.truncated,
    };
  } catch (error) {
    if (options.signal?.aborted) throw createAbortError(options.signal);
    if (controller.signal.aborted) throw new Error(`Request to ${hostHeader} timed out after ${timeoutMs}ms.`);
    throw new Error(`Request to ${hostHeader} failed: ${trimText(error?.message) || 'unknown error'}`);
  } finally {
    clearTimeout(timer);
    if (options.signal) options.signal.removeEventListener('abort', onAbort);
  }
}

function probeTcp(parts, address, family, options = {}) {
  const timeoutMs = Math.max(100, Math.min(Number(options.timeoutMs) || 3000, 15000));
  const port = parts.port || 22;
  return new Promise((resolve) => {
    const startedAt = Date.now();
    const socket = net.connect({ host: address, port, family });
    const done = (result) => {
      socket.removeAllListeners();
      socket.destroy();
      resolve(result);
    };
    socket.setTimeout(timeoutMs, () => done({
      reachable: false,
      reason: `no answer within ${timeoutMs}ms`,
      latencyMs: Date.now() - startedAt,
    }));
    socket.on('connect', () => done({
      reachable: true,
      reason: null,
      latencyMs: Date.now() - startedAt,
    }));
    socket.on('error', (error) => done({
      reachable: false,
      reason: trimText(error?.code) || trimText(error?.message) || 'connection failed',
      latencyMs: Date.now() - startedAt,
    }));
  });
}

module.exports = {
  MAX_RESPONSE_BYTES,
  isKnownPeer,
  isTailscaleAddress,
  parseHostTarget,
  peersFromStatus,
  requestOnce,
  probeTcp,
  resolveTailnetTarget,
  tailscaleRequest,
};
