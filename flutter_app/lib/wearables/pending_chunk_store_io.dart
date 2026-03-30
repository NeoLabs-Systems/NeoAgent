import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'pending_chunk_store.dart';

class _IoPendingChunkStore implements PendingChunkStore {
  static const String _folderName = 'wearables';
  static const String _fileName = 'pending_chunks.jsonl';

  @override
  Future<List<String>> readRows() async {
    final file = await _queueFile();
    if (!await file.exists()) {
      return const <String>[];
    }
    final content = await file.readAsLines();
    return content.where((line) => line.trim().isNotEmpty).toList(growable: false);
  }

  @override
  Future<void> writeRows(List<String> rows) async {
    final file = await _queueFile();
    final parent = file.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }

    final temp = File('${file.path}.tmp');
    final payload = rows.isEmpty ? '' : '${rows.join('\n')}\n';
    await temp.writeAsString(payload, flush: true);

    try {
      await temp.rename(file.path);
    } catch (_) {
      // Keep the original file untouched and leave the temp file for inspection/retry.
      rethrow;
    }
  }

  Future<File> _queueFile() async {
    final baseDir = await getApplicationSupportDirectory();
    return File('${baseDir.path}/$_folderName/$_fileName');
  }
}

PendingChunkStore createPendingChunkStorePlatform() {
  return _IoPendingChunkStore();
}
