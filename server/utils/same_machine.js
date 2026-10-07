'use strict';

const LOOPBACK_HOSTNAMES = new Set(['localhost', '127.0.0.1', '[::1]', '::1']);
const FORWARDING_HEADERS = ['forwarded', 'x-forwarded-for', 'x-forwarded-host', 'x-real-ip'];

function isLoopbackAddress(address) {
  const value = String(address || '').trim().toLowerCase();
  return value === '::1'
    || value.startsWith('127.')
    || value.startsWith('::ffff:127.');
}

function requestHostname(req) {
  const host = String(req.headers?.host || '').trim().toLowerCase();
  if (!host) return '';
  try {
    return new URL(`http://${host}`).hostname;
  } catch {
    return '';
  }
}

// True only when the client talks to this server directly over loopback:
// the TCP peer is loopback, the client addressed the server as localhost, and
// no reverse proxy sits in between (a proxy on the same host also connects
// from loopback, but forwards the public Host and adds forwarding headers).
// A browser on this request's side can therefore reach 127.0.0.1 callbacks.
function isSameMachineRequest(req) {
  if (!isLoopbackAddress(req.socket?.remoteAddress)) return false;
  if (FORWARDING_HEADERS.some((header) => req.headers?.[header] !== undefined)) return false;
  return LOOPBACK_HOSTNAMES.has(requestHostname(req));
}

module.exports = {
  isSameMachineRequest,
};
