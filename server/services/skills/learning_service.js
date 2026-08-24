'use strict';

const db = require('../../db/database');
const { getAiSettings } = require('../ai/settings');
const { createServiceLogger } = require('../../utils/logger');
const {
  compactDialogue,
  normalizeProposal,
  normalizeReview,
  normalizeText,
} = require('./learning_documents');
const { SkillLearningRepository } = require('./learning_repository');
const { SkillLearningWriter } = require('./learning_writer');

const logger = createServiceLogger('SkillLearning');
const DEFAULT_REVIEW_ACTIVITY_THRESHOLD = 3;
const DEFAULT_DETAILED_REQUEST_CHARS = 600;
const DEFAULT_REPEAT_OBSERVATIONS = 2;
const DEFAULT_MINIMUM_TOOL_STEPS = 3;

class SkillLearningService {
  constructor(options = {}) {
    this.skillRunner = options.skillRunner;
    this.agentEngine = options.agentEngine;
    this.io = options.io || null;
    this.repository = options.repository || new SkillLearningRepository();
    this.writer = options.writer || new SkillLearningWriter({
      skillRunner: this.skillRunner,
      repository: this.repository,
      io: this.io,
    });
    this.reviewActivityThreshold = options.reviewActivityThreshold
      || DEFAULT_REVIEW_ACTIVITY_THRESHOLD;
    this.detailedRequestChars = options.detailedRequestChars
      || DEFAULT_DETAILED_REQUEST_CHARS;
    this.repeatObservations = options.repeatObservations
      || DEFAULT_REPEAT_OBSERVATIONS;
    this.minimumToolSteps = options.minimumToolSteps
      || DEFAULT_MINIMUM_TOOL_STEPS;
    this.queues = new Map();
    this.pending = new Set();
    this.stopping = false;
  }

  enqueueCompletedRun(input) {
    if (this.stopping) return Promise.resolve(null);
    const queueKey = String(input?.userId || '');
    const previous = this.queues.get(queueKey) || Promise.resolve();
    const job = previous
      .catch(() => null)
      .then(() => this.observeCompletedRun(input))
      .catch((error) => {
        logger.warn('Post-run skill review failed.', error.message);
        return null;
      });
    this.queues.set(queueKey, job);
    this.pending.add(job);
    job.finally(() => {
      this.pending.delete(job);
      if (this.queues.get(queueKey) === job) this.queues.delete(queueKey);
    });
    return job;
  }

