'use strict';

const { BasePlatform } = require('./base');
const path = require('path');
const fs = require('fs');
const https = require('https');
const { OpenAI } = require('openai');
const { DATA_DIR, AGENT_DATA_DIR } = require('../../../runtime/paths');

const AUDIO_DIR = path.join(DATA_DIR, 'telnyx-audio');
const RECORDING_TURN_LIMIT_MS = 4000;

class TelnyxVoicePlatform extends BasePlatform {
  constructor(config = {}) {
    super('telnyx', config);
    this.supportsVoice = true;

    this.apiKey = config.apiKey || '';
    this.phoneNumber = config.phoneNumber || '';
    this.connectionId = config.connectionId || '';
    this.webhookUrl = config.webhookUrl || '';
    this.ttsVoice = config.ttsVoice || 'alloy';
    this.ttsModel = config.ttsModel || 'tts-1';
    this.sttModel = config.sttModel || 'whisper-1';
    this.allowedNumbers = Array.isArray(config.allowedNumbers)
      ? config.allowedNumbers
      : [];
    this.voiceSecret = String(config.voiceSecret || '').replace(/\D/g, '');

    this._sessions = new Map();
    this._recordingTimers = new Map();
    this._secretTimers = new Map();
    this._bannedNumbers = new Map();
    this._client = null;
    this._openai = null;
    this._webhookToken = null;
    this._thinkAudioFile = null;
  }

  async connect() {
    if (!this.apiKey || !this.phoneNumber || !this.connectionId || !this.webhookUrl) {
      throw new Error('Telnyx Voice requires apiKey, phoneNumber, connectionId, and webhookUrl');
    }

    if (!fs.existsSync(AUDIO_DIR)) fs.mkdirSync(AUDIO_DIR, { recursive: true });

    const TelnyxSDK = require('telnyx');
    const TelnyxClient = TelnyxSDK.default || TelnyxSDK;
    this._client = new TelnyxClient({ apiKey: this.apiKey });

    let openAiKey = process.env.OPENAI_API_KEY;
    if (!openAiKey) {
      try {
        const keysPath = path.join(AGENT_DATA_DIR, 'API_KEYS.json');
        const keys = JSON.parse(fs.readFileSync(keysPath, 'utf8'));
        openAiKey = keys.OPENAI_API_KEY || keys.openai_api_key || keys.openai || null;
      } catch {}
    }
    if (openAiKey) {
      this._openai = new OpenAI({ apiKey: openAiKey });
      console.log('[TelnyxVoice] OpenAI TTS enabled');
    } else {
      console.warn('[TelnyxVoice] No OpenAI API key found — TTS will use Telnyx native speak (language auto-detected)');
    }

    const token = process.env.TELNYX_WEBHOOK_TOKEN;
    this._webhookToken = token || null;
    const inboundUrl = `${this.webhookUrl}/api/telnyx/webhook${token ? `?token=${token}` : ''}`;
    console.log(`[TelnyxVoice] Inbound webhook URL (configure this in the Telnyx portal): ${inboundUrl}`);

    this._precacheThinkAudio();

    this.status = 'connected';
    this.emit('connected');
    console.log(`[TelnyxVoice] Connected — phone: ${this.phoneNumber}`);
    return { status: 'connected', inboundWebhookUrl: inboundUrl };
  }

  async disconnect() {
    // Hang up any live calls
    for (const [ccId] of this._sessions) {
      try { await this._client.calls.actions.hangup(ccId); } catch {}
    }
    this._sessions.clear();
    for (const t of this._recordingTimers.values()) clearTimeout(t);
    this._recordingTimers.clear();
    for (const t of this._secretTimers.values()) clearTimeout(t);
    this._secretTimers.clear();
    this.status = 'disconnected';
    this.emit('disconnected', {});
  }

  async logout() {
    await this.disconnect();
  }

  getStatus() { return this.status; }
  getAuthInfo() { return { phoneNumber: this.phoneNumber }; }

