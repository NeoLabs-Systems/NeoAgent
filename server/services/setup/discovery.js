'use strict';

const { Bonjour } = require('bonjour-service');
const { DEFAULT_NEOAGENT_PORT } = require('../../../lib/setup/contract');
const { createServiceLogger } = require('../../utils/logger');

const logger = createServiceLogger('SetupDiscovery');
const SERVICE_TYPE = 'neoagent';

function buildDiscoveryTxt(handshake) {
  return {
    instanceId: handshake.instanceId,
    protocolVersion: String(handshake.protocolVersion),
    serverVersion: handshake.serverVersion,
    claimed: handshake.claimed ? '1' : '0',
    transport: 'http',
  };
}

function startSetupDiscovery({
  port = Number(process.env.PORT) || DEFAULT_NEOAGENT_PORT,
} = {}) {
  if (String(process.env.NEOAGENT_DISABLE_MDNS || '').trim().toLowerCase() === 'true') {
    return null;
  }
  const { getSetupHandshake } = require('./onboarding');
  const bonjour = new Bonjour();
  const handshake = getSetupHandshake();
  const service = bonjour.publish({
    name: handshake.displayName,
    type: SERVICE_TYPE,
    protocol: 'tcp',
    port,
    txt: buildDiscoveryTxt(handshake),
  });
  service.on('error', (error) => {
    logger.warn(`Local discovery could not advertise: ${error.message}`);
  });
  logger.info(`Advertising ${handshake.displayName} on _${SERVICE_TYPE}._tcp.local:${port}`);
  return {
    stop() {
      try {
        service.stop();
      } catch {}
      try {
        bonjour.destroy();
      } catch {}
    },
  };
}

module.exports = {
  SERVICE_TYPE,
  buildDiscoveryTxt,
  startSetupDiscovery,
};
