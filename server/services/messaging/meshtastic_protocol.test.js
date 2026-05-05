const test = require('node:test');
const assert = require('node:assert/strict');

const {
  MeshtasticConnection,
  NODELESS_WANT_CONFIG_ID,
  decodeFields,
  encodeToRadioWantConfig,
} = require('./meshtastic_protocol');

test('nodeless startup uses Meshtastic special want_config_id', () => {
  const connection = new MeshtasticConnection({ noNodes: true });
  assert.equal(connection._configId, NODELESS_WANT_CONFIG_ID);
});

test('default startup never collides with nodeless want_config_id', () => {
  const originalRandom = Math.random;
  Math.random = () => NODELESS_WANT_CONFIG_ID / 0xFFFFFFFF;
  try {
    const connection = new MeshtasticConnection();
    assert.notEqual(connection._configId, NODELESS_WANT_CONFIG_ID);
  } finally {
    Math.random = originalRandom;
  }
});

test('want_config packets encode the requested config id in field 3', () => {
  const packet = Buffer.from(encodeToRadioWantConfig(NODELESS_WANT_CONFIG_ID));
  const fields = decodeFields(packet);
  assert.deepEqual(fields, [
    { field: 3, wire: 0, value: NODELESS_WANT_CONFIG_ID },
  ]);
});
