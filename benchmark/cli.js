'use strict';

const { loadBenchmarkEnv } = require('./bootstrap_env');
const { BenchmarkHarness } = require('./harness');
const { readJson } = require('./utils');
const { resolveBenchmarkConfig } = require('./config');
const { writeReportArtifacts } = require('./reporting');

function parseCommand(argv) {
  const [command = 'run'] = argv;
  return command;
}

async function main(argv = process.argv.slice(2)) {
  loadBenchmarkEnv();
  const command = parseCommand(argv);
  const config = resolveBenchmarkConfig();
  const harness = new BenchmarkHarness(config);

  switch (command) {
    case 'setup': {
      const result = await harness.setup();
      console.log(JSON.stringify({ command, result }, null, 2));
      return;
    }
    case 'run': {
      const result = await harness.run();
      console.log(JSON.stringify({
        command,
        totals: result.report.summary.totals,
        outputs: result.report.outputs,
      }, null, 2));
      return;
    }
    case 'report': {
      try {
        config.selectedModels = await harness.resolveSelectedModels();
      } catch {}
      let results = [];
      try {
        results = await readJson(config.suitePaths.outputs.resultsJsonPath);
      } catch {}
      const report = await writeReportArtifacts({ results, config });
      console.log(JSON.stringify({
        command,
        totals: report.summary.totals,
        outputs: report.outputs,
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
