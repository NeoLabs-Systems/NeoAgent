'use strict';

const { readEnvBool } = require('../../../runtime/env');

// The admin's server-wide switch for shared web pages; on unless turned off.
const WEB_SHARING_ENV = 'NEOAGENT_WEB_SHARING';

function isWebSharingAllowed() {
  return readEnvBool(WEB_SHARING_ENV, true);
}

module.exports = { WEB_SHARING_ENV, isWebSharingAllowed };
