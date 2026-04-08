'use strict';

const net = require('net');
const geoip = require('geoip-lite');

function normalizeIp(value) {
  const raw = String(value || '').trim();
  if (!raw) return '';
  const first = raw.split(',')[0].trim();
  if (first.startsWith('::ffff:')) return first.slice(7);
  if (first === '::1') return '127.0.0.1';
  return first;
}

function isLoopback(ip) {
  return ip === '127.0.0.1' || ip === '::1' || ip === 'localhost';
}

function isPrivateIpv4(ip) {
  const parts = ip.split('.').map((part) => Number(part));
  if (parts.length !== 4 || parts.some((part) => !Number.isInteger(part) || part < 0 || part > 255)) {
    return false;
  }
  const [a, b] = parts;
  return a === 10
    || (a === 172 && b >= 16 && b <= 31)
    || (a === 192 && b === 168)
    || (a === 169 && b === 254);
}

function isPrivateIpv6(ip) {
  const lower = ip.toLowerCase();
  return lower.startsWith('fc') || lower.startsWith('fd') || lower.startsWith('fe80:');
}

function locationFromGeoRecord(record) {
  if (!record) return { label: 'Unknown', data: {} };
  const parts = [record.city, record.region, record.country]
    .map((part) => String(part || '').trim())
    .filter(Boolean);
  return {
    label: parts.length ? parts.join(', ') : 'Unknown',
    data: {
      city: record.city || null,
      region: record.region || null,
      country: record.country || null,
      timezone: record.timezone || null,
      ll: Array.isArray(record.ll) ? record.ll : null,
    },
  };
}

function lookupIpLocation(value) {
  const ip = normalizeIp(value);
  if (!ip || net.isIP(ip) === 0) {
    return { ipAddress: ip || null, label: 'Unknown', data: {} };
  }
  if (isLoopback(ip)) {
    return { ipAddress: ip, label: 'Local network', data: { kind: 'loopback' } };
  }
  if ((net.isIPv4(ip) && isPrivateIpv4(ip)) || (net.isIPv6(ip) && isPrivateIpv6(ip))) {
    return { ipAddress: ip, label: 'Private network', data: { kind: 'private' } };
  }

  try {
    const location = locationFromGeoRecord(geoip.lookup(ip));
    return { ipAddress: ip, ...location };
  } catch {
    return { ipAddress: ip, label: 'Unknown', data: {} };
  }
}

function clientIpFromRequest(req) {
  return normalizeIp(req.ip || req.connection?.remoteAddress || req.socket?.remoteAddress || '');
}

module.exports = {
  clientIpFromRequest,
  lookupIpLocation,
  normalizeIp,
};
