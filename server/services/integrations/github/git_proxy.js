'use strict';

const crypto = require('crypto');
const https = require('https');
const { DEFAULT_NEOAGENT_PORT } = require('../../../../lib/setup/contract');
const { createServiceLogger } = require('../../../utils/logger');
const { getConnectionAccessMode, parseConnectionMetadata } = require('../access');
const { decryptValue } = require('../secrets');
const {
  buildPushRefusalReport,
  findPushRefusal,
  readPushCommands,
} = require('./git_push_policy');

const logger = createServiceLogger('GitProxy');

// Guest computers never hold a GitHub token. Every command an agent runs gets a
// short-lived capability bound to that user, agent, and run; git in the guest
// rewrites github.com URLs to this proxy and sends the capability as a header,
// and the proxy swaps it for that agent's own GitHub connection.

const CAPABILITY_HEADER = 'x-neoagent-git-capability';
const CAPABILITY_GRACE_MS = 5 * 60 * 1000;
const PROXY_PATH = '/api/git-proxy/github.com/';
const REPO_PATH = /^\/([A-Za-z0-9_.-]+)\/([A-Za-z0-9_.-]+?)(?:\.git)?\/(info\/refs|git-upload-pack|git-receive-pack)$/;
const GIT_SERVICES = new Set(['git-upload-pack', 'git-receive-pack']);
const FORWARDED_REQUEST_HEADERS = ['content-type', 'content-encoding', 'content-length', 'accept', 'accept-encoding', 'git-protocol', 'user-agent'];
const FORWARDED_RESPONSE_HEADERS = ['content-type', 'content-encoding', 'content-length', 'cache-control', 'expires', 'pragma'];

const capabilities = new Map();

function mintCapability(grant, ttlMs) {
  const now = Date.now();
  for (const [token, entry] of capabilities) {
    if (entry.expiresAt <= now) capabilities.delete(token);
  }
  const token = crypto.randomBytes(32).toString('base64url');
  capabilities.set(token, { ...grant, expiresAt: now + ttlMs + CAPABILITY_GRACE_MS });
  return token;
}

function resolveCapability(token) {
  const entry = capabilities.get(String(token || ''));
  if (!entry || entry.expiresAt <= Date.now()) return null;
  return entry;
}

function getAgentGithubConnection(integrationManager, userId, agentId) {
  return integrationManager.listConnections(userId, 'github', agentId)
    .find((connection) => connection.status === 'connected' && connection.app_key === 'repos') || null;
}

function readConnectionToken(connection) {
  try {
    return String(JSON.parse(decryptValue(connection.credentials_json || '{}') || '{}').access_token || '');
  } catch {
    return '';
  }
}

// Env for one guest command: route GitHub remotes through the proxy and commit
// as the agent's own GitHub account. Returns null when the agent has no GitHub
// connection, so git behaves exactly as the guest has it configured.
function buildGuestGitEnv({ integrationManager, userId, agentId, runId, guestHost, ttlMs }) {
  const connection = getAgentGithubConnection(integrationManager, userId, agentId);
  if (!connection) return null;

  const capability = mintCapability(
    { userId, agentId: connection.agent_id, runId: runId || null },
    ttlMs,
  );
  const base = `http://${guestHost}:${Number(process.env.PORT) || DEFAULT_NEOAGENT_PORT}${PROXY_PATH}`;
  const config = [
    [`url.${base}.insteadOf`, 'https://github.com/'],
    [`url.${base}.insteadOf`, 'git@github.com:'],
    [`url.${base}.insteadOf`, 'ssh://git@github.com/'],
    [`http.${base}.extraHeader`, `X-NeoAgent-Git-Capability: ${capability}`],
  ];
  const env = { GIT_CONFIG_COUNT: String(config.length), GIT_TERMINAL_PROMPT: '0' };
  config.forEach(([key, value], index) => {
    env[`GIT_CONFIG_KEY_${index}`] = key;
    env[`GIT_CONFIG_VALUE_${index}`] = value;
  });

  const login = String(connection.account_email || '').trim();
  const githubUserId = parseConnectionMetadata(connection.metadata_json).userId;
  if (login && githubUserId) {
    const email = `${githubUserId}+${login}@users.noreply.github.com`;
    env.GIT_AUTHOR_NAME = login;
    env.GIT_AUTHOR_EMAIL = email;
    env.GIT_COMMITTER_NAME = login;
    env.GIT_COMMITTER_EMAIL = email;
  }
  return env;
}

// text/plain bodies are shown by git as "remote: <message>".
function sendGitError(res, status, message) {
  res.status(status).type('text/plain').send(`NeoAgent: ${message}\n`);
}

