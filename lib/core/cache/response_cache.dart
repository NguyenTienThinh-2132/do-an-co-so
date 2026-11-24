import '../types/result.dart';
import 'cache_entry.dart';

/// Read-cache port; repository decides when cached data is safe to display.
abstract interface class ResponseCache {
  /// Missing entry or incompatible payload version returns Success(null).
  Future<Result<CacheEntry?>> read(
    CacheKey key, {
    int expectedSchemaVersion = 1,
  });

  /// Replaces this exact key atomically, including a valid empty response [].
  Future<Result<void>> write(
    CacheKey key, {
    required String payloadJson,
    int schemaVersion = 1,
  });
  Future<Result<void>> remove(CacheKey key);

  /// Clears one account/environment only, e.g. on logout. No global delete.
  Future<Result<void>> clearNamespace(String namespace);
}
