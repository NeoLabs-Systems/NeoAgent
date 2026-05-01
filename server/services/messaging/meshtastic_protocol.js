'use strict';

const { Socket } = require('node:net');
const { EventEmitter } = require('node:events');

// Meshtastic TCP wire framing constants (from public protocol docs)
const FRAME_START_1 = 0x94;
const FRAME_START_2 = 0xC3;

const BROADCAST_NUM = 0xFFFFFFFF;

// PortNum values from public protocol specification
const PortNum = Object.freeze({
  UNKNOWN_APP: 0,
  TEXT_MESSAGE_APP: 1,
  POSITION_APP: 3,
  NODEINFO_APP: 4,
  ROUTING_APP: 5,
  ADMIN_APP: 6,
  TELEMETRY_APP: 67,
});

// --------------------------------------------------------------------------
// Minimal protobuf wire-format encoder/decoder (Google public standard)
// Implements only the subset needed: varint, length-delimited, fixed32
// --------------------------------------------------------------------------

const WIRE_VARINT = 0;
const WIRE_FIXED64 = 1;
const WIRE_LENGTH_DELIMITED = 2;
const WIRE_FIXED32 = 5;

function encodeVarint(value) {
  const bytes = [];
  let v = value >>> 0;
  while (v > 0x7F) {
    bytes.push((v & 0x7F) | 0x80);
    v >>>= 7;
  }
  bytes.push(v & 0x7F);
  return bytes;
}

function encodeTag(fieldNumber, wireType) {
  return encodeVarint((fieldNumber << 3) | wireType);
}

function encodeVarintField(fieldNumber, value) {
  if (value === 0 || value == null) return [];
  return [...encodeTag(fieldNumber, WIRE_VARINT), ...encodeVarint(value)];
}

function encodeBoolField(fieldNumber, value) {
  if (!value) return [];
  return [...encodeTag(fieldNumber, WIRE_VARINT), 1];
}

function encodeFixed32Field(fieldNumber, value) {
  if (value === 0 || value == null) return [];
  const buf = Buffer.alloc(4);
  buf.writeUInt32LE(value >>> 0);
  return [...encodeTag(fieldNumber, WIRE_FIXED32), ...buf];
}

function encodeBytesField(fieldNumber, bytes) {
  if (!bytes || bytes.length === 0) return [];
  return [
    ...encodeTag(fieldNumber, WIRE_LENGTH_DELIMITED),
    ...encodeVarint(bytes.length),
    ...bytes,
  ];
}

function encodeStringField(fieldNumber, str) {
  if (!str) return [];
  return encodeBytesField(fieldNumber, Buffer.from(str, 'utf8'));
}

function encodeMessageField(fieldNumber, messageBytes) {
  return encodeBytesField(fieldNumber, messageBytes);
}

function decodeVarint(buf, offset) {
  let result = 0;
  let shift = 0;
  let pos = offset;
  while (pos < buf.length) {
    const b = buf[pos++];
    result |= (b & 0x7F) << shift;
    if ((b & 0x80) === 0) return { value: result >>> 0, offset: pos };
    shift += 7;
    if (shift > 35) throw new Error('Varint too long');
  }
  throw new Error('Unexpected end of varint');
}

function decodeFields(buf) {
  const fields = [];
  let offset = 0;
  while (offset < buf.length) {
    const tag = decodeVarint(buf, offset);
    offset = tag.offset;
    const fieldNumber = tag.value >>> 3;
    const wireType = tag.value & 0x07;

    switch (wireType) {
      case WIRE_VARINT: {
        const val = decodeVarint(buf, offset);
        offset = val.offset;
        fields.push({ field: fieldNumber, wire: wireType, value: val.value });
        break;
      }
      case WIRE_FIXED64: {
        offset += 8;
        break;
      }
      case WIRE_LENGTH_DELIMITED: {
        const len = decodeVarint(buf, offset);
        offset = len.offset;
        const data = buf.subarray(offset, offset + len.value);
        offset += len.value;
        fields.push({ field: fieldNumber, wire: wireType, value: data });
        break;
      }
      case WIRE_FIXED32: {
        const val32 = buf.readUInt32LE(offset);
        offset += 4;
        fields.push({ field: fieldNumber, wire: wireType, value: val32 });
        break;
      }
      default:
        throw new Error(`Unsupported wire type ${wireType}`);
    }
  }
  return fields;
}

function getField(fields, fieldNumber) {
  return fields.find((f) => f.field === fieldNumber) || null;
}

// --------------------------------------------------------------------------
// Protocol message builders and parsers
// Field numbers from the public Meshtastic protobuf specification
// --------------------------------------------------------------------------

function encodeData(payload, portnum, opts = {}) {
  return new Uint8Array([
    ...encodeVarintField(1, portnum),
    ...encodeBytesField(2, payload),
    ...encodeBoolField(3, opts.wantResponse),
    ...encodeFixed32Field(6, opts.requestId),
    ...encodeFixed32Field(7, opts.replyId),
    ...encodeFixed32Field(8, opts.emoji),
  ]);
}

