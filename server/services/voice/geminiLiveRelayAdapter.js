'use strict';

const { BufferedLiveRelayAdapter } = require('./bufferedLiveRelayAdapter');

class GeminiLiveRelayAdapter extends BufferedLiveRelayAdapter {
  constructor(options = {}) {
    super({
      ...options,
      provider: 'gemini',
    });
  }
}

module.exports = {
  GeminiLiveRelayAdapter,
};
