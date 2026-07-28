'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const test = require('node:test');

const {
  SETUP_CONTRACT,
  loadSetupContract,
} = require('../../../lib/setup/contract');
const {
  outputPath,
  renderContract,
} = require('../../../scripts/generate_setup_contract');

test('generated Flutter setup contract matches the canonical contract', () => {
  assert.equal(fs.readFileSync(outputPath, 'utf8'), renderContract());
  assert.equal(SETUP_CONTRACT.profiles.quick.optionalCapabilities, false);
  assert.equal(SETUP_CONTRACT.profiles.full.optionalCapabilities, true);
});

test('setup contract rejects duplicate profiles and wizard sections', () => {
  const duplicateProfile = structuredClone(SETUP_CONTRACT);
  duplicateProfile.profiles = [
    SETUP_CONTRACT.profiles.quick,
    SETUP_CONTRACT.profiles.quick,
  ];
  assert.throws(
    () => loadSetupContract(duplicateProfile),
    /Duplicate setup profile/,
  );

  const duplicateSection = structuredClone(SETUP_CONTRACT);
  duplicateSection.profiles = Object.values(SETUP_CONTRACT.profiles);
  duplicateSection.wizardSections = [
    SETUP_CONTRACT.wizardSections[0],
    SETUP_CONTRACT.wizardSections[0],
  ];
  assert.throws(
    () => loadSetupContract(duplicateSection),
    /Duplicate setup wizard section/,
  );
});
