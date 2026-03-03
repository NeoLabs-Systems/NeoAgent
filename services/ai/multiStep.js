const { v4: uuidv4 } = require('uuid');
const db = require('../../db/database');
const { AgentEngine } = require('./engine');

class MultiStepOrchestrator {
  constructor(engine, io) {
    this.io = io;
    this.engine = engine;
    this.activeOrchestrations = new Map();
  }

  async planAndExecute(userId, task, options = {}) {
    const orchestrationId = uuidv4();
    const app = options.app;

    this.activeOrchestrations.set(orchestrationId, {
      userId,
      task,
      status: 'planning',
      steps: [],
      currentStep: 0
    });

    this.emit(userId, 'orchestration:start', { orchestrationId, task });

    try {
      const result = await this.engine.run(userId, task, {
        runId: orchestrationId,
        conversationId: options.conversationId,
        app,
        triggerType: options.triggerType || 'user',
        triggerSource: options.triggerSource || 'web',
        context: options.context,
        stream: options.stream
      });

      this.activeOrchestrations.delete(orchestrationId);
      this.emit(userId, 'orchestration:complete', {
        orchestrationId,
        result: result.content,
        totalTokens: result.totalTokens,
        iterations: result.iterations
      });

      return result;
    } catch (err) {
      this.activeOrchestrations.delete(orchestrationId);
      this.emit(userId, 'orchestration:error', { orchestrationId, error: err.message });
      throw err;
    }
  }

  async runParallel(userId, tasks, options = {}) {
    const groupId = uuidv4();
    const app = options.app;
    const results = [];

    this.emit(userId, 'parallel:start', { groupId, taskCount: tasks.length });

    const promises = tasks.map(async (task, index) => {
      try {
        const result = await this.engine.run(userId, task, {
          app,
          triggerType: options.triggerType || 'user',
          triggerSource: options.triggerSource || 'parallel',
          context: options.context
        });
        return { index, status: 'completed', result };
      } catch (err) {
        return { index, status: 'failed', error: err.message };
      }
    });

    const settled = await Promise.allSettled(promises);
    for (const item of settled) {
      if (item.status === 'fulfilled') {
        results.push(item.value);
      } else {
        results.push({ status: 'failed', error: item.reason?.message });
      }
    }

    this.emit(userId, 'parallel:complete', { groupId, results });
    return results;
  }

  stop(orchestrationId) {
    const orch = this.activeOrchestrations.get(orchestrationId);
    if (orch) {
      this.engine.stopRun(orchestrationId);
      this.activeOrchestrations.delete(orchestrationId);
    }
  }

  getActive() {
    return Array.from(this.activeOrchestrations.entries()).map(([id, orch]) => ({
      id,
      userId: orch.userId,
      task: orch.task,
      status: orch.status,
      currentStep: orch.currentStep
    }));
  }

  emit(userId, event, data) {
    if (this.io) {
      this.io.to(`user:${userId}`).emit(event, data);
    }
  }
}

module.exports = { MultiStepOrchestrator };
