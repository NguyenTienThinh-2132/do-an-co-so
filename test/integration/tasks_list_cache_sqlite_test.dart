// Real TaskRepository + sqflite Dart + host SQLite. HTTP is a deterministic fixture.
// This does not verify Android's native plugin or a real phone.
import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:finai/core/cache/cache_database.dart';
import 'package:finai/core/cache/sqlite_response_cache.dart';
import 'package:finai/core/types/result.dart';
import 'package:finai/features/tasks/data/datasources/task_remote_datasource.dart';
import 'package:finai/features/tasks/data/repositories/http_task_repository.dart';
import 'package:finai/features/tasks/domain/entities/task.dart';
import 'package:finai/features/tasks/domain/entities/task_query.dart';
import 'package:finai/features/tasks/application/tasks_list_controller.dart';
import 'package:finai/features/tasks/application/tasks_list_state.dart';

import 'cache_sqlite_host_test.dart' as sql;

const node = String.fromEnvironment('CACHE_SQLITE_NODE');
const channel = MethodChannel('com.tekartik.sqflite');
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Task list is ready from SQLite after repository/database/process restart without API',
    () async {
      final root = Directory(p.absolute('build', 'cache_test_runs'));
      await root.create(recursive: true);
      final dir = await root.createTemp('tasks-');
      final file = p.join(dir.path, CacheDatabase.fileName);
      final transport = File(
        p.absolute('tool', 'testing', 'cache_sqlite_host.mjs'),
      ).path;
      sql.Host? host;
      CacheDatabase? db;
      HttpTaskRepository? repo;
      http.Client? client;
      final query = TaskQuery(
        start: DateTime.utc(2026, 11, 23),
        end: DateTime.utc(2026, 11, 24),
      );
      bool offline = false, empty = false;
      Future<void> open() async {
        host = sql.Host(await Process.start(node, [transport, file]));
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) => host!.call(call));
        db = CacheDatabase(
          directory: dir.path,
          factory: databaseFactorySqflitePlugin,
        );
        client = MockClient((_) async {
          if (offline) throw http.ClientException('offline fixture');
          return http.Response.bytes(
            utf8.encode(
              jsonEncode(
                empty
                    ? []
                    : [
                        {
                          'id': 'sqlite-probe',
                          'title': 'Công việc lưu trên SQLite',
                          'description': null,
                          'categoryId': null,
                          'startAt': '2026-11-23T02:00:00.000Z',
                          'endAt': '2026-11-23T03:00:00.000Z',
                          'priority': 'high',
                          'status': 'pending',
                          'createdAt': '2026-11-01T00:00:00.000Z',
                          'updatedAt': '2026-11-23T01:00:00.000Z',
                        },
                      ],
              ),
            ),
            200,
            headers: {'content-type': 'application/json'},
          );
        });
        repo = HttpTaskRepository(
          datasource: TaskRemoteDatasource(
            client: client!,
            baseUrl: Uri.parse('http://cache-test.local'),
          ),
          cache: SqliteResponseCache(database: db!),
          cacheNamespace: 'native-sqlite-test|server|tasks-list-v1',
        );
      }

      Future<void> close() async {
        repo?.dispose();
        await repo?.cacheSettled;
        client?.close();
        await db?.close();
        await host?.close();
        host = null;
      }

      try {
        await open();
        final first = await repo!.watch(query).first as Success<List<Task>>;
        expect(first.value.single.title, 'Công việc lưu trên SQLite');
        await close();
        offline = true;
        await open();
        // New controller sees ready with the persisted list despite failed HTTP.
        final controller = TasksListController(repository: repo!, query: query);
        final ready = Completer<TasksListState>();
        void listener() {
          if (!ready.isCompleted &&
              controller.state.phase != TasksListPhase.loading &&
              controller.state.phase != TasksListPhase.initial) {
            ready.complete(controller.state);
          }
        }

        controller.addListener(listener);
        controller.load();
        try {
          final state = await ready.future.timeout(const Duration(seconds: 10));
          expect(state.phase, TasksListPhase.ready);
          expect(state.tasks.single.id, 'sqlite-probe');
          expect(state.tasks.single.title, 'Công việc lưu trên SQLite');
        } finally {
          controller.removeListener(listener);
          controller.dispose();
        }
        offline = false;
        empty = true;
        expect(
          (await repo!.watch(query).first as Success<List<Task>>).value,
          isEmpty,
        );
        await close();
        offline = true;
        await open();
        expect(
          (await repo!.watch(query).first as Success<List<Task>>).value,
          isEmpty,
        );
      } finally {
        await close();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      }
    },
    skip: node.isEmpty
        ? 'Pass CACHE_SQLITE_NODE for real SQLite cache integration.'
        : false,
  );
}
