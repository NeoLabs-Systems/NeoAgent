'use strict';

const fs = require('node:fs/promises');
const path = require('node:path');
const {
  buildSignalCoverage,
  evaluateStructuredJudge,
  missingPrerequisiteResult,
  readJson,
} = require('./shared');

const WORKSPACE_SEED_FILES = Object.freeze([
  {
    sourcePath: 'README.md',
    workspacePath: 'README.md',
  },
  {
    sourcePath: path.join('docs', 'why-neoagent.md'),
    workspacePath: path.join('docs', 'why-neoagent.md'),
  },
]);

function countToolEvents(events) {
  return (events || [])
    .filter((event) => ['tool_completed', 'tool_failed'].includes(event.eventType))
    .length;
}

function collectArtifactRefs(events) {
  return (events || [])
    .filter((event) => event.eventType === 'deliverable_artifact_produced')
    .map((event) => event.payload?.artifact)
    .filter(Boolean);
}

function determineCaseBlocked(caseDefinition, systemHealth) {
  if (caseDefinition.requiresRuntime && systemHealth?.runtime?.ready !== true) {
    return 'Runtime validation is not ready for this benchmark case.';
  }
  return '';
}

async function configureModel(client, appModel) {
  await client.putSettings({
    ai_provider_configs: {
      openrouter: {
        enabled: true,
        baseUrl: 'https://openrouter.ai/api/v1',
      },
      openai: { enabled: false, baseUrl: '' },
      anthropic: { enabled: false, baseUrl: '' },
      google: { enabled: false, baseUrl: '' },
      grok: { enabled: false, baseUrl: 'https://api.x.ai/v1' },
      'grok-oauth': { enabled: false, baseUrl: '' },
      nvidia: { enabled: false, baseUrl: 'https://integrate.api.nvidia.com/v1' },
      minimax: { enabled: false, baseUrl: 'https://api.minimax.io/anthropic' },
      'github-copilot': { enabled: false, baseUrl: 'https://api.githubcopilot.com' },
      'openai-codex': { enabled: false, baseUrl: 'https://chatgpt.com/backend-api/codex' },
      'claude-code': { enabled: false, baseUrl: '' },
      ollama: { enabled: false, baseUrl: 'http://localhost:11434' },
    },
    enabled_models: [appModel.id],
    default_chat_model: appModel.id,
    fallback_model_id: appModel.id,
    smarter_model_selector: false,
  });
}

async function seedRepresentativeWorkspace(context) {
  if (typeof context.client.writeWorkspaceFile !== 'function') return;

  const files = await Promise.all(WORKSPACE_SEED_FILES.map(async (file) => ({
    workspacePath: file.workspacePath,
    content: await fs.readFile(path.join(context.config.rootDir, file.sourcePath), 'utf8'),
  })));

  await Promise.all(files.map((file) =>
    context.client.writeWorkspaceFile(file.workspacePath, file.content)));
}

