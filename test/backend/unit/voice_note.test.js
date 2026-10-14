'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { afterEach, beforeEach, describe, mock, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');
const { wrapPcmAsWav } = require('../../../server/services/voice/shared_audio');

const SAMPLE_RATE = 16000;
const HAS_FFMPEG = spawnSync(process.env.FFMPEG_BIN || 'ffmpeg', ['-version']).status === 0;

function pcm(seconds, sampleAt) {
  const count = seconds * SAMPLE_RATE;
  const buffer = Buffer.alloc(count * 2);
  for (let index = 0; index < count; index += 1) {
    const value = Math.max(-1, Math.min(1, sampleAt(index / SAMPLE_RATE)));
    buffer.writeInt16LE(Math.round(value * 32767), index * 2);
  }
  return buffer;
}

// 150 Hz voice with harmonics, gated into 150 ms syllables and 100 ms pauses.
function speechLike(t) {
  let voice = 0;
  for (let harmonic = 1; harmonic <= 5; harmonic += 1) {
    voice += Math.sin(2 * Math.PI * 150 * harmonic * t) / harmonic;
  }
  const phase = t % 0.25;
  const envelope = phase < 0.15 ? Math.sin((Math.PI * phase) / 0.15) : 0;
  return 0.3 * voice * envelope;
}

const steadyChord = (t) => 0.2 * (Math.sin(2 * Math.PI * 220 * t) + Math.sin(2 * Math.PI * 330 * t));
const bassBeat = (t) => (t % 0.5 < 0.1 ? 0.8 : 0.04) * Math.sin(2 * Math.PI * 60 * t);
const noiseClicks = (t) => (t % 0.3 < 0.08 ? 0.5 : 0.01) * (Math.random() * 2 - 1);

describe('voice note VAD', () => {
  const { analyzeSpeechActivity } = require('../../../server/services/voice/voice_note');

  test('detects syllabic voiced audio as speech', () => {
    assert.equal(analyzeSpeechActivity(pcm(3, speechLike)).speech, true);
  });

  test('rejects silence, steady music, sub-voice beats and noise bursts', () => {
    assert.equal(analyzeSpeechActivity(pcm(3, () => 0)).speech, false);
    assert.equal(analyzeSpeechActivity(pcm(3, steadyChord)).speech, false);
    assert.equal(analyzeSpeechActivity(pcm(3, bassBeat)).speech, false);
    assert.equal(analyzeSpeechActivity(pcm(3, noiseClicks)).speech, false);
  });
});

describe('voice note intent', () => {
  const {
    INTENT_AUDIO_CONTEXT: CONTEXT,
    INTENT_DICTATION: DICTATION,
    classifyVoiceNote,
  } = require('../../../server/services/voice/voice_note');
  const speech = { speech: true };

  test('short personal voice notes with speech are dictation on both platforms', () => {
    assert.equal(classifyVoiceNote({ vad: speech, source: 'whatsapp_ptt', durationSec: 3 }), DICTATION);
    assert.equal(classifyVoiceNote({ vad: speech, source: 'discord_voice_message', durationSec: 3 }), DICTATION);
  });

  test('no speech or uncertain VAD keeps the clip as context', () => {
    assert.equal(classifyVoiceNote({ vad: { speech: false }, source: 'whatsapp_ptt' }), CONTEXT);
    assert.equal(classifyVoiceNote({ vad: { speech: null }, source: 'discord_voice_message' }), CONTEXT);
  });

  test('a caption is the request and the clip becomes context', () => {
    assert.equal(
      classifyVoiceNote({ vad: speech, source: 'whatsapp_audio', durationSec: 45, caption: 'what is this' }),
      CONTEXT,
    );
  });

  test('files, forwarded notes and long clips are context even with speech', () => {
    assert.equal(classifyVoiceNote({ vad: speech, source: 'discord_audio_file', durationSec: 5 }), CONTEXT);
    assert.equal(classifyVoiceNote({ vad: speech, source: 'whatsapp_audio', durationSec: 5 }), CONTEXT);
    assert.equal(classifyVoiceNote({ vad: speech, source: 'whatsapp_ptt', forwarded: true }), CONTEXT);
    assert.equal(classifyVoiceNote({ vad: speech, source: 'whatsapp_ptt', durationSec: 600 }), CONTEXT);
  });

  test('without VAD, personal voice notes fall back to dictation and files to context', () => {
    assert.equal(classifyVoiceNote({ vad: null, source: 'whatsapp_ptt' }), DICTATION);
    assert.equal(classifyVoiceNote({ vad: null, source: 'discord_audio_file' }), CONTEXT);
  });
});

