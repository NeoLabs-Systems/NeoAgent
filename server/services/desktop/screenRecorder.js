'use strict';

const crypto = require('crypto');
const fs = require('fs/promises');
const path = require('path');
const os = require('os');
const { execFile } = require('child_process');
const { promisify } = require('util');
const tesseract = require('tesseract.js');
const db = require('../../db/database');
const { getErrorMessage } = require('../bootstrap_helpers');
const {
  CLEANUP_INTERVAL_MS,
  DEFAULT_CAPTURE_INTERVAL_MS,
  DEFAULT_RETENTION_DAYS,
  FRONTMOST_APP_SCRIPT,
  MINIMUM_TEXT_LENGTH,
  MIN_CAPTURE_INTERVAL_MS,
  hasOpenConnectionForUser,
  isExplicitlyEnabled,
  parsePositiveInteger,
} = require('./screen_recorder_support');

const execFileAsync = promisify(execFile);

class ScreenRecorder {
  constructor(options = {}) {
    this.env = options.env || process.env;
    this.platform = options.platform || process.platform;
    this.db = options.db || db;
    this.fs = options.fs || fs;
    this.execFile = options.execFile || execFileAsync;
    this.recognize = options.recognize || tesseract.recognize;
    this.setInterval = options.setInterval || setInterval;
    this.clearInterval = options.clearInterval || clearInterval;
    this.now = options.now || Date.now;
    this.hasActiveCaptureSessionForUser =
      typeof options.hasActiveCaptureSessionForUser === 'function'
        ? options.hasActiveCaptureSessionForUser
        : () => false;

    this.intervalId = null;
    this.cleanupIntervalId = null;
    this.isRecording = false;
    this.activeCapturePromise = null;
    this.tempFilePath = options.tempFilePath || path.join(
      os.tmpdir(),
      `neoagent-screen-${process.pid}-${crypto.randomUUID()}.png`,
    );
    this.lastBenignSkipAt = 0;
    this.lastErrorLogAt = 0;
    this.ownerUserId = null;
    this.intervalMs = DEFAULT_CAPTURE_INTERVAL_MS;
    this.retentionDays = DEFAULT_RETENTION_DAYS;
    this.state = 'idle';
    this.reason = 'not started';
    this.lastCaptureAt = null;
    this.lastSuccessAt = null;
    this.lastSkipReason = null;
    this.lastError = null;
  }

  getStatus() {
    return {
      state: this.state,
      reason: this.reason,
      ownerUserId: this.ownerUserId,
      intervalMs: this.intervalMs,
      retentionDays: this.retentionDays,
      lastCaptureAt: this.lastCaptureAt,
      lastSuccessAt: this.lastSuccessAt,
      lastSkipReason: this.lastSkipReason,
      lastError: this.lastError,
    };
  }

  _setInactiveState(state, reason) {
    this.state = state;
    this.reason = reason;
    this.isRecording = false;
    return this.getStatus();
  }

  _loadConfiguration() {
    const ownerUserId = parsePositiveInteger(
      this.env.NEOAGENT_SCREEN_RECORDER_USER_ID,
      'NEOAGENT_SCREEN_RECORDER_USER_ID',
      null,
    );
    if (ownerUserId == null) {
      throw new Error('NEOAGENT_SCREEN_RECORDER_USER_ID is required when screen recording is enabled.');
    }

    this.intervalMs = parsePositiveInteger(
      this.env.NEOAGENT_SCREEN_RECORDER_INTERVAL_MS,
      'NEOAGENT_SCREEN_RECORDER_INTERVAL_MS',
      DEFAULT_CAPTURE_INTERVAL_MS,
      MIN_CAPTURE_INTERVAL_MS,
    );
    this.retentionDays = parsePositiveInteger(
      this.env.NEOAGENT_SCREEN_RECORDER_RETENTION_DAYS,
      'NEOAGENT_SCREEN_RECORDER_RETENTION_DAYS',
      DEFAULT_RETENTION_DAYS,
    );
    this.ownerUserId = ownerUserId;
  }

  _ownerExists() {
    return Boolean(
      this.db.prepare('SELECT id FROM users WHERE id = ?').get(this.ownerUserId),
    );
  }

