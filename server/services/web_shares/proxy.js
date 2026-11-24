'use strict';

const http = require('http');
const zlib = require('zlib');
const rateLimit = require('express-rate-limit');
const { findPublicShare } = require('./shares');
const {
  HIDE_NOTICE_PATH,
  NOTICE_COOKIE,
  injectNotice,
  noticeHidden,
  noticeMarkup,
  offlinePage,
} = require('./page_chrome');

const UPSTREAM_TIMEOUT_MS = 60 * 1000;
const MAX_INJECTED_HTML_BYTES = 8 * 1024 * 1024;
const SHARE_PATH_RE = /^\/([^/?#]+)\/([a-z0-9-]{1,48})(\/[^?#]*)?(\?.*)?$/i;

// A shared page runs on this server's origin, so it gets an opaque one of its
// own: without allow-same-origin it cannot read NeoAgent's cookies, storage or
// API, and its requests to the server carry no session.
const SANDBOX_POLICY = 'sandbox allow-scripts allow-forms allow-modals allow-popups '
  + 'allow-popups-to-escape-sandbox allow-downloads allow-pointer-lock allow-presentation';

const DROPPED_REQUEST_HEADERS = new Set([
  'cookie', 'authorization', 'proxy-authorization', 'host', 'connection', 'keep-alive', 'te', 'trailer',
  'transfer-encoding', 'upgrade', 'forwarded', 'x-real-ip', 'true-client-ip',
]);
const DROPPED_REQUEST_PREFIXES = ['x-forwarded-', 'cf-', 'x-neoagent-'];

// Headers that would act on NeoAgent's origin rather than on the page.
const DROPPED_RESPONSE_HEADERS = new Set([
  'set-cookie', 'clear-site-data', 'strict-transport-security', 'service-worker-allowed',
  'access-control-allow-credentials', 'public-key-pins', 'alt-svc', 'x-neoagent-proxy',
  'connection', 'keep-alive', 'transfer-encoding', 'trailer', 'upgrade',
]);

function forwardedRequestHeaders(req, { prefix, token, publicUrl }) {
  const headers = {};
  for (const [name, value] of Object.entries(req.headers)) {
    const lower = name.toLowerCase();
    if (DROPPED_REQUEST_HEADERS.has(lower) || DROPPED_REQUEST_PREFIXES.some((p) => lower.startsWith(p))) continue;
    headers[lower] = value;
  }
  let proto = req.protocol || 'http';
  let host = req.get('host') || '';
  try {
    if (publicUrl) ({ protocol: proto, host } = new URL(publicUrl));
    proto = proto.replace(/:$/, '');
  } catch {}
  return {
    ...headers,
    authorization: `Bearer ${token}`,
    'x-forwarded-proto': proto,
    'x-forwarded-host': host,
    'x-forwarded-prefix': prefix,
  };
}

// A redirect the app sends to one of its own paths stays under the share.
function rewriteLocation(location, prefix, port) {
  const value = String(location || '');
  if (value.startsWith('/') && !value.startsWith('//')) return `${prefix}${value}`;
  const local = /^https?:\/\/(?:localhost|127\.0\.0\.1|0\.0\.0\.0|\[::1\])(?::(\d+))?(\/.*)?$/i.exec(value);
  if (local && (!local[1] || Number(local[1]) === port)) return `${prefix}${local[2] || '/'}`;
  return value;
}

function responseHeaders(upstreamHeaders, { prefix, port }) {
  const headers = {};
  for (const [name, value] of Object.entries(upstreamHeaders)) {
    const lower = name.toLowerCase();
    if (DROPPED_RESPONSE_HEADERS.has(lower)) continue;
    headers[lower] = lower === 'location' ? rewriteLocation(value, prefix, port) : value;
  }
  const appPolicies = [].concat(headers['content-security-policy'] || []);
  headers['content-security-policy'] = [...appPolicies, SANDBOX_POLICY];
  headers['x-content-type-options'] = 'nosniff';
  headers['x-robots-tag'] = 'noindex, nofollow';
  return headers;
}

// A "." or ".." segment, raw or percent-encoded, could step out of
// /proxy/<port> to the guest agent's own routes, which this request carries
// the token for. Such paths are refused outright.
function hasDotSegment(pathname) {
  return pathname.split(/[/\\]/).some((segment) => {
    let decoded = segment;
    try {
      decoded = decodeURIComponent(segment);
    } catch {
      return true;
    }
    return decoded === '.' || decoded === '..' || /[/\\]/.test(decoded);
  });
}

function decoderFor(encoding) {
  switch (String(encoding || '').trim().toLowerCase()) {
    case '': case 'identity': return null;
    case 'gzip': case 'x-gzip': return zlib.createGunzip();
    case 'deflate': return zlib.createInflate();
    case 'br': return zlib.createBrotliDecompress();
    default: return undefined;
  }
}

// The notice belongs on pages a person opens, not on fragments a script loads
// or on frames inside the page.
function wantsNotice(req, upstreamRes) {
  if (req.method !== 'GET' || upstreamRes.statusCode < 200 || upstreamRes.statusCode >= 300) return false;
  if (!/^text\/html\b/i.test(String(upstreamRes.headers['content-type'] || ''))) return false;
  if (noticeHidden(req.headers.cookie)) return false;
  const dest = String(req.headers['sec-fetch-dest'] || '');
  return dest ? dest === 'document' : !req.headers['x-requested-with'] && !req.headers['hx-request'];
}

function sendOffline(res, { share, user }) {
  res.status(503).set({
    'content-type': 'text/html; charset=utf-8',
    'cache-control': 'no-store',
    'retry-after': '30',
    'content-security-policy': "default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'",
    'x-robots-tag': 'noindex, nofollow',
  }).send(offlinePage({ username: user.username, title: share.title || share.slug }));
}

function relayWithNotice(req, res, upstreamRes, headers, notice) {
  const decoder = decoderFor(upstreamRes.headers['content-encoding']);
  if (decoder === undefined) {
    res.writeHead(upstreamRes.statusCode, headers);
    upstreamRes.pipe(res);
    return;
  }
  const source = decoder ? upstreamRes.pipe(decoder) : upstreamRes;
  const chunks = [];
  let size = 0;
  let passedThrough = false;
  source.on('data', (chunk) => {
    if (passedThrough) return;
    size += chunk.length;
    chunks.push(chunk);
    // A page this large is relayed as it is rather than held in memory.
    if (size > MAX_INJECTED_HTML_BYTES) {
      passedThrough = true;
      delete headers['content-length'];
      delete headers['content-encoding'];
      res.writeHead(upstreamRes.statusCode, headers);
      res.write(Buffer.concat(chunks));
      source.pipe(res);
    }
  });
  source.on('end', () => {
    if (passedThrough) return;
    const html = injectNotice(Buffer.concat(chunks).toString('utf8'), notice);
    for (const name of ['content-length', 'content-encoding', 'etag', 'last-modified']) delete headers[name];
    headers.vary = [].concat(headers.vary || [], 'Cookie').join(', ');
    res.writeHead(upstreamRes.statusCode, headers);
    res.end(html);
  });
  source.on('error', (err) => (res.headersSent ? res.destroy(err) : res.status(502).end()));
}

function hideNotice(req, res, { prefix, secure }) {
  const back = String(new URL(req.originalUrl, 'http://share.invalid').searchParams.get('back') || '');
  const target = back.startsWith(`${prefix}/`) && !back.includes('//') ? back : `${prefix}/`;
  res.setHeader('set-cookie', `${NOTICE_COOKIE}=hidden; Path=/; Max-Age=31536000; SameSite=Lax; HttpOnly${secure ? '; Secure' : ''}`);
  res.set('cache-control', 'no-store').redirect(303, target);
}

// Serves /<username>/<slug>/… from the port the share points at, while the
// owner's computer runs. Anything that is not a live share falls through.
function createWebShareProxy({ app, getRuntime }) {
  const limiter = rateLimit({
    windowMs: 60 * 1000,
    limit: 600,
    standardHeaders: 'draft-7',
    legacyHeaders: false,
    message: 'Too many requests to this shared page; try again in a minute.',
  });

  return function webShareProxy(req, res, next) {
    const match = SHARE_PATH_RE.exec(req.originalUrl || req.url);
    if (!match) return next();
    const found = findPublicShare(match[1], match[2]);
    if (!found) return next();
    const { share, user } = found;
    const prefix = `/${match[1]}/${share.slug}`;
    const rest = match[3] || '';
    const query = match[4] || '';
    if (!rest) return res.redirect(308, `${prefix}/${query}`);
    if (hasDotSegment(rest)) return res.status(400).type('text/plain').send('Bad request.');

    return limiter(req, res, () => {
      const publicUrl = app?.locals?.httpRuntimeConfig?.publicUrl || process.env.PUBLIC_URL || '';
      const secure = req.secure || /^https:/i.test(publicUrl);
      if (req.method === 'GET' && rest === HIDE_NOTICE_PATH) return hideNotice(req, res, { prefix, secure });

      const guest = getRuntime()?.runningGuestForUser?.(user.id);
      if (!guest) return sendOffline(res, found);

      // Built by hand: a URL object would resolve dot segments in the path.
      const { hostname, port } = new URL(guest.baseUrl);
      const upstream = http.request({
        hostname,
        port,
        path: `/proxy/${share.port}${rest}${query}`,
        method: req.method,
        headers: forwardedRequestHeaders(req, { prefix, token: guest.token, publicUrl }),
      }, (upstreamRes) => {
        if (upstreamRes.statusCode === 502 && upstreamRes.headers['x-neoagent-proxy']) {
          upstreamRes.resume();
          return sendOffline(res, found);
        }
        const headers = responseHeaders(upstreamRes.headers, { prefix, port: share.port });
        if (wantsNotice(req, upstreamRes)) {
          return relayWithNotice(req, res, upstreamRes, headers, noticeMarkup({
            username: user.username,
            prefix,
            returnPath: `${prefix}${rest}${query}`,
          }));
        }
        res.writeHead(upstreamRes.statusCode || 502, headers);
        return upstreamRes.pipe(res);
      });
      upstream.setTimeout(UPSTREAM_TIMEOUT_MS, () => upstream.destroy(new Error('Shared page timed out.')));
      upstream.on('error', () => (res.headersSent ? res.destroy() : sendOffline(res, found)));
      res.on('close', () => upstream.destroy());
      req.pipe(upstream);
      return undefined;
    });
  };
}

module.exports = {
  SANDBOX_POLICY,
  createWebShareProxy,
  rewriteLocation,
};
