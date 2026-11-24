class NativeEvent {
  const NativeEvent({
    required this.id,
    required this.kind,
    required this.receivedAt,
    required this.data,
  });
  final String id;
  final String kind;
  final DateTime receivedAt;
  final Map<String, Object?> data;

  factory NativeEvent.fromPlatform(Object? raw) {
    if (raw is! Map) throw const FormatException('Invalid Native event');
    final map = Map<String, Object?>.from(raw);
    if (map['id'] is! String ||
        map['kind'] is! String ||
        map['receivedAt'] is! int ||
        map['data'] is! Map) {
      throw const FormatException('Invalid Native event');
    }
    return NativeEvent(
      id: map['id'] as String,
      kind: map['kind'] as String,
      receivedAt: DateTime.fromMillisecondsSinceEpoch(
        map['receivedAt'] as int,
        isUtc: true,
      ),
      data: Map<String, Object?>.unmodifiable(
        Map<String, Object?>.from(map['data'] as Map),
      ),
    );
  }
}
