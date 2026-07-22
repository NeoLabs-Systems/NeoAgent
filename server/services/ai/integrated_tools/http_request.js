'use strict';

const safeRequest = require('../../network/safe_request');

module.exports = {
  ...safeRequest,
  executeHttpRequest: safeRequest.executeSafeHttpRequest,
};
