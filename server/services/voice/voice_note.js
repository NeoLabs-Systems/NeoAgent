'use strict';

const { spawn } = require('child_process');
const { createServiceLogger } = require('../../utils/logger');
const { runWithAbortTimeout } = require('../../utils/abort');
const { getVoiceRuntimeSettings } = require('./liveSettings');
const providers = require('./providers');

const log = createServiceLogger('VoiceNote');

// Inbound chat audio (WhatsApp PTT/audio, Discord voice messages/audio files)
// goes through one path: VAD first, then either dictation (STT transcript is
// the user's message) or audio_context (the clip itself is the payload and no
// transcript is invented as a request).
const INTENT_DICTATION = 'dictation';
const INTENT_AUDIO_CONTEXT = 'audio_context';
const VOICE_NOTE_SOURCES = new Set(['whatsapp_ptt', 'discord_voice_message']);

const SAMPLE_RATE = 16000;
const FRAME_SAMPLES = 320; // 20 ms
const FRAMES_PER_WINDOW = 50; // 1 s
const VAD_MAX_SECONDS = 180;
const VAD_TIMEOUT_MS = 8000;
const STT_TIMEOUT_MS = 20000;
const DICTATION_MAX_SECONDS = 180;

// Energy thresholds are on normalized RMS (1.0 = full scale).
const SILENCE_RMS = 0.004;
const MIN_ACTIVE_RATIO = 0.08;
// Speech alternates syllables and short pauses, so a large share of frames in
// each second sit well below that second's mean energy. Music, hum and steady
// noise stay close to their mean. Between the two bounds VAD is uncertain.
const SPEECH_LOW_ENERGY_RATIO = 0.3;
const NON_SPEECH_LOW_ENERGY_RATIO = 0.18;
// Share of active frames that must carry a pitch in the human voice range
// (70–400 Hz). Rejects beats, rumble and hiss that pulse like syllables.
const MIN_VOICED_RATIO = 0.2;
const VOICED_CORRELATION = 0.5;
const PITCH_MIN_LAG = Math.floor(SAMPLE_RATE / 2 / 400);
const PITCH_MAX_LAG = Math.ceil(SAMPLE_RATE / 2 / 70);

function frameRms(pcm) {
  const sampleCount = Math.floor(pcm.length / 2);
  const frameCount = Math.floor(sampleCount / FRAME_SAMPLES);
  const values = new Float64Array(frameCount);
  for (let frame = 0; frame < frameCount; frame += 1) {
    let sum = 0;
    const start = frame * FRAME_SAMPLES;
    for (let index = 0; index < FRAME_SAMPLES; index += 1) {
      const sample = pcm.readInt16LE((start + index) * 2) / 32768;
      sum += sample * sample;
    }
    values[frame] = Math.sqrt(sum / FRAME_SAMPLES);
  }
  return values;
}

// Normalized autocorrelation peak over pitch lags, on every second sample to
// keep the cost small.
function isVoicedFrame(pcm, frame) {
  const start = frame * FRAME_SAMPLES;
  const length = FRAME_SAMPLES / 2;
  const samples = new Float64Array(length);
  let energy = 0;
  for (let index = 0; index < length; index += 1) {
    const sample = pcm.readInt16LE((start + index * 2) * 2);
    samples[index] = sample;
    energy += sample * sample;
  }
  if (!energy) return false;
  let bestLag = 0;
  let best = -Infinity;
  for (let lag = PITCH_MIN_LAG; lag <= PITCH_MAX_LAG; lag += 1) {
    let sum = 0;
    for (let index = 0; index + lag < length; index += 1) sum += samples[index] * samples[index + lag];
    if (sum > best) {
      best = sum;
      bestLag = lag;
    }
  }
  // A peak on the edge of the range means the period lies outside the voice
  // range (rumble below 70 Hz, hiss above 400 Hz).
  return best / energy >= VOICED_CORRELATION
    && bestLag > PITCH_MIN_LAG
    && bestLag < PITCH_MAX_LAG;
}

function percentile(values, fraction) {
  const sorted = Array.from(values).sort((a, b) => a - b);
  return sorted[Math.min(sorted.length - 1, Math.floor(sorted.length * fraction))] || 0;
}

// Classifies 16 kHz mono s16le PCM. speech is true, false, or null (uncertain).
function analyzeSpeechActivity(pcm) {
  const rms = frameRms(pcm);
  const durationSec = pcm.length / 2 / SAMPLE_RATE;
  if (rms.length < FRAMES_PER_WINDOW / 2) {
    return { speech: false, durationSec, activeRatio: 0, voicedRatio: 0, lowEnergyRatio: 0 };
  }

  const activeThreshold = Math.max(SILENCE_RMS, percentile(rms, 0.1) * 2.5);
  let active = 0;
  let voiced = 0;
  for (let frame = 0; frame < rms.length; frame += 1) {
    if (rms[frame] <= activeThreshold) continue;
    active += 1;
    if (isVoicedFrame(pcm, frame)) voiced += 1;
  }
  const activeRatio = active / rms.length;
  const voicedRatio = active ? voiced / active : 0;

  let lowFrames = 0;
  let countedFrames = 0;
  for (let start = 0; start < rms.length; start += FRAMES_PER_WINDOW) {
    const window = rms.subarray(start, Math.min(rms.length, start + FRAMES_PER_WINDOW));
    let mean = 0;
    for (const value of window) mean += value;
    mean /= window.length;
    if (mean <= SILENCE_RMS) continue;
    for (const value of window) if (value < mean * 0.5) lowFrames += 1;
    countedFrames += window.length;
  }
  const lowEnergyRatio = countedFrames ? lowFrames / countedFrames : 0;

  let speech = null;
  if (
    activeRatio < MIN_ACTIVE_RATIO
    || voicedRatio < MIN_VOICED_RATIO
    || lowEnergyRatio < NON_SPEECH_LOW_ENERGY_RATIO
  ) {
    speech = false;
  } else if (lowEnergyRatio >= SPEECH_LOW_ENERGY_RATIO) {
    speech = true;
  }
  return { speech, durationSec, activeRatio, voicedRatio, lowEnergyRatio };
}

