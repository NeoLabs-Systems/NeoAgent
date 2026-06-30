'use strict';

const path = require('node:path');

console.log(JSON.stringify({
  message: 'Memorybench provider installation has been folded into the unified benchmark setup flow.',
  nextSteps: [
    'Run `npm run benchmark:setup` to prepare benchmark work directories and upstream public benchmark clones.',
    `Review ${path.join('benchmark', 'workdir')} manifests for any exact-suite prerequisites that still need local infrastructure.`,
  ],
}, null, 2));
