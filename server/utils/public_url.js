'use strict';

// The URL clients should use to reach this server: PUBLIC_URL when configured,
// otherwise the origin the request came in on.
function publicBaseUrlForRequest(req) {
  const configured = req.app?.locals?.httpRuntimeConfig?.publicUrl || process.env.PUBLIC_URL || '';
  if (configured) {
    return String(configured).replace(/\/+$/, '');
  }
  const forwardedProto = String(req.get?.('x-forwarded-proto') || '').trim();
  const protocol = forwardedProto || req.protocol || 'http';
  return `${protocol}://${req.get('host')}`;
}

module.exports = { publicBaseUrlForRequest };
