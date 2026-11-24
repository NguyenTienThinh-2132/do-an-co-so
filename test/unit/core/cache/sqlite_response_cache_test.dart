import 'package:finai/core/cache/cache_database.dart';
import 'package:finai/core/cache/cache_entry.dart';
import 'package:finai/core/cache/sqlite_response_cache.dart';
import 'package:finai/core/types/app_failure.dart';
import 'package:finai/core/types/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

class StubDatabase extends Fake implements Database {
  List<Map<String, Object?>> rows = [];
  bool readFails = false;
  int closes = 0;
  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    if (readFails) throw StateError('private database path and payload');
    return rows;
  }

  @override
  Future<void> close() async {
    closes++;
  }
}

class StubFactory extends Fake implements DatabaseFactory {
  final db = StubDatabase();
  int opens = 0;
  bool fail = false;
  @override
  Future<Database> openDatabase(
    String path, {
    OpenDatabaseOptions? options,
  }) async {
    opens++;
    if (fail) throw StateError('private SQL/credentials');
    return db;
  }
}

const key = CacheKey(
  namespace: 'demo-book',
  resource: 'tasks',
  queryKey: '2026-11',
);
void main() {
  late StubFactory factory;
  late CacheDatabase database;
  late SqliteResponseCache cache;
  setUp(() {
    factory = StubFactory();
    database = CacheDatabase(directory: 'cache-unit-test', factory: factory);
    cache = SqliteResponseCache(database: database);
  });
  tearDown(() async {
    await database.close();
  });
  test('invalid key, JSON and version do not touch storage', () async {
    const invalid = CacheKey(
      namespace: ' ',
      resource: 'tasks',
      queryKey: 'month',
    );
    expect(await cache.read(invalid), isA<Failure<CacheEntry?>>());
    for (final payload in ['broken', 'null', '42', '"text"']) {
      final result = await cache.write(key, payloadJson: payload);
      expect((result as Failure<void>).failure.code, AppFailureCode.validation);
    }
    expect(
      await cache.write(key, payloadJson: '[]', schemaVersion: 0),
      isA<Failure<void>>(),
    );
    expect(
      await cache.read(key, expectedSchemaVersion: 0),
      isA<Failure<CacheEntry?>>(),
    );
    expect(await cache.clearNamespace(' '), isA<Failure<void>>());
    expect(factory.opens, 0);
  });
  test('cache miss differs from an empty saved list', () async {
    expect((await cache.read(key) as Success<CacheEntry?>).value, isNull);
    factory.db.rows = [
      {'schema_version': 1, 'payload_json': '[]', 'saved_at_ms': 0},
    ];
    final entry = (await cache.read(key) as Success<CacheEntry?>).value;
    expect(entry, isNotNull);
    expect(entry!.payloadJson, '[]');
    expect(entry.savedAt, DateTime.fromMillisecondsSinceEpoch(0, isUtc: true));
  });
  test('old payload schema is a cache miss without deleting it', () async {
    factory.db.rows = [
      {'schema_version': 1, 'payload_json': '[]', 'saved_at_ms': 0},
    ];
    expect(
      (await cache.read(
        key,
        expectedSchemaVersion: 2,
      ) as Success<CacheEntry?>).value,
      isNull,
    );
    expect((await cache.read(key) as Success<CacheEntry?>).value, isNotNull);
  });
  test('corrupt local response is failure, never fake empty data', () async {
    factory.db.rows = [
      {'schema_version': 1, 'payload_json': 'not-json', 'saved_at_ms': 0},
    ];
    final result = await cache.read(key) as Failure<CacheEntry?>;
    expect(result.failure.code, AppFailureCode.unavailable);
  });
  test('storage failure is safe and a later open can recover', () async {
    factory.fail = true;
    final result = await cache.read(key) as Failure<CacheEntry?>;
    expect(result.failure.code, AppFailureCode.unavailable);
    expect(result.failure.message, isNot(contains('credentials')));
    expect(result.failure.message, isNot(contains('SQL')));
    factory.fail = false;
    expect(await cache.read(key), isA<Success<CacheEntry?>>());
    expect(factory.opens, 2);
  });
  test('closed store reports failure and close is idempotent', () async {
    await cache.read(key);
    await database.close();
    await database.close();
    expect(factory.db.closes, 1);
    expect(await cache.read(key), isA<Failure<CacheEntry?>>());
    expect(factory.opens, 1);
  });
}
