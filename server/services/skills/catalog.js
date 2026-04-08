const { BASE_CATALOG } = require('./base_catalog');
const { BUNDLED_SKILLS_CATALOG } = require('./store_bundles');

const STORE_CATALOG = BASE_CATALOG.concat(BUNDLED_SKILLS_CATALOG);

module.exports = {
  BASE_CATALOG,
  BUNDLED_SKILLS_CATALOG,
  STORE_CATALOG,
};