  start() {
    if (this.isRecording) {
      return this.getStatus();
    }

    if (!isExplicitlyEnabled(this.env.NEOAGENT_SCREEN_RECORDER_ENABLED)) {
      return this._setInactiveState('disabled', 'NEOAGENT_SCREEN_RECORDER_ENABLED is not enabled');
    }
    if (this.platform !== 'darwin') {
      return this._setInactiveState('unsupported', 'screen recording is currently supported only on macOS');
    }

    try {
      this._loadConfiguration();
      if (!this._ownerExists()) {
        return this._setInactiveState(
          'misconfigured',
          `configured screen recorder user ${this.ownerUserId} does not exist`,
        );
      }
    } catch (err) {
      return this._setInactiveState('misconfigured', getErrorMessage(err));
    }

    this.isRecording = true;
    this.state = 'running';
    this.reason = null;
    this.lastError = null;

    this.intervalId = this.setInterval(() => {
      void this.captureAndProcess();
    }, this.intervalMs);
    this.intervalId?.unref?.();

    this.cleanupIntervalId = this.setInterval(
      () => this.cleanupOldRecords(),
      CLEANUP_INTERVAL_MS,
    );
    this.cleanupIntervalId?.unref?.();

    void this.captureAndProcess();
    this.cleanupOldRecords();
    return this.getStatus();
  }

  async stop() {
    const wasRunning = this.isRecording;
    this.isRecording = false;

    if (this.intervalId) {
      this.clearInterval(this.intervalId);
      this.intervalId = null;
    }
    if (this.cleanupIntervalId) {
      this.clearInterval(this.cleanupIntervalId);
      this.cleanupIntervalId = null;
    }

    if (this.activeCapturePromise) {
      await this.activeCapturePromise;
    }
    if (wasRunning) {
      this.state = 'stopped';
      this.reason = 'service stopped';
    }
    return this.getStatus();
  }

  _isCaptureInactiveApp(appName) {
    const normalized = String(appName || '').trim().toLowerCase();
    return normalized === '' || normalized === 'loginwindow' || normalized === 'screensaverengine';
  }

  _recordSkip(reason) {
    this.lastSkipReason = reason;
    const now = this.now();
    if (now - this.lastBenignSkipAt < 5 * 60 * 1000) {
      return;
    }
    this.lastBenignSkipAt = now;
    console.log(`[ScreenRecorder] Capture skipped: ${reason}`);
  }

  _recordError(err) {
    this.lastError = getErrorMessage(err);
    const now = this.now();
    if (now - this.lastErrorLogAt < 5 * 60 * 1000) {
      return;
    }
    this.lastErrorLogAt = now;
    console.error('[ScreenRecorder] Capture/OCR failed:', this.lastError);
  }

  captureAndProcess() {
    if (!this.isRecording) {
      return Promise.resolve();
    }
    if (this.activeCapturePromise) {
      return this.activeCapturePromise;
    }

    this.activeCapturePromise = this._captureAndProcess().finally(() => {
      this.activeCapturePromise = null;
    });
    return this.activeCapturePromise;
  }

  async _captureAndProcess() {
    this.lastCaptureAt = new Date(this.now()).toISOString();
    try {
      if (!this.hasActiveCaptureSessionForUser(this.ownerUserId)) {
        this._recordSkip('no active external capture session for the configured user');
        return;
      }

      let frontmostApp = '';
      try {
        const { stdout } = await this.execFile('osascript', ['-e', FRONTMOST_APP_SCRIPT]);
        frontmostApp = String(stdout || '').trim();
      } catch {
        frontmostApp = '';
      }

      if (this._isCaptureInactiveApp(frontmostApp)) {
        this._recordSkip('no active frontmost app');
        return;
      }

      await this.execFile('screencapture', ['-x', this.tempFilePath]);
      await this.fs.access(this.tempFilePath);

      const { data } = await this.recognize(this.tempFilePath, 'eng+deu', {
        logger: () => {},
      });
      const textContent = String(data?.text || '').trim();

      if (!this.isRecording || textContent.length <= MINIMUM_TEXT_LENGTH) {
        return;
      }

      this.db.prepare(`
        INSERT INTO screen_history (user_id, app_name, text_content)
        VALUES (?, ?, ?)
      `).run(this.ownerUserId, frontmostApp, textContent);
      this.lastSuccessAt = new Date(this.now()).toISOString();
      this.lastSkipReason = null;
      this.lastError = null;
    } catch (err) {
      this._recordError(err);
    } finally {
      try {
        await this.fs.unlink(this.tempFilePath);
      } catch {
        // The file is absent when capture is skipped or fails before creating it.
      }
    }
  }

  cleanupOldRecords() {
    try {
      const result = this.db.prepare(`
        DELETE FROM screen_history
        WHERE timestamp < datetime('now', ?)
      `).run(`-${this.retentionDays} days`);
      if (result.changes > 0) {
        console.log(`[ScreenRecorder] Purged ${result.changes} old screen history records.`);
      }
    } catch (err) {
      console.error('[ScreenRecorder] Cleanup failed:', getErrorMessage(err));
    }
  }
}

module.exports = {
  ScreenRecorder,
  hasOpenConnectionForUser,
  isExplicitlyEnabled,
  parsePositiveInteger,
};
