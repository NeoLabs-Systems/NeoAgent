'use strict';

const {
  clampText,
  normalizeDeliverableSelection,
} = require('./contracts');
const { listDeliverableWorkflows } = require('./workflows');

function buildDeliverableSelectorPrompt({ tools = [] }) {
  const workflows = listDeliverableWorkflows().map((workflow) => ({
    type: workflow.type,
    displayName: workflow.displayName,
    expectedOutputs: workflow.expectedOutputs,
  }));
  const toolNames = tools
    .map((tool) => String(tool?.name || '').trim())
    .filter(Boolean)
    .slice(0, 40);

  return [
    'Return JSON only.',
    'Classify whether this request should use a deliverable workflow.',
    'Choose exactly one type from: slides, document, research_report, data_analysis, image, video.',
    'Use status="selected" only when a concrete artifact-producing workflow clearly owns the primary outcome.',
    'Use status="standard" when the request is conversational, operational, ambiguous, or not primarily about producing one of these deliverables.',
    'Be conservative. If confidence is low, choose status="standard".',
    'Schema:',
    JSON.stringify({
      status: 'selected',
      type: 'document',
      confidence: 0.82,
      goal: 'Create a polished launch memo.',
      requested_outputs: ['launch memo pdf'],
      supporting_capabilities: ['web_search'],
    }, null, 2),
    `Available workflows:\n${JSON.stringify(workflows, null, 2)}`,
    toolNames.length ? `Available tools/capabilities: ${toolNames.join(', ')}` : '',
  ].filter(Boolean).join('\n\n');
}

async function selectDeliverableWorkflow({
  engine,
  provider,
  providerName,
  model,
  messages,
  tools = [],
  options = {},
}) {
  const response = await engine.requestStructuredJson({
    provider,
    providerName,
    model,
    messages,
    prompt: buildDeliverableSelectorPrompt({ tools }),
    maxTokens: 600,
    normalize: normalizeDeliverableSelection,
    fallback: { status: 'standard', confidence: 0 },
    reasoningEffort: engine.getReasoningEffort(providerName, options),
  });

  const selection = normalizeDeliverableSelection(response.value);
  if (
    selection.status !== 'selected'
    || !selection.type
    || Number(selection.confidence || 0) < 0.7
  ) {
    return {
      selection: {
        status: 'standard',
        type: null,
        confidence: Number(selection.confidence || 0),
        goal: '',
        requestedOutputs: [],
        supportingCapabilities: [],
      },
      usage: response.usage,
      raw: response.raw,
    };
  }

  return {
    selection: {
      ...selection,
      goal: clampText(selection.goal, 240),
    },
    usage: response.usage,
    raw: response.raw,
  };
}

module.exports = {
  selectDeliverableWorkflow,
};
