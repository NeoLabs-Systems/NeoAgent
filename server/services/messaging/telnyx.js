'use strict';

const { BasePlatform } = require('./base');
const path = require('path');
const fs = require('fs');
const https = require('https');
const { DATA_DIR } = require('../../../runtime/paths');
const {
  DEFAULT_STT_PROVIDER,
  DEFAULT_TTS_PROVIDER,
  normalizeSttProvider,
  normalizeTtsProvider,
  resolveSttModel,
  resolveTtsModel,
  resolveTtsVoice,
  guessExtFromMimeType,
  transcribeVoiceInput,
  synthesizeVoiceReply,
} = require('../voice/providers');
const { createVoiceMessage } = require('../voice/message');
const { createVoiceTurnSessionState } = require('../voice/turnState');

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
    this.sttProvider = normalizeSttProvider(config.sttProvider || DEFAULT_STT_PROVIDER);
    this.ttsProvider = normalizeTtsProvider(config.ttsProvider || DEFAULT_TTS_PROVIDER);
    this.ttsVoice = resolveTtsVoice(this.ttsProvider, config.ttsVoice);
    this.ttsModel = resolveTtsModel(this.ttsProvider, config.ttsModel);
    this.sttModel = resolveSttModel(this.sttProvider, config.sttModel);
    this.allowedNumbers = Array.isArray(config.allowedNumbers)
      ? config.allowedNumbers
      : [];
    this.voiceSecret = String(config.voiceSecret || '').replace(/\D/g, '');

    this._sessions = new Map();
    this._recordingTimers = new Map();
    this._secretTimers = new Map();
    this._bannedNumbers = new Map();
    this._client = null;
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

    console.log(
      `[TelnyxVoice] Voice providers: STT=${this.sttProvider}/${this.sttModel}, ` +
      `TTS=${this.ttsProvider}/${this.ttsModel}${this.ttsVoice ? ` (${this.ttsVoice})` : ''}`,
    );

    const token = process.env.TELNYX_WEBHOOK_TOKEN;
    this._webhookToken = token || null;
    const inboundUrl = `${this.webhookUrl}/api/telnyx/webhook${token ? `?token=${token}` : ''}`;
    console.log(`[TelnyxVoice] Inbound webhook URL (configure this in the Telnyx portal): ${inboundUrl}`);

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

  setVoiceConfig(config = {}) {
    if (typeof config !== 'object' || config == null) return;

    if (config.sttProvider !== undefined) {
      this.sttProvider = normalizeSttProvider(config.sttProvider || DEFAULT_STT_PROVIDER);
    }
    if (config.ttsProvider !== undefined) {
      this.ttsProvider = normalizeTtsProvider(config.ttsProvider || DEFAULT_TTS_PROVIDER);
    }

    this.sttModel = resolveSttModel(this.sttProvider, config.sttModel ?? this.sttModel);
    this.ttsModel = resolveTtsModel(this.ttsProvider, config.ttsModel ?? this.ttsModel);
    this.ttsVoice = resolveTtsVoice(this.ttsProvider, config.ttsVoice ?? this.ttsVoice);

    console.log(
      `[TelnyxVoice] Voice config updated: STT=${this.sttProvider}/${this.sttModel}, ` +
      `TTS=${this.ttsProvider}/${this.ttsModel}${this.ttsVoice ? ` (${this.ttsVoice})` : ''}`,
    );
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

  matchesWebhookEvent(event) {
    const payload = event?.data?.payload || {};
    const ccId = payload.call_control_id;
    if (ccId && this._hasSession(ccId)) {
      return true;
    }

    if (payload.connection_id && String(payload.connection_id) === String(this.connectionId)) {
      return true;
    }

    const targetNumbers = [payload.to, payload.from]
      .map((value) => this._normalizeNumber(String(value || '')))
      .filter(Boolean);
    const ownNumber = this._normalizeNumber(String(this.phoneNumber || ''));
    return !!ownNumber && targetNumbers.some((value) => value === ownNumber || value.endsWith(ownNumber) || ownNumber.endsWith(value));
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
    this._sessions.set(ccId, createVoiceTurnSessionState({ callerNumber }));
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

  async _sayText(ccId, text) {
    try {
      const synthesized = await synthesizeVoiceReply(text, {
        provider: this.ttsProvider,
        model: this.ttsModel,
        voice: this.ttsVoice,
      });
      const ext = guessExtFromMimeType(synthesized.mimeType);
      const file = this._tmpFile('say', ccId, ext);
      const filePath = path.join(AUDIO_DIR, file);
      await fs.promises.writeFile(filePath, synthesized.audioBytes);
      await this._playAudio(ccId, this._publicUrl(file));
      setTimeout(() => fs.unlink(filePath, () => {}), 60000);
      return;
    } catch (err) {
      console.warn(
        `[TelnyxVoice] ${this.ttsProvider} TTS failed (${err.message}), ` +
        'falling back to Telnyx native speak',
      );
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
      return await transcribeVoiceInput(filePath, {
        provider: this.sttProvider,
        model: this.sttModel,
        mimeType: 'audio/mpeg',
      });
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

  _tmpFile(prefix, ccId, ext = 'mp3') {
    const safeExt = String(ext || 'mp3').replace(/[^a-z0-9]/gi, '').toLowerCase() || 'mp3';
    return `${prefix}_${ccId.replace(/[^a-zA-Z0-9]/g, '')}_${Date.now()}.${safeExt}`;
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
          
          if (sess.audioQueue && sess.audioQueue.length > 0) {
            const nextAudio = sess.audioQueue.shift();
            sess.isPlayingInterim = nextAudio.isInterim;
            if (!nextAudio.isInterim) {
              sess.isThinking = false;
              sess.replySent = true;
            }
            sess.isProcessing = true;
            sess.awaitingUserInput = !nextAudio.isInterim;
            try {
              await this._sayText(ccId, nextAudio.content);
            } catch (err) {
              console.error('[TelnyxVoice] Failed to play queued audio:', err);
              // Retry or clean up? Fall through to reset if not interim
            }
            break;
          }

          sess.isPlayingInterim = false;
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
          sess.audioQueue        = [];    // clear pending audio
          sess.isPlayingInterim  = false;
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

          // Emit message event — MessagingManager routes it to the AI engine.
          // The agent will call sendMessage(ccId, response) when it has a reply.
          this.emit('message', createVoiceMessage({
            platform: 'telnyx',
            chatId: ccId,
            sender: sess.callerNumber || ccId,
            senderName: sess.callerNumber || 'Caller',
            senderTag: sess.callerNumber || ccId,
            content: transcript,
            isGroup: false,
            mediaType: 'voice',
          }));
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

  async sendMessage(to, content, options = {}) {
    const sess = this._session(to);
    if (!sess) {
      console.warn(`[TelnyxVoice] sendMessage: no active session for ${to} (call may have ended)`);
      return { success: false, reason: 'call_ended' };
    }

    const isInterim = options.deliveryKind === 'interim';

    // Guard against the agent calling send_message more than once per turn.
    if (!isInterim && sess.replySent) {
      console.warn(`[TelnyxVoice] sendMessage: reply already sent for this turn, ignoring duplicate`);
      return { success: false, reason: 'already_replied' };
    }

    if (!isInterim) {
      sess.replySent = true;
    }

    // Stop the "please hold" TTS (suppress all errors — it may have already ended)
    if (!sess.isPlayingInterim) {
      try { await this._stopAudio(to); } catch {}
    }

    if (sess.isPlayingInterim || sess.audioQueue.length > 0) {
      // Queue it up
      sess.audioQueue.push({ content, isInterim });
      return { success: true, queued: true };
    }

    // Generate TTS response and play it.
    // If anything here throws, reset replySent so the session isn't bricked.
    try {
      // Commit state before firing audio so call.playback/speak.ended
      // belongs to this response, not any residual think audio.
      sess.isPlayingInterim = isInterim;
      if (!isInterim) {
        sess.isThinking      = false;
      }
      sess.isProcessing    = true;
      sess.awaitingUserInput = !isInterim;
      await this._sayText(to, content);
    } catch (err) {
      // Audio failed — reset so the turn isn't silently lost.
      if (!isInterim) {
        sess.replySent     = false;
        sess.isThinking    = false;
      }
      sess.isPlayingInterim = false;
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