  setAllowedNumbers(numbers) {
    this.allowedNumbers = Array.isArray(numbers) ? numbers : [];
    console.log(`[TelnyxVoice] Whitelist updated: ${this.allowedNumbers.length} number(s)`);
  }

  setVoiceSecret(secret) {
    this.voiceSecret = String(secret || '').replace(/\D/g, '');
    console.log(`[TelnyxVoice] Voice secret updated (${this.voiceSecret.length} digit(s))`);
  }

  _isAllowed(number) {
    if (!this.allowedNumbers || !this.allowedNumbers.length) return false;
    const normalize = (n) => n.replace(/\D/g, '');
    const cn = normalize(number);
    return this.allowedNumbers.some(wl => {
      const cw = normalize(wl);
      return cn === cw || cn.endsWith(cw) || cw.endsWith(cn);
    });
  }

  _normalizeNumber(n) {
    return n.replace(/\D/g, '');
  }

  _isBanned(number) {
    const key = this._normalizeNumber(number);
    const expiry = this._bannedNumbers.get(key);
    if (!expiry) return false;
    if (Date.now() > expiry) {
      this._bannedNumbers.delete(key);
      return false;
    }
    return true;
  }

  _banNumber(number, durationMs = 10 * 60 * 1000) {
    const key = this._normalizeNumber(number);
    this._bannedNumbers.set(key, Date.now() + durationMs);
    console.log(`[TelnyxVoice] Banned ${number} for ${durationMs / 60000} min`);
  }

  _startSecretTimer(ccId) {
    this._cancelSecretTimer(ccId);
    const t = setTimeout(async () => {
      this._secretTimers.delete(ccId);
      if (!this._hasSession(ccId)) return;
      const sess = this._session(ccId);
      if (!sess.awaitingSecret) return;
      console.log(`[TelnyxVoice] Secret code timeout for ${ccId.slice(-8)} (${sess.callerNumber})`);
      this._banNumber(sess.callerNumber);
      this._endSession(ccId);
      try { await this._hangupCall(ccId); } catch {}
    }, 10000);
    this._secretTimers.set(ccId, t);
  }

  _cancelSecretTimer(ccId) {
    const t = this._secretTimers.get(ccId);
    if (t) { clearTimeout(t); this._secretTimers.delete(ccId); }
  }

  _initSession(ccId, callerNumber = '') {
    this._sessions.set(ccId, {
      callerNumber,
      isProcessing: false,
      awaitingUserInput: false,
      isThinking: false,
      replySent: false,
      processedRecordings: new Set(),
      awaitingSecret: false,
      secretDigits: '',
    });
  }

  _session(ccId)    { return this._sessions.get(ccId); }
  _hasSession(ccId) { return this._sessions.has(ccId); }

  _endSession(ccId) {
    this._sessions.delete(ccId);
    this._cancelRecordingTimer(ccId);
    this._cancelSecretTimer(ccId);
  }

  _scheduleRecordingStop(ccId) {
    this._cancelRecordingTimer(ccId);
    const t = setTimeout(async () => {
      this._recordingTimers.delete(ccId);
      if (!this._hasSession(ccId)) return;
      console.log(`[TelnyxVoice] Auto-stopping recording for ${ccId}`);
      try { await this._stopRecording(ccId); } catch {}
    }, RECORDING_TURN_LIMIT_MS);
    this._recordingTimers.set(ccId, t);
  }

  _cancelRecordingTimer(ccId) {
    const t = this._recordingTimers.get(ccId);
    if (t) { clearTimeout(t); this._recordingTimers.delete(ccId); }
  }

  _isTerminalError(err) {
    const errs = (err.error?.errors) || err.errors ||
                 (err.raw?.errors)   || (err.response?.data?.errors);
    if (!errs) return false;
    return errs.some(e => ['90018', '90053', '90055'].includes(String(e.code)));
  }

