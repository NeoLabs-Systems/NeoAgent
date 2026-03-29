import 'pending_chunk_store_impl.dart';

abstract class PendingChunkStore {
  Future<List<String>> readRows();
  Future<void> writeRows(List<String> rows);
}

PendingChunkStore createPendingChunkStore() {
  return createPendingChunkStoreImpl();
}
