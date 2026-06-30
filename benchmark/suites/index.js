'use strict';

const { buildBrowseCompSuite } = require('./browsecomp');
const { buildGaiaSuite } = require('./gaia');
const { buildMemorySuite } = require('./neoagent_memory');
const { buildRepresentativeSuite } = require('./neoagent_representative');
const { buildSweBenchSuite } = require('./swebench');
const { buildVisualWebArenaSuite } = require('./visualwebarena');
const { buildWebArenaSuite } = require('./webarena');

function createSuites(config) {
  return [
    buildGaiaSuite(config),
    buildBrowseCompSuite(config),
    buildWebArenaSuite(config),
    buildVisualWebArenaSuite(config),
    buildSweBenchSuite(config),
    buildRepresentativeSuite(config),
    buildMemorySuite(config),
  ];
}

module.exports = {
  createSuites,
};
