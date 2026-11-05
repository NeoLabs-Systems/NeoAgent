'use strict';

const { parseJsonObject } = require('../../../utils/text');
const METHODS = new Set(['GET', 'HEAD', 'OPTIONS', 'POST', 'PUT', 'PATCH', 'DELETE']);

function normalizeServices(value) {
  if (!Array.isArray(value) || value.length > 64) throw new Error('Provide at most 64 service operations.');
  return value.map((entry) => {
    const peerId = String(entry?.peerId || '').trim();
    const port = Number(entry?.port);
    const scheme = String(entry?.scheme || 'https');
    const path = String(entry?.path || '');
    const methods = entry?.methods;
    if (!peerId || peerId.length > 256 || !Number.isInteger(port) || port < 1 || port > 65535) {
      throw new Error('Select a peer and a port from 1 to 65535.');
    }
    if (!['http', 'https'].includes(scheme)) throw new Error('Service scheme must be http or https.');
    if (!path.startsWith('/') || path.startsWith('//') || /[\s\\#]/.test(path) || path.length > 2048) {
      throw new Error('Provide an exact service path, including any query string.');
    }
    if (!Array.isArray(methods) || !methods.length || methods.some((method) => !METHODS.has(method))) {
      throw new Error('Select valid HTTP methods for each service operation.');
    }
    return { peerId, port, scheme, path, methods: [...new Set(methods)] };
  });
}

function servicesFor(connection) {
  return normalizeServices(parseJsonObject(connection.metadata_json).services || []);
}

function authorizeRequest(connection, action, args) {
  const port = Number(args.port);
  const peerId = String(args.peer_id || '');
  const method = String(args.method || 'GET').toUpperCase();
  const scheme = String(args.scheme || 'https');
  const path = String(args.path || '/');
  const grants = servicesFor(connection);
  const allowed = grants.some((grant) => grant.peerId === peerId && grant.port === port
    && (action === 'ping' || (grant.scheme === scheme && grant.path === path && grant.methods.includes(method))));
  if (!allowed) throw new Error('This service operation has not been granted. Configure service access in the Tailscale integration.');
  const body = args.body == null ? '' : String(args.body);
  if (Buffer.byteLength(body) > 512 * 1024) throw new Error('Request body exceeds limit.');
  const headers = args.headers || {};
  if (!headers || typeof headers !== 'object' || Array.isArray(headers)
    || Object.entries(headers).some(([key, value]) => typeof value !== 'string' || /[\r\n]/.test(key + value))
    || Buffer.byteLength(JSON.stringify(headers)) > 16384) throw new Error('Invalid request headers.');
  return { peerId, port, method, scheme, path, body, headers, grants };
}

module.exports = { authorizeRequest, normalizeServices, servicesFor };
