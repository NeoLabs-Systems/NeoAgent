'use strict';

const DEFAULT_PCM = Object.freeze({
  sampleRate: 24000,
  channels: 1,
  bitsPerSample: 16,
});

function pcmMimeType(format = DEFAULT_PCM) {
  return `audio/pcm;rate=${format.sampleRate};channels=${format.channels}`;
}

function wrapPcmAsWav(audioBytes, format = DEFAULT_PCM) {
  const data = Buffer.isBuffer(audioBytes) ? audioBytes : Buffer.from(audioBytes || []);
  const sampleRate = Number(format.sampleRate) || DEFAULT_PCM.sampleRate;
  const channels = Number(format.channels) || DEFAULT_PCM.channels;
  const bitsPerSample = Number(format.bitsPerSample) || DEFAULT_PCM.bitsPerSample;
  const blockAlign = channels * (bitsPerSample / 8);
  const byteRate = sampleRate * blockAlign;
  const header = Buffer.alloc(44);
  header.write('RIFF', 0, 4, 'ascii');
  header.writeUInt32LE(36 + data.length, 4);
  header.write('WAVE', 8, 4, 'ascii');
  header.write('fmt ', 12, 4, 'ascii');
  header.writeUInt32LE(16, 16);
  header.writeUInt16LE(1, 20);
  header.writeUInt16LE(channels, 22);
  header.writeUInt32LE(sampleRate, 24);
  header.writeUInt32LE(byteRate, 28);
  header.writeUInt16LE(blockAlign, 32);
  header.writeUInt16LE(bitsPerSample, 34);
  header.write('data', 36, 4, 'ascii');
  header.writeUInt32LE(data.length, 40);
  return Buffer.concat([header, data]);
}

module.exports = {
  DEFAULT_PCM,
  pcmMimeType,
  wrapPcmAsWav,
};
