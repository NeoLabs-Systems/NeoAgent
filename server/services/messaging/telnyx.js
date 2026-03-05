'use strict';

const { BasePlatform } = require('./base');
const path = require('path');
const fs = require('fs');
const https = require('https');
const { OpenAI } = require('openai');

const AUDIO_DIR = path.join(__dirname, '..', '..', '..', 'data', 'telnyx-audio');
const RECORDING_TURN_LIMIT_MS = 8000; // auto-stop recording after 8 s of silence

class TelnyxVoicePlatform extends BasePlatform {
  constructor(config = {}) {
    super('telnyx', config);
    this.supportsVoice = true;

    // Config fields set via the web UI connect modal
    this.apiKey      = config.apiKey      || '';
    this.phoneNumber = config.phoneNumber || '';
    this.connectionId = config.connectionId || '';
    this.webhookUrl  = config.webhookUrl  || '';   // e.g. https://xyz.ngrok.io
    this.ttsVoice    = config.ttsVoice   || 'alloy';
    this.ttsModel    = config.ttsModel   || 'tts-1';
    this.sttModel    = config.sttModel   || 'whisper-1';

    // Allowed-numbers whitelist (empty = allow all)
    this.allowedNumbers = Array.isArray(config.allowedNumbers) ? config.allowedNumbers : [];

    // Runtime state
    this._sessions        = new Map(); // ccId → session object
    this._recordingTimers = new Map(); // ccId → setTimeout handle
    this._client          = null;      // Telnyx SDK instance
    this._openai          = null;      // OpenAI client
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  async connect() {
    if (!this.apiKey || !this.phoneNumber || !this.connectionId || !this.webhookUrl) {
      throw new Error('Telnyx Voice requires apiKey, phoneNumber, connectionId, and webhookUrl');
    }

    if (!fs.existsSync(AUDIO_DIR)) fs.mkdirSync(AUDIO_DIR, { recursive: true });

    const TelnyxSDK = require('telnyx');
    const TelnyxClient = TelnyxSDK.default || TelnyxSDK;
    this._client = new TelnyxClient({ apiKey: this.apiKey });
    this._openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

    this.status = 'connected';
    this.emit('connected');
    console.log(`[TelnyxVoice] Connected — phone: ${this.phoneNumber}`);
    return { status: 'connected' };
  }

  async disconnect() {
    // Hang up any live calls
    for (const [ccId] of this._sessions) {
      try { await this._client.calls.actions.hangup(ccId); } catch {}
    }
    this._sessions.clear();
    for (const t of this._recordingTimers.values()) clearTimeout(t);
    this._recordingTimers.clear();
    this.status = 'disconnected';
    this.emit('disconnected', {});
  }

  async logout() {
    await this.disconnect();
  }

  getStatus() { return this.status; }
  getAuthInfo() { return { phoneNumber: this.phoneNumber }; }

  // ── Whitelist management ────────────────────────────────────────────────────

  setAllowedNumbers(numbers) {
    this.allowedNumbers = Array.isArray(numbers) ? numbers : [];
    console.log(`[TelnyxVoice] Whitelist updated: ${this.allowedNumbers.length} number(s)`);
  }

  _isAllowed(number) {
    if (!this.allowedNumbers || !this.allowedNumbers.length) return true;
    const strip = (n) => n.replace(/\D/g, '');
    const cn = strip(number);
    return this.allowedNumbers.some(wl => {
      const cw = strip(wl);
      return cn === cw || cn.endsWith(cw) || cw.endsWith(cn);
    });
  }

  // ── Session helpers ────────────────────────────────────────────────────────

  _initSession(ccId, callerNumber = '') {
    this._sessions.set(ccId, {
      callerNumber,
      isProcessing:       false,
      awaitingUserInput:  false,
      isThinking:         false, // true while agent is processing — gates playback.ended mutations
      replySent:          false, // prevents double-reply within one agent turn
      processedRecordings: new Set(),

    });
  }

  _session(ccId)    { return this._sessions.get(ccId); }
  _hasSession(ccId) { return this._sessions.has(ccId); }

  _endSession(ccId) {
    this._sessions.delete(ccId);
    this._cancelRecordingTimer(ccId);
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

  // ── Telnyx call-control wrappers ───────────────────────────────────────────

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

  // ── OpenAI TTS / STT ───────────────────────────────────────────────────────

  async _tts(text, destPath) {
    const mp3 = await this._openai.audio.speech.create({
      model: this.ttsModel,
      voice: this.ttsVoice,
      input: text,
    });
    const buf = Buffer.from(await mp3.arrayBuffer());
    await fs.promises.writeFile(destPath, buf);
  }

  // Say text on a call — tries OpenAI TTS+hosted audio first, falls back to
  // Telnyx native speak (no external hosting or OpenAI key required).
  async _sayText(ccId, text) {
    try {
      const file = this._tmpFile('say', ccId);
      const filePath = path.join(AUDIO_DIR, file);
      await this._tts(text, filePath);
      await this._playAudio(ccId, this._publicUrl(file));
      setTimeout(() => fs.unlink(filePath, () => {}), 60000);
    } catch (err) {
      console.warn(`[TelnyxVoice] OpenAI TTS failed (${err.message}), falling back to Telnyx speak`);
      try {
        await this._client.calls.actions.speak(ccId, {
          payload:  text,
          voice:    'female',
          language: 'en-US',
        });
      } catch (speakErr) {
        if (!this._isTerminalError(speakErr)) throw speakErr;
      }
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

  // ── File helpers ───────────────────────────────────────────────────────────

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

  // ── Main webhook handler ───────────────────────────────────────────────────
  //   Called by MessagingManager.handleTelnyxWebhook() from /api/telnyx/webhook

  async handleWebhook(event) {
    if (!event?.data?.event_type) return;
    const { event_type: eventType, payload } = event.data;
    const ccId = payload?.call_control_id;
    if (!ccId) return;

    // Ignore events for sessions we don't know about (except the ones that start one)
    if (!this._hasSession(ccId) &&
        eventType !== 'call.initiated' &&
        eventType !== 'call.answered') {
      return;
    }

    // Outbound call.initiated is handled by initiateCall() already
    if (eventType === 'call.initiated' && payload.direction === 'outbound') return;

    console.log(`[TelnyxVoice] ${eventType} — ccId=${ccId.slice(-8)}`);

    try {
      switch (eventType) {

        // ── Inbound call received ───────────────────────────────────────────
        case 'call.initiated': {
          if (payload.direction !== 'incoming') break;
          const caller = payload.from;
          if (!this._isAllowed(caller)) {
            console.log(`[TelnyxVoice] Blocked non-whitelisted caller: ${caller}`);
            await this._rejectCall(ccId);
            this.emit('blocked_caller', { caller, ccId });
            break;
          }
          // Init session BEFORE answering so call.answered (which arrives as a
          // separate concurrent webhook) always finds a valid session.
          this._initSession(ccId, caller);
          await this._answerCall(ccId);
          console.log(`[TelnyxVoice] Answered inbound call from ${caller}`);
          break;
        }

        // ── Call connected — play greeting ──────────────────────────────────
        case 'call.answered': {
          // Fallback: if call.initiated raced and session isn't created yet, init now.
          if (!this._hasSession(ccId)) {
            const caller = payload.from || payload.to || ccId;
            this._initSession(ccId, caller);
            console.log(`[TelnyxVoice] call.answered race — session created late for ${ccId.slice(-8)}`);
          }
          const sess = this._session(ccId);
          sess.isProcessing = true;
          sess.awaitingUserInput = true;
          const greetText = sess._outboundGreeting || 'Hello! I am your AI assistant. How can I help you?';
          delete sess._outboundGreeting;
          await this._sayText(ccId, greetText);
          break;
        }

        // ── Playback lifecycle ──────────────────────────────────────────────
        case 'call.playback.started':
          // Only set isProcessing for audio we care about (not mid-think noise).
          if (this._hasSession(ccId) && !this._session(ccId).isThinking)
            this._session(ccId).isProcessing = true;
          break;

        case 'call.playback.ended':
        case 'call.speak.ended': {
          if (!this._hasSession(ccId)) break;
          const sess = this._session(ccId);
          // While the agent is thinking (think audio looping) or already thinking,
          // ignore these events — they are from the think-loop audio, not the response.
          if (sess.isThinking) break;
          sess.isProcessing = false;
          if (!sess.awaitingUserInput) break;
          sess.awaitingUserInput = false;
          setTimeout(async () => {
            try {
              await this._startRecording(ccId);
              this._scheduleRecordingStop(ccId);
            } catch {}
          }, 500);
          break;
        }

        // ── DTMF key — interrupt and restart recording ──────────────────────
        case 'call.dtmf.received': {
          if (!this._hasSession(ccId)) break;
          this._cancelRecordingTimer(ccId);
          const sess = this._session(ccId);
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
          }, 300);
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

          // Play a single (non-looping) hold phrase while the agent thinks.
          try {
            await this._sayText(ccId, 'One moment please.');
          } catch (err) {
            console.error('[TelnyxVoice] Failed to play think audio:', err.message);
          }

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
    const webhookUrl = `${this.webhookUrl}/api/telnyx/webhook`;
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
