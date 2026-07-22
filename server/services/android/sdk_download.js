'use strict';

const crypto = require('node:crypto');
const fs = require('node:fs');
const https = require('node:https');
const os = require('node:os');
const { Transform } = require('node:stream');
const { pipeline } = require('node:stream/promises');
const { createAbortError } = require('../../utils/abort');
const { clampNumber } = require('./process');

// Google publishes the current filenames and checksums at:
// https://developer.android.com/studio#command-line-tools-only
const COMMAND_LINE_TOOLS_VERSION = '15859902';
const COMMAND_LINE_TOOLS_RELEASES = {
  darwin: {
    arm64: {
      url: `https://dl.google.com/android/repository/commandlinetools-mac_arm64-${COMMAND_LINE_TOOLS_VERSION}_latest.zip`,
      sha256: '835b62a26162b229b441d1f6d4680383815a270809eb33522c0d480fa5002c4e',
    },
    x64: {
      url: `https://dl.google.com/android/repository/commandlinetools-mac_x86_64-${COMMAND_LINE_TOOLS_VERSION}_latest.zip`,
      sha256: 'c5a6378ab5cf7e0d5701921405115befff13e9ff7417fb588389338f8bd050f3',
    },
  },
  linux: {
    url: `https://dl.google.com/android/repository/commandlinetools-linux-${COMMAND_LINE_TOOLS_VERSION}_latest.zip`,
    sha256: '4e4c464f145a7512b57d088ac6c278c03c9eea610886b35a5e0804e74eedf583',
  },
  win32: {
    url: `https://dl.google.com/android/repository/commandlinetools-win-${COMMAND_LINE_TOOLS_VERSION}_latest.zip`,
    sha256: '90ae805d20434428bffcb699c290860f19bb5f66a67e6b330067e3de801fb04a',
  },
};

function resolveCommandLineToolsRelease(platform = process.platform, arch = os.arch()) {
  const release = COMMAND_LINE_TOOLS_RELEASES[platform];
  if (!release) throw new Error(`No Android command-line-tools download for platform: ${platform}`);
  if (platform !== 'darwin') return release;
  if (arch !== 'arm64' && arch !== 'x64') {
    throw new Error(`No Android command-line-tools download for macOS architecture: ${arch}`);
  }
  return release[arch];
}

function assertExpectedDigest(actualDigest, expectedDigest) {
  const expected = String(expectedDigest || '').trim().toLowerCase();
  if (!/^[a-f0-9]{64}$/.test(expected)) {
    throw new Error('Android SDK download is missing a valid SHA-256 checksum.');
  }
  const actualBuffer = Buffer.from(actualDigest, 'hex');
  const expectedBuffer = Buffer.from(expected, 'hex');
  if (!crypto.timingSafeEqual(actualBuffer, expectedBuffer)) {
    const error = new Error('Android SDK download failed SHA-256 verification.');
    error.code = 'ANDROID_SDK_CHECKSUM_MISMATCH';
    throw error;
  }
}

async function downloadFile(url, destination, options = {}) {
  const maxRedirects = clampNumber(options.maxRedirects, 5, 0, 10);
  const timeoutMs = clampNumber(options.timeoutMs, 60_000, 1000, 10 * 60 * 1000);
  const maxBytes = clampNumber(options.maxBytes, 500 * 1024 * 1024, 1024, 1024 * 1024 * 1024);
  const temporary = `${destination}.${process.pid}.${Math.random().toString(16).slice(2)}.part`;

  const openResponse = (target, redirectsLeft) => new Promise((resolve, reject) => {
    if (options.signal?.aborted) {
      reject(createAbortError(options.signal, 'Android SDK download was aborted.'));
      return;
    }
    const parsed = new URL(target);
    if (parsed.protocol !== 'https:') {
      reject(new Error(`Refusing non-HTTPS Android SDK download: ${parsed.protocol}`));
      return;
    }
    const request = https.get(parsed, (response) => {
      options.signal?.removeEventListener('abort', onAbort);
      const status = Number(response.statusCode || 0);
      if (status >= 300 && status < 400 && response.headers.location) {
        response.resume();
        if (redirectsLeft <= 0) {
          reject(new Error('Android SDK download exceeded its redirect limit.'));
          return;
        }
        resolve(openResponse(new URL(response.headers.location, parsed).toString(), redirectsLeft - 1));
        return;
      }
      if (status !== 200) {
        response.resume();
        reject(new Error(`Android SDK download failed with HTTP ${status}.`));
        return;
      }
      const contentLength = Number(response.headers['content-length'] || 0);
      if (contentLength > maxBytes) {
        response.destroy();
        reject(new Error(`Android SDK download exceeds the ${maxBytes}-byte limit.`));
        return;
      }
      resolve(response);
    });
    const onAbort = () => request.destroy(createAbortError(options.signal, 'Android SDK download was aborted.'));
    options.signal?.addEventListener('abort', onAbort, { once: true });
    request.setTimeout(timeoutMs, () => request.destroy(new Error('Android SDK download timed out.')));
    request.once('error', (error) => {
      options.signal?.removeEventListener('abort', onAbort);
      reject(error);
    });
  });

  try {
    const response = await openResponse(url, maxRedirects);
    const hash = crypto.createHash('sha256');
    let received = 0;
    const verifier = new Transform({
      transform(chunk, _encoding, callback) {
        received += chunk.length;
        if (received > maxBytes) {
          callback(new Error(`Android SDK download exceeds the ${maxBytes}-byte limit.`));
          return;
        }
        hash.update(chunk);
        callback(null, chunk);
      },
    });
    await pipeline(response, verifier, fs.createWriteStream(temporary, { mode: 0o600 }), {
      signal: options.signal,
    });
    assertExpectedDigest(hash.digest('hex'), options.expectedSha256);
    fs.renameSync(temporary, destination);
  } catch (error) {
    if (options.signal?.aborted) {
      throw createAbortError(options.signal, 'Android SDK download was aborted.');
    }
    throw error;
  } finally {
    try { fs.unlinkSync(temporary); } catch {}
  }
}

module.exports = {
  downloadFile,
  resolveCommandLineToolsRelease,
};
