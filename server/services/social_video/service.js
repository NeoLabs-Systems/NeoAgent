'use strict';

const fs = require('fs');
const fsp = require('fs/promises');
const path = require('path');
const { randomUUID } = require('crypto');

const db = require('../../db/database');
const { DATA_DIR } = require('../../../runtime/paths');
const { CLIExecutor } = require('../cli/executor');
const { executeSafeHttpRequest } = require('../network/safe_request');
const { getAdapterForPlatform } = require('./adapters');
const {
  MAX_VTT_BYTES,
  decideTranscriptPath,
  parseCaptionText,
  pickCaptionTrack,
} = require('./captions');
const { inferImageContentType, pickDeterministicFrameSecond } = require('./frame');
const { extractPublicMetadataFromHtml } = require('./metadata');
const { shapeSocialVideoResult } = require('./result');
const { normalizeAndDetectPlatform } = require('./url');
const { isMainAgent } = require('../agents/manager');
const { resolveSttModel, transcribeVoiceInput } = require('../voice/providers');
const { createAbortError, isAbortError, throwIfAborted } = require('../../utils/abort');

const SOCIAL_VIDEO_TMP_DIR = path.join(DATA_DIR, 'social-video-temp');
fs.mkdirSync(SOCIAL_VIDEO_TMP_DIR, { recursive: true });

const HEALTH_CACHE_TTL_MS = 5 * 60 * 1000;
const MAX_PAGE_HTML_BYTES = 2 * 1024 * 1024;
const MAX_THUMBNAIL_BYTES = 10 * 1024 * 1024;

// A realistic desktop browser UA. Social platforms frequently return 403/bot
// challenge pages to the default Node/yt-dlp user agents, so we present a
// browser-like identity for every outbound request.
const BROWSER_USER_AGENT = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
  + 'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

// Network hardening flags applied to every yt-dlp invocation. Transient
// failures (rate limits, dropped fragments, slow extractors) are the most
// common cause of unreliable extraction, so we retry aggressively and cap
// socket waits instead of failing on the first hiccup.
const YT_DLP_NETWORK_FLAGS = [
  '--retries', '5',
  '--fragment-retries', '5',
  '--extractor-retries', '3',
  '--socket-timeout', '30',
  '--user-agent', BROWSER_USER_AGENT,
];

// Platforms that gate most video content behind authentication or aggressive
// bot detection. For these we always try to attach the user's browser cookies.
const COOKIE_ASSISTED_PLATFORMS = new Set(['instagram', 'youtube', 'tiktok', 'x']);

async function fetchPublicResource(url, options = {}) {
  const result = await executeSafeHttpRequest({
    url,
    method: 'GET',
    timeout_ms: options.timeoutMs || 30000,
    headers: {
      'user-agent': BROWSER_USER_AGENT,
      'accept-language': 'en-US,en;q=0.9',
      accept: options.accept || '*/*',
      ...(options.headers || {}),
    },
  }, {
    signal: options.signal,
    maxResponseBytes: options.maxResponseBytes,
    responseType: options.responseType,
  });
  if (result.truncated) {
    const error = new Error('Social video response exceeded its safety limit.');
    error.code = 'SOCIAL_VIDEO_RESPONSE_TOO_LARGE';
    throw error;
  }
  if (result.status < 200 || result.status >= 300) {
    const error = new Error(`Social video request failed (${result.status}).`);
    error.status = result.status;
    throw error;
  }
  return result;
}

function rethrowCancellation(error, signal) {
  if (signal?.aborted) throw createAbortError(signal);
  if (isAbortError(error)) throw error;
}

