'use strict';

const { commandExists, exists, missingPrerequisiteResult, writeSuiteManifest, writeText } = require('./shared');
const { executeCommand } = require('../utils');

async function tryExportGaiaCases(config) {
  const suite = config.suitePaths.gaia;
  if (!config.allowSetupDownloads) return;
  const pythonAvailable = await commandExists('python3');
  if (!pythonAvailable || !process.env.HF_TOKEN) return;
  const script = [
    'import json',
    'from datasets import load_dataset',
    `dataset = load_dataset("gaia-benchmark/GAIA", "2023_all", split="validation")`,
    `with open(${JSON.stringify(suite.casesPath)}, "w", encoding="utf-8") as fh:`,
    '  for row in dataset:',
    '    payload = {',
    '      "id": row.get("task_id") or row.get("id"),',
    '      "prompt": row.get("Question") or row.get("question"),',
    '      "answer": row.get("Final answer") or row.get("final_answer"),',
    '    }',
    '    fh.write(json.dumps(payload, ensure_ascii=False) + "\\n")',
  ].join('\n');
  await executeCommand(`python3 - <<'PY'\n${script}\nPY`);
}

function buildGaiaSuite(config) {
  const suitePaths = config.suitePaths.gaia;
  return {
    id: 'gaia',
    label: 'GAIA',
    benchmarkType: 'public',
    modelDriven: true,
    sourceUrl: suitePaths.sourceUrl,

    async setup() {
      await writeSuiteManifest(suitePaths.manifestPath, {
        suiteId: 'gaia',
        sourceUrl: suitePaths.sourceUrl,
        casesPath: suitePaths.casesPath,
        runnerCommand: suitePaths.runnerCommand || null,
        notes: [
          'GAIA is a gated dataset on Hugging Face.',
          'Provide HF_TOKEN and a Python environment with datasets installed to auto-export cases.',
          'Otherwise place an exact normalized JSONL cache at benchmark/workdir/gaia/cases.jsonl.',
        ],
      });
      await writeText(
        suitePaths.manifestPath.replace(/\.json$/, '.README.txt'),
        'GAIA setup expects either a normalized JSONL cache or an external exact runner command.\n',
      );
      await tryExportGaiaCases(config);
      return { suiteId: this.id, manifestPath: suitePaths.manifestPath };
    },

    async preflight() {
      const hasCases = await exists(suitePaths.casesPath);
      if (!hasCases && !suitePaths.runnerCommand) {
        return {
          runnable: false,
          reason: 'GAIA cases are not present locally and no external exact GAIA runner command is configured.',
        };
      }
      if (suitePaths.runnerCommand) {
        return { runnable: false, reason: 'GAIA exact execution is delegated to an external runner command and is not configured in this repository yet.' };
      }
      return { runnable: false, reason: 'GAIA normalized case execution requires an exact official evaluator command.' };
    },

    async run(_context, model, preflight) {
      return [missingPrerequisiteResult(this, preflight.reason, model)];
    },
  };
}

module.exports = {
  buildGaiaSuite,
};
