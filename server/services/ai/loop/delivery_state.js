'use strict';

function createDeliveryState(seed = {}) {
  return {
    alreadySent: seed.alreadySent === true,
    finalResponseSent: seed.finalResponseSent === true,
    finalContentDelivered: seed.finalContentDelivered === true,
  };
}

function markInterimDelivered(state) {
  if (!state) return;
  state.alreadySent = true;
}

function markFinalDelivered(state) {
  if (!state) return;
  state.alreadySent = true;
  state.finalResponseSent = true;
  state.finalContentDelivered = true;
}

module.exports = {
  createDeliveryState,
  markInterimDelivered,
  markFinalDelivered,
};
