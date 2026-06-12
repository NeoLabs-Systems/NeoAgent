'use strict';

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
  if (h.startsWith('fe80:')) return true;
  if (/^f[cd][0-9a-f]*:/.test(h)) return true; // fc00::/7 unique-local

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
  if (BLOCKED_SCHEMES.has(scheme)) return { allowed: false };

  const hostname = parsed.hostname;
  if (isPrivateHost(hostname)) return { allowed: false };
  if (isBlockedTld(hostname)) return { allowed: false };

  return { allowed: true };
}

module.exports = { validateCloudUrl, isPrivateHost };
