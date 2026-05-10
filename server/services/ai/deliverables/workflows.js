'use strict';

const { clampText, normalizeArtifactContract } = require('./contracts');

function cloneWorkflow(workflow) {
  if (!workflow) return null;
  return {
    ...workflow,
    preferredTools: Array.isArray(workflow.preferredTools) ? [...workflow.preferredTools] : [],
    expectedOutputs: Array.isArray(workflow.expectedOutputs) ? [...workflow.expectedOutputs] : [],
    expectedArtifactKinds: Array.isArray(workflow.expectedArtifactKinds) ? [...workflow.expectedArtifactKinds] : [],
    expectedExtensions: Array.isArray(workflow.expectedExtensions) ? [...workflow.expectedExtensions] : [],
    summaryHints: Array.isArray(workflow.summaryHints) ? [...workflow.summaryHints] : [],
  };
}

function createWorkflow(config) {
  const workflow = {
    type: config.type,
    displayName: config.displayName,
    preferredTools: Array.isArray(config.preferredTools) ? [...config.preferredTools] : [],
    expectedOutputs: Array.isArray(config.expectedOutputs) ? [...config.expectedOutputs] : [],
    expectedArtifactKinds: Array.isArray(config.expectedArtifactKinds) ? [...config.expectedArtifactKinds] : [],
    expectedExtensions: Array.isArray(config.expectedExtensions) ? [...config.expectedExtensions] : [],
    summaryHints: Array.isArray(config.summaryHints) ? [...config.summaryHints] : [],
    canHandle(request) {
      return request?.type === config.type;
    },
    normalizeRequest(input = {}) {
      return {
        type: config.type,
        goal: clampText(input.goal || input.userMessage, 240),
        requestedOutputs: Array.isArray(input.requestedOutputs) ? input.requestedOutputs.map((item) => clampText(item, 120)).filter(Boolean) : [],
        supportingCapabilities: Array.isArray(input.supportingCapabilities) ? input.supportingCapabilities.map((item) => clampText(item, 64)).filter(Boolean) : [],
      };
    },
    buildExecutionPlan(request) {
      return {
        type: config.type,
        displayName: config.displayName,
        goal: request.goal,
        requestedOutputs: request.requestedOutputs,
        supportingCapabilities: request.supportingCapabilities,
        preferredTools: [...this.preferredTools],
        expectedOutputs: [...this.expectedOutputs],
        validationRules: [
          `Produce deliverable artifacts of type "${config.type}" before finishing.`,
          'Mention output files or artifact links explicitly in the final response when available.',
          'Do not report success until the expected deliverable exists and can be summarized concretely.',
        ],
      };
    },
    async run(plan) {
      return plan;
    },
    validate({ artifacts = [], finalReply = '', toolExecutions = [] }) {
      const artifactList = Array.isArray(artifacts)
        ? artifacts.map(normalizeArtifactContract).filter((artifact) => artifact.path || artifact.uri)
        : [];
      const matchedArtifacts = artifactList.filter((artifact) => {
        if (this.expectedArtifactKinds.includes(artifact.kind)) return true;
        const candidate = (artifact.path || artifact.uri || '').toLowerCase();
        return this.expectedExtensions.some((extension) => candidate.endsWith(extension));
      });

      const errors = [];
      const warnings = [];
      if (matchedArtifacts.length === 0) {
        errors.push(`No ${this.displayName.toLowerCase()} artifact was detected.`);
      }
      const trimmedReply = String(finalReply || '').trim();
      if (!trimmedReply) {
        errors.push('Final response is empty.');
      }
      if (!errors.length && trimmedReply.length < 24) {
        warnings.push('Final response is extremely short for a deliverable run.');
      }

      return {
        status: errors.length > 0 ? 'failed' : 'passed',
        summary: errors.length > 0
          ? `${this.displayName} validation failed: ${errors[0]}`
          : `${this.displayName} deliverable validated.`,
        errors,
        warnings,
        artifacts: matchedArtifacts,
        metrics: {
          artifactCount: matchedArtifacts.length,
          toolExecutionCount: Array.isArray(toolExecutions) ? toolExecutions.length : 0,
        },
      };
    },
    summarize({ artifacts = [], validation, finalReply = '' }) {
      const artifactSummary = artifacts.length > 0
        ? artifacts.map((artifact) => artifact.label || artifact.path || artifact.uri).filter(Boolean).slice(0, 4).join(', ')
        : 'no artifacts captured';
      return clampText(
        validation?.status === 'passed'
          ? `${this.displayName} delivered: ${artifactSummary}.`
          : `${this.displayName} validation failed: ${validation?.errors?.[0] || 'unknown validation error'}.`,
        320,
      );
    },
  };
  workflow.baseValidate = workflow.validate;
  return workflow;
}

