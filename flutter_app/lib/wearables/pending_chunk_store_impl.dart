import 'pending_chunk_store.dart';
import 'pending_chunk_store_io.dart'
    if (dart.library.html) 'pending_chunk_store_web.dart';

PendingChunkStore createPendingChunkStoreImpl() {
  return createPendingChunkStorePlatform();
}