  async _answerCall(ccId) {
    try { await this._client.calls.actions.answer(ccId); }
    catch (err) { if (!this._isTerminalError(err)) throw err; }
  }

  async _rejectCall(ccId) {
    try { await this._client.calls.actions.reject(ccId, { cause: 'CALL_REJECTED' }); } catch {}
  }

  async _hangupCall(ccId) {
    try { await this._client.calls.actions.hangup(ccId); }
    catch (err) { if (!this._isTerminalError(err)) throw err; }
  }

  async _playAudio(ccId, url, loop = false) {
    try {
      await this._client.calls.actions.startPlayback(ccId, {
        audio_url: url,
        loop: loop ? 'infinity' : 1,
      });
    } catch (err) { if (!this._isTerminalError(err)) throw err; }
  }

  async _stopAudio(ccId) {
    try { await this._client.calls.actions.stopPlayback(ccId, {}); }
    catch (err) { if (!this._isTerminalError(err)) throw err; }
  }

  async _startRecording(ccId) {
    try {
      await this._client.calls.actions.startRecording(ccId, {
        format: 'mp3',
        channels: 'single',
        play_beep: false,
        time_limit: 60,
      });
    } catch (err) { if (!this._isTerminalError(err)) throw err; }
  }

  async _stopRecording(ccId) {
    try { await this._client.calls.actions.stopRecording(ccId, {}); }
    catch (err) { if (!this._isTerminalError(err)) throw err; }
  }

  async _precacheThinkAudio() {
    if (!this._openai) return;
    try {
      const file = `think_hold_${Date.now()}.mp3`;
      const filePath = path.join(AUDIO_DIR, file);
      const mp3 = await this._openai.audio.speech.create({
        model: this.ttsModel,
        voice: this.ttsVoice,
        input: 'One moment please.',
      });
      const buf = Buffer.from(await mp3.arrayBuffer());
      await fs.promises.writeFile(filePath, buf);
      this._thinkAudioFile = file;
      console.log('[TelnyxVoice] Think audio pre-cached');
    } catch (err) {
      console.warn(`[TelnyxVoice] Failed to pre-cache think audio: ${err.message}`);
    }
  }

  async _playThinkAudio(ccId) {
    if (this._thinkAudioFile) {
      try {
        await this._playAudio(ccId, this._publicUrl(this._thinkAudioFile));
        return;
      } catch (err) {
        console.warn(`[TelnyxVoice] Pre-cached think audio failed: ${err.message}`);
      }
    }
    try {
      await this._client.calls.actions.speak(ccId, {
        payload:  'One moment please.',
        voice:    'female',
        language: 'en-US',
      });
    } catch (err) {
      if (!this._isTerminalError(err)) console.error('[TelnyxVoice] Think speak failed:', err.message);
    }
  }

  async _tts(text, destPath) {
    const mp3 = await this._openai.audio.speech.create({
      model: this.ttsModel,
      voice: this.ttsVoice,
      input: text,
    });
    const buf = Buffer.from(await mp3.arrayBuffer());
    await fs.promises.writeFile(destPath, buf);
  }

  async _sayText(ccId, text) {
    if (this._openai) {
      try {
        const file = this._tmpFile('say', ccId);
        const filePath = path.join(AUDIO_DIR, file);
        await this._tts(text, filePath);
        await this._playAudio(ccId, this._publicUrl(file));
        setTimeout(() => fs.unlink(filePath, () => {}), 60000);
        return;
      } catch (err) {
        console.warn(`[TelnyxVoice] OpenAI TTS failed (${err.message}), falling back to Telnyx speak`);
      }
    }
    try {
      const isGerman = /\b(ich|du|ist|und|der|die|das|nicht|ein|hallo|auf|danke|bitte|wie|was|wer|wo|warum|kann|haben|sein|noch|auch|mit|von|bei|nach|für)\b/i.test(text);
      await this._client.calls.actions.speak(ccId, {
        payload:  text,
        voice:    'female',
        language: isGerman ? 'de-DE' : 'en-US',
      });
    } catch (speakErr) {
      console.error(`[TelnyxVoice] Telnyx speak also failed: ${speakErr.message}`, speakErr?.error?.errors || '');
      if (!this._isTerminalError(speakErr)) throw speakErr;
    }
  }