function encodeMeshPacket(from, to, channel, id, decoded, opts = {}) {
  return new Uint8Array([
    ...encodeFixed32Field(1, from),
    ...encodeFixed32Field(2, to),
    ...encodeVarintField(3, channel),
    ...encodeMessageField(4, decoded),
    ...encodeFixed32Field(6, id),
    ...encodeBoolField(10, opts.wantAck),
  ]);
}

function encodeToRadioPacket(meshPacketBytes) {
  return new Uint8Array(encodeMessageField(1, meshPacketBytes));
}

function encodeToRadioWantConfig(configId) {
  return new Uint8Array(encodeVarintField(3, configId));
}

function decodeUser(buf) {
  const fields = decodeFields(buf);
  return {
    id: getField(fields, 1)?.value?.toString('utf8') || '',
    longName: getField(fields, 2)?.value?.toString('utf8') || '',
    shortName: getField(fields, 3)?.value?.toString('utf8') || '',
  };
}

function decodeData(buf) {
  const fields = decodeFields(buf);
  return {
    portnum: getField(fields, 1)?.value || 0,
    payload: getField(fields, 2)?.value || Buffer.alloc(0),
    wantResponse: !!(getField(fields, 3)?.value),
    source: getField(fields, 5)?.value || 0,
    dest: getField(fields, 4)?.value || 0,
    requestId: getField(fields, 6)?.value || 0,
  };
}

function decodeMeshPacket(buf) {
  const fields = decodeFields(buf);
  const decodedField = getField(fields, 4);
  const encryptedField = getField(fields, 5);
  return {
    from: getField(fields, 1)?.value || 0,
    to: getField(fields, 2)?.value || 0,
    channel: getField(fields, 3)?.value || 0,
    decoded: decodedField ? decodeData(decodedField.value) : null,
    encrypted: encryptedField ? encryptedField.value : null,
    id: getField(fields, 6)?.value || 0,
    rxTime: getField(fields, 7)?.value || 0,
  };
}

function decodeNodeInfo(buf) {
  const fields = decodeFields(buf);
  const userField = getField(fields, 2);
  return {
    num: getField(fields, 1)?.value || 0,
    user: userField ? decodeUser(userField.value) : null,
  };
}

function decodeMyNodeInfo(buf) {
  const fields = decodeFields(buf);
  return {
    myNodeNum: getField(fields, 1)?.value || 0,
  };
}

function decodeFromRadio(buf) {
  const fields = decodeFields(buf);
  const id = getField(fields, 1)?.value || 0;

  const packetField = getField(fields, 2);
  if (packetField) return { id, type: 'packet', packet: decodeMeshPacket(packetField.value) };

  const myInfoField = getField(fields, 3);
  if (myInfoField) return { id, type: 'myInfo', myInfo: decodeMyNodeInfo(myInfoField.value) };

  const nodeInfoField = getField(fields, 4);
  if (nodeInfoField) return { id, type: 'nodeInfo', nodeInfo: decodeNodeInfo(nodeInfoField.value) };

  const configCompleteField = getField(fields, 7);
  if (configCompleteField) return { id, type: 'configComplete', configId: configCompleteField.value };

  const rebootedField = getField(fields, 8);
  if (rebootedField) return { id, type: 'rebooted' };

  return { id, type: 'unknown' };
}

// --------------------------------------------------------------------------
// TCP wire framing: [0x94, 0xC3, len_msb, len_lsb, ...protobuf_payload]
// --------------------------------------------------------------------------

function framePacket(protobufBytes) {
  const len = protobufBytes.length;
  const frame = Buffer.alloc(4 + len);
  frame[0] = FRAME_START_1;
  frame[1] = FRAME_START_2;
  frame[2] = (len >> 8) & 0xFF;
  frame[3] = len & 0xFF;
  frame.set(protobufBytes, 4);
  return frame;
}

function createFrameParser(onPacket) {
  let buffer = Buffer.alloc(0);
  return (chunk) => {
    buffer = Buffer.concat([buffer, chunk]);
    while (buffer.length >= 4) {
      const idx = buffer.indexOf(FRAME_START_1);
      if (idx === -1) { buffer = Buffer.alloc(0); return; }
      if (idx > 0) { buffer = buffer.subarray(idx); }
      if (buffer.length < 2) return;
      if (buffer[1] !== FRAME_START_2) { buffer = buffer.subarray(1); continue; }
      if (buffer.length < 4) return;
      const payloadLen = (buffer[2] << 8) | buffer[3];
      if (buffer.length < 4 + payloadLen) return;
      const payload = buffer.subarray(4, 4 + payloadLen);
      buffer = buffer.subarray(4 + payloadLen);
      onPacket(payload);
    }
  };
}

// --------------------------------------------------------------------------
// MeshtasticConnection — TCP connection + protocol state machine
// --------------------------------------------------------------------------

class MeshtasticConnection extends EventEmitter {
  constructor() {
    super();
    this._socket = null;
    this._configId = (Math.random() * 0x7FFFFFFF) >>> 0;
    this._myNodeNum = 0;
    this._configured = false;
    this._closing = false;
    this._nodeUsers = new Map();
    // Prevent 'error' events with no listener from crashing the process
    this.on('error', () => {});
  }

