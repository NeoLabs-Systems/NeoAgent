'use strict';

const { main } = require('../benchmark/cli');

main(['run']).catch((error) => {
  console.error('[benchmark:memory]', error.message);
  process.exit(1);
});