  async _stt(filePath) {
    try {
      const t = await this._openai.audio.transcriptions.create({
        file:  fs.createReadStream(filePath),
        model: this.sttModel,
      });
      return t.text;
    } catch (err) {
      console.error('[TelnyxVoice] STT error:', err.message);
      return '';
    }
  }

  async _downloadRecording(url, dest) {
    return new Promise((resolve, reject) => {
      const file = fs.createWriteStream(dest);
      https.get(url, (res) => {
        if (res.statusCode !== 200) {
          file.close();
          return reject(new Error(`Download failed: ${res.statusCode}`));
        }
        res.pipe(file);
        file.on('finish', () => file.close(resolve));
      }).on('error', (err) => { fs.unlink(dest, () => {}); reject(err); });
    });
  }

  _publicUrl(filename) {
    return `${this.webhookUrl}/telnyx-audio/${filename}`;
  }

  _tmpFile(prefix, ccId) {
    return `${prefix}_${ccId.replace(/[^a-zA-Z0-9]/g, '')}_${Date.now()}.mp3`;
  }

  async handleWebhook(event) {
    if (!event?.data?.event_type) return;
    const { event_type: eventType, payload } = event.data;
    const ccId = payload?.call_control_id;
    if (!ccId) return;

    if (!this._hasSession(ccId) &&
        eventType !== 'call.initiated' &&
        eventType !== 'call.answered') {
      return;
    }

    if (eventType === 'call.initiated' && payload.direction === 'outbound') return;

    console.log(`[TelnyxVoice] ${eventType} — ccId=${ccId.slice(-8)}`);

    try {
      switch (eventType) {
        case 'call.initiated': {
          if (payload.direction !== 'incoming') break;
          const caller = payload.from;
          if (!this._isAllowed(caller)) {
            if (this._isBanned(caller)) {
              console.log(`[TelnyxVoice] Rejecting banned caller: ${caller}`);
              await this._rejectCall(ccId);
              this.emit('blocked_caller', { caller, ccId });
              break;
            }
            if (!this.voiceSecret) {
              console.log(`[TelnyxVoice] Blocked non-whitelisted caller (no secret set): ${caller}`);
              await this._rejectCall(ccId);
              this.emit('blocked_caller', { caller, ccId });
              break;
            }
            console.log(`[TelnyxVoice] Non-whitelisted caller ${caller} — awaiting secret code`);
            this._initSession(ccId, caller);
            this._session(ccId).awaitingSecret = true;
            await this._answerCall(ccId);
            break;
          }
          this._initSession(ccId, caller);
          await this._answerCall(ccId);
          console.log(`[TelnyxVoice] Answered inbound call from ${caller}`);
          break;
        }
        case 'call.answered': {
          if (!this._hasSession(ccId)) {
            const caller = payload.from || payload.to || ccId;
            this._initSession(ccId, caller);
            console.log(`[TelnyxVoice] call.answered race — session created late for ${ccId.slice(-8)}`);
          }
          const sess = this._session(ccId);
          if (sess.awaitingSecret) {
            this._startSecretTimer(ccId);
            break;
          }
          sess.isProcessing = true;
          sess.awaitingUserInput = true;
          const greetText = sess._outboundGreeting || 'Hello! I am your AI assistant. How can I help you?';
          delete sess._outboundGreeting;
          await this._sayText(ccId, greetText);
          break;
        }
        case 'call.playback.started':
          if (this._hasSession(ccId) && !this._session(ccId).isThinking)
            this._session(ccId).isProcessing = true;
          break;

        case 'call.playback.ended':
        case 'call.speak.ended': {
          if (!this._hasSession(ccId)) break;
          const sess = this._session(ccId);
          if (sess.isThinking) break;
          sess.isProcessing = false;
          if (!sess.awaitingUserInput) break;
          sess.awaitingUserInput = false;
          setTimeout(async () => {
            try {
              await this._startRecording(ccId);
              this._scheduleRecordingStop(ccId);
            } catch {}
          }, 200);
          break;
        }
        case 'call.dtmf.received': {
          if (!this._hasSession(ccId)) break;
          const sess = this._session(ccId);
          if (sess.awaitingSecret) {
            const digit = String(payload.digit ?? payload.dtmf_digit ?? '').trim();
            if (/^[0-9]$/.test(digit)) {
              sess.secretDigits += digit;
              if (this.voiceSecret && sess.secretDigits.length >= this.voiceSecret.length) {
                this._cancelSecretTimer(ccId);
                if (sess.secretDigits === this.voiceSecret) {
                  console.log(`[TelnyxVoice] Secret accepted for ${ccId.slice(-8)} (${sess.callerNumber})`);
                  sess.awaitingSecret = false;
                  sess.secretDigits = '';
                  sess.isProcessing = true;
                  sess.awaitingUserInput = true;
                  await this._sayText(ccId, 'Hello! I am your AI assistant. How can I help you?');
                } else {
                  console.log(`[TelnyxVoice] Wrong secret from ${sess.callerNumber}, banning`);
                  this._banNumber(sess.callerNumber);
                  this._endSession(ccId);
                  try { await this._hangupCall(ccId); } catch {}
                }
              }
            }
            break;
          }

          // ── Normal in-call DTMF — interrupt and restart recording ──────────
          this._cancelRecordingTimer(ccId);
          sess.isProcessing      = true;
          sess.awaitingUserInput = false;
          sess.isThinking        = false; // cancel think state if user interrupts
          sess.replySent         = false; // allow a fresh reply for the new turn
          await this._stopAudio(ccId);
          await this._stopRecording(ccId);
          setTimeout(async () => {
            if (!this._hasSession(ccId)) return;
            this._session(ccId).isProcessing = false;
            try {
              await this._startRecording(ccId);
              this._scheduleRecordingStop(ccId);
            } catch {}
          }, 150);
          break;
        }

        // ── Recording saved — STT → emit message → agent replies ───────────
        case 'call.recording.saved': {
          this._cancelRecordingTimer(ccId);
          if (!this._hasSession(ccId)) break;
          const sess = this._session(ccId);

          const recordingUrl = payload.recording_urls?.mp3;
          if (!recordingUrl) break;
          // Dedup before isProcessing check — prevents Telnyx retries from slipping through.
          if (sess.processedRecordings.has(recordingUrl)) break;
          sess.processedRecordings.add(recordingUrl);

          if (sess.isProcessing) break;

          sess.isProcessing     = true;
          sess.awaitingUserInput = false;

          // Download + transcribe
          const recFile = this._tmpFile('rec', ccId);
          const recPath = path.join(AUDIO_DIR, recFile);
          try {
            await this._downloadRecording(recordingUrl, recPath);
          } catch (err) {
            console.error('[TelnyxVoice] Failed to download recording:', err.message);
            sess.isProcessing = false;
            break;
          }

          const transcript = await this._stt(recPath);
          fs.unlink(recPath, () => {});

          if (!transcript?.trim()) {
            // Nothing intelligible — restart recording
            console.log(`[TelnyxVoice] Empty transcript for ${ccId}, restarting recording`);
            sess.isProcessing    = false;
            sess.awaitingUserInput = true;
            try { await this._startRecording(ccId); this._scheduleRecordingStop(ccId); } catch {}
            break;
          }

          console.log(`[TelnyxVoice] Transcript [${sess.callerNumber}]: ${transcript}`);

          // Mark as thinking — gates call.playback.ended so think-audio events
          // don't corrupt session state while the agent is processing.
          sess.isThinking = true;
          sess.replySent  = false;

          // Fire hold phrase and agent processing in parallel — the pre-cached
          // think audio plays instantly while the AI starts working immediately.
          this._playThinkAudio(ccId).catch(err =>
            console.error('[TelnyxVoice] Failed to play think audio:', err.message)
          );

          // Emit message event — MessagingManager routes it to the AI engine.
          // The agent will call sendMessage(ccId, response) when it has a reply.
          this.emit('message', {
            messageId:  `telnyx_${ccId}_${Date.now()}`,
            chatId:     ccId,
            sender:     sess.callerNumber || ccId,
            senderName: sess.callerNumber || 'Caller',
            content:    transcript,
            isGroup:    false,
            mediaType:  'voice',
            timestamp:  new Date().toISOString(),
          });
          break;
        }

        // ── Hangup — clean up session ───────────────────────────────────────
        case 'call.hangup': {
          this._endSession(ccId);
          console.log(`[TelnyxVoice] Call ended (${ccId.slice(-8)})`);
          break;
        }

        default:
          break;
      }
    } catch (err) {
      console.error(`[TelnyxVoice] Error handling ${eventType} for ${ccId}:`, err.message || err);
    }
  }

