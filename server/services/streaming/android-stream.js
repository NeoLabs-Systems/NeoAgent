'use strict';

const path = require('path');
const { spawn } = require('child_process');
const { EventEmitter } = require('events');
const sharp = require('sharp');

// Derive the full path to the `adb` binary the same way the Android controller does.
function resolveAdbBin(sdkDir) {
  if (sdkDir) {
    return path.join(sdkDir, 'platform-tools', process.platform === 'win32' ? 'adb.exe' : 'adb');
  }
  return process.platform === 'win32' ? 'adb.exe' : 'adb'; // fall back to PATH
}

function clampInt(value, fallback, min, max) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.min(max, Math.max(min, Math.floor(parsed)));
}

// ---------------------------------------------------------------------------
// JpegFrameParser — extracts complete JPEG images from a raw byte stream.
// ffmpeg writes MJPEG to stdout as a continuous stream of JPEG frames, each
// delimited by SOI (FF D8) and EOI (FF D9) markers.  We buffer incoming
// chunks and emit a 'frame' event for every complete JPEG found.
// ---------------------------------------------------------------------------
class JpegFrameParser extends EventEmitter {
  constructor() {
    super();
    this._buf = null; // Buffer | null
  }

  push(chunk) {
    if (!chunk?.length) return;
    this._buf = this._buf ? Buffer.concat([this._buf, chunk]) : Buffer.from(chunk);
    let start = 0;

    while (start < this._buf.length - 1) {
      // Locate SOI marker (0xFF 0xD8).
      let soiIdx = -1;
      for (let i = start; i < this._buf.length - 1; i++) {
        if (this._buf[i] === 0xff && this._buf[i + 1] === 0xd8) {
          soiIdx = i;
          break;
        }
      }
      if (soiIdx === -1) {
        // No SOI found – discard everything.
        this._buf = null;
        return;
      }

      // Locate EOI marker (0xFF 0xD9) that comes after SOI.
      let eoiIdx = -1;
      for (let i = soiIdx + 2; i < this._buf.length - 1; i++) {
        if (this._buf[i] === 0xff && this._buf[i + 1] === 0xd9) {
          eoiIdx = i;
          break;
        }
      }
      if (eoiIdx === -1) {
        // SOI found but no matching EOI yet – keep buffered from SOI onward.
        this._buf = soiIdx > 0 ? this._buf.slice(soiIdx) : this._buf;
        return;
      }

      // Emit the complete JPEG (inclusive of both markers).
      this.emit('frame', this._buf.slice(soiIdx, eoiIdx + 2));
      start = eoiIdx + 2;
    }

    // Retain any leftover bytes that haven't formed a complete frame yet.
    this._buf = start < this._buf.length ? this._buf.slice(start) : null;
  }
}

// ---------------------------------------------------------------------------
// AndroidStream
//
// Streams the Android emulator screen by:
//   1. Running `adb exec-out screenrecord --output-format=h264 -` to get a
//      continuous H.264 bitstream at up to 30 fps with no per-frame process
//      overhead (replacing the previous one-shot screencap-per-frame approach).
//   2. Piping the bitstream through `ffmpeg` which decodes H.264 and re-encodes
//      each frame as MJPEG at the requested fps / quality.
//   3. Parsing complete JPEG frames from ffmpeg stdout via JpegFrameParser and
//      forwarding them to StreamHub.
//   4. Auto-restarting when Android's built-in 3-minute screenrecord limit
//      expires (~170 s to give a small safety margin).
//   5. Falling back to screencap polling when H.264 streaming cannot start
//      (e.g. older device without screenrecord stdout support).
// ---------------------------------------------------------------------------
class AndroidStream {
  constructor({ userId, deviceId, controller, streamHub, fps = 12, quality = 75 }) {
    this.userId = String(userId || '');
    this.deviceId = String(deviceId || '');
    this.controller = controller;
    this.streamHub = streamHub;
    this.fps = clampInt(fps, 12, 1, 30);
    this.quality = clampInt(quality, 75, 30, 95);

    this._stopped = true;
    this._adbProc = null;
    this._ffmpegProc = null;
    this._restartTimer = null;
    this._seq = 0;
    this._lastErrorLogAt = 0;
    this._usePollingFallback = false; // set true when H.264 fails to start
  }

  start() {
    if (!this._stopped) return;
    this._stopped = false;
    if (this._usePollingFallback) {
      this._startPollingFallback();
    } else {
      this._launchH264();
    }
  }

  stop() {
    this._stopped = true;
    this._killProcesses();
  }

  // ── H.264 streaming (primary path) ─────────────────────────────────────

