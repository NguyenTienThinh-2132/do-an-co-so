import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../core/cache/cache_database.dart';
import '../core/cache/cache_entry.dart';
import '../core/cache/sqlite_response_cache.dart';
import '../core/types/result.dart';

T _value<T>(Result<T> result) => switch (result) {
  Success<T>(:final value) => value,
  Failure<T>() => throw StateError('CACHE_PROBE_OPERATION_FAILED'),
};
void _check(bool condition) {
  if (!condition) throw StateError('CACHE_PROBE_ASSERTION_FAILED');
}

const _a = CacheKey(
  namespace: 'probe-a',
  resource: 'tasks',
  queryKey: 'month-11',
);
const _b = CacheKey(
  namespace: 'probe-b',
  resource: 'tasks',
  queryKey: 'month-11',
);
const _next = CacheKey(
  namespace: 'probe-a',
  resource: 'tasks',
  queryKey: 'month-12',
);
const _sentinel = CacheKey(
  namespace: 'probe-restart',
  resource: 'probe',
  queryKey: 'v1',
);
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SizedBox.shrink());
  try {
    await _run();
  } catch (_) {
    debugPrint('CACHE_PROBE_FAIL');
  }
}

Future<void> _run() async {
  // Separate subdirectory: never touches the app's future live cache.
  final directory = p.join(await getDatabasesPath(), 'read_cache_probe');
  var db = CacheDatabase(directory: directory);
  var cache = SqliteResponseCache(
    database: db,
    clock: () => DateTime.utc(2026, 11, 13, 9),
  );
  try {
    final old = _value(await cache.read(_sentinel));
    if (old != null) {
      _check(old.payloadJson == '{"restart":true}');
      _value(await cache.clearNamespace('probe-restart'));
      debugPrint('CACHE_PROBE_PROCESS_RESTART_PASS');
      return;
    }
    _value(await cache.clearNamespace('probe-a'));
    _value(await cache.clearNamespace('probe-b'));
    _check(_value(await cache.read(_a)) == null);
    _value(
      await cache.write(
        _a,
        payloadJson: '[{"id":"task-probe","title":"Cache probe"}]',
      ),
    );
    _value(await cache.write(_b, payloadJson: '{"scope":"b"}'));
    _value(await cache.write(_next, payloadJson: '{"month":12}'));
    await db.close();
    db = CacheDatabase(directory: directory);
    cache = SqliteResponseCache(database: db);
    final restored = _value(await cache.read(_a));
    _check(
      restored != null && restored.savedAt == DateTime.utc(2026, 11, 13, 9),
    );
    _check(
      (jsonDecode(restored!.payloadJson) as List).single['id'] == 'task-probe',
    );
    _value(await cache.write(_a, payloadJson: '[]'));
    _check(_value(await cache.read(_a))!.payloadJson == '[]');
    _check(_value(await cache.read(_b))!.payloadJson == '{"scope":"b"}');
    _check(_value(await cache.read(_next))!.payloadJson == '{"month":12}');
    _check(await cache.write(_a, payloadJson: 'invalid') is Failure<void>);
    _check(_value(await cache.read(_a))!.payloadJson == '[]');
    _check(_value(await cache.read(_a, expectedSchemaVersion: 2)) == null);
    _value(await cache.remove(_next));
    _check(_value(await cache.read(_next)) == null);
    _value(await cache.clearNamespace('probe-a'));
    _check(_value(await cache.read(_a)) == null);
    _check(_value(await cache.read(_b)) != null);
    _value(await cache.clearNamespace('probe-b'));
    _value(await cache.write(_sentinel, payloadJson: '{"restart":true}'));
    debugPrint('CACHE_PROBE_SQLITE_PASS');
    debugPrint('CACHE_PROBE_RESTART_READY');
  } finally {
    await db.close();
  }
}
