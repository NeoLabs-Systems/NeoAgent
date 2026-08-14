'use strict';

// TEMPORARY diagnostic tracing for the cloud computer display path. Remove this file and
// its call sites (grep for `trace(`) once the frozen-desktop reports stop. Set
// NEOAGENT_COMPUTER_TRACE=0 to silence it without a code change.

const { createServiceLogger } = require('../../utils/logger');

const logger = createServiceLogger('ComputerTrace');
const enabled = String(process.env.NEOAGENT_COMPUTER_TRACE ?? '1') !== '0';

function trace(event, details = {}) {
  if (!enabled) return;
  const rendered = Object.entries(details)
    .filter(([, value]) => value !== undefined && value !== null && value !== '')
    .map(([key, value]) => `${key}=${typeof value === 'object' ? JSON.stringify(value) : value}`)
    .join(' ');
  logger.info(rendered ? `${event} ${rendered}` : event);
}

module.exports = { trace };