function forwardToGithub({ req, res, upstreamPath, token, head = null }) {
  return new Promise((resolve) => {
    const headers = {
      authorization: `Basic ${Buffer.from(`x-access-token:${token}`).toString('base64')}`,
    };
    for (const name of FORWARDED_REQUEST_HEADERS) {
      if (req.headers[name]) headers[name] = req.headers[name];
    }

    const upstream = https.request(
      { hostname: 'github.com', path: upstreamPath, method: req.method, headers },
      (upstreamRes) => {
        if (upstreamRes.statusCode === 401) {
          upstreamRes.resume();
          sendGitError(res, 403, 'GitHub rejected this agent\'s token. Reconnect GitHub for this agent in Integrations.');
          resolve();
          return;
        }
        res.status(upstreamRes.statusCode);
        for (const name of FORWARDED_RESPONSE_HEADERS) {
          if (upstreamRes.headers[name]) res.setHeader(name, upstreamRes.headers[name]);
        }
        upstreamRes.pipe(res);
        upstreamRes.on('end', resolve);
        upstreamRes.on('error', resolve);
      },
    );
    upstream.on('error', (error) => {
      logger.warn(`GitHub request failed: ${error.message}`);
      if (res.headersSent) res.destroy(error);
      else sendGitError(res, 502, 'GitHub request failed.');
      resolve();
    });
    res.on('close', () => {
      if (!res.writableFinished) upstream.destroy();
    });

    if (head) upstream.write(head);
    if (req.method === 'POST') req.pipe(upstream);
    else upstream.end();
  });
}

async function refuseOrForwardPush({ req, res, grant, owner, repo, upstreamPath, token }) {
  if (req.headers['content-encoding']) {
    sendGitError(res, 415, 'Compressed push requests are not supported.');
    return;
  }
  const { head, commands, clientCapabilities } = await readPushCommands(req);
  const refs = commands.map((command) => command.ref).join(', ');
  const refusal = await findPushRefusal({ commands, owner, repo, token, signal: req.signal });
  if (refusal) {
    logger.warn(`Refused push by agent ${grant.agentId} (run ${grant.runId}) to ${owner}/${repo} [${refs}]: ${refusal.reason}`);
    const report = buildPushRefusalReport({ commands, clientCapabilities, refusal });
    // Drain the pack the client is still sending before answering.
    req.on('end', () => {
      res.status(200)
        .set('Content-Type', 'application/x-git-receive-pack-result')
        .set('Cache-Control', 'no-cache')
        .send(report);
    });
    req.resume();
    return;
  }
  logger.info(`Agent ${grant.agentId} (run ${grant.runId}) pushing to ${owner}/${repo} [${refs}]`);
  await forwardToGithub({ req, res, upstreamPath, token, head });
}

async function proxyGitRequest({ integrationManager, req, res }) {
  const grant = resolveCapability(req.get(CAPABILITY_HEADER));
  if (!grant) {
    sendGitError(res, 403, 'git access for this command has expired. Run the git command again.');
    return;
  }
  const match = REPO_PATH.exec(req.path);
  if (!match) {
    sendGitError(res, 404, 'only GitHub repository clone, fetch, and push requests are proxied.');
    return;
  }
  const [, owner, repo, endpoint] = match;
  const isAdvertisement = endpoint === 'info/refs';
  const service = isAdvertisement ? String(req.query.service || '') : endpoint;
  if (!GIT_SERVICES.has(service) || req.method !== (isAdvertisement ? 'GET' : 'POST')) {
    sendGitError(res, 400, 'unsupported git request.');
    return;
  }

  const connection = getAgentGithubConnection(integrationManager, grant.userId, grant.agentId);
  const token = connection ? readConnectionToken(connection) : '';
  if (!token) {
    sendGitError(res, 403, 'this agent has no connected GitHub account. Connect GitHub for this agent in Integrations.');
    return;
  }
  const pushing = service === 'git-receive-pack';
  if (pushing && getConnectionAccessMode(connection) === 'read_only') {
    sendGitError(res, 403, 'this agent\'s GitHub connection is read-only.');
    return;
  }

  const upstreamPath = `/${owner}/${repo}.git/${endpoint}${isAdvertisement ? `?service=${service}` : ''}`;
  try {
    if (pushing && !isAdvertisement) {
      await refuseOrForwardPush({ req, res, grant, owner, repo, upstreamPath, token });
    } else {
      await forwardToGithub({ req, res, upstreamPath, token });
    }
  } catch (error) {
    logger.warn(`Proxying ${service} for ${owner}/${repo} failed: ${error.message}`);
    if (!res.headersSent) sendGitError(res, 502, error.message);
    else res.destroy(error);
  }
}

module.exports = {
  buildGuestGitEnv,
  proxyGitRequest,
};
