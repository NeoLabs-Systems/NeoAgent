import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/src/recording_chunk_queue.dart';
import 'package:neoagent_flutter/src/recording_chunk_queue_io.dart';

PendingChunk chunk(int sequence, {String sourceKey = 'microphone'}) {
  return PendingChunk(
    sourceKey: sourceKey,
    sequence: sequence,
    startMs: sequence * 4000,
    endMs: (sequence + 1) * 4000,
    mimeType: 'audio/wav',
    bytes: Uint8List.fromList(<int>[sequence, sequence, sequence]),
  );
}

void main() {
  const fast = Duration(milliseconds: 1);

  group('MemoryChunkUploadQueue', () {
    test('uploads queued chunks in order', () async {
      final uploaded = <int>[];
      final queue = MemoryChunkUploadQueue(
        retryBackoff: fast,
        uploader: (c) async => uploaded.add(c.sequence),
      );
      queue.enqueue(chunk(0));
      queue.enqueue(chunk(1));
      queue.enqueue(chunk(2));
      await queue.flush(timeout: const Duration(seconds: 5));
      expect(uploaded, <int>[0, 1, 2]);
      expect(queue.pendingCount, 0);
    });

    test('retries a failing chunk until it succeeds instead of dropping it', () async {
      var attempts = 0;
      final uploaded = <int>[];
      final queue = MemoryChunkUploadQueue(
        maxAttemptsPerPass: 2,
        retryBackoff: fast,
        uploader: (c) async {
          attempts += 1;
          if (attempts < 4) {
            throw StateError('transient failure $attempts');
          }
          uploaded.add(c.sequence);
        },
      );
      queue.enqueue(chunk(7));
      await queue.flush(timeout: const Duration(seconds: 5));
      expect(uploaded, <int>[7]);
      expect(queue.pendingCount, 0);
      expect(attempts, greaterThanOrEqualTo(4));
    });

    test('a stalled chunk does not block a later one in a separate queue', () async {
      // Per-source queues isolate failures: build two and confirm the healthy
      // one drains while the other keeps retrying.
      final ok = <int>[];
      final healthy = MemoryChunkUploadQueue(
        retryBackoff: fast,
        uploader: (c) async => ok.add(c.sequence),
      );
      final stalled = MemoryChunkUploadQueue(
        maxAttemptsPerPass: 1,
        retryBackoff: const Duration(seconds: 30),
        uploader: (c) async => throw StateError('offline'),
      );
      stalled.enqueue(chunk(0, sourceKey: 'system'));
      healthy.enqueue(chunk(0));
      healthy.enqueue(chunk(1));
      await healthy.flush(timeout: const Duration(seconds: 5));
      expect(ok, <int>[0, 1]);
      expect(stalled.pendingCount, 1);
      await stalled.dispose();
      await healthy.dispose();
    });
  });

  group('DiskChunkUploadQueue', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('chunk-queue-test');
    });

    tearDown(() async {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });

    test('persists, uploads, then removes each chunk', () async {
      final uploaded = <int, Uint8List>{};
      final queue = DiskChunkUploadQueue(
        directory: dir,
        retryBackoff: fast,
        uploader: (c) async => uploaded[c.sequence] = c.bytes,
      );
      await queue.enqueue(chunk(0));
      await queue.enqueue(chunk(1));
      await queue.flush(timeout: const Duration(seconds: 5));

      expect(uploaded.keys.toList()..sort(), <int>[0, 1]);
      expect(uploaded[1], <int>[1, 1, 1]);
      expect(await queue.pendingCount(), 0);
      await queue.dispose();
    });

    test('keeps a chunk on disk until a failing upload finally succeeds', () async {
      var attempts = 0;
      final queue = DiskChunkUploadQueue(
        directory: dir,
        maxAttemptsPerPass: 2,
        retryBackoff: fast,
        uploader: (c) async {
          attempts += 1;
          if (attempts < 4) {
            throw StateError('backend down $attempts');
          }
        },
      );
      await queue.enqueue(chunk(0));
      // Before it succeeds the chunk must still be persisted.
      expect(await queue.pendingCount(), 1);
      await queue.flush(timeout: const Duration(seconds: 5));
      expect(await queue.pendingCount(), 0);
      expect(attempts, greaterThanOrEqualTo(4));
      await queue.dispose();
    });

    test('flush waits for a chunk whose file persistence started before flush', () async {
      final uploaded = <int>[];
      final queue = DiskChunkUploadQueue(
        directory: dir,
        retryBackoff: fast,
        uploader: (c) async => uploaded.add(c.sequence),
      );

      unawaited(queue.enqueue(chunk(2)));
      await queue.flush(timeout: const Duration(seconds: 5));

      expect(uploaded, <int>[2]);
      expect(await queue.pendingCount(), 0);
      await queue.dispose();
    });
  });
}
