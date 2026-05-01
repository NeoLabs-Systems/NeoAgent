'use strict';

const { Socket } = require('node:net');
const { Readable, Writable } = require('node:stream');

class MeshtasticTcpTransport {
  static async create(core, hostname, port = 4403, timeout = 60000) {
    return await new Promise((resolve, reject) => {
      const socket = new Socket();
      const onError = (error) => {
        socket.destroy();
        socket.removeAllListeners();
        reject(error);
      };

      socket.once('error', onError);
      socket.once('ready', () => {
        socket.removeListener('error', onError);
        resolve(new MeshtasticTcpTransport(core, socket));
      });

      socket.setTimeout(timeout);
      socket.connect(port, hostname);
    });
  }

  constructor(core, connection) {
    this._core = core;
    this._socket = connection;
    this._lastStatus = core.Types.DeviceStatusEnum.DeviceDisconnected;
    this._closingByUser = false;
    this._errored = false;
    this._fromDeviceController = null;
    this._pipePromise = null;
    this._abortController = new AbortController();

    this._socket.on('error', () => {
      this._errored = true;
      this._socket?.removeAllListeners();
      this._socket?.destroy();
      if (!this._closingByUser) {
        this._emitStatus(core.Types.DeviceStatusEnum.DeviceDisconnected, 'socket-error');
      }
    });

    this._socket.on('end', () => {
      if (this._closingByUser) return;
      this._emitStatus(core.Types.DeviceStatusEnum.DeviceDisconnected, 'socket-end');
      this._socket?.removeAllListeners();
      this._socket?.destroy();
    });

    this._socket.on('timeout', () => {
      this._emitStatus(core.Types.DeviceStatusEnum.DeviceDisconnected, 'socket-timeout');
      this._socket?.removeAllListeners();
      this._socket?.destroy();
    });

    this._socket.on('close', () => {
      if (this._closingByUser) return;
      this._emitStatus(core.Types.DeviceStatusEnum.DeviceDisconnected, 'socket-closed');
    });

    const transformed = Readable.toWeb(connection).pipeThrough(core.Utils.fromDeviceStream());
    this._fromDevice = new ReadableStream({
      start: async (controller) => {
        this._fromDeviceController = controller;
        this._emitStatus(core.Types.DeviceStatusEnum.DeviceConnecting);
        this._emitStatus(core.Types.DeviceStatusEnum.DeviceConnected);
        const reader = transformed.getReader();

        try {
          while (true) {
            const { value, done } = await reader.read();
            if (done) break;
            controller.enqueue(value);
          }
          controller.close();
        } catch (error) {
          if (this._closingByUser || this._errored) {
            controller.close();
          } else {
            this._emitStatus(core.Types.DeviceStatusEnum.DeviceDisconnected, 'read-error');
            controller.error(error instanceof Error ? error : new Error(String(error)));
          }

          try {
            await transformed.cancel();
          } catch {}
        } finally {
          reader.releaseLock();
        }
      },
    });

    const toDeviceTransform = core.Utils.toDeviceStream();
    this._toDevice = toDeviceTransform.writable;
    this._pipePromise = toDeviceTransform.readable.pipeTo(
      Writable.toWeb(connection),
      { signal: this._abortController.signal }
    ).catch((error) => {
      if (this._abortController.signal.aborted || this._socket?.destroyed) return;
      const socketError = error instanceof Error ? error : new Error(String(error));
      this._socket?.destroy(socketError);
    });
  }

  get toDevice() {
    return this._toDevice;
  }

  get fromDevice() {
    return this._fromDevice;
  }

  async disconnect() {
    try {
      this._closingByUser = true;
      this._emitStatus(this._core.Types.DeviceStatusEnum.DeviceDisconnected, 'user');
      this._abortController.abort();
      if (this._pipePromise) {
        await this._pipePromise;
      }
      this._socket?.destroy();
    } finally {
      this._socket = null;
      this._closingByUser = false;
      this._errored = false;
    }
  }

  _emitStatus(nextStatus, reason) {
    if (nextStatus === this._lastStatus) return;
    this._lastStatus = nextStatus;
    this._fromDeviceController?.enqueue({
      type: 'status',
      data: {
        status: nextStatus,
        reason,
      },
    });
  }
}

module.exports = {
  MeshtasticTcpTransport,
};
