'use strict';

const fs = require('fs');
const path = require('path');
const { v4: uuidv4 } = require('uuid');

const db = require('../../db/database');
const { DATA_DIR } = require('../../../runtime/paths');
const { sanitizeError } = require('../../utils/security');
const {
  DEFAULT_LANGUAGE,
  DEFAULT_MODEL,
  isDeepgramConfigured,
  transcribeChunkWithDeepgram,
} = require('./deepgram');

const RECORDINGS_DIR = path.join(DATA_DIR, 'recordings');
const SESSION_STATUS = {
  recording: 'recording',
  processing: 'processing',
  completed: 'completed',
  failed: 'failed',
  cancelled: 'cancelled',
};

function ensureRecordingDirs() {
  fs.mkdirSync(RECORDINGS_DIR, { recursive: true });
}

class RecordingManager {
  constructor(io) {
    this.io = io;
    ensureRecordingDirs();
  }

  listSessions(userId, { limit = 24 } = {}) {
    const rows = db.prepare(`
      SELECT *
      FROM recording_sessions
      WHERE user_id = ?
      ORDER BY datetime(created_at) DESC
      LIMIT ?
    `).all(userId, Math.max(1, Math.min(Number(limit) || 24, 100)));

    return rows.map((row) => this.getSession(userId, row.id));
  }

