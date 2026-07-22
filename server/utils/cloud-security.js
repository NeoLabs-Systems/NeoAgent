'use strict';

const dns = require('node:dns');
const net = require('node:net');

const ALLOWED_SCHEMES = new Set(['http', 'https']);
const BLOCKED_ANDROID_INTENT_SCHEMES = new Set([
  'about',
  'chrome',
  'chrome-extension',
  'content',
  'data',
  'file',
  'javascript',
  'vbscript',
]);

function urlAbortError(signal) {
  if (signal?.reason instanceof Error) return signal.reason;
  const error = new Error('URL validation was aborted.');
  error.name = 'AbortError';
  error.code = 'ABORT_ERR';
  return error;
}

// URL schemes that must never be navigated to in the cloud browser or Android.
const BLOCKED_SCHEMES = new Set([
  'javascript',
  'file',
  'chrome',
  'chrome-extension',
  'about',
  'vbscript',
  'data',
]);

// Adult-content TLDs. The dot is part of the suffix so ".com" is not matched.
const BLOCKED_TLDS = new Set(['.xxx', '.porn', '.sex', '.adult', '.sexy']);

// Private/internal IPv4 patterns for SSRF prevention.
const PRIVATE_IPV4 = [
  /^127\./,           // loopback
  /^10\./,            // private class A
  /^172\.(1[6-9]|2\d|3[01])\./,  // private class B
  /^192\.168\./,      // private class C
  /^169\.254\./,      // link-local
  /^100\.(6[4-9]|[7-9]\d|1[01]\d|12[0-7])\./, // CGNAT
  /^0\./,             // reserved
  /^255\./,           // broadcast
];

function isPrivateHost(hostname) {
  if (!hostname) return false;
  let h = hostname.toLowerCase().replace(/^\[|\]$/g, '');

  if (h === 'localhost' || h === 'localhost.localdomain') return true;
  if (h.endsWith('.local') || h.endsWith('.internal') || h.endsWith('.localhost')) return true;

  // Unwrap IPv4-mapped/compatible IPv6 (e.g. ::ffff:127.0.0.1 or ::ffff:7f00:1)
  // so the embedded IPv4 address is checked against the private ranges below.
  const mapped = h.match(/^::(?:ffff:)?(?:0:)?([0-9a-f.:]+)$/);
  if (mapped) {
    const tail = mapped[1];
    if (tail.includes('.')) {
      // Dotted IPv4 form, e.g. ::ffff:127.0.0.1
      h = tail;
    } else {
      // Hex form, e.g. ::ffff:7f00:1 -> reconstruct dotted IPv4.
      const groups = tail.split(':');
      if (groups.length === 2) {
        const hi = parseInt(groups[0], 16);
        const lo = parseInt(groups[1], 16);
        if (Number.isFinite(hi) && Number.isFinite(lo) && hi <= 0xffff && lo <= 0xffff) {
          h = `${(hi >> 8) & 0xff}.${hi & 0xff}.${(lo >> 8) & 0xff}.${lo & 0xff}`;
        }
      }
    }
  }

  // IPv6 loopback, link-local and unique-local
  if (h === '::1' || h === '::') return true;
  if (/^fe[89ab][0-9a-f]:/.test(h)) return true; // fe80::/10 link-local
  if (/^fe[c-f][0-9a-f]:/.test(h)) return true; // fec0::/10 deprecated site-local
  if (/^f[cd][0-9a-f]*:/.test(h)) return true; // fc00::/7 unique-local
  if (h.startsWith('ff')) return true; // IPv6 multicast
  if (h === '100::' || h.startsWith('100::')) return true; // discard-only prefix
  if (h === '2001:db8::' || h.startsWith('2001:db8:')) return true; // documentation

  if (net.isIPv4(h)) {
    const [a, b, c] = h.split('.').map(Number);
    if (a === 0 || a === 10 || a === 127 || a >= 224) return true;
    if (a === 100 && b >= 64 && b <= 127) return true;
    if (a === 169 && b === 254) return true;
    if (a === 172 && b >= 16 && b <= 31) return true;
    if (a === 192 && b === 168) return true;
    if (a === 192 && b === 0 && c === 0) return true;
    if (a === 192 && b === 0 && c === 2) return true;
    if (a === 198 && (b === 18 || b === 19)) return true;
    if (a === 198 && b === 51 && c === 100) return true;
    if (a === 203 && b === 0 && c === 113) return true;
  }

  for (const pattern of PRIVATE_IPV4) {
    if (pattern.test(h)) return true;
  }

  return false;
}