function shellEscape(value) {
  const text = String(value ?? '');
  if (!text.length) return process.platform === 'win32' ? '""' : "''";
  if (process.platform === 'win32') {
    return `"${text
      .replace(/(["^&|<>])/g, '^$1')
      .replace(/%/g, '%%')}"`;
  }
  return `'${text.replace(/'/g, `'\\''`)}'`;
}

function detectMimeFromFile(filePath) {
  const ext = path.extname(String(filePath || '')).toLowerCase();
  if (ext === '.mp3') return 'audio/mpeg';
  if (ext === '.m4a') return 'audio/mp4';
  if (ext === '.wav') return 'audio/wav';
  if (ext === '.webm') return 'audio/webm';
  if (ext === '.opus') return 'audio/opus';
  if (ext === '.ogg') return 'audio/ogg';
  return 'application/octet-stream';
}

function pickBestThumbnail(thumbnails = []) {
  const candidates = Array.isArray(thumbnails)
    ? thumbnails.filter((item) => item && typeof item === 'object' && item.url)
    : [];
  if (candidates.length === 0) return null;
  const scored = candidates.map((thumb, index) => {
    const width = Number(thumb.width) || 0;
    const height = Number(thumb.height) || 0;
    return {
      index,
      thumb,
      area: width * height,
    };
  });
  scored.sort((left, right) => {
    if (right.area !== left.area) return right.area - left.area;
    return left.index - right.index;
  });
  return scored[0]?.thumb || null;
}

function unwrapBrowserExtractValue(payload) {
  if (payload == null) return '';
  if (typeof payload === 'string') return payload;
  if (typeof payload?.result === 'string') return payload.result;
  return '';
}

function parseStoredSettingValue(value) {
  if (typeof value !== 'string') {
    return value;
  }
  try {
    return JSON.parse(value);
  } catch {
    return value;
  }
}

function readStoredSetting(userId, agentId, key) {
  if (!userId) {
    return null;
  }

  if (agentId) {
    const agentRow = db.prepare(
      'SELECT value FROM agent_settings WHERE user_id = ? AND agent_id = ? AND key = ?',
    ).get(userId, agentId, key);
    if (agentRow) {
      return parseStoredSettingValue(agentRow.value);
    }
  }

  if (!agentId || isMainAgent(userId, agentId)) {
    const userRow = db.prepare(
      'SELECT value FROM user_settings WHERE user_id = ? AND key = ?',
    ).get(userId, key);
    if (userRow) {
      return parseStoredSettingValue(userRow.value);
    }
  }

  return null;
}

function resolveVoiceSttConfigFromSettings(settings = {}) {
  const provider = String(settings.voice_stt_provider || '').trim().toLowerCase() || 'openai';
  const model = String(settings.voice_stt_model || '').trim();
  return {
    provider,
    model: resolveSttModel(provider, model),
  };
}

function serializeCookiesForNetscapeJar(cookies = []) {
  const lines = ['# Netscape HTTP Cookie File'];
  for (const cookie of Array.isArray(cookies) ? cookies : []) {
    if (!cookie || typeof cookie !== 'object') continue;
    const domain = String(cookie.domain || '').trim();
    const name = String(cookie.name || '').trim();
    const value = String(cookie.value || '').replace(/[\r\n\t]/g, ' ');
    if (!domain || !name) continue;
    const cookieDomain = domain.startsWith('.') ? domain : domain;
    const includeSubdomains = domain.startsWith('.') ? 'TRUE' : 'FALSE';
    const pathValue = String(cookie.path || '/').trim() || '/';
    const secure = cookie.secure ? 'TRUE' : 'FALSE';
    const expires = Number.isFinite(Number(cookie.expires)) && Number(cookie.expires) > 0
      ? String(Math.floor(Number(cookie.expires)))
      : '0';
    const httpOnlyPrefix = cookie.httpOnly ? '#HttpOnly_' : '';
    lines.push([
      `${httpOnlyPrefix}${cookieDomain}`,
      includeSubdomains,
      pathValue,
      secure,
      expires,
      name,
      value,
    ].join('\t'));
  }
  return `${lines.join('\n')}\n`;
}

function fileExists(filePath) {
  try {
    return fs.statSync(filePath).isFile();
  } catch {
    return false;
  }
}

function firstFileMatching(dirPath, startsWith) {
  const items = fs.readdirSync(dirPath);
  const match = items
    .filter((name) => name.startsWith(startsWith))
    .sort()[0];
  if (!match) return null;
  return path.join(dirPath, match);
}

function classifyExtractionError(error) {
  const message = String(error?.message || error || '').trim();
  const normalized = message.toLowerCase();
  if (/unsupported social video url|unsupported url/.test(normalized)) {
    return { code: 'unsupported_url', message };
  }
  if (/private|login required|sign in to confirm|requested content is not available|account is private/.test(normalized)) {
    return { code: 'private_or_auth_required', message };
  }
  if (/\b429\b|rate.?limit|too many requests/.test(normalized)) {
    return { code: 'rate_limited', message };
  }
  if (/\b403\b|forbidden|blocked|not a bot/.test(normalized)) {
    return { code: 'blocked_or_unavailable', message };
  }
  if (/timed out|timeout|etimedout|socket hang up|network is unreachable/.test(normalized)) {
    return { code: 'network_error', message };
  }
  if (/this video is unavailable|video unavailable|removed|404|not found/.test(normalized)) {
    return { code: 'content_unavailable', message };
  }
  return { code: 'social_video_extract_failed', message };
}

function buildInstallHint(binaryName) {
  const name = String(binaryName || '').trim().toLowerCase();
  if (process.platform === 'darwin') {
    if (name === 'ffmpeg') return 'Install with: brew install ffmpeg';
    if (name === 'yt-dlp' || name === 'yt_dlp') return 'Install with: brew install yt-dlp';
  }
  if (process.platform === 'linux') {
    if (name === 'ffmpeg') return 'Install with your package manager, for example: sudo apt-get install -y ffmpeg';
    if (name === 'yt-dlp' || name === 'yt_dlp') return 'Install with your package manager or pipx, for example: pipx install yt-dlp';
  }
  if (process.platform === 'win32') {
    if (name === 'ffmpeg') return 'Install ffmpeg and ensure ffmpeg.exe is on PATH.';
    if (name === 'yt-dlp' || name === 'yt_dlp') return 'Install yt-dlp and ensure yt-dlp.exe is on PATH.';
  }
  return `Install ${binaryName} and ensure it is available on PATH.`;
}

class SocialVideoService {
  constructor(options = {}) {
    this.artifactStore = options.artifactStore || null;
    this.runtimeManager = options.runtimeManager || null;
    this.cliExecutor = options.cliExecutor || new CLIExecutor();
    this.voiceTranscriber = options.voiceTranscriber || transcribeVoiceInput;
    this.voiceSettingsResolver = options.voiceSettingsResolver || ((userId, agentId) => this.#resolveVoiceSttConfig(userId, agentId));
    this.ytDlpBin = String(process.env.YT_DLP_BIN || 'yt-dlp').trim() || 'yt-dlp';
    this.ffmpegBin = String(process.env.FFMPEG_BIN || 'ffmpeg').trim() || 'ffmpeg';
    this._healthCache = {
      ts: 0,
      value: null,
    };
  }

  async getHealthStatus(options = {}) {
    throwIfAborted(options.signal, 'Social video health check aborted.');
    const forceRefresh = options.forceRefresh === true;
    const now = Date.now();
    if (!forceRefresh && this._healthCache.value && (now - this._healthCache.ts) < HEALTH_CACHE_TTL_MS) {
      return this._healthCache.value;
    }

    const [ytDlp, ffmpeg] = await Promise.all([
      this.#probeBinary(this.ytDlpBin, '--version', options.signal),
      this.#probeBinary(this.ffmpegBin, '-version', options.signal),
    ]);

    const health = {
      ready: ytDlp.available && ffmpeg.available,
      dependencies: [ytDlp, ffmpeg],
      speechToText: {
        note: 'Transcript fallback uses the configured voice STT provider from Flutter settings.',
      },
      checkedAt: new Date().toISOString(),
    };

    this._healthCache = {
      ts: now,
      value: health,
    };
    return health;
  }

  async extractFromUrl(userId, sourceUrl, options = {}) {
    const warnings = [];
    const errors = [];
    const source = String(sourceUrl || '').trim();
    const agentId = options.agentId || null;
    let jobDir = null;

    try {
      throwIfAborted(options.signal, 'Social video extraction aborted.');
      const health = await this.getHealthStatus({ signal: options.signal });
      if (!health.ready) {
        const missing = health.dependencies.filter((item) => !item.available).map((item) => item.name);
        throw new Error(`Missing required dependency: ${missing.join(', ')}`);
      }

      const { platform, normalizedUrl } = normalizeAndDetectPlatform(source);
      const adapter = getAdapterForPlatform(platform);
      if (!adapter) {
        throw new Error(`No adapter registered for platform: ${platform}`);
      }

      const pageMetadata = await this.#resolvePageMetadata(
        userId,
        normalizedUrl,
        warnings,
        options.signal,
      );
      throwIfAborted(options.signal, 'Social video extraction aborted.');
      jobDir = await fsp.mkdtemp(path.join(SOCIAL_VIDEO_TMP_DIR, `${platform}-${Date.now()}-`));
      const cookieFilePath = await this.#resolveCookieFile({
        userId,
        platform,
        jobDir,
        warnings,
        signal: options.signal,
      });

      const mediaInfo = await this.#readMediaInfo(
        normalizedUrl,
        jobDir,
        cookieFilePath,
        options.signal,
      );
      const baseTitle = String(pageMetadata.title || mediaInfo.title || '').trim();
      const baseDescription = String(pageMetadata.description || mediaInfo.description || '').trim();
      const resolvedUrl = String(pageMetadata.resolvedUrl || mediaInfo.webpage_url || normalizedUrl).trim();
      const canonicalUrl = String(pageMetadata.canonicalUrl || mediaInfo.webpage_url || normalizedUrl).trim();

      const subtitles = mediaInfo.subtitles || {};
      const automaticCaptions = mediaInfo.automatic_captions || {};
      const preferredLanguages = adapter.getCaptionLanguagePreferences();
      const subtitleTrack = pickCaptionTrack(subtitles, preferredLanguages);
      const autoTrack = pickCaptionTrack(automaticCaptions, preferredLanguages);
      const captionTrack = subtitleTrack || autoTrack;
      const transcriptDecision = decideTranscriptPath({
        forceStt: options.forceStt === true,
        captionTrack,
      });

      const transcriptResolution = await this.#resolveTranscript({
        sourceUrl: normalizedUrl,
        mediaInfo,
        captionTrack,
        transcriptDecision,
        jobDir,
        cookieFilePath,
        userId,
        agentId,
        warnings,
        signal: options.signal,
      });

      const frameImage = options.includeFrame === false
        ? null
        : await this.#resolveFrameImage({
          userId,
          sourceUrl: normalizedUrl,
          mediaInfo,
          jobDir,
          cookieFilePath,
          warnings,
          signal: options.signal,
        });

      return shapeSocialVideoResult({
        sourceUrl: source,
        resolvedUrl,
        canonicalUrl,
        platform,
        title: baseTitle,
        description: baseDescription,
        transcript: transcriptResolution.text,
        transcriptSource: transcriptResolution.source,
        frameImage,
        metadata: {
          provider: 'yt-dlp',
          durationSeconds: Number(mediaInfo.duration) || null,
          videoId: mediaInfo.id || null,
        },
        setup: health,
        warnings,
        errors,
      });
    } catch (error) {
      rethrowCancellation(error, options.signal);
      const health = await this.getHealthStatus({ signal: options.signal }).catch(() => null);
      errors.push(classifyExtractionError(error));
      return shapeSocialVideoResult({
        sourceUrl: source,
        resolvedUrl: source,
        platform: 'unknown',
        title: '',
        description: '',
        transcript: '',
        transcriptSource: 'unavailable',
        frameImage: null,
        setup: health,
        warnings,
        errors,
      });
    } finally {
      if (jobDir) {
        await fsp.rm(jobDir, { recursive: true, force: true }).catch(() => {});
      }
    }
  }

  #networkFlags() {
    return YT_DLP_NETWORK_FLAGS.map(shellEscape).join(' ');
  }

  async #runCommand(command, options = {}) {
    const result = await this.cliExecutor.execute(command, {
      cwd: options.cwd || process.cwd(),
      timeout: options.timeout || 10 * 60 * 1000,
      env: options.env,
      signal: options.signal,
    });
    throwIfAborted(options.signal, 'Social video command aborted.');
    if (result.exitCode !== 0) {
      throw new Error(result.stderr || result.stdout || `Command failed: ${command}`);
    }
    return result;
  }

  async #probeBinary(binary, versionFlag, signal = null) {
    const name = String(binary || '').trim();
    const fallback = {
      name,
      available: false,
      version: null,
      installHint: buildInstallHint(name),
      error: 'Binary probe failed.',
    };
    if (!name) {
      return {
        ...fallback,
        error: 'Binary name is empty.',
      };
    }

    try {
      const command = `${shellEscape(name)} ${versionFlag}`;
      const result = await this.cliExecutor.execute(command, {
        timeout: 8 * 1000,
        signal,
      });
      throwIfAborted(signal, 'Social video dependency probe aborted.');
      if (result.exitCode !== 0) {
        return {
          ...fallback,
          error: result.stderr || result.stdout || `Exit code ${result.exitCode}`,
        };
      }
      const output = String(result.stdout || result.stderr || '').trim();
      const firstLine = output.split(/\r?\n/)[0] || null;
      return {
        name,
        available: true,
        version: firstLine,
        installHint: null,
        error: null,
      };
    } catch (error) {
      rethrowCancellation(error, signal);
      return {
        ...fallback,
        error: error.message || String(error),
      };
    }
  }

  async #resolvePageMetadata(userId, normalizedUrl, warnings, signal = null) {
    const browserMetadata = await this.#resolvePageMetadataViaBrowser(
      userId,
      normalizedUrl,
      signal,
    ).catch((error) => {
      rethrowCancellation(error, signal);
      warnings.push(`Browser metadata resolve failed: ${error.message}`);
      return null;
    });
    if (browserMetadata) {
      return browserMetadata;
    }

    const response = await fetchPublicResource(normalizedUrl, {
      signal,
      maxResponseBytes: MAX_PAGE_HTML_BYTES,
      accept: 'text/html,*/*',
    });
    const metadata = extractPublicMetadataFromHtml(response.body, response.finalUrl || normalizedUrl);
    return {
      ...metadata,
      resolvedUrl: String(response.finalUrl || normalizedUrl),
    };
  }

  async #resolvePageMetadataViaBrowser(userId, normalizedUrl, signal = null) {
    if (!this.runtimeManager || typeof this.runtimeManager.getBrowserProviderForUser !== 'function') {
      throw new Error('Runtime browser provider is unavailable.');
    }

    const browser = await this.runtimeManager.getBrowserProviderForUser(userId, { signal });
    if (!browser || typeof browser.navigate !== 'function' || typeof browser.extract !== 'function') {
      throw new Error('Runtime browser provider does not support metadata extraction.');
    }

    const nav = await browser.navigate(normalizedUrl, {
      screenshot: false,
      waitUntil: 'domcontentloaded',
      signal,
    });
    if (nav?.error) {
      throw new Error(nav.error);
    }

    const [canonicalRaw, descriptionRaw, ogDescriptionRaw, titleTagRaw] = await Promise.all([
      browser.extract('link[rel="canonical"]', 'href', false, { signal }).catch((error) => {
        rethrowCancellation(error, signal);
        return '';
      }),
      browser.extract('meta[name="description"]', 'content', false, { signal }).catch((error) => {
        rethrowCancellation(error, signal);
        return '';
      }),
      browser.extract('meta[property="og:description"]', 'content', false, { signal }).catch((error) => {
        rethrowCancellation(error, signal);
        return '';
      }),
      browser.extract('meta[property="og:title"]', 'content', false, { signal }).catch((error) => {
        rethrowCancellation(error, signal);
        return '';
      }),
    ]);
    const canonical = unwrapBrowserExtractValue(canonicalRaw);
    const description = unwrapBrowserExtractValue(descriptionRaw);
    const ogDescription = unwrapBrowserExtractValue(ogDescriptionRaw);
    const titleTag = unwrapBrowserExtractValue(titleTagRaw);

    return {
      title: String(titleTag || nav.title || '').trim(),
      description: String(description || ogDescription || '').trim(),
      canonicalUrl: String(canonical || nav.url || normalizedUrl).trim(),
      resolvedUrl: String(nav.url || normalizedUrl).trim(),
    };
  }

  async #readMediaInfo(normalizedUrl, jobDir, cookieFilePath = null, signal = null) {
    const infoTemplate = path.join(jobDir, 'media.%(ext)s');
    const infoPath = path.join(jobDir, 'media.info.json');
    const cookieArg = cookieFilePath ? ` --cookies ${shellEscape(cookieFilePath)}` : '';
    const command = `${shellEscape(this.ytDlpBin)} --quiet --no-warnings --no-playlist ${this.#networkFlags()} --skip-download --write-info-json --no-clean-infojson${cookieArg} -o ${shellEscape(infoTemplate)} -- ${shellEscape(normalizedUrl)}`;
    await this.#runCommand(command, { cwd: jobDir, timeout: 4 * 60 * 1000, signal });
    if (!fileExists(infoPath)) {
      throw new Error('yt-dlp did not produce an info JSON artifact.');
    }
    const raw = String(await fsp.readFile(infoPath, 'utf8')).trim();
    throwIfAborted(signal, 'Social video extraction aborted.');
    let parsed;
    try {
      parsed = JSON.parse(raw);
    } catch (error) {
      throw new Error(`Failed to parse media metadata JSON: ${error.message}`);
    }
    return parsed;
  }

  async #resolveTranscript(context) {
    if (context.transcriptDecision.mode === 'captions' && context.captionTrack) {
      const captionText = await this.#readTranscriptFromCaption(
        context.captionTrack,
        context.signal,
      ).catch((error) => {
        rethrowCancellation(error, context.signal);
        context.warnings.push(`Caption transcript failed: ${error.message}`);
        return '';
      });
      if (captionText) {
        return {
          text: captionText,
          source: 'captions',
        };
      }
      context.warnings.push('Caption track was present but transcript text was empty. Falling back to speech-to-text.');
    }

    const transcript = await this.#transcribeViaStt(context).catch((error) => {
      rethrowCancellation(error, context.signal);
      context.warnings.push(`Speech-to-text fallback failed: ${error.message}`);
      return '';
    });
    return {
      text: transcript,
      source: transcript ? 'stt' : 'unavailable',
    };
  }

  async #readTranscriptFromCaption(captionTrack, signal = null) {
    const response = await fetchPublicResource(captionTrack.url, {
      signal,
      maxResponseBytes: MAX_VTT_BYTES,
      accept: 'text/vtt,text/plain,application/json,application/xml,*/*',
    });
    return parseCaptionText(response.body, captionTrack.ext);
  }

  async #transcribeViaStt(context) {
    const template = path.join(context.jobDir, 'audio.%(ext)s');
    const cookieArg = context.cookieFilePath ? ` --cookies ${shellEscape(context.cookieFilePath)}` : '';
    const command = `${shellEscape(this.ytDlpBin)} --quiet --no-warnings --no-playlist ${this.#networkFlags()}${cookieArg} -o ${shellEscape(template)} -f bestaudio/best -- ${shellEscape(context.sourceUrl)}`;
    await this.#runCommand(command, {
      cwd: context.jobDir,
      timeout: 10 * 60 * 1000,
      signal: context.signal,
    });

    const audioPath = firstFileMatching(context.jobDir, 'audio.');
    if (!audioPath || !fileExists(audioPath)) {
      throw new Error('Audio download succeeded but no audio file was created.');
    }

    const sttConfig = await Promise.resolve(
      this.voiceSettingsResolver(context.userId, context.agentId),
    );
    throwIfAborted(context.signal, 'Social video transcription aborted.');
    return this.voiceTranscriber(audioPath, {
      provider: sttConfig?.provider || 'openai',
      model: sttConfig?.model || '',
      mimeType: detectMimeFromFile(audioPath),
      signal: context.signal,
    });
  }

  async #resolveVoiceSttConfig(userId, agentId) {
    return resolveVoiceSttConfigFromSettings({
      voice_stt_provider: readStoredSetting(userId, agentId, 'voice_stt_provider'),
      voice_stt_model: readStoredSetting(userId, agentId, 'voice_stt_model'),
    });
  }

  async #resolveCookieFile(context) {
    if (!COOKIE_ASSISTED_PLATFORMS.has(context.platform)) {
      return null;
    }
    if (!this.runtimeManager || typeof this.runtimeManager.getBrowserProviderForUser !== 'function') {
      return null;
    }

    const browser = await Promise.resolve(
      this.runtimeManager.getBrowserProviderForUser(context.userId, {
        signal: context.signal,
      }),
    ).catch((error) => {
      rethrowCancellation(error, context.signal);
      return null;
    });
    if (!browser || typeof browser.getCookies !== 'function') {
      return null;
    }

    const payload = await browser.getCookies({ signal: context.signal }).catch((error) => {
      rethrowCancellation(error, context.signal);
      context.warnings.push(`Browser cookie export failed: ${error.message}`);
      return null;
    });
    const cookies = Array.isArray(payload?.cookies) ? payload.cookies : [];
    if (cookies.length === 0) {
      // Not fatal: many videos are public. yt-dlp will simply attempt the
      // extraction without an authenticated session.
      context.warnings.push(`Browser cookie export returned no cookies for ${context.platform}.`);
      return null;
    }

    const cookieFilePath = path.join(context.jobDir, 'browser.cookies.txt');
    await fsp.writeFile(cookieFilePath, serializeCookiesForNetscapeJar(cookies), 'utf8');
    throwIfAborted(context.signal, 'Social video cookie export aborted.');
    return cookieFilePath;
  }

  async #resolveFrameImage(context) {
    const downloadedFrame = await this.#extractFrameFromVideo(context).catch((error) => {
      rethrowCancellation(error, context.signal);
      context.warnings.push(`Frame extraction failed: ${error.message}`);
      return null;
    });
    if (downloadedFrame) {
      return downloadedFrame;
    }

    const thumbnail = pickBestThumbnail(context.mediaInfo.thumbnails);
    if (!thumbnail?.url) {
      context.warnings.push('No thumbnail fallback was available after frame extraction failed.');
      return null;
    }
    return this.#downloadThumbnailArtifact(
      context.userId,
      thumbnail.url,
      context.signal,
    );
  }

  async #extractFrameFromVideo(context) {
    const template = path.join(context.jobDir, 'video.%(ext)s');
    const cookieArg = context.cookieFilePath ? ` --cookies ${shellEscape(context.cookieFilePath)}` : '';
    const downloadCommand = `${shellEscape(this.ytDlpBin)} --quiet --no-warnings --no-playlist ${this.#networkFlags()}${cookieArg} -o ${shellEscape(template)} -f "bv*[ext=mp4]+ba[ext=m4a]/b[ext=mp4]/best" --merge-output-format mp4 -- ${shellEscape(context.sourceUrl)}`;
    await this.#runCommand(downloadCommand, {
      cwd: context.jobDir,
      timeout: 14 * 60 * 1000,
      signal: context.signal,
    });

    const videoPath = firstFileMatching(context.jobDir, 'video.');
    if (!videoPath || !fileExists(videoPath)) {
      throw new Error('Video download succeeded but no playable file was created.');
    }

    const framePath = path.join(context.jobDir, 'frame.jpg');
    const frameSecond = pickDeterministicFrameSecond(context.mediaInfo.duration);
    const frameCommand = `${shellEscape(this.ffmpegBin)} -hwaccel none -y -hide_banner -loglevel error -ss ${frameSecond} -i ${shellEscape(videoPath)} -frames:v 1 -q:v 2 ${shellEscape(framePath)}`;
    await this.#runCommand(frameCommand, {
      cwd: context.jobDir,
      timeout: 2 * 60 * 1000,
      signal: context.signal,
    });

    if (!fileExists(framePath)) {
      throw new Error('ffmpeg did not produce a frame image.');
    }
    return this.#saveImageArtifact(context.userId, framePath, 'frame');
  }

  async #downloadThumbnailArtifact(userId, thumbnailUrl, signal = null) {
    const response = await fetchPublicResource(thumbnailUrl, {
      signal,
      maxResponseBytes: MAX_THUMBNAIL_BYTES,
      responseType: 'buffer',
      accept: 'image/*,*/*',
    });
    const buffer = response.body;
    const guessedExtension = path.extname(
      new URL(response.finalUrl || thumbnailUrl).pathname,
    ).replace('.', '') || 'jpg';
    const mimeType = String(response.headers['content-type'] || '').trim()
      || `image/${guessedExtension}`;
    if (!this.artifactStore || userId == null) {
      return {
        url: null,
        artifactId: null,
        mimeType,
        byteSize: buffer.length,
        source: 'thumbnail',
      };
    }
    const allocation = await Promise.resolve(this.artifactStore.allocateFile(userId, {
      kind: 'social-video-frame',
      extension: guessedExtension,
      contentType: mimeType,
      filenameBase: `social-video-thumbnail-${randomUUID().slice(0, 8)}`,
      metadata: {
        source: 'social-video-thumbnail',
      },
    }));
    await fsp.writeFile(allocation.storagePath, buffer);
    const finalized = await Promise.resolve(
      this.artifactStore.finalizeFile(allocation.artifactId, allocation.storagePath),
    );
    return {
      url: finalized.url,
      artifactId: finalized.artifactId,
      mimeType,
      byteSize: finalized.byteSize,
      source: 'thumbnail',
    };
  }

  async #saveImageArtifact(userId, imagePath, source) {
    const mimeType = inferImageContentType(imagePath);
    if (!this.artifactStore || userId == null) {
      const byteSize = (await fsp.stat(imagePath)).size;
      return {
        url: imagePath,
        artifactId: null,
        mimeType,
        byteSize,
        source,
      };
    }

    const extension = path.extname(imagePath).replace(/^\./, '') || 'jpg';
    const allocation = await Promise.resolve(this.artifactStore.allocateFile(userId, {
      kind: 'social-video-frame',
      extension,
      contentType: mimeType,
      filenameBase: `social-video-${source}`,
      metadata: {
        source,
      },
    }));
    await fsp.copyFile(imagePath, allocation.storagePath);
    const finalized = await Promise.resolve(
      this.artifactStore.finalizeFile(allocation.artifactId, allocation.storagePath),
    );
    return {
      url: finalized.url,
      artifactId: finalized.artifactId,
      mimeType,
      byteSize: finalized.byteSize,
      source,
    };
  }
}

module.exports = {
  SOCIAL_VIDEO_TMP_DIR,
  SocialVideoService,
  buildInstallHint,
  HEALTH_CACHE_TTL_MS,
  detectMimeFromFile,
  fileExists,
  firstFileMatching,
  pickBestThumbnail,
  classifyExtractionError,
  resolveVoiceSttConfigFromSettings,
  shellEscape,
};
