import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'recording_chunk_queue.dart';

/// Disk-backed, ordered, retry-until-success upload queue for desktop.
///
/// Each chunk is persisted atomically before upload, so a network outage or
/// backend hiccup mid-meeting never loses audio: the chunk stays on disk and is
/// re-sent on the next drain. Files are deleted only after a confirmed upload.
class DiskChunkUploadQueue {
  DiskChunkUploadQueue({
    required Directory directory,
    required ChunkUploader uploader,
    this.maxAttemptsPerPass = 3,
    this.retryBackoff = const Duration(seconds: 2),
    QueueLogger? logger,
  }) : _dir = directory,
       _uploader = uploader,
       _logger = logger;

  final Directory _dir;
  final ChunkUploader _uploader;
  final int maxAttemptsPerPass;
  final Duration retryBackoff;
  final QueueLogger? _logger;

  bool _draining = false;
  bool _disposed = false;
  Timer? _retryTimer;

  Future<void> enqueue(PendingChunk chunk) async {
    if (_disposed) {
      return;
    }
    await _dir.create(recursive: true);
    final base = '${chunk.sourceKey}-${chunk.sequence.toString().padLeft(6, '0')}';
    final audioFile = File('${_dir.path}/$base.bin');
    final metaFile = File('${_dir.path}/$base.json');
    final audioTmp = File('${audioFile.path}.tmp');
    final metaTmp = File('${metaFile.path}.tmp');
    await audioTmp.writeAsBytes(chunk.bytes, flush: true);
    await metaTmp.writeAsString(jsonEncode(chunk.toMeta()), flush: true);
    await audioTmp.rename(audioFile.path);
    await metaTmp.rename(metaFile.path);
    unawaited(drain());
  }

  Future<void> drain() async {
    if (_draining || _disposed) {
      return;
    }
    _draining = true;
    try {
      while (!_disposed) {
        final metaFiles = await _listMetaFiles();
        if (metaFiles.isEmpty) {
          break;
        }
        final metaFile = metaFiles.first;
        final audioFile = File(
          metaFile.path.replaceFirst(RegExp(r'\.json$'), '.bin'),
        );
        if (!await audioFile.exists()) {
          await _deleteQuietly(metaFile);
          continue;
        }

        final PendingChunk chunk;
        try {
          final meta =
              jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
          chunk = PendingChunk.fromMeta(meta, await audioFile.readAsBytes());
        } catch (error) {
          // Corrupt metadata: drop the pair rather than blocking the queue.
          _logger?.call('chunk.read.failed', error: error);
          await _deleteQuietly(metaFile);
          await _deleteQuietly(audioFile);
          continue;
        }

        final uploaded = await _attemptUpload(chunk);
        if (!uploaded) {
          _scheduleRetry();
          break;
        }
        await _deleteQuietly(audioFile);
        await _deleteQuietly(metaFile);
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

  Future<List<File>> _listMetaFiles() async {
    if (!await _dir.exists()) {
      return const <File>[];
    }
    final entries = await _dir.list().toList();
    final metaFiles = entries
        .whereType<File>()
        .where((file) => file.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    return metaFiles;
  }

  Future<int> pendingCount() async => (await _listMetaFiles()).length;

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(retryBackoff, () => unawaited(drain()));
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (error) {
      _logger?.call('chunk.delete.failed', error: error);
    }
  }

  /// Wait until every persisted chunk has uploaded, or [timeout] elapses.
  Future<void> flush({Duration timeout = const Duration(seconds: 30)}) async {
    final deadline = DateTime.now().add(timeout);
    while (!_disposed && DateTime.now().isBefore(deadline)) {
      await drain();
      if (await pendingCount() == 0) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _retryTimer?.cancel();
    _retryTimer = null;
  }
}