  get myNodeNum() { return this._myNodeNum; }
  get nodeUsers() { return this._nodeUsers; }
  get configured() { return this._configured; }

  async connect(host, port, timeout = 60000) {
    if (this._socket) throw new Error('Already connected');
    this._closing = false;
    this._configured = false;
    this._myNodeNum = 0;
    this._nodeUsers.clear();

    return new Promise((resolve, reject) => {
      const socket = new Socket();
      let settled = false;

      const fail = (err) => {
        if (settled) return;
        settled = true;
        socket.destroy();
        reject(err);
      };

      const timer = setTimeout(() => fail(new Error('Connection timeout')), timeout);

      socket.once('error', fail);
      socket.once('ready', () => {
        socket.removeListener('error', fail);
        this._socket = socket;
        this._wireSocket(socket);
        this.emit('status', 'connected');

        const onConfigured = () => {
          if (settled) return;
          settled = true;
          clearTimeout(timer);
          resolve();
        };
        this.once('configured', onConfigured);

        const toRadio = encodeToRadioWantConfig(this._configId);
        socket.write(framePacket(toRadio));
      });

      socket.setTimeout(timeout);
      socket.connect(port, host);
    });
  }

  _wireSocket(socket) {
    const parser = createFrameParser((payload) => {
      if (this._closing) return;
      try {
        const msg = decodeFromRadio(payload);
        this._handleFromRadio(msg);
      } catch (err) {
        // Bad packet from the mesh — log and skip, don't crash
        console.warn('[Meshtastic] Decode error (skipping packet):', err.message);
      }
    });

    socket.on('data', parser);
    socket.on('error', (err) => this._onDisconnected(`socket-error: ${err.message}`))
    socket.on('end', () => this._onDisconnected('socket-end'));
    socket.on('close', () => this._onDisconnected('socket-closed'));
    socket.on('timeout', () => {
      this._onDisconnected('socket-timeout');
      socket.destroy();
    });
  }

  _onDisconnected(reason) {
    if (this._closing) return;
    this._configured = false;
    this.emit('status', 'disconnected');
    this.emit('disconnected', { reason });
  }

  _handleFromRadio(msg) {
    switch (msg.type) {
      case 'myInfo':
        this._myNodeNum = msg.myInfo.myNodeNum;
        this.emit('myNodeInfo', msg.myInfo);
        break;

      case 'nodeInfo':
        if (msg.nodeInfo.user && msg.nodeInfo.num) {
          this._nodeUsers.set(msg.nodeInfo.num, msg.nodeInfo.user);
          this.emit('nodeInfo', msg.nodeInfo);
        }
        break;

      case 'configComplete':
        if (msg.configId === this._configId) {
          this._configured = true;
          this.emit('configured');
        }
        break;

      case 'rebooted':
        this._configured = false;
        this._socket?.write(framePacket(encodeToRadioWantConfig(this._configId)));
        break;

      case 'packet': {
        const pkt = msg.packet;
        if (!pkt.decoded) break;
        this._handleDecodedPacket(pkt);
        break;
      }
    }
  }

  _handleDecodedPacket(pkt) {
    const { decoded } = pkt;

    switch (decoded.portnum) {
      case PortNum.TEXT_MESSAGE_APP:
        this.emit('textMessage', {
          id: pkt.id,
          from: pkt.from,
          to: pkt.to,
          channel: pkt.channel,
          rxTime: pkt.rxTime,
          type: pkt.to === BROADCAST_NUM ? 'broadcast' : 'direct',
          data: decoded.payload.toString('utf8'),
        });
        break;

      case PortNum.NODEINFO_APP:
        try {
          const user = decodeUser(decoded.payload);
          if (pkt.from) this._nodeUsers.set(pkt.from, user);
          this.emit('nodeInfo', { num: pkt.from, user });
        } catch {}
        break;
    }
  }

  async sendText(text, channel = 0, destination = BROADCAST_NUM, wantAck = true) {
    if (!this._socket || !this._configured) throw new Error('Not connected');
    const payload = Buffer.from(text, 'utf8');
    const data = encodeData(payload, PortNum.TEXT_MESSAGE_APP, { wantResponse: false });
    const id = (Math.random() * 0x7FFFFFFF) >>> 0;
    const packet = encodeMeshPacket(this._myNodeNum, destination, channel, id, data, { wantAck });
    const toRadio = encodeToRadioPacket(packet);
    this._socket.write(framePacket(toRadio));
    return id;
  }

  async disconnect() {
    this._closing = true;
    this._configured = false;
    const socket = this._socket;
    this._socket = null;
    if (socket) {
      socket.removeAllListeners();
      socket.destroy();
    }
  }
}

module.exports = {
  MeshtasticConnection,
  PortNum,
  BROADCAST_NUM,
  encodeVarint,
  decodeVarint,
  decodeFields,
  decodeFromRadio,
  decodeMeshPacket,
  decodeUser,
  framePacket,
  createFrameParser,
};
