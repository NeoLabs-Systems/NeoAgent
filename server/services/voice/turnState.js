'use strict';

function createVoiceTurnSessionState({ callerNumber = '' } = {}) {
  return {
    callerNumber,
    isProcessing: false,
    awaitingUserInput: false,
    isThinking: false,
    replySent: false,
    processedRecordings: new Set(),
    awaitingSecret: false,
    secretDigits: '',
    audioQueue: [],
    isPlayingInterim: false,
  };
}

module.exports = {
  createVoiceTurnSessionState,
};
