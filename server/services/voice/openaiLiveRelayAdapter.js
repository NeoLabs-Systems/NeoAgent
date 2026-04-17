'use strict';

const { BufferedLiveRelayAdapter } = require('./bufferedLiveRelayAdapter');

class OpenAiLiveRelayAdapter extends BufferedLiveRelayAdapter {
  constructor(options = {}) {
    super({
      ...options,
      provider: 'openai',
    });
  }
}

module.exports = {
  OpenAiLiveRelayAdapter,
};
