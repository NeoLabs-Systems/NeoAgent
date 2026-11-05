'use strict';

const http = require('node:http');

const MAX_STATUS_BYTES = 4 * 1024 * 1024;

function localRequest(socketPath, method, endpoint, body, signal) {
  return new Promise((resolve, reject) => {
    const request = http.request({
      socketPath, path: `/localapi/v0/${endpoint}`, method, signal,
      headers: { Host: 'local-tailscaled.sock', 'Content-Type': 'application/json' },
    }, (response) => {
      const chunks = [];
      let size = 0;
      response.on('data', (chunk) => {
        size += chunk.length;
        if (size > MAX_STATUS_BYTES) response.destroy(new Error('Tailscale status exceeds limit.'));
        else chunks.push(chunk);
      });
      response.on('error', reject);
      response.on('end', () => {
        if (response.statusCode < 200 || response.statusCode >= 300) {
          return reject(new Error('Tailscale local API operation failed.'));
        }
        try { resolve(size ? JSON.parse(Buffer.concat(chunks).toString('utf8')) : null); }
        catch { reject(new Error('Invalid Tailscale status response.')); }
      });
    });
    request.setTimeout(5000, () => request.destroy(new Error('Tailscale local API timed out.')));
    request.on('error', reject);
    request.end(body ? JSON.stringify(body) : undefined);
  });
}

// Use tailscaled's private Unix-socket dial API. It returns the peer stream
// directly, so no SOCKS listener or proxy port needs to exist in the VM.
function dialPeer(socketPath, address, port, signal) {
  return new Promise((resolve, reject) => {
    const request = http.request({
      socketPath, path: '/localapi/v0/dial', method: 'POST', signal,
      headers: {
        Host: 'local-tailscaled.sock', Connection: 'upgrade', Upgrade: 'ts-dial',
        'Dial-Host': address, 'Dial-Port': String(port), 'Dial-Network': 'tcp',
      },
    });
    request.on('upgrade', (response, socket, head) => {
      if (response.statusCode !== 101) { socket.destroy(); reject(new Error('Peer dial refused.')); return; }
      if (head.length) socket.unshift(head);
      resolve(socket);
    });
    // In particular, never implement LocalAPI's Dial-Self fallback, which
    // asks the caller to dial a non-tailnet address using ordinary networking.
    request.on('response', (response) => { response.resume(); reject(new Error('Tailscale did not provide a peer stream.')); });
    request.on('error', reject);
    request.end();
  });
}

module.exports = { dialPeer, localRequest };