describe('voice note preparation', () => {
  let ctx;
  let tempDir;
  let transcription;
  let voiceNote;
  let userId;

  beforeEach(async () => {
    ctx = createTestRuntime();
    ({ userId } = await createTestUser(ctx.db));
    tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-voice-note-'));
    transcription = require('../../../server/services/voice/transcription');
    voiceNote = require('../../../server/services/voice/voice_note');
  });

  afterEach(() => {
    mock.restoreAll();
    fs.rmSync(tempDir, { recursive: true, force: true });
    teardownTestRuntime(ctx);
  });

  function writeWav(name, sampleAt) {
    const filePath = path.join(tempDir, name);
    fs.writeFileSync(filePath, wrapPcmAsWav(pcm(3, sampleAt), { sampleRate: SAMPLE_RATE, channels: 1, bitsPerSample: 16 }));
    return filePath;
  }

  function inbound(filePath, source, content = '') {
    return {
      platform: source.startsWith('discord') ? 'discord' : 'whatsapp',
      chatId: 'chat-1',
      content,
      mediaType: 'audio',
      localMediaPath: filePath,
      voiceNote: { source, durationSec: 3 },
    };
  }

  test('speech goes to STT and the transcript becomes the message', { skip: !HAS_FFMPEG }, async () => {
    const stt = mock.method(transcription, 'transcribeForUser', async () => "what's on my calendar");
    const msg = await voiceNote.prepareVoiceNote(
      inbound(writeWav('speech.wav', speechLike), 'whatsapp_ptt'),
      { userId },
    );
    assert.equal(stt.mock.callCount(), 1);
    assert.equal(msg.content, "what's on my calendar");
    assert.equal(msg.voiceNote.intent, voiceNote.INTENT_DICTATION);
    assert.ok(msg.localMediaPath, 'original audio stays on the turn');
  });

  test('non-speech audio skips STT and stays as context', { skip: !HAS_FFMPEG }, async () => {
    const stt = mock.method(transcription, 'transcribeForUser', async () => 'should not run');
    const msg = await voiceNote.prepareVoiceNote(
      inbound(writeWav('music.wav', steadyChord), 'discord_audio_file'),
      { userId },
    );
    assert.equal(stt.mock.callCount(), 0);
    assert.equal(msg.content, '');
    assert.equal(msg.voiceNote.intent, voiceNote.INTENT_AUDIO_CONTEXT);
  });

  test('a caption on a clip is the request and STT is skipped', { skip: !HAS_FFMPEG }, async () => {
    const stt = mock.method(transcription, 'transcribeForUser', async () => 'should not run');
    const msg = await voiceNote.prepareVoiceNote(
      inbound(writeWav('clip.wav', speechLike), 'whatsapp_audio', 'what is this'),
      { userId },
    );
    assert.equal(stt.mock.callCount(), 0);
    assert.equal(msg.content, 'what is this');
    assert.equal(msg.voiceNote.intent, voiceNote.INTENT_AUDIO_CONTEXT);
  });

  test('an STT failure keeps the dictation intent and records the error', { skip: !HAS_FFMPEG }, async () => {
    mock.method(transcription, 'transcribeForUser', async () => {
      throw new Error('openai STT timed out after 20000ms.');
    });
    const msg = await voiceNote.prepareVoiceNote(
      inbound(writeWav('speech.wav', speechLike), 'discord_voice_message'),
      { userId },
    );
    assert.equal(msg.voiceNote.intent, voiceNote.INTENT_DICTATION);
    assert.match(msg.voiceNote.sttError, /timed out/);
    assert.ok(msg.localMediaPath);
  });

  test('without ffmpeg a personal voice note still dictates', async () => {
    const previous = process.env.FFMPEG_BIN;
    process.env.FFMPEG_BIN = path.join(tempDir, 'missing-ffmpeg');
    try {
      mock.method(transcription, 'transcribeForUser', async () => 'call mom');
      const msg = await voiceNote.prepareVoiceNote(
        inbound(path.join(tempDir, 'note.ogg'), 'whatsapp_ptt'),
        { userId },
      );
      assert.equal(msg.voiceNote.intent, voiceNote.INTENT_DICTATION);
      assert.equal(msg.voiceNote.speech, 'unavailable');
      assert.equal(msg.content, 'call mom');
    } finally {
      if (previous === undefined) delete process.env.FFMPEG_BIN;
      else process.env.FFMPEG_BIN = previous;
    }
  });
});

describe('voice note prompts', () => {
  const sender = {
    platform: 'discord',
    chatId: 'dm_1',
    sender: '1',
    senderDisplayName: 'neo',
    isGroup: false,
    mediaType: 'audio',
    localMediaPath: '/data/artifacts/clip.ogg',
  };

  test('dictation runs as a spoken turn; audio context runs as a normal message', () => {
    const { isVoiceLikeMessage } = require('../../../server/services/voice/runtime');
    assert.equal(isVoiceLikeMessage({ ...sender, voiceNote: { intent: 'dictation' } }), true);
    assert.equal(isVoiceLikeMessage({ ...sender, voiceNote: { intent: 'audio_context' } }), false);
  });

  test('audio context prompt treats the caption as the request and the clip as context', () => {
    const { buildIncomingPrompt } = require('../../../server/services/messaging/automation');
    const prompt = buildIncomingPrompt({
      ...sender,
      content: 'what is this',
      voiceNote: { intent: 'audio_context', source: 'discord_audio_file' },
    });
    assert.match(prompt, /what is this/);
    assert.match(prompt, /not a spoken request/);
    assert.match(prompt, /transcribe_audio/);
    assert.match(prompt, /The message text is the request/);
  });

  test('failed transcription asks the model for one clarification instead of guessing', () => {
    const { buildVoiceMessagingPrompt } = require('../../../server/services/voice/runtime');
    const prompt = buildVoiceMessagingPrompt({
      ...sender,
      content: '',
      voiceNote: { intent: 'dictation', sttError: 'timed out' },
    });
    assert.match(prompt, /transcribing it failed \(timed out\)/);
    assert.match(prompt, /Do not guess/);
    assert.match(prompt, /one short question/);
  });

  test('history keeps the clip path so a follow-up can reclassify it', () => {
    const { voiceNoteHistoryText } = require('../../../server/services/voice/voice_note');
    assert.equal(
      voiceNoteHistoryText({ ...sender, content: 'call mom', voiceNote: { intent: 'dictation' } }),
      'call mom\n[dictated voice note: /data/artifacts/clip.ogg]',
    );
    assert.equal(
      voiceNoteHistoryText({ ...sender, content: '', voiceNote: { intent: 'audio_context' } }),
      '[audio clip: /data/artifacts/clip.ogg]',
    );
  });
});
