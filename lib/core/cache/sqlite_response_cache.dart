import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../types/app_failure.dart';
import '../types/result.dart';
import 'cache_database.dart';
import 'cache_entry.dart';
import 'response_cache.dart';

class SqliteResponseCache implements ResponseCache {
  SqliteResponseCache({required this.database, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;
  final CacheDatabase database;
  final DateTime Function() _clock;
  static const _where = 'namespace = ? AND resource = ? AND query_key = ?';
  List<Object?> _args(CacheKey key) => [
    key.namespace,
    key.resource,
    key.queryKey,
  ];

  bool _isJsonContainer(String value) {
    try {
      final decoded = jsonDecode(value);
      return decoded is Map || decoded is List;
    } catch (_) {
      return false;
    }
  }

  Failure<T> _invalid<T>() => const Failure(
    AppFailure(
      code: AppFailureCode.validation,
      message: 'Khóa cache, phiên bản hoặc dữ liệu JSON không hợp lệ.',
    ),
  );
  Failure<T> _unavailable<T>() => const Failure(
    AppFailure(
      code: AppFailureCode.unavailable,
      message: 'Chưa đọc hoặc lưu được dữ liệu cache trên thiết bị.',
    ),
  );
  @override
  Future<Result<CacheEntry?>> read(
    CacheKey key, {
    int expectedSchemaVersion = 1,
  }) async {
    if (!key.isValid || expectedSchemaVersion < 1) return _invalid();
    try {
      final db = await database.connection;
      final rows = await db.query(
        CacheDatabase.table,
        where: _where,
        whereArgs: _args(key),
        limit: 1,
      );
      if (rows.isEmpty) return const Success(null);
      final row = rows.single;
      final version = row['schema_version'] as int;
      if (version != expectedSchemaVersion) return const Success(null);
      final payload = row['payload_json'] as String;
      if (!_isJsonContainer(payload)) return _unavailable();
      return Success(
        CacheEntry(
          key: key,
          payloadJson: payload,
          savedAt: DateTime.fromMillisecondsSinceEpoch(
            row['saved_at_ms'] as int,
            isUtc: true,
          ),
          schemaVersion: version,
        ),
      );
    } catch (_) {
      return _unavailable();
    }
  }

  @override
  Future<Result<void>> write(
    CacheKey key, {
    required String payloadJson,
    int schemaVersion = 1,
  }) async {
    if (!key.isValid || schemaVersion < 1 || !_isJsonContainer(payloadJson)) {
      return _invalid();
    }
    try {
      final db = await database.connection;
      // One atomic statement, no child tables; replacing [] removes old results.
      await db.insert(CacheDatabase.table, {
        'namespace': key.namespace,
        'resource': key.resource,
        'query_key': key.queryKey,
        'payload_json': payloadJson,
        'saved_at_ms': _clock().toUtc().millisecondsSinceEpoch,
        'schema_version': schemaVersion,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return const Success(null);
    } catch (_) {
      return _unavailable();
    }
  }

  @override
  Future<Result<void>> remove(CacheKey key) async {
    if (!key.isValid) return _invalid();
    try {
      final db = await database.connection;
      await db.delete(
        CacheDatabase.table,
        where: _where,
        whereArgs: _args(key),
      );
      return const Success(null);
    } catch (_) {
      return _unavailable();
    }
  }

  @override
  Future<Result<void>> clearNamespace(String namespace) async {
    if (namespace.trim().isEmpty) return _invalid();
    try {
      final db = await database.connection;
      await db.delete(
        CacheDatabase.table,
        where: 'namespace = ?',
        whereArgs: [namespace],
      );
      return const Success(null);
    } catch (_) {
      return _unavailable();
    }
  }
}
