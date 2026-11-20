'use strict';

const COUNTLY_ENDPOINT = new URL('https://data.neo.eu.com/i');

const config = Object.freeze({
  endpoint: COUNTLY_ENDPOINT.href,
  origin: COUNTLY_ENDPOINT.origin,
  appKey: '91fc954ad5418517ec757049fdb6b383375517ba',
});

function analyticsConfig() {
  const enabled = (process.env.ANALYTICS_ENABLED || '').trim().toLowerCase();
  return ['false', '0', 'off', 'no'].includes(enabled) ? null : config;
}

module.exports = { analyticsConfig };
