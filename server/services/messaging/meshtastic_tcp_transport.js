'use strict';

const { MeshtasticConnection } = require('./meshtastic_protocol');

class MeshtasticTcpTransport {
  constructor(connection) {
    this._connection = connection;
  }

  static async create(hostname, port = 4403, timeout = 60000, options = {}) {
    const connection = new MeshtasticConnection(options);
    await connection.connect(hostname, port, timeout);
    return new MeshtasticTcpTransport(connection);
  }

  get connection() { return this._connection; }

  async disconnect() {
    await this._connection.disconnect();
  }
}

module.exports = {
  MeshtasticTcpTransport,
};
