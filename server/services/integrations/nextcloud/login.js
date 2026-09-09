'use strict';

const { fetchJson } = require('../oauth_provider');
const { abortableDelay } = require('../../../utils/retry');
const { LOGIN_POLL_MS, LOGIN_TIMEOUT_MS, USER_AGENT } = require('./constants');
const { instanceRequest } = require('./client');
const { normalizeBaseUrl, requireText, text } = require('./network');

function sameOrigin(baseUrl, candidate) {
  const base = new URL(normalizeBaseUrl(baseUrl));
  const resolved = new URL(text(candidate), base);
  return resolved.origin === base.origin;
}

async function postLogin(origin, path, options = {}) {
  return fetchJson(
    `${origin}${path}`,
    {
      method: 'POST',
      headers: { 'User-Agent': USER_AGENT, Accept: 'application/json' },
      signal: options.signal,
    },
    { serviceName: 'Nextcloud login' },
  );
}

async function startLoginFlow(baseUrl, options = {}) {
  const origin = normalizeBaseUrl(baseUrl);
  let data;
  try {
    data = await postLogin(origin, '/index.php/login/v2', options);
  } catch {
    data = await postLogin(origin, '/login/v2', options);
  }
  const loginUrl = text(data?.login);
  const pollEndpoint = text(data?.poll?.endpoint);
  const pollToken = text(data?.poll?.token);
  if (!loginUrl || !pollEndpoint || !pollToken) {
    throw new Error('Nextcloud did not return a Login Flow v2 session.');
  }
  if (!sameOrigin(origin, pollEndpoint)) {
    throw new Error('Nextcloud login poll endpoint must stay on the configured instance.');
  }
  let parsedLogin;
  try {
    parsedLogin = new URL(loginUrl);
  } catch {
    throw new Error('Nextcloud returned an invalid login URL.');
  }
  if (!['http:', 'https:'].includes(parsedLogin.protocol)) {
    throw new Error('Nextcloud login URL must be HTTP or HTTPS.');
  }
  return {
    loginUrl,
    poll: { endpoint: new URL(pollEndpoint, origin).toString(), token: pollToken },
  };
}

async function pollLoginFlow(poll, options = {}) {
  const endpoint = new URL(requireText(poll?.endpoint, 'poll endpoint'));
  const token = requireText(poll?.token, 'poll token');
  const deadline = Date.now() + (Number(options.timeoutMs) > 0 ? Number(options.timeoutMs) : LOGIN_TIMEOUT_MS);
  while (Date.now() < deadline) {
    const { response, text: body } = await instanceRequest(
      endpoint.origin,
      `${endpoint.pathname}${endpoint.search}`,
      {
        method: 'POST',
        headers: {
          'User-Agent': USER_AGENT,
          Accept: 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: new URLSearchParams({ token }).toString(),
        signal: options.signal,
        serviceName: 'Nextcloud login poll',
      },
    );
    if (response.status === 404) {
      await abortableDelay(LOGIN_POLL_MS, options.signal);
      continue;
    }
    if (!response.ok) {
      throw new Error(`Nextcloud login poll failed (${response.status}).`);
    }
    let data = null;
    try {
      data = body ? JSON.parse(body) : null;
    } catch {
      data = null;
    }
    const loginName = text(data?.loginName);
    const appPassword = text(data?.appPassword);
    if (!loginName || !appPassword) {
      throw new Error('Nextcloud login did not return account credentials.');
    }
    return {
      loginName,
      appPassword,
      server: text(data?.server),
    };
  }
  throw new Error('Nextcloud login timed out. Approve the login page and try again.');
}

async function revokeAppPassword(credentials, options = {}) {
  await instanceRequest(credentials.baseUrl, '/ocs/v2.php/core/apppassword', {
    method: 'DELETE',
    headers: {
      Authorization: `Basic ${Buffer.from(`${credentials.username}:${credentials.appPassword}`, 'utf8').toString('base64')}`,
      'OCS-APIRequest': 'true',
      Accept: 'application/json',
      'User-Agent': USER_AGENT,
    },
    prefix: '/ocs/v2.php/',
    label: 'Nextcloud OCS path',
    signal: options.signal,
    serviceName: 'Nextcloud app password revoke',
  }).catch(() => {});
}

module.exports = {
  pollLoginFlow,
  revokeAppPassword,
  startLoginFlow,
};