function buildRepresentativeSuite(config) {
  return {
    id: 'neoagent_representative',
    label: 'NeoAgent Representative Tasks',
    benchmarkType: 'first_party',
    modelDriven: true,

    async setup(context) {
      const suitePaths = config.suitePaths.neoagent_representative;
      return {
        suiteId: this.id,
        casesPath: suitePaths.casesPath,
        rubricPath: suitePaths.rubricPath,
      };
    },

    async preflight() {
      const suitePaths = config.suitePaths.neoagent_representative;
      const [cases, rubric] = await Promise.all([
        readJson(suitePaths.casesPath),
        readJson(suitePaths.rubricPath),
      ]);
      const rubricById = new Map(rubric.map((entry) => [entry.id, entry]));
      const resolvedCases = cases.map((entry) => ({
        ...entry,
        rubric: rubricById.get(entry.id) || null,
      }));
      return {
        runnable: true,
        cases: resolvedCases,
      };
    },

    async run(context, model, preflight) {
      const systemHealth = await context.client.getHealth().catch(() => null);
      await seedRepresentativeWorkspace(context);
      await configureModel(context.client, model);
      const results = [];

      for (const caseDefinition of preflight.cases) {
        const rubric = caseDefinition.rubric;
        if (!rubric) {
          results.push(missingPrerequisiteResult(this, `No representative rubric was found for case ${caseDefinition.id}.`, model, caseDefinition.id));
          continue;
        }

        const blockedReason = determineCaseBlocked(caseDefinition, systemHealth);
        if (blockedReason) {
          results.push(missingPrerequisiteResult(this, blockedReason, model, caseDefinition.id));
          continue;
        }

        const startedAt = Date.now();
        try {
          const runResponse = await context.client.runAgentTask(caseDefinition.prompt, caseDefinition.options || {});
          const runId = runResponse?.runId || null;
          const details = runId ? await context.client.getRunSteps(runId) : null;
          const signalCoverage = buildSignalCoverage(rubric.requiredSignals, details?.events || []);
          const artifacts = collectArtifactRefs(details?.events || []);
          const toolCalls = countToolEvents(details?.events || []);
          const judge = evaluateStructuredJudge(details?.response || runResponse?.content || '', caseDefinition.judge || {});
          const missingArtifacts = rubric.requiredArtifacts === true && artifacts.length === 0;
          const overToolBudget = Number.isInteger(rubric.maximumToolCalls) && toolCalls > rubric.maximumToolCalls;
          const passed = signalCoverage.satisfied && judge.passed && !missingArtifacts && !overToolBudget;

          results.push({
            suiteId: this.id,
            suiteLabel: this.label,
            benchmarkType: this.benchmarkType,
            modelDriven: true,
            caseId: caseDefinition.id,
            status: passed ? 'passed' : 'failed',
            score: passed ? 1 : 0,
            reason: [
              signalCoverage.satisfied ? '' : `Missing run signals: ${signalCoverage.missing.join(', ')}`,
              judge.reason || '',
              missingArtifacts ? 'No artifact was captured for an artifact-required case.' : '',
              overToolBudget ? `Tool budget exceeded: ${toolCalls}/${rubric.maximumToolCalls}.` : '',
            ].filter(Boolean).join(' '),
            provider: model.provider,
            modelId: model.id,
            priceTier: model.priceTier || null,
            latencyMs: Date.now() - startedAt,
            tokenUsage: details?.usage?.totals || null,
            estimatedCostUsd: Number.isFinite(details?.usage?.totals?.estimatedCostUsd)
              ? Number(details.usage.totals.estimatedCostUsd)
              : context.estimateRunCost(details?.usage?.totals, model),
            finalResponse: details?.response || runResponse?.content || '',
            runId,
            artifactRefs: artifacts,
            requiredSignalCoverage: signalCoverage,
            metadata: {
              title: caseDefinition.title,
              category: caseDefinition.category,
              requiredArtifacts: rubric.requiredArtifacts === true,
              toolCalls,
            },
          });
        } catch (error) {
          results.push({
            suiteId: this.id,
            suiteLabel: this.label,
            benchmarkType: this.benchmarkType,
            modelDriven: true,
            caseId: caseDefinition.id,
            status: 'error',
            score: 0,
            reason: error?.message || 'Representative benchmark case failed to execute.',
            provider: model.provider,
            modelId: model.id,
            priceTier: model.priceTier || null,
            latencyMs: Date.now() - startedAt,
            tokenUsage: null,
            estimatedCostUsd: null,
            finalResponse: '',
            runId: null,
            artifactRefs: [],
            requiredSignalCoverage: null,
            metadata: {
              title: caseDefinition.title,
              category: caseDefinition.category,
            },
          });
        }
      }

      return results;
    },
  };
}

module.exports = {
  buildRepresentativeSuite,
};