const WORKFLOWS = [
  createWorkflow({
    type: 'slides',
    displayName: 'Slides',
    preferredTools: ['write_file', 'edit_file', 'execute_command', 'browser_screenshot', 'generate_image'],
    expectedOutputs: ['presentation deck', 'exported slide file', 'visual proof'],
    expectedArtifactKinds: ['slides', 'document', 'image'],
    expectedExtensions: ['.ppt', '.pptx', '.pdf', '.html', '.png', '.jpg', '.jpeg'],
  }),
  createWorkflow({
    type: 'document',
    displayName: 'Document',
    preferredTools: ['write_file', 'edit_file', 'execute_command', 'browser_screenshot'],
    expectedOutputs: ['document file', 'rendered export'],
    expectedArtifactKinds: ['document'],
    expectedExtensions: ['.pdf', '.doc', '.docx', '.md', '.txt', '.html', '.htm'],
  }),
  createWorkflow({
    type: 'research_report',
    displayName: 'Research report',
    preferredTools: ['web_search', 'http_request', 'write_file', 'edit_file'],
    expectedOutputs: ['research report', 'citations or source-backed artifact'],
    expectedArtifactKinds: ['document'],
    expectedExtensions: ['.pdf', '.doc', '.docx', '.md', '.txt', '.html', '.htm'],
    validate(payload) {
      const base = this.baseValidate(payload);
      const reply = String(payload.finalReply || '');
      const hasCitation = /(https?:\/\/|source:|sources:|references?:|\[\d+\])/i.test(reply);
      if (!hasCitation && base.artifacts.length === 0) {
        base.errors.push('No citation or report artifact was detected.');
        base.status = 'failed';
        base.summary = 'Research report validation failed: no citation or report artifact was detected.';
      }
      return base;
    },
  }),
  createWorkflow({
    type: 'data_analysis',
    displayName: 'Data analysis',
    preferredTools: ['execute_command', 'write_file', 'edit_file', 'browser_screenshot'],
    expectedOutputs: ['analysis artifact', 'chart or data export'],
    expectedArtifactKinds: ['data', 'image', 'document'],
    expectedExtensions: ['.csv', '.tsv', '.xlsx', '.xls', '.json', '.png', '.jpg', '.jpeg', '.svg', '.pdf', '.html'],
  }),
  createWorkflow({
    type: 'image',
    displayName: 'Image',
    preferredTools: ['generate_image', 'write_file', 'edit_file'],
    expectedOutputs: ['generated or edited image'],
    expectedArtifactKinds: ['image'],
    expectedExtensions: ['.png', '.jpg', '.jpeg', '.gif', '.webp', '.svg'],
  }),
  createWorkflow({
    type: 'video',
    displayName: 'Video',
    preferredTools: ['execute_command', 'write_file', 'edit_file'],
    expectedOutputs: ['rendered video asset'],
    expectedArtifactKinds: ['video'],
    expectedExtensions: ['.mp4', '.mov', '.m4v', '.webm'],
  }),
];

function listDeliverableWorkflows() {
  return WORKFLOWS.map(cloneWorkflow);
}

function getDeliverableWorkflow(type) {
  return cloneWorkflow(WORKFLOWS.find((workflow) => workflow.type === type) || null);
}

function buildDeliverableWorkflowGuidance(plan) {
  if (!plan) return '';
  return [
    `[Deliverable workflow: ${plan.displayName}]`,
    plan.goal ? `Deliverable goal: ${plan.goal}` : '',
    plan.requestedOutputs?.length ? `Requested outputs: ${plan.requestedOutputs.join(', ')}` : '',
    plan.preferredTools?.length ? `Preferred tools/capabilities: ${plan.preferredTools.join(', ')}` : '',
    plan.expectedOutputs?.length ? `Expected artifacts: ${plan.expectedOutputs.join(', ')}` : '',
    'Before finishing, ensure the final deliverable exists, validate it, and summarize the produced artifacts clearly.',
  ].filter(Boolean).join('\n');
}

module.exports = {
  buildDeliverableWorkflowGuidance,
  getDeliverableWorkflow,
  listDeliverableWorkflows,
};
