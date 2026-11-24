// Executes the real sqflite Dart SQL against real SQLite on the host.
// It replaces the native method-channel transport only; it does NOT verify Android.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:finai/core/cache/cache_database.dart';
import 'package:finai/core/cache/cache_entry.dart';
import 'package:finai/core/cache/sqlite_response_cache.dart';
import 'package:finai/core/types/result.dart';

const node = String.fromEnvironment('CACHE_SQLITE_NODE');
const channel = MethodChannel('com.tekartik.sqflite');
T value<T>(Result<T> r) => (r as Success<T>).value;

class Host {
  Host(this.process)
    : lines = StreamIterator(
        process.stdout.transform(utf8.decoder).transform(const LineSplitter()),
      ) {
    process.stderr.drain<void>();
  }
  final Process process;
  final StreamIterator<String> lines;
  Future<Object?> call(MethodCall call) async {
    process.stdin.writeln(
      jsonEncode({'method': call.method, 'args': call.arguments}),
    );
    await process.stdin.flush();
    if (!await lines.moveNext()) throw StateError('SQLite test host stopped');
    final reply = jsonDecode(lines.current) as Map;
    if (reply.containsKey('error')) {
      throw PlatformException(
        code: 'sqlite_error',
        message: 'Test transport failed',
      );
    }
    return reply['result'];
  }

  Future<void> close() async {
    await process.stdin.close();
    await process.exitCode.timeout(const Duration(seconds: 5));
    await lines.cancel();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'SQLite persists across a host process restart and isolates exact cache keys',
    () async {
      final root = Directory(p.absolute('build', 'cache_test_runs'));
      await root.create(recursive: true);
      final dir = await root.createTemp('sqlite-');
      final file = p.join(dir.path, CacheDatabase.fileName);
      final transport = File(
        p.absolute('tool', 'testing', 'cache_sqlite_host.mjs'),
      ).path;
      Host? host;
      CacheDatabase? db;
      Future<void> open() async {
        host = Host(await Process.start(node, [transport, file]));
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) => host!.call(call));
        db = CacheDatabase(
          directory: dir.path,
          factory: databaseFactorySqflitePlugin,
        );
      }

      const a = CacheKey(
        namespace: 'book-a',
        resource: 'tasks',
        queryKey: 'month-11',
      );
      const b = CacheKey(
        namespace: 'book-b',
        resource: 'tasks',
        queryKey: 'month-11',
      );
      const next = CacheKey(
        namespace: 'book-a',
        resource: 'tasks',
        queryKey: 'month-12',
      );
      const other = CacheKey(
        namespace: 'book-a',
        resource: 'jars',
        queryKey: 'month-11',
      );
      final at = DateTime.utc(2026, 11, 13, 9);
      try {
        await open();
        var cache = SqliteResponseCache(database: db!, clock: () => at);
        expect(value(await cache.read(a)), isNull);
        value(
          await cache.write(
            a,
            payloadJson: '[{"id":"probe","title":"Dữ liệu thử"}]',
          ),
        );
        value(await cache.write(b, payloadJson: '{"book":"b"}'));
        value(await cache.write(next, payloadJson: '{"month":12}'));
        value(await cache.write(other, payloadJson: '{"type":"jars"}'));
        await db!.close();
        await host!.close();
        host = null;
        // New SQLite process + new Dart owner, same file, before any new writes.
        await open();
        cache = SqliteResponseCache(database: db!);
        final restored = value(await cache.read(a));
        expect(restored!.savedAt, at);
        expect(restored.savedAt.isUtc, isTrue);
        expect(
          (jsonDecode(restored.payloadJson) as List).single['title'],
          'Dữ liệu thử',
        );
        value(await cache.write(a, payloadJson: '[]'));
        expect(value(await cache.read(a))!.payloadJson, '[]');
        expect(value(await cache.read(b))!.payloadJson, '{"book":"b"}');
        expect(value(await cache.read(next))!.payloadJson, '{"month":12}');
        expect(value(await cache.read(other))!.payloadJson, '{"type":"jars"}');
        expect(
          await cache.write(a, payloadJson: 'broken'),
          isA<Failure<void>>(),
        );
        expect(value(await cache.read(a))!.payloadJson, '[]');
        expect(value(await cache.read(a, expectedSchemaVersion: 2)), isNull);
        value(await cache.remove(next));
        expect(value(await cache.read(next)), isNull);
        value(await cache.clearNamespace('book-a'));
        expect(value(await cache.read(a)), isNull);
        expect(value(await cache.read(other)), isNull);
        expect(value(await cache.read(b)), isNotNull);
        expect(File(file).existsSync(), isTrue);
      } finally {
        await db?.close();
        await host?.close();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      }
    },
    skip: node.isEmpty
        ? 'Pass CACHE_SQLITE_NODE to test real host SQLite.'
        : false,
  );
}
