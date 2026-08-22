'use strict';

const { buildSkillInstructions, isUsableProposal } = require('./learning_documents');

class SkillLearningWriter {
  constructor({ skillRunner, repository, io = null }) {
    this.skillRunner = skillRunner;
    this.repository = repository;
    this.io = io;
  }

  skillCatalog(userId) {
    return this.skillRunner.getAll(userId).slice(0, 80).map((skill) => ({
      name: skill.name,
      description: skill.description,
      source: skill.metadata?.source || skill.ownerType,
      learningManaged: this.isLearningManaged(skill),
      workflowKey: skill.metadata?.learning?.workflowKey || '',
    }));
  }

  isLearningManaged(skill) {
    return skill?.ownerType === 'user'
      && skill.metadata?.auto_created === true
      && skill.metadata?.learning?.managed === true;
  }

  async persist({
    userId,
    runId,
    proposal,
    review,
    existing = null,
    observationCount = 1,
    sourceKind = 'agent-run',
  }) {
    if (!isUsableProposal(proposal)) return { success: false, ignored: true };
    let target = existing
      || this.findManagedWorkflow(userId, proposal.workflowKey || review.workflowKey)
      || this.skillRunner.getSkill(proposal.existingSkillName || proposal.name, userId);
    if (target && !this.isLearningManaged(target)) target = null;

    const priorLearning = target?.metadata?.learning || {};
    const sourceRunIds = [...new Set([
      ...(Array.isArray(priorLearning.sourceRunIds) ? priorLearning.sourceRunIds : []),
      ...(runId ? [runId] : []),
    ])].slice(-8);
    const metadata = {
      ...(target?.metadata || {}),
      category: sourceKind === 'computer-demonstration' ? 'computer' : proposal.category,
      trigger: proposal.trigger,
      source: 'learned',
      enabled: true,
      draft: false,
      auto_created: true,
      ...(sourceKind === 'computer-demonstration' ? { required_capabilities: ['computer'] } : {}),
      learning: {
        managed: true,
        origin: sourceKind,
        workflowKey: proposal.workflowKey || review.workflowKey,
        observationCount: Math.max(
          Number(priorLearning.observationCount || 0) + 1,
          Number(observationCount || 1),
        ),
        confidence: review.confidence,
        sourceRunIds,
        updatedAt: new Date().toISOString(),
      },
    };
    const instructions = buildSkillInstructions(proposal, {
      computerAdaptive: sourceKind === 'computer-demonstration',
    });
    let result;
    let action;
    if (target) {
      action = 'updated';
      result = this.skillRunner.updateSkill(userId, target.name, {
        description: proposal.description,
        instructions,
        metadata,
      });
    } else {
      action = 'created';
      const name = this.availableName(userId, proposal.name);
      result = this.skillRunner.createSkill(
        userId,
        name,
        proposal.description,
        instructions,
        metadata,
      );
    }
    if (!result?.success) return result;
    this.repository.recordEvaluation({
      versionId: result.versionId,
      runId,
      score: review.confidence,
      outcome: action,
      notes: review.reason || `Learned from ${sourceKind}.`,
    });
    this.io?.to(`user:${userId}`).emit('skill:learned', {
      action,
      name: result.name,
      description: proposal.description,
      origin: sourceKind,
    });
    return { ...result, action, description: proposal.description };
  }

  availableName(userId, requestedName) {
    if (!this.skillRunner.getSkill(requestedName, userId)) return requestedName;
    let suffix = 2;
    while (this.skillRunner.getSkill(`${requestedName}-${suffix}`, userId)) suffix += 1;
    return `${requestedName}-${suffix}`;
  }

  findManagedWorkflow(userId, workflowKey) {
    if (!workflowKey) return null;
    return this.skillRunner.getAll(userId).find(
      (skill) => this.isLearningManaged(skill)
        && skill.metadata?.learning?.workflowKey === workflowKey,
    ) || null;
  }
}

module.exports = { SkillLearningWriter };
