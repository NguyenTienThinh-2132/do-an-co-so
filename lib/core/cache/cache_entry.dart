/// Scope is explicit: e.g. API environment + finance book + user ID.
/// queryKey must be canonical (sorted filters, UTC range), supplied by the reader.
class CacheKey {
  const CacheKey({
    required this.namespace,
    required this.resource,
    required this.queryKey,
  });
  final String namespace;
  final String resource;
  final String queryKey;
  bool get isValid =>
      namespace.trim().isNotEmpty &&
      resource.trim().isNotEmpty &&
      queryKey.trim().isNotEmpty;
}

/// An API response snapshot. It never represents a pending offline mutation.
class CacheEntry {
  const CacheEntry({
    required this.key,
    required this.payloadJson,
    required this.savedAt,
    required this.schemaVersion,
  });
  final CacheKey key;
  final String payloadJson;
  final DateTime savedAt;
  final int schemaVersion;
}