  getSession(userId, sessionId) {
    const session = db.prepare(`
      SELECT *
      FROM recording_sessions
      WHERE user_id = ? AND id = ?
    `).get(userId, sessionId);
    if (!session) {
      throw new Error('Recording session not found.');
    }

    const sources = db.prepare(`
      SELECT *
      FROM recording_sources
      WHERE session_id = ?
      ORDER BY created_at ASC
    `).all(sessionId);

    const segments = db.prepare(`
      SELECT *
      FROM recording_transcript_segments
      WHERE session_id = ?
      ORDER BY start_ms ASC, id ASC
    `).all(sessionId);

    return {
      ...this.#mapSession(session),
      sources: sources.map((source) => this.#mapSource(source)),
      transcriptSegments: segments.map((segment) => this.#mapSegment(segment)),
    };
  }

  createSession(userId, payload = {}) {
    const sessionId = uuidv4();
    const now = new Date().toISOString();
    const platform = typeof payload.platform === 'string' && payload.platform.trim()
      ? payload.platform.trim()
      : 'unknown';
    const sources = this.#normalizeSources(payload.sources, platform);
    const metadata = {
      capturePlan: payload.capturePlan || 'chunked-dual-source',
      screenAnalysisReady: payload.screenAnalysisReady !== false,
      notes: payload.notes || null,
    };

    const insertSession = db.prepare(`
      INSERT INTO recording_sessions (
        id, user_id, title, platform, status, metadata_json, started_at, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    `);
    const insertSource = db.prepare(`
      INSERT INTO recording_sources (
        id, session_id, source_key, source_kind, media_kind, mime_type, status, metadata_json, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `);

    db.transaction(() => {
      insertSession.run(
        sessionId,
        userId,
        this.#resolveTitle(payload.title, platform, now),
        platform,
        SESSION_STATUS.recording,
        JSON.stringify(metadata),
        now,
        now,
        now,
      );

      for (const source of sources) {
        insertSource.run(
          uuidv4(),
          sessionId,
          source.sourceKey,
          source.sourceKind,
          source.mediaKind,
          source.mimeType,
          SESSION_STATUS.recording,
          JSON.stringify(source.metadata),
          now,
          now,
        );
      }
    })();

    this.#emitUpdate(userId, sessionId);
    return this.getSession(userId, sessionId);
  }

  appendChunk(userId, sessionId, metadata = {}, audioBytes) {
    if (!(audioBytes instanceof Buffer) || audioBytes.length === 0) {
      throw new Error('Recording chunk is empty.');
    }

    const session = db.prepare(`
      SELECT *
      FROM recording_sessions
      WHERE id = ? AND user_id = ?
    `).get(sessionId, userId);
    if (!session) {
      throw new Error('Recording session not found.');
    }
    if (![SESSION_STATUS.recording, SESSION_STATUS.processing].includes(session.status)) {
      throw new Error('Recording session is not accepting more chunks.');
    }

    const sourceKey = `${metadata.sourceKey || ''}`.trim();
    if (!sourceKey) {
      throw new Error('sourceKey is required.');
    }
    const source = db.prepare(`
      SELECT *
      FROM recording_sources
      WHERE session_id = ? AND source_key = ?
    `).get(sessionId, sourceKey);
    if (!source) {
      throw new Error(`Unknown recording source: ${sourceKey}`);
    }

    const sequenceIndex = Number(metadata.sequenceIndex);
    if (!Number.isInteger(sequenceIndex) || sequenceIndex < 0) {
      throw new Error('sequenceIndex must be a non-negative integer.');
    }

    const existing = db.prepare(`
      SELECT id
      FROM recording_chunks
      WHERE source_id = ? AND sequence_index = ?
    `).get(source.id, sequenceIndex);
    if (existing) {
      return {
        duplicate: true,
        accepted: false,
        sessionId,
        sourceKey,
        sequenceIndex,
      };
    }

    const mimeType = `${metadata.mimeType || source.mime_type || 'application/octet-stream'}`.trim();
    const startMs = Math.max(0, Number(metadata.startMs) || 0);
    const endMs = Math.max(startMs, Number(metadata.endMs) || startMs);
    const extension = this.#extensionForMime(mimeType);
    const fileDir = path.join(RECORDINGS_DIR, `user-${userId}`, sessionId, sourceKey);
    fs.mkdirSync(fileDir, { recursive: true });
    const filePath = path.join(fileDir, `${String(sequenceIndex).padStart(6, '0')}${extension}`);
    const tempPath = `${filePath}.tmp-${process.pid}-${Date.now()}`;
    fs.writeFileSync(tempPath, audioBytes);
    fs.renameSync(tempPath, filePath);

    db.transaction(() => {
      db.prepare(`
        INSERT INTO recording_chunks (
          source_id, sequence_index, start_ms, end_ms, byte_count, mime_type, file_path
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
      `).run(
        source.id,
        sequenceIndex,
        startMs,
        endMs,
        audioBytes.length,
        mimeType,
        filePath,
      );

      db.prepare(`
        UPDATE recording_sources
        SET
          mime_type = COALESCE(?, mime_type),
          chunk_count = chunk_count + 1,
          bytes_received = bytes_received + ?,
          duration_ms = MAX(duration_ms, ?),
          updated_at = ?
        WHERE id = ?
      `).run(
        mimeType,
        audioBytes.length,
        endMs,
        new Date().toISOString(),
        source.id,
      );

      db.prepare(`
        UPDATE recording_sessions
        SET updated_at = ?
        WHERE id = ?
      `).run(new Date().toISOString(), sessionId);
    })();

    return {
      duplicate: false,
      accepted: true,
      sessionId,
      sourceKey,
      sequenceIndex,
      bytesReceived: audioBytes.length,
    };
  }

  finalizeSession(userId, sessionId, options = {}) {
    const session = db.prepare(`
      SELECT *
      FROM recording_sessions
      WHERE id = ? AND user_id = ?
    `).get(sessionId, userId);
    if (!session) {
      throw new Error('Recording session not found.');
    }

    const stopReason = `${options.stopReason || 'stopped'}`.trim();
    const mergedMetadata = {
      ...this.#parseJson(session.metadata_json, {}),
      stopReason,
    };
    const chunkCount = db.prepare(`
      SELECT COUNT(*) AS count
      FROM recording_chunks c
      INNER JOIN recording_sources s ON s.id = c.source_id
      WHERE s.session_id = ?
    `).get(sessionId).count;
    const nextStatus = chunkCount > 0 ? SESSION_STATUS.processing : SESSION_STATUS.cancelled;
    const now = new Date().toISOString();

    db.transaction(() => {
      db.prepare(`
        UPDATE recording_sessions
        SET
          status = ?,
          ended_at = COALESCE(ended_at, ?),
          metadata_json = ?,
          updated_at = ?
        WHERE id = ?
      `).run(nextStatus, now, JSON.stringify(mergedMetadata), now, sessionId);

      db.prepare(`
        UPDATE recording_sources
        SET status = CASE WHEN chunk_count > 0 THEN ? ELSE ? END, updated_at = ?
        WHERE session_id = ?
      `).run(nextStatus, nextStatus === SESSION_STATUS.processing ? SESSION_STATUS.cancelled : nextStatus, now, sessionId);
    })();

    this.#emitUpdate(userId, sessionId);

    if (nextStatus === SESSION_STATUS.processing) {
      this.processSession(userId, sessionId).catch((error) => {
        console.error('[Recordings] Processing failed:', sanitizeError(error));
      });
    }

    return this.getSession(userId, sessionId);
  }

  async retrySession(userId, sessionId) {
    const session = db.prepare(`
      SELECT *
      FROM recording_sessions
      WHERE id = ? AND user_id = ?
    `).get(sessionId, userId);
    if (!session) {
      throw new Error('Recording session not found.');
    }
    if (!isDeepgramConfigured()) {
      throw new Error('DEEPGRAM_API_KEY is not configured.');
    }

    db.prepare(`
      UPDATE recording_sessions
      SET status = ?, last_error = NULL, updated_at = ?
      WHERE id = ?
    `).run(SESSION_STATUS.processing, new Date().toISOString(), sessionId);
    this.#emitUpdate(userId, sessionId);

    await this.processSession(userId, sessionId);
    return this.getSession(userId, sessionId);
  }

  async resumePendingSessions() {
    const rows = db.prepare(`
      SELECT id, user_id
      FROM recording_sessions
      WHERE status = ?
      ORDER BY created_at ASC
    `).all(SESSION_STATUS.processing);

    for (const row of rows) {
      try {
        await this.processSession(row.user_id, row.id);
      } catch (error) {
        console.error('[Recordings] Resume failed:', sanitizeError(error));
      }
    }
  }

  async processSession(userId, sessionId) {
    if (!isDeepgramConfigured()) {
      throw new Error('DEEPGRAM_API_KEY is not configured.');
    }

    const session = db.prepare(`
      SELECT *
      FROM recording_sessions
      WHERE id = ? AND user_id = ?
    `).get(sessionId, userId);
    if (!session) {
      throw new Error('Recording session not found.');
    }

    const sources = db.prepare(`
      SELECT *
      FROM recording_sources
      WHERE session_id = ?
      ORDER BY created_at ASC
    `).all(sessionId);
    if (sources.length == 0) {
      throw new Error('Recording session has no sources.');
    }

    db.transaction(() => {
      db.prepare(`
        DELETE FROM recording_transcript_segments
        WHERE session_id = ?
      `).run(sessionId);
      db.prepare(`
        UPDATE recording_sources
        SET status = ?, updated_at = ?
        WHERE session_id = ?
      `).run(SESSION_STATUS.processing, new Date().toISOString(), sessionId);
    })();

    const collectedSegments = [];
    let maxDuration = 0;

    try {
      for (const source of sources) {
        const chunks = db.prepare(`
          SELECT *
          FROM recording_chunks
          WHERE source_id = ?
          ORDER BY sequence_index ASC
        `).all(source.id);

        if (chunks.length === 0) {
          continue;
        }

        this.#assertSequentialChunks(source.source_key, chunks);
        const sourceSegments = await this.#transcribeSourceChunks(source, chunks);
        maxDuration = Math.max(
          maxDuration,
          ...sourceSegments.map((segment) => Number(segment.endMs) || 0),
          Number(source.duration_ms) || 0,
        );
        collectedSegments.push(...sourceSegments);

        db.prepare(`
          UPDATE recording_sources
          SET status = ?, duration_ms = ?, updated_at = ?
          WHERE id = ?
        `).run(
          SESSION_STATUS.completed,
          Math.max(
            Number(source.duration_ms) || 0,
            ...sourceSegments.map((segment) => Number(segment.endMs) || 0),
          ),
          new Date().toISOString(),
          source.id,
        );
      }

      const insertSegment = db.prepare(`
        INSERT INTO recording_transcript_segments (
          session_id, source_id, source_key, speaker, text, start_ms, end_ms, confidence, words_json
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      `);
      const ordered = collectedSegments.sort((a, b) => {
        if (a.startMs !== b.startMs) {
          return a.startMs - b.startMs;
        }
        return a.sourceKey.localeCompare(b.sourceKey);
      });

      db.transaction(() => {
        for (const segment of ordered) {
          insertSegment.run(
            sessionId,
            segment.sourceId,
            segment.sourceKey,
            segment.speaker,
            segment.text,
            segment.startMs,
            segment.endMs,
            segment.confidence,
            JSON.stringify(segment.words),
          );
        }
      })();

      const transcriptText = this.#composeTranscriptText(ordered);
      db.prepare(`
        UPDATE recording_sessions
        SET
          status = ?,
          transcript_text = ?,
          transcript_language = ?,
          transcript_model = ?,
          duration_ms = ?,
          last_error = NULL,
          updated_at = ?,
          ended_at = COALESCE(ended_at, ?)
        WHERE id = ?
      `).run(
        SESSION_STATUS.completed,
        transcriptText,
        DEFAULT_LANGUAGE,
        DEFAULT_MODEL,
        maxDuration,
        new Date().toISOString(),
        new Date().toISOString(),
        sessionId,
      );
    } catch (error) {
      db.prepare(`
        UPDATE recording_sessions
        SET status = ?, last_error = ?, updated_at = ?
        WHERE id = ?
      `).run(
        SESSION_STATUS.failed,
        sanitizeError(error),
        new Date().toISOString(),
        sessionId,
      );
      db.prepare(`
        UPDATE recording_sources
        SET status = ?, updated_at = ?
        WHERE session_id = ?
      `).run(SESSION_STATUS.failed, new Date().toISOString(), sessionId);
      this.#emitUpdate(userId, sessionId);
      throw error;
    }

    this.#emitUpdate(userId, sessionId);
    return this.getSession(userId, sessionId);
  }

  deleteTranscriptSegment(userId, sessionId, segmentId) {
    const session = db.prepare(`
      SELECT id
      FROM recording_sessions
      WHERE id = ? AND user_id = ?
    `).get(sessionId, userId);
    if (!session) {
      throw new Error('Recording session not found.');
    }

    const normalizedSegmentId = Number(segmentId);
    if (!Number.isInteger(normalizedSegmentId) || normalizedSegmentId <= 0) {
      throw new Error('segmentId must be a positive integer.');
    }

    const segment = db.prepare(`
      SELECT id
      FROM recording_transcript_segments
      WHERE session_id = ? AND id = ?
    `).get(sessionId, normalizedSegmentId);
    if (!segment) {
      throw new Error('Transcript segment not found.');
    }

    const now = new Date().toISOString();
    let transcriptText = '';
    db.transaction(() => {
      db.prepare(`
        DELETE FROM recording_transcript_segments
        WHERE session_id = ? AND id = ?
      `).run(sessionId, normalizedSegmentId);

      const remainingSegments = db.prepare(`
        SELECT start_ms, text
        FROM recording_transcript_segments
        WHERE session_id = ?
        ORDER BY start_ms ASC, id ASC
      `).all(sessionId);
      transcriptText = this.#composeTranscriptText(remainingSegments);

      db.prepare(`
        UPDATE recording_sessions
        SET transcript_text = ?, updated_at = ?
        WHERE id = ?
      `).run(transcriptText, now, sessionId);
    })();

    this.#emitUpdate(userId, sessionId);
    return this.getSession(userId, sessionId);
  }

  async #transcribeSourceChunks(source, chunks) {
    const segments = [];

    for (const chunk of chunks) {
      const audioBytes = fs.readFileSync(chunk.file_path);
      const payload = await transcribeChunkWithDeepgram({
        audioBytes,
        mimeType: chunk.mime_type || source.mime_type,
        detectLanguage: DEFAULT_LANGUAGE,
      });
      segments.push(...this.#extractSegments(source, chunk, payload));
    }

    return segments;
  }

  #extractSegments(source, chunk, payload) {
    const results = payload?.results || {};
    const channels = Array.isArray(results.channels) ? results.channels : [];
    const alternative = channels[0]?.alternatives?.[0] || {};
    const utterances = Array.isArray(results.utterances) ? results.utterances : [];
    const words = Array.isArray(alternative.words) ? alternative.words : [];
    const chunkStartMs = Number(chunk.start_ms) || 0;
    const chunkEndMs = Number(chunk.end_ms) || chunkStartMs;

    if (utterances.length > 0) {
      return utterances
        .map((utterance, index) => {
          const startMs = chunkStartMs + Math.max(0, Math.round((Number(utterance.start) || 0) * 1000));
          const endMs = chunkStartMs + Math.max(0, Math.round((Number(utterance.end) || 0) * 1000));
          return {
            sourceId: source.id,
            sourceKey: source.source_key,
            speaker: source.source_kind,
            text: `${utterance.transcript || ''}`.trim(),
            startMs,
            endMs: Math.max(startMs, endMs),
            confidence: Number(utterance.confidence) || null,
            words: Array.isArray(utterance.words) ? utterance.words : [],
            index,
          };
        })
        .filter((item) => item.text.length > 0);
    }

    const transcript = `${alternative.transcript || ''}`.trim();
    if (!transcript) {
      return [];
    }

    return [
      {
        sourceId: source.id,
        sourceKey: source.source_key,
        speaker: source.source_kind,
        text: transcript,
        startMs: chunkStartMs,
        endMs: Math.max(chunkStartMs, chunkEndMs),
        confidence: Number(alternative.confidence) || null,
        words,
      },
    ];
  }

  #assertSequentialChunks(sourceKey, chunks) {
    for (let index = 0; index < chunks.length; index += 1) {
      if (Number(chunks[index].sequence_index) !== index) {
        throw new Error(`Recording source "${sourceKey}" is missing chunk ${index}.`);
      }
    }
  }