  // ── sendMessage — agent TTS reply to an active call ────────────────────────
  //   `to` is the callControlId (= msg.chatId from the message event)

  async sendMessage(to, content, _options = {}) {
    const sess = this._session(to);
    if (!sess) {
      console.warn(`[TelnyxVoice] sendMessage: no active session for ${to} (call may have ended)`);
      return { success: false, reason: 'call_ended' };
    }

    // Guard against the agent calling send_message more than once per turn.
    if (sess.replySent) {
      console.warn(`[TelnyxVoice] sendMessage: reply already sent for this turn, ignoring duplicate`);
      return { success: false, reason: 'already_replied' };
    }
    sess.replySent  = true;
    // Keep isThinking=true until the response audio command is accepted by Telnyx.
    // This blocks any stray call.playback.ended (from the think-audio stop) from
    // corrupting session state during the transition window.

    // Stop the "please hold" TTS (suppress all errors — it may have already ended)
    try { await this._stopAudio(to); } catch {}

    // Generate TTS response and play it.
    // If anything here throws, reset replySent so the session isn't bricked.
    try {
      // Commit state before firing audio so call.playback/speak.ended
      // belongs to this response, not any residual think audio.
      sess.isThinking      = false;
      sess.isProcessing    = true;
      sess.awaitingUserInput = true;
      await this._sayText(to, content);
    } catch (err) {
      // Audio failed — reset so the turn isn't silently lost.
      sess.replySent     = false;
      sess.isThinking    = false;
      sess.isProcessing  = false;
      console.error('[TelnyxVoice] sendMessage failed:', err.message);
      throw err;
    }

    return { success: true };
  }

  // ── Initiate outbound call (optional, for agent-triggered calls) ────────────

  async initiateCall(to, greetingText) {
    if (!this._client) throw new Error('Telnyx not connected');
    if (!this._isAllowed(to)) throw new Error(`Number ${to} not in whitelist`);
    const webhookUrl = `${this.webhookUrl}/api/telnyx/webhook${this._webhookToken ? `?token=${this._webhookToken}` : ''}`;
    const call = await this._client.calls.dial({
      to,
      from:          this.phoneNumber,
      connection_id: this.connectionId,
      webhook_url:   webhookUrl,
    });
    const ccId = call.data.call_control_id;
    this._initSession(ccId, to);
    if (greetingText) {
      // Store greeting — will be played on call.answered
      this._session(ccId)._outboundGreeting = greetingText;
    }
    return { callControlId: ccId };
  }
}

module.exports = { TelnyxVoicePlatform };