  _launchH264() {
    if (this._stopped) return;

    const adb = resolveAdbBin(this.controller?.sdkDir);
    // deviceId is the ADB serial (emulator-5554, etc.)
    const serial = this.deviceId;
    const adbArgs = [
      '-s', serial,
      'exec-out',
      'screenrecord',
      '--output-format=h264',
      '--bit-rate=2000000',
      '--size=1280x720',
      '-',
    ];

    try {
      this._adbProc = spawn(adb, adbArgs, { stdio: ['ignore', 'pipe', 'ignore'] });
    } catch (err) {
      this._logError('Failed to spawn adb for H.264 streaming, falling back to screencap', err);
      this._fallback();
      return;
    }

    // Map our 30–95 quality range to ffmpeg q:v 2–20 (lower = better quality).
    const ffmpegQ = Math.round(2 + ((95 - this.quality) / (95 - 30)) * 18);
    const ffmpegArgs = [
      '-loglevel', 'error',
      '-f', 'h264',
      '-i', 'pipe:0',
      '-f', 'image2pipe',
      '-vcodec', 'mjpeg',
      '-q:v', String(ffmpegQ),
      '-vf', `fps=${this.fps}`,
      'pipe:1',
    ];

    try {
      this._ffmpegProc = spawn('ffmpeg', ffmpegArgs, { stdio: ['pipe', 'pipe', 'ignore'] });
    } catch (err) {
      this._logError('ffmpeg not found, falling back to screencap', err);
      try { this._adbProc?.kill('SIGTERM'); } catch {}
      this._adbProc = null;
      this._fallback();
      return;
    }

    // Wire adb stdout → ffmpeg stdin.
    this._adbProc.stdout.pipe(this._ffmpegProc.stdin);

    // Parse JPEG frames from ffmpeg stdout and forward to StreamHub.
    const parser = new JpegFrameParser();
    this._ffmpegProc.stdout.on('data', (chunk) => parser.push(chunk));
    parser.on('frame', (jpeg) => {
      if (this._stopped) return;
      this.streamHub.handleFrame(this.userId, this.deviceId, {
        jpeg,
        platform: 'android',
        seq: this._seq++ >>> 0,
        ts: Date.now() >>> 0,
        flags: 1,
      });
    });

    this._adbProc.on('error', (err) => {
      this._logError('adb process error', err);
    });
    this._ffmpegProc.on('error', (err) => {
      this._logError('ffmpeg process error', err);
    });

    // Android screenrecord's hard limit is 180 s — restart at 170 s so there
    // is no gap in the stream.
    this._restartTimer = setTimeout(() => {
      if (!this._stopped) {
        this._killProcesses();
        this._launchH264();
      }
    }, 170_000);
    this._restartTimer.unref?.();

    // If adb exits early (e.g. emulator restart), attempt recovery.
    this._adbProc.on('close', (code) => {
      if (this._stopped) return;
      // If it exited immediately with a bad code, the device likely does not
      // support stdout screenrecord — fall back to screencap polling.
      if (code !== 0 && this._seq === 0) {
        this._logError(`screenrecord exited (code ${code}) before producing any frames — using screencap fallback`);
        this._killProcesses();
        this._fallback();
        return;
      }
      this._logError(`adb screenrecord exited (code ${code}), restarting in 2 s`);
      this._killProcesses();
      this._scheduleRestart(2000, () => this._launchH264());
    });
  }

  _fallback() {
    this._usePollingFallback = true;
    if (!this._stopped) this._startPollingFallback();
  }

  // ── Screencap polling fallback ──────────────────────────────────────────
  // Used when H.264 streaming is unavailable.  Runs a tight continuous loop
  // (no fixed interval) so there is never idle time waiting between captures.

  _startPollingFallback() {
    // Fire and forget — the loop runs until this._stopped is set.
    void this._pollLoop();
  }

  async _pollLoop() {
    while (!this._stopped) {
      try {
        if (!this.controller || typeof this.controller.capturePng !== 'function') {
          throw new Error('Android streaming requires a controller with capturePng().');
        }
        const png = await this.controller.capturePng({ deviceId: this.deviceId });
        if (this._stopped || !png?.length) continue;
        const jpeg = await sharp(png)
          .jpeg({ quality: this.quality, mozjpeg: false })
          .toBuffer();
        if (this._stopped) return;
        this.streamHub.handleFrame(this.userId, this.deviceId, {
          jpeg,
          platform: 'android',
          seq: this._seq++ >>> 0,
          ts: Date.now() >>> 0,
          flags: 1,
        });
      } catch (error) {
        this._logError('screencap poll failed', error);
        // Brief pause before retrying to avoid a tight spin on persistent errors.
        await new Promise((r) => setTimeout(r, 500));
      }
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  _scheduleRestart(delayMs, fn) {
    this._restartTimer = setTimeout(fn, delayMs);
    this._restartTimer.unref?.();
  }

  _killProcesses() {
    clearTimeout(this._restartTimer);
    this._restartTimer = null;
    // Kill ffmpeg first so it stops reading; then kill adb.
    try { this._ffmpegProc?.kill('SIGTERM'); } catch {}
    try { this._adbProc?.kill('SIGTERM'); } catch {}
    this._ffmpegProc = null;
    this._adbProc = null;
  }

  _logError(msg, err) {
    const now = Date.now();
    if (now - this._lastErrorLogAt > 10_000) {
      this._lastErrorLogAt = now;
      console.warn(`[AndroidStream] ${msg}`, {
        userId: this.userId,
        deviceId: this.deviceId,
        error: err ? String(err?.message || err) : undefined,
      });
    }
  }
}

module.exports = { AndroidStream };