  #resolveTitle(title, platform, nowIso) {
    if (typeof title === 'string' && title.trim()) {
      return title.trim().slice(0, 160);
    }
    const stamp = new Date(nowIso).toISOString().replace('T', ' ').slice(0, 16);
    if (platform === 'web') {
      return `Screen + mic recording ${stamp}`;
    }
    if (platform === 'android') {
      return `Background microphone recording ${stamp}`;
    }
    return `Recording ${stamp}`;
  }

  #normalizeSources(rawSources, platform) {
    const fallback = platform === 'android'
      ? [
          {
            sourceKey: 'microphone',
            sourceKind: 'microphone',
            mediaKind: 'audio',
            mimeType: 'audio/wav',
            metadata: { backgroundCapable: true },
          },
        ]
      : [
          {
            sourceKey: 'screen',
            sourceKind: 'screen-share',
            mediaKind: 'video',
            mimeType: 'video/webm',
            metadata: { analysisReady: true },
          },
          {
            sourceKey: 'microphone',
            sourceKind: 'microphone',
            mediaKind: 'audio',
            mimeType: 'audio/webm',
            metadata: {},
          },
        ];

    const inputs = Array.isArray(rawSources) && rawSources.length > 0 ? rawSources : fallback;
    const seen = new Set();

    return inputs.map((item, index) => {
      const sourceKey = `${item?.sourceKey || item?.id || `source-${index}`}`.trim().toLowerCase();
      if (!sourceKey) {
        throw new Error('Every recording source needs a sourceKey.');
      }
      if (seen.has(sourceKey)) {
        throw new Error(`Duplicate recording source: ${sourceKey}`);
      }
      seen.add(sourceKey);
      return {
        sourceKey,
        sourceKind: `${item?.sourceKind || sourceKey}`.trim().toLowerCase(),
        mediaKind: `${item?.mediaKind || 'audio'}`.trim().toLowerCase(),
        mimeType: `${item?.mimeType || 'application/octet-stream'}`.trim().toLowerCase(),
        metadata: item?.metadata && typeof item.metadata === 'object'
          ? item.metadata
          : {},
      };
    });
  }

  #mapSession(row) {
    const metadata = this.#parseJson(row.metadata_json, {});
    return {
      id: row.id,
      title: row.title || 'Recording',
      platform: row.platform || 'unknown',
      status: row.status || SESSION_STATUS.recording,
      transcriptText: row.transcript_text || '',
      transcriptLanguage: row.transcript_language || DEFAULT_LANGUAGE,
      transcriptModel: row.transcript_model || DEFAULT_MODEL,
      startedAt: row.started_at,
      endedAt: row.ended_at,
      durationMs: Number(row.duration_ms) || 0,
      lastError: row.last_error,
      metadata,
      sourceCount: Number(
        db.prepare('SELECT COUNT(*) AS count FROM recording_sources WHERE session_id = ?').get(row.id).count,
      ) || 0,
    };
  }

  #mapSource(row) {
    return {
      id: row.id,
      sourceKey: row.source_key,
      sourceKind: row.source_kind,
      mediaKind: row.media_kind,
      mimeType: row.mime_type,
      status: row.status,
      chunkCount: Number(row.chunk_count) || 0,
      bytesReceived: Number(row.bytes_received) || 0,
      durationMs: Number(row.duration_ms) || 0,
      metadata: this.#parseJson(row.metadata_json, {}),
    };
  }

  #mapSegment(row) {
    return {
      id: Number(row.id),
      sourceKey: row.source_key,
      speaker: row.speaker || row.source_key || 'source',
      text: row.text || '',
      startMs: Number(row.start_ms) || 0,
      endMs: Number(row.end_ms) || 0,
      confidence: row.confidence == null ? null : Number(row.confidence),
      words: this.#parseJson(row.words_json, []),
    };
  }

  #composeTranscriptText(segments) {
    return (Array.isArray(segments) ? segments : [])
      .map((segment) => {
        const startMs = Number(segment.startMs ?? segment.start_ms) || 0;
        const text = `${segment.text || ''}`.trim();
        if (!text) {
          return null;
        }
        return `[${this.#formatTimestamp(startMs)}] ${text}`;
      })
      .filter((line) => line != null)
      .join('\n');
  }

  #emitUpdate(userId, sessionId) {
    this.io?.to?.(`user:${userId}`)?.emit('recordings:updated', { sessionId });
  }

  #extensionForMime(mimeType) {
    if (/wav/i.test(mimeType)) return '.wav';
    if (/webm/i.test(mimeType)) return '.webm';
    if (/mp4|m4a/i.test(mimeType)) return '.m4a';
    if (/ogg|opus/i.test(mimeType)) return '.ogg';
    return '.bin';
  }

  #formatTimestamp(ms) {
    const totalSeconds = Math.max(0, Math.floor((Number(ms) || 0) / 1000));
    const hours = Math.floor(totalSeconds / 3600);
    const minutes = Math.floor((totalSeconds % 3600) / 60);
    const seconds = totalSeconds % 60;
    if (hours > 0) {
      return `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
    }
    return `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
  }

  #parseJson(value, fallback) {
    try {
      return value ? JSON.parse(value) : fallback;
    } catch {
      return fallback;
    }
  }
}

module.exports = {
  RecordingManager,
  SESSION_STATUS,
};
