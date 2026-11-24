'use strict';

const http = require('node:http');
const https = require('node:https');
const tls = require('node:tls');
const net = require('node:net');
const { dialPeer } = require('./guest_api');

const MAX_BODY_BYTES = 512 * 1024;
const BLOCKED_HEADERS = new Set(['host', 'connection', 'content-length', 'transfer-encoding', 'upgrade', 'proxy-authorization', 'proxy-connection', 'trailer', 'te']);

function peerTarget(status, peerId) {
  const peer = Object.values(status.Peer || {}).find((entry) => entry?.ID === peerId);
  const address = peer?.TailscaleIPs?.find((ip) => {
    if (net.isIPv4(ip)) { const [first, second] = ip.split('.').map(Number); return first === 100 && second >= 64 && second < 128; }
    return net.isIPv6(ip) && ip.toLowerCase().startsWith('fd7a:115c:a1e0:');
  });
  if (!peer || !address) throw new Error('The selected peer is no longer available.');
  return { peer, address };
}

async function requestPeer(socketPath, status, operation, { signal } = {}) {
  const { peer, address } = peerTarget(status, operation.peerId);
  signal?.throwIfAborted();
  const started = Date.now();
  const socket = await dialPeer(socketPath, address, operation.port, signal);
  const abort = () => socket.destroy(new Error('Tailscale operation canceled.'));
  signal?.addEventListener('abort', abort, { once: true });
  try {
    signal?.throwIfAborted();
    if (operation.action === 'ping') return { reachable: true, latencyMs: Date.now() - started };
    const host = String(peer.DNSName || '').replace(/\.$/, '') || address;
    const headers = { ...operation.headers };
    for (const name of Object.keys(headers)) {
      if (BLOCKED_HEADERS.has(name.toLowerCase())) throw new Error('Unsupported request header.');
    }
    const secure = operation.scheme === 'https';
    const agent = secure ? new https.Agent({ keepAlive: false }) : new http.Agent({ keepAlive: false });
    agent.createConnection = (_options, callback) => {
      if (!secure) { callback(null, socket); return; }
      const tlsSocket = tls.connect({ socket, host, servername: net.isIP(host) ? undefined : host, minVersion: 'TLSv1.2', rejectUnauthorized: true });
      tlsSocket.once('secureConnect', () => { tlsSocket.removeListener('error', callback); callback(null, tlsSocket); });
      tlsSocket.once('error', callback);
    };
    try {
      return await new Promise((resolve, reject) => {
        const request = (secure ? https : http).request({
          hostname: host, port: operation.port, path: operation.path, method: operation.method,
          headers, agent, signal, maxHeaderSize: 32768,
        }, (response) => {
          const chunks = [];
          let size = 0;
          let truncated = false;
          const finish = () => {
            const responseHeaders = {};
            for (const [name, value] of Object.entries(response.headers)) {
              if (!['set-cookie', 'www-authenticate', 'proxy-authenticate'].includes(name)) responseHeaders[name] = value;
            }
            resolve({ status: response.statusCode, headers: responseHeaders, body: Buffer.concat(chunks).toString('utf8'), truncated });
          };
          response.on('data', (chunk) => {
            const remaining = MAX_BODY_BYTES - size;
            chunks.push(chunk.subarray(0, Math.max(0, remaining)));
            size += Math.min(remaining, chunk.length);
            if (chunk.length > remaining) { truncated = true; finish(); response.destroy(); }
          });
          response.once('end', finish);
          response.once('error', reject);
        });
        request.once('error', () => reject(new Error('Peer request failed.')));
        request.end(operation.body || undefined);
      });
    } finally { agent.destroy(); }
  } finally {
    signal?.removeEventListener('abort', abort);
    socket.destroy();
  }
}

module.exports = { peerTarget, requestPeer };
