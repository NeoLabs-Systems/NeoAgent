'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const { extractArtifactsFromResult } = require('./artifact_helpers');
const { getDeliverableWorkflow } = require('./workflows');
const { validateDeliverableExecution } = require('./validator');

test('extractArtifactsFromResult collects artifact urls and local file paths', async () => {
  const artifacts = await extractArtifactsFromResult('generate_image', {
    paths: ['/tmp/launch-visual.png'],
    previewUrl: '/api/artifacts/123/content',
  });

  assert.equal(artifacts.length, 2);
  assert.equal(artifacts[0].kind, 'image');
  assert.equal(artifacts[0].path, '/tmp/launch-visual.png');
  assert.ok(!artifacts[0].uri);
  assert.equal(artifacts[1].kind, 'image');
  assert.equal(artifacts[1].uri, '/api/artifacts/123/content');
  assert.ok(!artifacts[1].path);
});

test('slides workflow passes when a matching presentation artifact exists', async () => {
  const workflow = getDeliverableWorkflow('slides');
  const request = workflow.normalizeRequest({
    goal: 'Create the board deck',
    requestedOutputs: ['pptx deck'],
  });
  const plan = workflow.buildExecutionPlan(request);

  const result = await validateDeliverableExecution({
    workflow,
    request,
    plan,
    finalReply: 'The presentation is ready at /tmp/board-deck.pptx.',
    artifacts: [
      {
        kind: 'slides',
        path: '/tmp/board-deck.pptx',
        label: 'board-deck.pptx',
        mimeType:
          'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      },
    ],
    toolExecutions: [],
    runId: 'run-1',
  });

  assert.equal(result.validation.status, 'passed');
  assert.equal(result.result.type, 'slides');
  assert.equal(result.result.artifacts.length, 1);
});

test('video workflow fails when no video artifact was produced', async () => {
  const workflow = getDeliverableWorkflow('video');
  const request = workflow.normalizeRequest({
    goal: 'Create a launch trailer',
    requestedOutputs: ['launch video'],
  });
  const plan = workflow.buildExecutionPlan(request);

  const result = await validateDeliverableExecution({
    workflow,
    request,
    plan,
    finalReply: 'I finished the video.',
    artifacts: [],
    toolExecutions: [],
    runId: 'run-2',
  });

  assert.equal(result.validation.status, 'failed');
  assert.match(result.validation.summary, /validation failed/i);
});
