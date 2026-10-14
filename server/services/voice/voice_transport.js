'use strict';

// One event vocabulary for every live voice client. A transport only supplies
// how an event reaches its client: socket.io for the app, a raw WebSocket for
// the wearable.
//
// Server → client events: voice:session_ready, voice:state, voice:audio,
// voice:interrupted, voice:transcript, voice:task, voice:error.
function createVoiceSink(deliver) {
  return {
    send(kind, payload) {
      deliver(`voice:${kind}`, payload);
    },
  };
}

function createSocketVoiceSink(socket) {
  return createVoiceSink((event, payload) => socket.emit(event, payload));
}

module.exports = {
  createSocketVoiceSink,
  createVoiceSink,
};