  async observeCompletedRun(input = {}) {
    const userId = Number(input.userId);
    const agentId = normalizeText(input.agentId, 128) || null;
    const runId = normalizeText(input.runId, 128);
    const task = normalizeText(input.task, 6000);
    const finalContent = normalizeText(input.finalContent, 4000);
    if (!userId || !runId || !task || !finalContent) return null;
    const triggerType = normalizeText(input.triggerType, 64) || 'user';
    const triggerSource = normalizeText(input.triggerSource, 64);
    const userOrigin = triggerType === 'user';
    const taskOrigin = Boolean(input.taskId) || ['schedule', 'tasks'].includes(triggerSource);
    if (!userOrigin && !taskOrigin) return null;
    if (!getAiSettings(userId, agentId).auto_skill_learning) return null;

    const steps = db.prepare(
      `SELECT step_index, tool_name, status, description, error
       FROM agent_steps WHERE run_id = ? ORDER BY step_index ASC`,
    ).all(runId).filter((step) => step.tool_name).map((step) => ({
      index: Number(step.step_index || 0),
      tool: step.tool_name,
      status: step.status,
      description: normalizeText(step.description, 300),
      error: normalizeText(step.error, 240),
    }));
    const recentDialogue = compactDialogue(input.messages);
    const explainedChars = recentDialogue
      .filter((message) => message.role === 'user')
      .reduce((total, message) => total + message.content.length, 0);
    const detailed = Math.max(task.length, explainedChars) >= this.detailedRequestChars;
    const modelIterations = Math.max(0, Number(input.iterations || 0));
    const completedStepCount = steps.filter((step) => step.status === 'completed').length;
    const substantial = detailed || completedStepCount >= this.minimumToolSteps;
    if (!substantial) return null;
    const activity = this.repository.recordActivity(
      userId,
      agentId,
      Math.max(completedStepCount, 1),
      this.reviewActivityThreshold,
    );
    if (!detailed && activity < this.reviewActivityThreshold) return null;

    const experience = {
      triggerSource,
      triggerType,
      userRequest: task,
      recentDialogue,
      finalResponse: finalContent,
      toolSteps: steps,
      modelIterations,
    };
    const review = await this.#reviewExperience({ userId, agentId, experience });
    if (review.decision === 'ignore') return null;

    if (review.decision === 'update') {
      const existing = this.skillRunner.getSkill(review.existingSkillName, userId);
      if (!this.writer.isLearningManaged(existing)) return null;
      const proposal = await this.#synthesize({
        userId,
        agentId,
        sourceKind: 'agent-run',
        experience,
        review,
        existing,
      });
      return this.writer.persist({ userId, runId, proposal, review, existing });
    }

    if (!review.workflowKey || !review.title || !review.summary) return null;
    const candidate = this.repository.observeCandidate({
      userId,
      workflowKey: review.workflowKey,
      title: review.title,
      summary: review.summary,
      runId,
    });
    if (candidate.status === 'promoted') return { observed: true, candidate };
    if (review.decision !== 'create' && candidate.observationCount < this.repeatObservations) {
      return { observed: true, candidate };
    }

    const existing = this.writer.findManagedWorkflow(userId, review.workflowKey);
    const proposal = await this.#synthesize({
      userId,
      agentId,
      sourceKind: 'agent-run',
      experience: { ...experience, repeatedEvidence: candidate.evidence },
      review,
      existing,
    });
    const result = await this.writer.persist({
      userId,
      runId,
      proposal,
      review,
      existing,
      observationCount: candidate.observationCount,
    });
    if (result?.success) {
      this.repository.promoteCandidate(userId, review.workflowKey, result.name);
    }
    return result;
  }

  async learnFromComputerDemonstration(input = {}) {
    const userId = Number(input.userId);
    const agentId = normalizeText(input.agentId, 128) || null;
    const goal = normalizeText(input.goal, 2000);
    if (!userId || !goal) {
      throw new Error('Computer learning requires a user and demonstrated goal.');
    }
    const proposal = await this.#synthesize({
      userId,
      agentId,
      sourceKind: 'computer-demonstration',
      experience: {
        goal,
        demonstration: input.evidence,
      },
      review: {
        workflowKey: '',
        title: goal,
        summary: 'A user-demonstrated computer workflow.',
        confidence: 1,
      },
      signal: input.signal || null,
    });
    return this.writer.persist({
      userId,
      runId: null,
      proposal,
      review: { workflowKey: proposal.workflowKey, confidence: 1 },
      sourceKind: 'computer-demonstration',
    });
  }

  async #reviewExperience({ userId, agentId, experience }) {
    const installedSkills = this.writer.skillCatalog(userId);
    const candidates = this.repository.listCandidates(userId);
    const response = await this.agentEngine.inferStructured({
      userId,
      agentId,
      purpose: 'fast',
      system: [
        'You review completed agent work for durable procedural learning.',
        'Return JSON only with decision, workflowKey, title, summary, existingSkillName, confidence, and reason.',
        'decision must be ignore, observe, create, or update.',
        'Skills are reusable procedures, not facts, conversation summaries, outputs, or one-off task narratives.',
        'Create when a proven reusable procedure was taught in detail or is clearly represented by repeated evidence.',
        'Observe when a reusable pattern is plausible but needs another occurrence. Use a stable class-level workflowKey.',
        'Update only an existing skill whose catalog entry says learningManaged=true and only when this run produced a concrete correction or improvement.',
        'Ignore unresolved failures, transient environment problems, and work with no reusable method.',
        'Do not preserve secrets, credentials, literal private data, brittle coordinates, or session-specific identifiers.',
      ].join(' '),
      prompt: JSON.stringify({ installedSkills, candidates, experience }).slice(0, 36000),
      maxTokens: 900,
      fallback: { decision: 'ignore', confidence: 0, reason: 'Review unavailable.' },
    });
    return normalizeReview(response.parsed);
  }

  async #synthesize({
    userId,
    agentId,
    sourceKind,
    experience,
    review,
    existing = null,
    signal = null,
  }) {
    const response = await this.agentEngine.inferStructured({
      userId,
      agentId,
      purpose: 'general',
      system: [
        'You synthesize and validate a reusable NeoAgent skill from proven experience.',
        'Return JSON only as {approved, skill}. skill contains name, description, trigger, category, workflowKey, existingSkillName, requiredInputs, steps, pitfalls, and verification.',
        'Use a class-level name and make the description and trigger precise enough for future semantic selection.',
        'Generalize the successful method; omit transcript narration, final-answer content, temporary failures, and task-specific identifiers.',
        'Every step must be actionable and adaptive. Include observed pitfalls only when the evidence includes a working recovery.',
        'Verification must describe observable proof, not an assumption of success.',
        sourceKind === 'computer-demonstration'
          ? 'For computer workflows, use semantic UI state and never coordinates, recorded timing, brittle selectors, clipboard contents, or macro replay.'
          : '',
        'Reject with approved=false if the evidence does not prove a safe reusable procedure.',
      ].filter(Boolean).join(' '),
      prompt: JSON.stringify({
        sourceKind,
        review,
        experience,
        existingSkill: existing ? {
          name: existing.name,
          description: existing.description,
          instructions: existing.instructions,
          metadata: existing.metadata,
        } : null,
        installedSkills: this.writer.skillCatalog(userId),
      }).slice(0, 48000),
      maxTokens: 2200,
      fallback: { approved: false, skill: {} },
      signal,
    });
    return normalizeProposal(response.parsed);
  }

  async shutdown() {
    this.stopping = true;
    await Promise.allSettled([...this.pending]);
  }
}

module.exports = {
  DEFAULT_DETAILED_REQUEST_CHARS,
  DEFAULT_MINIMUM_TOOL_STEPS,
  DEFAULT_REPEAT_OBSERVATIONS,
  DEFAULT_REVIEW_ACTIVITY_THRESHOLD,
  SkillLearningService,
};
