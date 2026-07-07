'use strict';

const { ensureDir, limitCases, mapWithConcurrency, readJson } = require('./utils');
const { NeoAgentHttpClient } = require('./http_client');
const { ensureLocomoDataset, summarizeLocomoDataset } = require('./locomo/fetch');
const { buildQaManifest, buildSessionDocuments } = require('./locomo/convert');
const { renderAnswerPrompt, renderAccuracyPrompt } = require('./locomo/prompts');
const { fetchOpenRouterCatalog, selectModel } = require('./model_catalog');
const { openRouterChat } = require('./openrouter_client');
const { writeReportArtifacts } = require('./reporting');

// Draining background LLM extraction: NeoAgent only promotes raw ingested chunks into
// structured memories as a side effect of the agent loop's memory-recall step
// (server/services/ai/loop/agent_engine_core.js buildMemoryRecall), which drains up to
// 5 pending chunks per call. The plain recall endpoint used for QA-head retrieval does
// not trigger this, so a handful of trivial agent runs settle extraction first.
const DRAIN_BATCH_SIZE = 5;
const DRAIN_TASK = 'Reply with just the word "ok".';
const MAX_DRAIN_ROUNDS = 12;

function formatMemoriesForPrompt(recallResults) {
  if (!recallResults.length) return '(no memories retrieved)';
  return recallResults
    .map((memory, index) => {
      const when = memory.created_at || memory.updated_at || '';
      const label = when ? ` (recorded ${when})` : '';
      return `Memory ${index + 1}${label}:\n${memory.summary || memory.content || ''}`;
    })
    .join('\n\n');
}

function extractJudgeLabel(rawContent) {
  const jsonMatch = String(rawContent || '').match(/\{[\s\S]*\}/);
  if (jsonMatch) {
    try {
      const parsed = JSON.parse(jsonMatch[0]);
      if (parsed && typeof parsed.label === 'string') {
        return parsed.label.toUpperCase().startsWith('C') ? 'CORRECT' : 'WRONG';
      }
    } catch {
      // fall through to plain-text extraction below
    }
  }
  const matches = String(rawContent || '').toUpperCase().match(/CORRECT|WRONG/g);
  return matches && matches.length ? matches[matches.length - 1] : 'WRONG';
}

async function resolveModels(config) {
  if (!config.openRouter.apiKey) {
    throw new Error(
      'OPENROUTER_API_KEY is required: it configures each benchmark account\'s memory '
      + 'extraction provider and drives the answerer/judge models.',
    );
  }
  const catalog = await fetchOpenRouterCatalog(config.openRouter);
  if (!catalog.length) {
    throw new Error('No OpenRouter models were returned. Check OPENROUTER_API_KEY and network access.');
  }
  const answerModel = selectModel(catalog, config.openRouter.answerModelId);
  const judgeModel = selectModel(catalog, config.openRouter.judgeModelId);
  if (!answerModel || !judgeModel) {
    throw new Error('Could not resolve an OpenRouter model for answering/judging.');
  }
  return { answerModel, judgeModel };
}

async function registerSampleAccount(config, sampleId, models) {
  const client = new NeoAgentHttpClient(config.serverBaseUrl);
  const username = `${config.benchmarkUser.usernamePrefix}_${sampleId}`
    .toLowerCase()
    .replace(/[^a-z0-9_]/g, '')
    .slice(0, 60);
  const auth = {
    username,
    password: config.benchmarkUser.password,
    email: `${username}@${config.benchmarkUser.emailDomain}`,
  };
  await client.ensureAuthenticated(auth);
  await client.putSettings({
    ai_provider_configs: {
      openrouter: {
        enabled: true,
        baseUrl: config.openRouter.baseUrl,
        apiKey: config.openRouter.apiKey,
      },
    },
    // The account's own agent loop drives extraction of ingested chunks (see
    // drainExtraction below) and needs a working default model of its own, distinct
    // from the answerer/judge models the harness calls directly.
    default_chat_model: models.answerModel.id,
    default_subagent_model: models.answerModel.id,
    smarter_model_selector: false,
  });
  return client;
}

async function drainExtraction(client, pendingChunkCount) {
  const rounds = Math.min(MAX_DRAIN_ROUNDS, Math.max(1, Math.ceil(pendingChunkCount / DRAIN_BATCH_SIZE)));
  for (let round = 0; round < rounds; round += 1) {
    try {
      await client.runAgentTask(DRAIN_TASK);
    } catch (err) {
      console.warn(`[locomo] extraction drain round ${round + 1} failed: ${err.message}`);
    }
  }
}

