'use strict';

const { main } = require('../benchmark/cli');

main(['report']).catch((error) => {
  console.error('[benchmark:tokens]', error.message);
  process.exit(1);
});
