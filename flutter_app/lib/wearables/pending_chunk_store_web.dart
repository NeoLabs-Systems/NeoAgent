import 'package:shared_preferences/shared_preferences.dart';

import 'pending_chunk_store.dart';

class _WebPendingChunkStore implements PendingChunkStore {
  static const String _pendingQueuePrefsKey = 'wearable_pending_chunks_v1';

  @override
  Future<List<String>> readRows() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_pendingQueuePrefsKey) ?? const <String>[];
  }

  @override
  Future<void> writeRows(List<String> rows) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_pendingQueuePrefsKey, rows);
  }
}

PendingChunkStore createPendingChunkStorePlatform() {
  return _WebPendingChunkStore();
}