function decodePcm(filePath, signal) {
  const ffmpegBin = String(process.env.FFMPEG_BIN || 'ffmpeg').trim() || 'ffmpeg';
  return new Promise((resolve, reject) => {
    const child = spawn(ffmpegBin, [
      '-hide_banner', '-loglevel', 'error', '-nostdin',
      '-t', String(VAD_MAX_SECONDS), '-i', filePath,
      '-vn', '-ac', '1', '-ar', String(SAMPLE_RATE), '-f', 's16le', 'pipe:1',
    ], { signal, stdio: ['ignore', 'pipe', 'pipe'] });
    const chunks = [];
    let stderr = '';
    child.stdout.on('data', (chunk) => chunks.push(chunk));
    child.stderr.on('data', (chunk) => { stderr += chunk; });
    child.on('error', reject);
    child.on('close', (code) => {
      if (code === 0) resolve(Buffer.concat(chunks));
      else reject(new Error(`ffmpeg exited with code ${code}: ${stderr.trim().slice(0, 200)}`));
    });
  });
}

// Returns null when VAD could not run (for example ffmpeg is not installed).
async function detectSpeech(filePath, { signal } = {}) {
  try {
    const pcm = await runWithAbortTimeout((linked) => decodePcm(filePath, linked), {
      signal,
      timeoutMs: VAD_TIMEOUT_MS,
      timeoutCode: 'VOICE_VAD_TIMEOUT',
      label: 'Voice note VAD',
    });
    return analyzeSpeechActivity(pcm);
  } catch (error) {
    if (signal?.aborted) throw error;
    log.warn(`VAD unavailable: ${error.message}`);
    return null;
  }
}

function classifyVoiceNote({ vad, source, durationSec, caption, forwarded }) {
  const isVoiceNote = VOICE_NOTE_SOURCES.has(source) && !forwarded;
  // A caption is the real request; the clip is what it is about.
  if (String(caption || '').trim()) return INTENT_AUDIO_CONTEXT;
  if (!vad) return isVoiceNote ? INTENT_DICTATION : INTENT_AUDIO_CONTEXT;
  if (vad.speech !== true) return INTENT_AUDIO_CONTEXT;
  if (!isVoiceNote) return INTENT_AUDIO_CONTEXT;
  if (Number(durationSec) > DICTATION_MAX_SECONDS) return INTENT_AUDIO_CONTEXT;
  return INTENT_DICTATION;
}

async function transcribeFile(filePath, { userId, agentId, signal, timeoutMs = STT_TIMEOUT_MS }) {
  const settings = getVoiceRuntimeSettings(userId, agentId);
  return String(await providers.transcribeVoiceInput(filePath, {
    provider: settings.sttProvider,
    model: settings.sttModel,
    userId,
    agentId,
    timeoutMs,
    signal,
  }) || '').trim();
}

function isPendingVoiceNote(msg) {
  return Boolean(msg?.voiceNote && !msg.voiceNote.intent && msg.localMediaPath);
}

// Runs VAD, picks the intent and, only for dictation, transcribes the clip.
// The original audio always stays on the message.
async function prepareVoiceNote(msg, { userId, agentId = null, signal = null } = {}) {
  if (!isPendingVoiceNote(msg)) return msg;
  const startedAt = Date.now();
  const caption = String(msg.content || '').trim();
  const vad = await detectSpeech(msg.localMediaPath, { signal });
  const durationSec = Number(msg.voiceNote.durationSec) || vad?.durationSec || null;
  const intent = classifyVoiceNote({
    vad,
    source: msg.voiceNote.source,
    durationSec,
    caption,
    forwarded: msg.voiceNote.forwarded === true,
  });
  const voiceNote = {
    ...msg.voiceNote,
    intent,
    durationSec,
    speech: vad ? vad.speech : 'unavailable',
  };

  let content = caption;
  if (intent === INTENT_DICTATION) {
    try {
      content = await transcribeFile(msg.localMediaPath, { userId, agentId, signal });
      if (!content) voiceNote.sttError = 'empty transcript';
    } catch (error) {
      if (signal?.aborted) throw error;
      voiceNote.sttError = error.message;
    }
  }

  log.info(
    `source=${voiceNote.source} speech=${voiceNote.speech} intent=${intent}`
    + `${voiceNote.sttError ? ` stt_error=${voiceNote.sttError}` : ''} took=${Date.now() - startedAt}ms`,
  );
  return { ...msg, content, voiceNote };
}

// History keeps only the raw message, so the clip reference must live there
// for a follow-up ("that was audio, not a message") to reach the same file.
function voiceNoteHistoryText(msg) {
  const text = String(msg.content || '').trim();
  if (!msg.voiceNote?.intent || !msg.localMediaPath) return text;
  const marker = `[${msg.voiceNote.intent === INTENT_DICTATION ? 'dictated voice note' : 'audio clip'}: ${msg.localMediaPath}]`;
  return text ? `${text}\n${marker}` : marker;
}

module.exports = {
  INTENT_AUDIO_CONTEXT,
  INTENT_DICTATION,
  analyzeSpeechActivity,
  classifyVoiceNote,
  detectSpeech,
  isPendingVoiceNote,
  prepareVoiceNote,
  transcribeFile,
  voiceNoteHistoryText,
};
