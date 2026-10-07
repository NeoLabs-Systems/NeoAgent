'use strict';

const crypto = require('crypto');
const http = require('http');
const { safeEqual } = require('../../../utils/security');
const { createServiceLogger } = require('../../../utils/logger');

const log = createServiceLogger('LoopbackCallback');
const CALLBACK_PATH = '/auth/callback';

function escapeHtml(value) {
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function renderResultPage({ success, message, providerKey }) {
  // Lets the web client's popup launcher finish without waiting for its poll.
  const payload = JSON.stringify({
    type: success ? 'auth_oauth_success' : 'auth_oauth_error',
    provider: providerKey,
    ...(success ? {} : { error: message }),
  });
  const script = `try{if(window.opener)window.opener.postMessage(${payload},'*')}catch(e){}history.replaceState(null,'','/auth/complete');`;
  const scriptHash = crypto.createHash('sha256').update(script).digest('base64');
  const html = `<!doctype html><html lang="en"><meta charset="utf-8"><title>NeoAgent</title>
<style>body{font:16px system-ui,sans-serif;max-width:32rem;margin:18vh auto;padding:24px}</style>
<h1>${success ? 'You are signed in' : 'Sign-in failed'}</h1><p>${escapeHtml(message)}</p>
<script>${script}</script></html>`;
  return {
    html,
    csp: `default-src 'none'; script-src 'sha256-${scriptHash}'; style-src 'unsafe-inline'; frame-ancestors 'none'; base-uri 'none'`,
  };
}

// Receives one OAuth redirect on an ephemeral 127.0.0.1 port, for providers
// that only allow loopback redirect URIs (RFC 8252 native-app flow). Only a
// browser on the same machine as this server can reach it, so callers must
// offer this transport to same-machine clients only.
//
// `onCallback(query)` runs once for the request carrying the expected state;
// its resolved `{ message }` or thrown error is shown in the browser tab.
async function openLoopbackCallback({ state, providerKey, ttlMs, onCallback }) {
  let settled = false;
  let port = 0;

  const server = http.createServer(async (req, res) => {
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('Referrer-Policy', 'no-referrer');
    let url;
    try {
      url = new URL(req.url || '/', `http://127.0.0.1:${port}`);
    } catch {
      res.writeHead(400).end('Invalid request');
      return;
    }
    if (req.method !== 'GET' || req.headers.host !== `127.0.0.1:${port}` || url.pathname !== CALLBACK_PATH || settled) {
      res.writeHead(404).end('Not found');
      return;
    }
    // Unrelated loopback requests must not consume the pending sign-in.
    if (url.searchParams.getAll('state').length !== 1 || !safeEqual(url.searchParams.get('state'), state)) {
      res.writeHead(400).end('Invalid sign-in state. Return to the browser tab that started sign-in.');
      return;
    }
    settled = true;

    let page;
    try {
      const result = await onCallback(url.searchParams);
      page = renderResultPage({ success: true, message: result.message, providerKey });
    } catch (error) {
      page = renderResultPage({ success: false, message: error.message || 'Sign-in failed.', providerKey });
    }
    res.writeHead(200, {
      'Content-Type': 'text/html; charset=utf-8',
      'Content-Security-Policy': page.csp,
    });
    res.end(page.html, close);
  });
  server.requestTimeout = 15000;
  server.headersTimeout = 10000;

  const timer = setTimeout(close, ttlMs);
  timer.unref();

  function close() {
    clearTimeout(timer);
    server.close();
    server.closeAllConnections();
  }

  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen({ port: 0, host: '127.0.0.1' }, () => {
      server.removeListener('error', reject);
      server.on('error', (error) => log.warn(`Listener error: ${error.message}`));
      port = server.address().port;
      // A pending sign-in must not keep the process alive on shutdown.
      server.unref();
      resolve();
    });
  });

  return {
    redirectUri: `http://127.0.0.1:${port}${CALLBACK_PATH}`,
    close,
  };
}

module.exports = {
  openLoopbackCallback,
};
