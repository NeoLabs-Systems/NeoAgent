'use strict';

const fs = require('fs');
const fsp = require('fs/promises');
const path = require('path');
const { randomUUID } = require('crypto');

const { DATA_DIR } = require('../../../runtime/paths');
const { CLIExecutor } = require('../cli/executor');
const { isDeepgramConfigured, transcribeChunkWithDeepgram } = require('../recordings/deepgram');
const { getAdapterForPlatform } = require('./adapters');
const { decideTranscriptPath, parseCaptionText, pickCaptionTrack } = require('./captions');
const { inferImageContentType, pickDeterministicFrameSecond } = require('./frame');
const { extractPublicMetadataFromHtml } = require('./metadata');
const { shapeSocialVideoResult } = require('./result');
const { normalizeAndDetectPlatform } = require('./url');

const SOCIAL_VIDEO_TMP_DIR = path.join(DATA_DIR, 'social-video-temp');
fs.mkdirSync(SOCIAL_VIDEO_TMP_DIR, { recursive: true });

const HEALTH_CACHE_TTL_MS = 5 * 60 * 1000;

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
  if (/private|login required|sign in to confirm/.test(normalized)) {
    return { code: 'private_or_auth_required', message };
  }
  if (/403|forbidden|blocked/.test(normalized)) {
    return { code: 'blocked_or_unavailable', message };
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
    this.ytDlpBin = String(process.env.YT_DLP_BIN || 'yt-dlp').trim() || 'yt-dlp';
    this.ffmpegBin = String(process.env.FFMPEG_BIN || 'ffmpeg').trim() || 'ffmpeg';
    this._healthCache = {
      ts: 0,
      value: null,
    };
  }

  async getHealthStatus(options = {}) {
    const forceRefresh = options.forceRefresh === true;
    const now = Date.now();
    if (!forceRefresh && this._healthCache.value && (now - this._healthCache.ts) < HEALTH_CACHE_TTL_MS) {
      return this._healthCache.value;
    }

    const [ytDlp, ffmpeg] = await Promise.all([
      this.#probeBinary(this.ytDlpBin, '--version'),
      this.#probeBinary(this.ffmpegBin, '-version'),
    ]);

    const health = {
      ready: ytDlp.available && ffmpeg.available,
      dependencies: [ytDlp, ffmpeg],
      speechToText: {
        configured: isDeepgramConfigured(),
        note: isDeepgramConfigured()
          ? 'Deepgram is configured for speech-to-text fallback.'
          : 'DEEPGRAM_API_KEY is not configured. Extraction still works when platform captions are available.',
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
    let jobDir = null;

    try {
      const health = await this.getHealthStatus();
      if (!health.ready) {
        const missing = health.dependencies.filter((item) => !item.available).map((item) => item.name);
        throw new Error(`Missing required dependency: ${missing.join(', ')}`);
      }

      const { platform, normalizedUrl } = normalizeAndDetectPlatform(source);
      const adapter = getAdapterForPlatform(platform);
      if (!adapter) {
        throw new Error(`No adapter registered for platform: ${platform}`);
      }

      const pageMetadata = await this.#resolvePageMetadata(userId, normalizedUrl, warnings);
      jobDir = await fsp.mkdtemp(path.join(SOCIAL_VIDEO_TMP_DIR, `${platform}-${Date.now()}-`));

      const mediaInfo = await this.#readMediaInfo(normalizedUrl, jobDir);
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
        warnings,
      });

      const frameImage = options.includeFrame === false
        ? null
        : await this.#resolveFrameImage({
          userId,
          sourceUrl: normalizedUrl,
          mediaInfo,
          jobDir,
          warnings,
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
      const health = await this.getHealthStatus().catch(() => null);
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

  async #runCommand(command, options = {}) {
    const result = await this.cliExecutor.execute(command, {
      cwd: options.cwd || process.cwd(),
      timeout: options.timeout || 10 * 60 * 1000,
      env: options.env,
    });
    if (result.exitCode !== 0) {
      throw new Error(result.stderr || result.stdout || `Command failed: ${command}`);
    }
    return result;
  }

  async #probeBinary(binary, versionFlag) {
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
      });
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
      return {
        ...fallback,
        error: error.message || String(error),
      };
    }
  }

  async #resolvePageMetadata(userId, normalizedUrl, warnings) {
    const browserMetadata = await this.#resolvePageMetadataViaBrowser(userId, normalizedUrl).catch((error) => {
      warnings.push(`Browser metadata resolve failed: ${error.message}`);
      return null;
    });
    if (browserMetadata) {
      return browserMetadata;
    }

    const response = await fetch(normalizedUrl, { redirect: 'follow' });
    const html = await response.text();
    const metadata = extractPublicMetadataFromHtml(html, response.url || normalizedUrl);
    return {
      ...metadata,
      resolvedUrl: String(response.url || normalizedUrl),
    };
  }

  async #resolvePageMetadataViaBrowser(userId, normalizedUrl) {
    if (!this.runtimeManager || typeof this.runtimeManager.getBrowserProviderForUser !== 'function') {
      throw new Error('Runtime browser provider is unavailable.');
    }

    const browser = await this.runtimeManager.getBrowserProviderForUser(userId);
    if (!browser || typeof browser.navigate !== 'function' || typeof browser.extract !== 'function') {
      throw new Error('Runtime browser provider does not support metadata extraction.');
    }

    const nav = await browser.navigate(normalizedUrl, {
      screenshot: false,
      waitUntil: 'domcontentloaded',
    });
    if (nav?.error) {
      throw new Error(nav.error);
    }

    const [canonicalRaw, descriptionRaw, ogDescriptionRaw, titleTagRaw] = await Promise.all([
      browser.extract('link[rel="canonical"]', 'href', false).catch(() => ''),
      browser.extract('meta[name="description"]', 'content', false).catch(() => ''),
      browser.extract('meta[property="og:description"]', 'content', false).catch(() => ''),
      browser.extract('meta[property="og:title"]', 'content', false).catch(() => ''),
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

  async #readMediaInfo(normalizedUrl, jobDir) {
    const infoPath = path.join(jobDir, 'media-info.json');
    const command = `${shellEscape(this.ytDlpBin)} --no-playlist --skip-download --dump-single-json -- ${shellEscape(normalizedUrl)}`;
    const result = await this.#runCommand(command, { cwd: jobDir, timeout: 4 * 60 * 1000 });
    const raw = String(result.stdout || '').trim();
    if (!raw) {
      throw new Error('yt-dlp returned empty media metadata output.');
    }
    await fsp.writeFile(infoPath, `${raw}\n`, 'utf8');
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
      const captionText = await this.#readTranscriptFromCaption(context.captionTrack).catch((error) => {
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

    if (!isDeepgramConfigured()) {
      context.warnings.push('Captions unavailable and DEEPGRAM_API_KEY is not configured; transcript could not be generated.');
      return {
        text: '',
        source: 'unavailable',
      };
    }

    const transcript = await this.#transcribeViaStt(context.sourceUrl, context.jobDir);
    return {
      text: transcript,
      source: transcript ? 'stt' : 'unavailable',
    };
  }

  async #readTranscriptFromCaption(captionTrack) {
    const response = await fetch(captionTrack.url, { redirect: 'follow' });
    if (!response.ok) {
      throw new Error(`Caption request failed (${response.status}).`);
    }
    const raw = await response.text();
    return parseCaptionText(raw, captionTrack.ext);
  }

  async #transcribeViaStt(sourceUrl, jobDir) {
    const template = path.join(jobDir, 'audio.%(ext)s');
    const command = `${shellEscape(this.ytDlpBin)} --no-playlist -f bestaudio -- ${shellEscape(sourceUrl)} -o ${shellEscape(template)}`;
    await this.#runCommand(command, { cwd: jobDir, timeout: 10 * 60 * 1000 });

    const audioPath = firstFileMatching(jobDir, 'audio.');
    if (!audioPath || !fileExists(audioPath)) {
      throw new Error('Audio download succeeded but no audio file was created.');
    }

    const audioBytes = await fsp.readFile(audioPath);
    const deepgramResult = await transcribeChunkWithDeepgram({
      audioBytes,
      mimeType: detectMimeFromFile(audioPath),
    });
    const transcript = deepgramResult?.results?.channels?.[0]?.alternatives?.[0]?.transcript;
    return String(transcript || '').trim();
  }

  async #resolveFrameImage(context) {
    const downloadedFrame = await this.#extractFrameFromVideo(context).catch((error) => {
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
    return this.#downloadThumbnailArtifact(context.userId, thumbnail.url);
  }

  async #extractFrameFromVideo(context) {
    const template = path.join(context.jobDir, 'video.%(ext)s');
    const downloadCommand = `${shellEscape(this.ytDlpBin)} --no-playlist -f "bv*[ext=mp4]+ba[ext=m4a]/b[ext=mp4]/best" --merge-output-format mp4 -- ${shellEscape(context.sourceUrl)} -o ${shellEscape(template)}`;
    await this.#runCommand(downloadCommand, { cwd: context.jobDir, timeout: 14 * 60 * 1000 });

    const videoPath = firstFileMatching(context.jobDir, 'video.');
    if (!videoPath || !fileExists(videoPath)) {
      throw new Error('Video download succeeded but no playable file was created.');
    }

    const framePath = path.join(context.jobDir, 'frame.jpg');
    const frameSecond = pickDeterministicFrameSecond(context.mediaInfo.duration);
    const frameCommand = `${shellEscape(this.ffmpegBin)} -y -hide_banner -loglevel error -ss ${frameSecond} -i ${shellEscape(videoPath)} -frames:v 1 -q:v 2 ${shellEscape(framePath)}`;
    await this.#runCommand(frameCommand, { cwd: context.jobDir, timeout: 2 * 60 * 1000 });

    if (!fileExists(framePath)) {
      throw new Error('ffmpeg did not produce a frame image.');
    }
    return this.#saveImageArtifact(context.userId, framePath, 'frame');
  }

  async #downloadThumbnailArtifact(userId, thumbnailUrl) {
    const response = await fetch(thumbnailUrl, { redirect: 'follow' });
    if (!response.ok) {
      throw new Error(`Thumbnail request failed (${response.status}).`);
    }
    const buffer = Buffer.from(await response.arrayBuffer());
    const guessedExtension = path.extname(new URL(response.url || thumbnailUrl).pathname).replace('.', '') || 'jpg';
    const mimeType = String(response.headers.get('content-type') || '').trim() || `image/${guessedExtension}`;
    if (!this.artifactStore || userId == null) {
      return {
        url: null,
        artifactId: null,
        mimeType,
        byteSize: buffer.length,
        source: 'thumbnail',
      };
    }
    const allocation = this.artifactStore.allocateFile(userId, {
      kind: 'social-video-frame',
      extension: guessedExtension,
      contentType: mimeType,
      filenameBase: `social-video-thumbnail-${randomUUID().slice(0, 8)}`,
      metadata: {
        source: 'social-video-thumbnail',
      },
    });
    await fsp.writeFile(allocation.storagePath, buffer);
    const finalized = this.artifactStore.finalizeFile(allocation.artifactId, allocation.storagePath);
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
  shellEscape,
};
