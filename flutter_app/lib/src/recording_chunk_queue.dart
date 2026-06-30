import 'dart:async';
import 'dart:typed_data';

/// Metadata plus bytes for one recording chunk awaiting upload.
class PendingChunk {
  const PendingChunk({
    required this.sourceKey,
    required this.sequence,
    required this.startMs,
    required this.endMs,
    required this.mimeType,
    required this.bytes,
  });

  final String sourceKey;
  final int sequence;
  final int startMs;
  final int endMs;
  final String mimeType;
  final Uint8List bytes;

  Map<String, Object?> toMeta() => <String, Object?>{
    'sourceKey': sourceKey,
    'sequence': sequence,
    'startMs': startMs,
    'endMs': endMs,
    'mimeType': mimeType,
  };

  static PendingChunk fromMeta(Map<String, Object?> meta, Uint8List bytes) {
    return PendingChunk(
      sourceKey: '${meta['sourceKey']}',
      sequence: (meta['sequence'] as num?)?.toInt() ?? 0,
      startMs: (meta['startMs'] as num?)?.toInt() ?? 0,
      endMs: (meta['endMs'] as num?)?.toInt() ?? 0,
      mimeType: meta['mimeType'] as String? ?? 'application/octet-stream',
      bytes: bytes,
    );
  }
}

/// Uploads a single chunk. Must throw on any failure so the queue retries.
typedef ChunkUploader = Future<void> Function(PendingChunk chunk);

typedef QueueLogger =
    void Function(String event, {Map<String, Object?> data, Object? error});

/// In-memory, ordered, retry-until-success upload queue.
///
/// Chunks upload one at a time in enqueue order. A chunk that fails is kept and
/// retried (with backoff) until it succeeds or [dispose] is called, so a
/// transient network failure never silently drops audio while new chunks keep
/// buffering. Used on web, where no filesystem is available; the queue lives
/// only for the lifetime of the tab.
class MemoryChunkUploadQueue {
  MemoryChunkUploadQueue({
    required ChunkUploader uploader,
    this.maxAttemptsPerPass = 3,
    this.retryBackoff = const Duration(seconds: 2),
    QueueLogger? logger,
  }) : _uploader = uploader,
       _logger = logger;

  final ChunkUploader _uploader;
  final int maxAttemptsPerPass;
  final Duration retryBackoff;
  final QueueLogger? _logger;

  final List<PendingChunk> _pending = <PendingChunk>[];
  bool _draining = false;
  bool _disposed = false;
  Timer? _retryTimer;

  int get pendingCount => _pending.length;

  void enqueue(PendingChunk chunk) {
    if (_disposed) {
      return;
    }
    _pending.add(chunk);
    unawaited(drain());
  }

  Future<void> drain() async {
    if (_draining || _disposed) {
      return;
    }
    _draining = true;
    try {
      while (_pending.isNotEmpty && !_disposed) {
        final chunk = _pending.first;
        final uploaded = await _attemptUpload(chunk);
        if (!uploaded) {
          _scheduleRetry();
          break;
        }
        if (_pending.isNotEmpty && identical(_pending.first, chunk)) {
          _pending.removeAt(0);
        }
      }
    } finally {
      _draining = false;
    }
  }

  Future<bool> _attemptUpload(PendingChunk chunk) async {
    for (var attempt = 0; attempt < maxAttemptsPerPass && !_disposed; attempt += 1) {
      try {
        await _uploader(chunk);
        return true;
      } catch (error) {
        _logger?.call(
          'chunk.upload.failed',
          data: <String, Object?>{
            'sourceKey': chunk.sourceKey,
            'sequence': chunk.sequence,
            'attempt': attempt + 1,
          },
          error: error,
        );
        await Future<void>.delayed(retryBackoff * (attempt + 1));
      }
    }
    return false;
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(retryBackoff, () => unawaited(drain()));
  }

  /// Wait until every queued chunk has uploaded, or [timeout] elapses.
  Future<void> flush({Duration timeout = const Duration(seconds: 30)}) async {
    final deadline = DateTime.now().add(timeout);
    while (_pending.isNotEmpty && !_disposed && DateTime.now().isBefore(deadline)) {
      await drain();
      if (_pending.isNotEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    _pending.clear();
  }
}