async function ingestSample(client, sample) {
  const documents = buildSessionDocuments(sample);
  if (!documents.length) return { memoryIds: [] };
  return client.ingestDocuments(documents, {
    sourceType: 'chat',
    metadata: { benchmark: 'locomo', sampleId: sample.sample_id },
  });
}

async function answerQuestion({ config, client, models, question }) {
  const startedAt = Date.now();
  const recall = await client.recallMemories(question.question, config.locomo.memK);
  const recallResults = Array.isArray(recall) ? recall : (recall?.results || []);

  const answerPrompt = renderAnswerPrompt({
    memories: formatMemoriesForPrompt(recallResults),
    question: question.question,
  });
  const answerResponse = await openRouterChat({
    baseUrl: config.openRouter.baseUrl,
    apiKey: config.openRouter.apiKey,
    model: models.answerModel.id,
    prompt: answerPrompt,
    maxTokens: 700,
  });
  const generated = answerResponse.content.slice(0, 600);

  const judgePrompt = renderAccuracyPrompt({
    question: question.question,
    goldAnswer: question.answer,
    generatedAnswer: generated,
  });
  const judgeResponse = await openRouterChat({
    baseUrl: config.openRouter.baseUrl,
    apiKey: config.openRouter.apiKey,
    model: models.judgeModel.id,
    prompt: judgePrompt,
    maxTokens: 150,
  });

  return {
    questionId: question.questionId,
    questionType: question.questionType,
    question: question.question,
    goldAnswer: question.answer,
    generated,
    label: extractJudgeLabel(judgeResponse.content),
    retrievedMemoryIds: recallResults.map((memory) => memory.id),
    latencyMs: Date.now() - startedAt,
    answerModelId: models.answerModel.id,
    judgeModelId: models.judgeModel.id,
    answerUsage: answerResponse.usage,
    judgeUsage: judgeResponse.usage,
  };
}

async function setup(config) {
  await ensureDir(config.workDir);
  await ensureDir(config.outputDir);
  const dataset = await ensureLocomoDataset({
    datasetPath: config.locomo.datasetPath,
    sourceUrl: config.locomo.sourceUrl,
    allowDownload: config.allowDatasetDownload,
  });
  return summarizeLocomoDataset(dataset);
}

async function run(config) {
  await ensureDir(config.workDir);
  await ensureDir(config.outputDir);

  const models = await resolveModels(config);
  const dataset = await ensureLocomoDataset({
    datasetPath: config.locomo.datasetPath,
    sourceUrl: config.locomo.sourceUrl,
    allowDownload: config.allowDatasetDownload,
  });
  const samples = dataset.slice(config.locomo.offset, config.locomo.offset + config.locomo.samples);
  if (!samples.length) {
    throw new Error(
      `No LoCoMo samples selected (offset ${config.locomo.offset}, samples `
      + `${config.locomo.samples}, dataset size ${dataset.length}).`,
    );
  }

  const tasks = [];
  for (const sample of samples) {
    console.log(`[locomo] ingesting ${sample.sample_id}...`);
    const client = await registerSampleAccount(config, sample.sample_id, models);
    const ingestResult = await ingestSample(client, sample);
    await drainExtraction(client, (ingestResult.memoryIds || []).length);

    for (const question of buildQaManifest(sample, { qaPerSample: config.locomo.qaPerSample })) {
      tasks.push({ client, question });
    }
  }

  const selectedTasks = config.caseLimit > 0 ? limitCases(tasks, config.caseLimit) : tasks;
  console.log(
    `[locomo] running QA-head over ${selectedTasks.length} questions `
    + `(answer=${models.answerModel.id}, judge=${models.judgeModel.id})`,
  );

  const rows = await mapWithConcurrency(selectedTasks, config.concurrency, async ({ client, question }) => {
    try {
      const row = await answerQuestion({ config, client, models, question });
      console.log(`[locomo] ${row.label === 'CORRECT' ? '✓' : '✗'} ${row.questionType} ${row.question.slice(0, 60)}`);
      return row;
    } catch (err) {
      console.warn(`[locomo] error on ${question.questionId}: ${err.message}`);
      return {
        questionId: question.questionId,
        questionType: question.questionType,
        question: question.question,
        goldAnswer: question.answer,
        generated: '',
        label: 'ERROR',
        error: err.message,
      };
    }
  });

  return writeReportArtifacts({ rows, config });
}

async function report(config) {
  let rows = [];
  try {
    rows = await readJson(config.outputs.resultsJsonPath);
  } catch {
    // no prior run to report on; write an empty report below
  }
  return writeReportArtifacts({ rows, config });
}

module.exports = {
  report,
  run,
  setup,
};
