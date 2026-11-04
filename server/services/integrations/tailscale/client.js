'use strict';

const http = require('node:http');
const { execFile } = require('node:child_process');
const { trimText } = require('../../../utils/text');
const { createServiceLogger } = require('../../../utils/logger');

const logger = createServiceLogger('Tailscale');

// Reading the tailnet costs one local call: whichever of tailscaled's unix
// socket or its CGNAT HTTP listener answers first. The status payload is
// authenticated by the local socket, so there is no token to store for reads.
const DEFAULT_SOCKET_PATHS = [
  '/var/run/tailscale/tailscaled.sock',
  '/run/tailscale/tailscaled.sock',
];
const LOCALAPI_ADDRESS = 'http://100.100.100.200';
const LOCALAPI_HOST_HEADER = 'local-tailscaled.sock';
const DEFAULT_TIMEOUT_MS = 5000;
const MAX_RESPONSE_BYTES = 4 * 1024 * 1024;
const CGNAT_TIMEOUT_MS = 1500;

function configuredSocketPaths() {
  const explicit = trimText(process.env.NEOAGENT_TAILSCALE_SOCKET);
  return explicit ? [explicit] : DEFAULT_SOCKET_PATHS;
}

function collect(response, limitBytes) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let total = 0;
    response.on('data', (chunk) => {
      const buffer = Buffer.from(chunk);
      if (total + buffer.byteLength > limitBytes) {
        response.destroy();
        reject(new Error('Tailscale status response was too large.'));
        return;
      }
      chunks.push(buffer);
      total += buffer.byteLength;
    });
    response.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
    response.on('error', reject);
  });
}

function readJson(requestOptions, timeoutMs) {
  return new Promise((resolve, reject) => {
    const request = http.request(requestOptions, async (response) => {
      try {
        const text = await collect(response, MAX_RESPONSE_BYTES);
        if (response.statusCode !== 200) {
          reject(new Error(`tailscaled answered ${response.statusCode}: ${trimText(text).slice(0, 200)}`));
          return;
        }
        resolve(JSON.parse(text));
      } catch (error) {
        reject(error);
      }
    });
    request.setTimeout(timeoutMs, () => {
      request.destroy(new Error(`tailscaled did not answer within ${timeoutMs}ms.`));
    });
    request.on('error', reject);
    request.end();
  });
}

async function readStatusFromSocket(socketPath, timeoutMs) {
  return readJson(
    {
      socketPath,
      path: '/localapi/v0/status',
      method: 'GET',
      headers: { Host: LOCALAPI_HOST_HEADER },
    },
    timeoutMs,
  );
}

async function readStatusFromCgnat(timeoutMs) {
  return readJson(
    {
      host: '100.100.100.200',
      port: 80,
      path: '/localapi/v0/status',
      method: 'GET',
      headers: { Host: LOCALAPI_HOST_HEADER },
    },
    timeoutMs,
  );
}

function readStatusFromCli(timeoutMs) {
  return new Promise((resolve, reject) => {
    execFile(
      'tailscale',
      ['status', '--json'],
      { timeout: timeoutMs, maxBuffer: MAX_RESPONSE_BYTES },
      (error, stdout) => {
        if (error) {
          reject(new Error(`tailscale status failed: ${error.message}`));
          return;
        }
        try {
          resolve(JSON.parse(stdout));
        } catch (parseError) {
          reject(new Error(`tailscale status returned unreadable JSON: ${parseError.message}`));
        }
      },
    );
  });
}

let lastReadMethod = null;

// The three readers differ only in transport, so try them in order of how much
// they assume: local socket, then tailscaled's own HTTP listener, then the CLI
// on PATH. A host that joined the tailnet answers at least one of them.
async function readTailscaleStatus(options = {}) {
  const timeoutMs = Math.max(
    500,
    Math.min(Number(options.timeoutMs) || DEFAULT_TIMEOUT_MS, 30000),
  );
  const failures = [];
  const readers = [
    ...(options.socketPaths || configuredSocketPaths())
      .map((socketPath) => [`socket ${socketPath}`, () => readStatusFromSocket(socketPath, timeoutMs)]),
    // The CGNAT listener is only reachable once the node is up; when it is not,
    // waiting the full status timeout just delays the error the user needs.
    ['CGNAT local API', () => readStatusFromCgnat(Math.min(timeoutMs, CGNAT_TIMEOUT_MS))],
    ['CLI', () => readStatusFromCli(timeoutMs)],
  ];
  for (const [label, read] of readers) {
    try {
      const status = await read();
      if (status && typeof status === 'object') {
        lastReadMethod = label;
        return status;
      }
      failures.push(`${label}: empty status`);
    } catch (error) {
      failures.push(`${label}: ${trimText(error?.message) || 'failed'}`);
    }
  }
  logger.warn(`Could not read tailnet status (${failures.join('; ')})`);
  throw new Error(
    'This NeoAgent server is not joined to a Tailscale network, or tailscaled is not running. '
    + 'Run `tailscale up` on the host, or point NEOAGENT_TAILSCALE_SOCKET at tailscaled.sock.',
  );
}

function getLastReadMethod() {
  return lastReadMethod;
}

module.exports = {
  LOCALAPI_ADDRESS,
  LOCALAPI_HOST_HEADER,
  getLastReadMethod,
  readTailscaleStatus,
};
