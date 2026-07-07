'use strict';

const { loadBenchmarkEnv } = require('./bootstrap_env');
const memoryBenchmark = require('./memory_benchmark');
const { resolveBenchmarkConfig } = require('./config');

function parseCommand(argv) {
  const [command = 'run'] = argv;
  return command;
}

async function main(argv = process.argv.slice(2)) {
  loadBenchmarkEnv();
  const command = parseCommand(argv);
  const config = resolveBenchmarkConfig();

  switch (command) {
    case 'setup': {
      const result = await memoryBenchmark.setup(config);
      console.log(JSON.stringify({ command, result }, null, 2));
      return;
    }
    case 'run': {
      const result = await memoryBenchmark.run(config);
      console.log(JSON.stringify({
        command,
        totals: result.summary.totals,
        outputs: result.outputs,
      }, null, 2));
      return;
    }
    case 'report': {
      const result = await memoryBenchmark.report(config);
      console.log(JSON.stringify({
        command,
        totals: result.summary.totals,
        outputs: result.outputs,
      }, null, 2));
      return;
    }
    default:
      throw new Error(`Unknown benchmark command: ${command}`);
  }
}

if (require.main === module) {
  main().catch((error) => {
    console.error('[benchmark]', error.message);
    process.exit(1);
  });
}

module.exports = {
  main,
};
