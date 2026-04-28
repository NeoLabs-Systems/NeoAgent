'use strict';

const fs = require('fs/promises');
const path = require('path');
const os = require('os');
const { exec } = require('child_process');
const { promisify } = require('util');
const tesseract = require('tesseract.js');
const db = require('../../db/database');
const { getErrorMessage } = require('../bootstrap_helpers');

const execAsync = promisify(exec);

class ScreenRecorder {
  constructor() {
    this.intervalMs = 10000; // 10 seconds
    this.intervalId = null;
    this.cleanupIntervalId = null;
    this.isRecording = false;
    this.isProcessing = false;
    this.tempFilePath = path.join(os.tmpdir(), `neoagent-screen-${Date.now()}.png`);
    this.lastBenignSkipAt = 0;
  }

  _isCaptureInactiveApp(appName) {
    const normalized = String(appName || '').trim().toLowerCase();
    return normalized === '' || normalized === 'loginwindow' || normalized === 'screensaverengine';
  }

  _isBenignCaptureError(message) {
    const text = String(message || '').toLowerCase();
    return (
      text.includes('operation not permitted') ||
      text.includes('not authorized') ||
      text.includes('user canceled') ||
      text.includes('cgwindowlistcreateimage') ||
      text.includes('screencapture') ||
      text.includes('timed out')
    );
  }

  _logBenignSkip(reason) {
    const now = Date.now();
    if (now - this.lastBenignSkipAt < 5 * 60 * 1000) {
      return;
    }
    this.lastBenignSkipAt = now;
    console.log(`[ScreenRecorder] Capture skipped: ${reason}`);
  }

  start() {
    const enabledEnv = String(process.env.NEOAGENT_SCREEN_RECORDER_ENABLED || '').trim().toLowerCase();
    if (enabledEnv === '0' || enabledEnv === 'false' || enabledEnv === 'off' || enabledEnv === 'no') {
      console.log('[ScreenRecorder] Not starting: disabled by NEOAGENT_SCREEN_RECORDER_ENABLED.');
      return;
    }

    if (process.platform !== 'darwin') {
      console.log('[ScreenRecorder] Not starting: Screen recording is currently macOS only.');
      return;
    }

    if (this.isRecording) return;
    this.isRecording = true;

    console.log('[ScreenRecorder] Starting continuous screen recording (10s interval)');
    
    // Start the recording loop
    this.intervalId = setInterval(() => this.captureAndProcess(), this.intervalMs);
    
    // Run an initial capture
    this.captureAndProcess();

    // Start daily cleanup of old records (7 days)
    this.cleanupIntervalId = setInterval(() => this.cleanupOldRecords(), 24 * 60 * 60 * 1000);
    this.cleanupOldRecords();
  }

  stop() {
    this.isRecording = false;
    if (this.intervalId) {
      clearInterval(this.intervalId);
      this.intervalId = null;
    }
    if (this.cleanupIntervalId) {
      clearInterval(this.cleanupIntervalId);
      this.cleanupIntervalId = null;
    }
    console.log('[ScreenRecorder] Stopped continuous screen recording');
  }

  async captureAndProcess() {
    if (this.isProcessing || !this.isRecording) return;
    this.isProcessing = true;

    try {
      // Skip capture when the desktop session is inactive (e.g. locked screen).
      let frontmostApp = '';
      try {
        const { stdout } = await execAsync(`osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true'`);
        frontmostApp = (stdout || '').trim();
      } catch {
        frontmostApp = '';
      }

      if (this._isCaptureInactiveApp(frontmostApp)) {
        this._logBenignSkip('no active frontmost app');
        return;
      }

      // Capture screen silently (-x) to file
      await execAsync(`screencapture -x "${this.tempFilePath}"`);

      // Verify file exists
      await fs.access(this.tempFilePath);

      // Extract text via local OCR
      const { data } = await tesseract.recognize(this.tempFilePath, 'eng+deu', {
        logger: () => {} // Silence verbose OCR logs
      });

      const textContent = data.text.trim();

      // Only store if meaningful text was found
      if (textContent.length > 5) {
        // We need a user ID. For the local desktop agent, usually user 1 or we query the active user.
        const userRow = db.prepare('SELECT id FROM users ORDER BY id ASC LIMIT 1').get();
        if (userRow) {
          // Identify the active foreground app via AppleScript
          let appName = frontmostApp || 'Unknown';

          db.prepare(`
            INSERT INTO screen_history (user_id, app_name, text_content)
            VALUES (?, ?, ?)
          `).run(userRow.id, appName, textContent);
        }
      }

    } catch (err) {
      const errorMessage = getErrorMessage(err);
      if (this._isBenignCaptureError(errorMessage)) {
        this._logBenignSkip(errorMessage);
      } else {
        console.error('[ScreenRecorder] Capture/OCR failed:', errorMessage);
      }
    } finally {
      // Always cleanup the screenshot image immediately
      try {
        await fs.unlink(this.tempFilePath);
      } catch (e) {
        // Ignore unlink errors if file didn't exist
      }
      this.isProcessing = false;
    }
  }

  cleanupOldRecords() {
    try {
      const result = db.prepare(`
        DELETE FROM screen_history 
        WHERE timestamp < datetime('now', '-7 days')
      `).run();
      if (result.changes > 0) {
        console.log(`[ScreenRecorder] Purged ${result.changes} old screen history records.`);
      }
    } catch (err) {
      console.error('[ScreenRecorder] Cleanup failed:', getErrorMessage(err));
    }
  }
}

module.exports = { ScreenRecorder };
