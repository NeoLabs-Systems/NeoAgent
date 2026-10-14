'use strict';

const { buildLoopPolicy } = require('../loopPolicy');

// Runaway guards. The model decides how the work goes and when it is done;
// these only end a run that is spinning: tool turns that change nothing and
// learn nothing, tool turns in which every call fails, or the emergency turn
// ceiling. The run then gets one last turn to tell the user where it stands.
function createRunGuards({ aiSettings = {}, options = {} } = {}) {
  const policy = buildLoopPolicy(aiSettings, options);
  let modelTurns = 0;
  let idleTurns = 0;
  let failedTurns = 0;

  return {
    policy,
    recordModelTurn() {
      modelTurns += 1;
    },
    recordToolTurn({ progressed, allFailed }) {
      idleTurns = progressed ? 0 : idleTurns + 1;
      failedTurns = allFailed ? failedTurns + 1 : 0;
    },
    stopReason() {
      if (modelTurns >= policy.maxIterations) return 'turn_limit';
      if (idleTurns >= policy.maxIdleTurns) return 'no_progress';
      if (failedTurns >= policy.maxFailedTurns) return 'tool_failures';
      return null;
    },
  };
}

module.exports = {
  createRunGuards,
};
