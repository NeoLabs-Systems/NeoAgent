'use strict';

const http = require('http');
const { isWebSharingAllowed } = require('./server_switch');
const { PUBLIC_PAGE_RULES } = require('./page_rules');
const {
  isWebSharingEnabled,
  listShares,
  removeShare,
  saveShare,
  validatePort,
} = require('./shares');

const PROBE_TIMEOUT_MS = 5000;

// What the app on that port answers, through the guest agent: 'ok' when
// anything answers, 'closed' when nothing listens there.
function probeGuestPort(guest, port) {
  return new Promise((resolve) => {
    const request = http.request(new URL(`/proxy/${port}/`, guest.baseUrl), {
      method: 'GET',
      headers: { authorization: `Bearer ${guest.token}`, accept: 'text/html,*/*' },
    }, (response) => {
      response.resume();
      resolve(response.statusCode === 502 && response.headers['x-neoagent-proxy'] ? 'closed' : 'ok');
    });
    request.setTimeout(PROBE_TIMEOUT_MS, () => request.destroy(new Error('timeout')));
    request.on('error', () => resolve('closed'));
    request.end();
  });
}

const PATH_NOTE = 'The page is served under that path, not at a domain root: links, scripts and styles must use relative paths '
  + '(or the base path from the X-Forwarded-Prefix header). It runs sandboxed, so it gets no cookies or local storage. '
  + 'It is reachable only while your computer and the app on it run. '
  + `${PUBLIC_PAGE_RULES} If anything on it breaks that, stop sharing it now.`;

async function shareWebPage({ userId, agentId = null, runtime, name, port, baseUrl }) {
  if (!isWebSharingEnabled(userId)) return { error: 'Web page sharing is turned off in settings.' };
  const validPort = validatePort(port);
  if (!validPort) return { error: 'port must be the port the app listens on inside your computer (1-65535).' };
  if (!String(name || '').trim()) return { error: 'name is required.' };
  const guest = runtime?.runningGuestForUser?.(userId);
  if (!guest) return { error: 'Your computer is not running, so there is nothing to share. Start the app on it first.' };
  if (await probeGuestPort(guest, validPort) === 'closed') {
    return { error: `Nothing answers on port ${validPort} inside your computer. Start the app there (listening on localhost or 0.0.0.0), then share it.` };
  }
  const saved = saveShare({ userId, agentId, name, port: validPort, baseUrl });
  if (saved.error) return saved;
  return { shared: true, ...saved.share, replaced_existing: saved.replaced, note: PATH_NOTE };
}

function stopSharingWebPage({ userId, ref }) {
  return removeShare(userId, ref)
    ? { stopped: true }
    : { error: `No shared page matches "${ref}".`, shared_pages: listShares(userId).map((share) => share.name) };
}

module.exports = {
  isWebSharingAllowed,
  isWebSharingEnabled,
  listShares,
  probeGuestPort,
  shareWebPage,
  stopSharingWebPage,
};