function isBlockedTld(hostname) {
  const h = hostname.toLowerCase();
  for (const tld of BLOCKED_TLDS) {
    if (h === tld.slice(1) || h.endsWith(tld)) return true;
  }
  return false;
}

/**
 * Validates a URL for use in the cloud browser or Android.
 * Returns { allowed: true } when safe, or { allowed: false } when blocked.
 * The caller should respond with a generic 403 — do not expose which rule matched.
 */
function validateCloudUrl(urlString) {
  if (!urlString || typeof urlString !== 'string') return { allowed: false };

  let parsed;
  try {
    parsed = new URL(urlString);
  } catch {
    return { allowed: false };
  }

  const scheme = parsed.protocol.replace(/:$/, '').toLowerCase();
  if (BLOCKED_SCHEMES.has(scheme) || !ALLOWED_SCHEMES.has(scheme)) return { allowed: false };

  const hostname = parsed.hostname;
  if (isPrivateHost(hostname)) return { allowed: false };
  if (isBlockedTld(hostname)) return { allowed: false };

  return { allowed: true };
}

async function validateCloudUrlWithDns(urlString, options = {}) {
  if (options.signal?.aborted) {
    throw urlAbortError(options.signal);
  }
  const syntactic = validateCloudUrl(urlString);
  if (!syntactic.allowed) return syntactic;

  const hostname = new URL(urlString).hostname.replace(/^\[|\]$/g, '');
  if (net.isIP(hostname)) return { allowed: !isPrivateHost(hostname) };

  const lookup = options.lookup || dns.promises.lookup;
  const timeoutMs = Math.max(100, Math.min(Number(options.timeoutMs) || 5000, 30_000));
  let timer = null;
  let onAbort = null;
  try {
    const pending = [
      lookup(hostname, { all: true, verbatim: true }),
      new Promise((_, reject) => {
        timer = setTimeout(() => reject(new Error('DNS lookup timed out.')), timeoutMs);
        timer.unref?.();
      }),
    ];
    if (options.signal) {
      pending.push(new Promise((_, reject) => {
        onAbort = () => {
          reject(urlAbortError(options.signal));
        };
        options.signal.addEventListener('abort', onAbort, { once: true });
      }));
    }
    const addresses = await Promise.race(pending);
    const resolved = Array.isArray(addresses) ? addresses : [addresses];
    if (resolved.length === 0) return { allowed: false };
    if (resolved.some((entry) => isPrivateHost(entry?.address || entry))) {
      return { allowed: false };
    }
    return { allowed: true };
  } catch (error) {
    if (options.signal?.aborted) throw error;
    return { allowed: false };
  } finally {
    if (timer) clearTimeout(timer);
    if (onAbort) options.signal?.removeEventListener('abort', onAbort);
  }
}

async function validateAndroidIntentUrl(urlString, options = {}) {
  if (!urlString || typeof urlString !== 'string') return { allowed: false };
  let parsed;
  try {
    parsed = new URL(urlString);
  } catch {
    return { allowed: false };
  }
  const scheme = parsed.protocol.replace(/:$/, '').toLowerCase();
  if (BLOCKED_ANDROID_INTENT_SCHEMES.has(scheme)) return { allowed: false };
  if (ALLOWED_SCHEMES.has(scheme)) {
    return validateCloudUrlWithDns(urlString, options);
  }
  return { allowed: /^[a-z][a-z0-9+.-]*$/.test(scheme) };
}

module.exports = {
  validateAndroidIntentUrl,
  validateCloudUrl,
  validateCloudUrlWithDns,
  isPrivateHost,
};
