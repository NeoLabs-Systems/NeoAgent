'use strict';

const { createAbortError } = require('../../utils/abort');
const {
  DEFAULT_MAX_RESPONSE_BYTES,
  fetchResponseText: fetchBoundedResponseText,
  readResponseText: readBoundedResponseText,
  waitForAbortableResult,
  waitForBoundedResult: waitForBoundedIo,
} = require('../network/http');

const DEFAULT_INTEGRATION_HTTP_TIMEOUT_MS = 15000;

function abortError(signal, fallback = 'Integration request aborted.') {
  return createAbortError(signal, fallback);
}

async function readResponseText(response, options = {}) {
  return readBoundedResponseText(response, {
    ...options,
    serviceName: String(options.serviceName || 'Integration').trim() || 'Integration',
    tooLargeCode: 'INTEGRATION_RESPONSE_TOO_LARGE',
  });
}

async function fetchResponseText(url, options = {}, context = {}) {
  return fetchBoundedResponseText(url, {
    ...options,
    serviceName: String(context.serviceName || 'Integration').trim() || 'Integration',
    timeoutCode: 'INTEGRATION_HTTP_TIMEOUT',
    tooLargeCode: 'INTEGRATION_RESPONSE_TOO_LARGE',
  });
}

async function waitForBoundedResult(promise, options = {}) {
  return waitForBoundedIo(promise, {
    ...options,
    serviceName: String(options.serviceName || 'Integration').trim() || 'Integration',
    timeoutCode: 'INTEGRATION_HTTP_TIMEOUT',
  });
}

module.exports = {
  DEFAULT_INTEGRATION_HTTP_TIMEOUT_MS,
  DEFAULT_MAX_RESPONSE_BYTES,
  abortError,
  fetchResponseText,
  readResponseText,
  waitForAbortableResult,
  waitForBoundedResult,
};
