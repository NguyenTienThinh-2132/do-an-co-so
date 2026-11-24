import 'package:finai/features/tasks/data/mappers/task_sync_request_mapper.dart';

// Actual sqflite Dart SQL + Node SQLite host. Not Android plugin verification.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:finai/core/types/result.dart';
import 'package:finai/core/types/app_failure.dart';
import 'package:finai/features/tasks/data/local/tasks_local_database.dart';
import 'package:finai/features/tasks/data/local/task_local_store.dart';
import 'package:finai/features/tasks/domain/entities/task.dart';
import 'package:finai/features/tasks/domain/entities/task_draft.dart';
import 'package:finai/features/tasks/domain/entities/task_priority.dart';
import 'package:finai/features/tasks/domain/entities/task_query.dart';
import 'package:finai/features/tasks/domain/entities/task_status.dart';
import 'package:finai/features/tasks/domain/sync/task_sync_operation.dart';
import 'package:finai/features/tasks/domain/sync/task_outbox_status.dart';

import 'cache_sqlite_host_test.dart' as sql;

const node = String.fromEnvironment('CACHE_SQLITE_NODE');
const channel = MethodChannel('com.tekartik.sqflite');
const t1 = '10000000-0000-4000-8000-000000000001',
    t2 = '10000000-0000-4000-8000-000000000002';
const op1 = '00000000-0000-4000-8000-000000000001',
    op2 = '00000000-0000-4000-8000-000000000002',
    op3 = '00000000-0000-4000-8000-000000000003',
    op4 = '00000000-0000-4000-8000-000000000004';
T value<T>(Result<T> result) {
  if (result is Failure<T>) {
    throw TestFailure('${result.failure.code}: ${result.failure.message}');
  }
  return (result as Success<T>).value;
}

void failure<T>(Result<T> result, AppFailureCode code) {
  expect(result, isA<Failure<T>>());
  expect((result as Failure<T>).failure.code, code);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group(
    'Task local / durable outbox',
    () {
      late Directory dir;
      late sql.Host host;
      late TasksLocalDatabase db;
      late TaskLocalStore a, b;
      final at = DateTime.utc(2026, 11, 23, 9, 0, 0, 123, 456);
      TaskDraft draft({
        String title = 'Báo cáo offline',
        TaskPriority priority = TaskPriority.high,
      }) => TaskDraft(
        title: title,
        startAt: DateTime.utc(2026, 11, 23, 2),
        endAt: DateTime.utc(2026, 11, 23, 3),
        priority: priority,
      );
      Task server({
        String id = t1,
        String title = 'Bản server',
        TaskStatus status = TaskStatus.pending,
        TaskPriority priority = TaskPriority.high,
        DateTime? start,
        DateTime? end,
      }) => Task(
        id: id,
        title: title,
        description: 'Ghi chú server',
        categoryId: 'study',
        startAt: start ?? DateTime.utc(2026, 11, 23, 2),
        endAt: end ?? DateTime.utc(2026, 11, 23, 3),
        priority: priority,
        status: status,
        createdAt: DateTime.utc(2026, 11, 1),
        updatedAt: DateTime.utc(2026, 11, 22),
      );
      TaskQuery query({
        TaskStatus? status,
        TaskPriority? priority,
        String search = '',
      }) => TaskQuery(
        start: DateTime.utc(2026, 11, 23),
        end: DateTime.utc(2026, 11, 24),
        status: status,
        priority: priority,
        searchText: search,
      );
      TaskSyncOperation create({
        String operation = op1,
        String task = t1,
        String title = 'Báo cáo offline',
      }) => TaskSyncOperation.create(
        operationId: operation,
        taskId: task,
        draft: draft(title: title),
        queuedAt: at,
      );
      Future<void> open() async {
        host = sql.Host(
          await Process.start(node, [
            p.absolute('tool', 'testing', 'cache_sqlite_host.mjs'),
            p.join(dir.path, TasksLocalDatabase.fileName),
          ]),
        );
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, host.call);
        db = TasksLocalDatabase(
          directory: dir.path,
          factory: databaseFactorySqflitePlugin,
        );
        a = TaskLocalStore(database: db, namespace: 'native|account-a');
        b = TaskLocalStore(database: db, namespace: 'native|account-b');
      }

      setUp(() async {
        final root = Directory(p.absolute('build', 'task_local_test_runs'));
        await root.create(recursive: true);
        dir = await root.createTemp('sqlite-');
        await open();
      });
      tearDown(() async {
        await db.close();
        await host.close();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      test('server baseline saves without creating any outbox entry', () async {
        final record = value(await a.saveServerSnapshot(server(), version: 4));
        expect(record.serverVersion, 4);
        expect(record.hasPendingChanges, isFalse);
        expect(record.task.title, 'Bản server');
        expect(value(await a.getOutbox()), isEmpty);
      });
      test('create projection and pending operation persist across SQLite process restart', () async {
        final created = value(await a.enqueue(create()));
        expect(created.task.id, t1);
        expect(created.hasPendingChanges, isTrue);
        expect(created.serverVersion, isNull);
        await db.close();
        await host.close();
        await open();
        final restored = value(await a.getById(t1));
        final outbox = value(await a.getOutbox());
        expect(restored!.task.title, 'Báo cáo offline');
        expect(restored.task.createdAt, at);
        expect(outbox, hasLength(1));
        expect(outbox.single.operation.queuedAt, at);
        expect(outbox.single.state, TaskOutboxStatus.pending);
        expect(outbox.single.attemptCount, 0);
        expect(outbox.single.frozenRequestJson, isNull);
      });
      test('offline create -> edit -> complete -> delete is ordered with stable IDs', () async {
        value(await a.enqueue(create()));
        value(
          await a.enqueue(
            TaskSyncOperation.update(
              operationId: op2,
              taskId: t1,
              draft: draft(title: 'Tên đã sửa'),
              queuedAt: at.add(const Duration(seconds: 1)),
              dependsOnOperationId: op1,
            ),
          ),
        );
        final completed = value(
          await a.enqueue(
            TaskSyncOperation.setStatus(
              operationId: op3,
              taskId: t1,
              status: TaskStatus.completed,
              queuedAt: at.add(const Duration(seconds: 2)),
              dependsOnOperationId: op2,
            ),
          ),
        );
        expect(completed.task.title, 'Tên đã sửa');
        expect(completed.task.status, TaskStatus.completed);
        expect(completed.task.createdAt, at);
        value(
          await a.enqueue(
            TaskSyncOperation.delete(
              operationId: op4,
              taskId: t1,
              queuedAt: at.add(const Duration(seconds: 3)),
              dependsOnOperationId: op3,
            ),
          ),
        );
        expect(value(await a.getById(t1)), isNull);
        expect(value(await a.list(query())), isEmpty);
        final tombstone = value(await a.getById(t1, includeDeleted: true));
        expect(tombstone!.isDeleted, isTrue);
        expect(tombstone.task.id, t1);
        final entries = value(await a.getOutbox());
        expect(entries.map((e) => e.operation.operationId), [
          op1,
          op2,
          op3,
          op4,
        ]);
        expect(entries.every((e) => e.operation.taskId == t1), isTrue);
        expect(
          entries.map((e) => e.sequence).toList(),
          orderedEquals([...entries.map((e) => e.sequence)]..sort()),
        );
      });
      test(
        'retry same enqueue does not duplicate or roll projection back',
        () async {
          final first = create();
          value(await a.enqueue(first));
          value(
            await a.enqueue(
              TaskSyncOperation.update(
                operationId: op2,
                taskId: t1,
                draft: draft(title: 'Mới hơn'),
                queuedAt: at,
                dependsOnOperationId: op1,
              ),
            ),
          );
          expect(value(await a.enqueue(first)).task.title, 'Mới hơn');
          expect(value(await a.getOutbox()), hasLength(2));
        },
      );
      test(
        'reused operation ID with different content is conflict and unchanged',
        () async {
          value(await a.enqueue(create()));
          failure(
            await a.enqueue(create(title: 'Nội dung khác')),
            AppFailureCode.conflict,
          );
          expect(value(await a.getById(t1))!.task.title, 'Báo cáo offline');
          expect(value(await a.getOutbox()), hasLength(1));
        },
      );
      test('existing server edit validates base version and supports nullable field clearing', () async {
        value(await a.saveServerSnapshot(server(), version: 4));
        failure(
          await a.enqueue(
            TaskSyncOperation.update(
              operationId: op1,
              taskId: t1,
              draft: draft(),
              queuedAt: at,
              baseVersion: 3,
            ),
          ),
          AppFailureCode.conflict,
        );
        final edited = value(
          await a.enqueue(
            TaskSyncOperation.update(
              operationId: op1,
              taskId: t1,
              draft: draft(),
              queuedAt: at,
              baseVersion: 4,
            ),
          ),
        );
        expect(edited.task.description, isNull);
        expect(edited.task.categoryId, isNull);
        expect(edited.serverTask!.description, 'Ghi chú server');
        expect(edited.serverVersion, 4);
      });
      test('wrong task/dependency, missing ID and duplicate task cannot modify rows', () async {
        value(await a.enqueue(create()));
        value(await a.enqueue(create(operation: op2, task: t2)));
        failure(
          await a.enqueue(
            TaskSyncOperation.update(
              operationId: op3,
              taskId: t2,
              draft: draft(title: 'Sai phụ thuộc'),
              queuedAt: at,
              dependsOnOperationId: op1,
            ),
          ),
          AppFailureCode.conflict,
        );
        failure(
          await a.enqueue(
            TaskSyncOperation.delete(
              operationId: op3,
              taskId: '10000000-0000-4000-8000-000000000099',
              queuedAt: at,
              baseVersion: 1,
            ),
          ),
          AppFailureCode.notFound,
        );
        failure(
          await a.enqueue(create(operation: op3)),
          AppFailureCode.conflict,
        );
        expect(value(await a.getOutbox()), hasLength(2));
      });
      test('scope isolation includes tasks, operation IDs and foreign dependencies', () async {
        value(await a.enqueue(create()));
        expect(value(await b.getById(t1)), isNull);
        expect(value(await b.getOutbox()), isEmpty);
        value(await b.saveServerSnapshot(server(), version: 1));
        failure(
          await b.enqueue(
            TaskSyncOperation.update(
              operationId: op2,
              taskId: t1,
              draft: draft(),
              queuedAt: at,
              dependsOnOperationId: op1,
            ),
          ),
          AppFailureCode.conflict,
        );
        value(
          await b.enqueue(
            TaskSyncOperation.update(
              operationId: op1,
              taskId: t1,
              draft: draft(title: 'Account B'),
              queuedAt: at,
              baseVersion: 1,
            ),
          ),
        );
        expect(value(await a.getById(t1))!.task.title, 'Báo cáo offline');
        expect(value(await b.getById(t1))!.task.title, 'Account B');
      });
      test('server refresh updates baseline but preserves unsynced local projection', () async {
        value(await a.saveServerSnapshot(server(), version: 4));
        value(
          await a.enqueue(
            TaskSyncOperation.update(
              operationId: op1,
              taskId: t1,
              draft: draft(title: 'Người dùng sửa'),
              queuedAt: at,
              baseVersion: 4,
            ),
          ),
        );
        final refreshed = value(
          await a.saveServerSnapshot(
            server(title: 'Thiết bị khác sửa'),
            version: 5,
          ),
        );
        expect(refreshed.task.title, 'Người dùng sửa');
        expect(refreshed.serverTask!.title, 'Thiết bị khác sửa');
        expect(refreshed.serverVersion, 5);
        expect(value(await a.getOutbox()).single.operation.baseVersion, 4);
        value(await a.saveServerSnapshot(server(title: 'Bản cũ'), version: 3));
        expect(value(await a.getById(t1))!.serverVersion, 5);
        failure(
          await a.saveServerSnapshot(
            server(title: 'Cùng version nhưng khác'),
            version: 5,
          ),
          AppFailureCode.conflict,
        );
      });
      test(
        'failed outbox INSERT rolls back a new projection completely',
        () async {
          final connection = await db.connection;
          await connection.execute(
            "CREATE TRIGGER reject_outbox BEFORE INSERT ON task_outbox BEGIN SELECT RAISE(ABORT,'injected failure'); END",
          );
          failure(await a.enqueue(create()), AppFailureCode.unavailable);
          expect(value(await a.getById(t1, includeDeleted: true)), isNull);
          expect(value(await a.getOutbox()), isEmpty);
        },
      );
      test(
        'failed outbox INSERT also rolls back editing an existing projection',
        () async {
          value(await a.saveServerSnapshot(server(), version: 4));
          final connection = await db.connection;
          await connection.execute(
            "CREATE TRIGGER reject_outbox BEFORE INSERT ON task_outbox BEGIN SELECT RAISE(ABORT,'injected failure'); END",
          );
          failure(
            await a.enqueue(
              TaskSyncOperation.update(
                operationId: op1,
                taskId: t1,
                draft: draft(title: 'Không được lưu dở'),
                queuedAt: at,
                baseVersion: 4,
              ),
            ),
            AppFailureCode.unavailable,
          );
          final restored = value(await a.getById(t1));
          expect(restored!.task.title, 'Bản server');
          expect(restored.hasPendingChanges, isFalse);
          expect(value(await a.getOutbox()), isEmpty);
        },
      );
      test(
        'parallel duplicate enqueue is idempotent on the injected connection',
        () async {
          final op = create();
          final results = await Future.wait([a.enqueue(op), a.enqueue(op)]);
          expect(results.every((r) => r is Success), isTrue);
          expect(value(await a.getOutbox()), hasLength(1));
        },
      );
      test('local query uses half-open overlap, Unicode search, status and priority', () async {
        value(
          await a.saveServerSnapshot(
            server(title: 'BÁO CÁO', status: TaskStatus.completed),
            version: 1,
          ),
        );
        value(
          await a.saveServerSnapshot(
            server(
              id: t2,
              title: 'Việc sau',
              priority: TaskPriority.low,
              start: DateTime.utc(2026, 11, 24),
              end: DateTime.utc(2026, 11, 24, 1),
            ),
            version: 1,
          ),
        );
        final filtered = value(
          await a.list(
            query(
              status: TaskStatus.completed,
              priority: TaskPriority.high,
              search: 'báo cáo',
            ),
          ),
        );
        expect(filtered.map((r) => r.task.id), [t1]);
        expect(value(await a.list(query(status: TaskStatus.pending))), isEmpty);
      });
      test('corrupt stored task or operation is failure instead of fake empty data', () async {
        value(await a.enqueue(create()));
        final connection = await db.connection;
        await connection.update('task_outbox', {'operation_json': '{}'});
        failure(await a.getOutbox(), AppFailureCode.unavailable);
        await connection.update('tasks_local', {'local_json': '{}'});
        failure(await a.getById(t1), AppFailureCode.unavailable);
      });
      test('database cannot mark sending/synced without durable request/ack metadata', () async {
        value(await a.enqueue(create()));
        final connection = await db.connection;
        await expectLater(
          connection.update('task_outbox', {'state': 'sending'}),
          throwsA(isA<DatabaseException>()),
        );
        await expectLater(
          connection.update('task_outbox', {'state': 'synced'}),
          throwsA(isA<DatabaseException>()),
        );
        expect(
          value(await a.getOutbox()).single.state,
          TaskOutboxStatus.pending,
        );
      });
      test('frozen request can resolve version while original dependency remains immutable', () async {
        value(await a.enqueue(create()));
        final dependent = TaskSyncOperation.update(
          operationId: op2,
          taskId: t1,
          draft: draft(),
          queuedAt: at,
          dependsOnOperationId: op1,
        );
        value(await a.enqueue(dependent));
        final ready = dependent.resolveDependency(
          acknowledgedOperationId: op1,
          acknowledgedTaskId: t1,
          serverVersion: 1,
        );
        final frozen = jsonEncode(TaskSyncRequestMapper.toJson(ready));
        final connection = await db.connection;
        // Fixture setup only; no sending method or network engine exists yet.
        await connection.update(
          'task_outbox',
          {
            'state': 'sending',
            'attempt_count': 1,
            'frozen_request_json': frozen,
          },
          where: 'operation_id=?',
          whereArgs: [op2],
        );
        final entry = value(await a.getOutbox()).last;
        expect(entry.operation.dependsOnOperationId, op1);
        expect(entry.frozenRequestJson, frozen);
        expect(value(await a.enqueue(dependent)).task.id, t1);
        expect(value(await a.getOutbox()), hasLength(2));
      });
      test(
        'invalid version/ID and closed database return explicit failures',
        () async {
          failure(
            await a.saveServerSnapshot(server(), version: 0),
            AppFailureCode.validation,
          );
          failure(await a.getById('bad'), AppFailureCode.validation);
          await db.close();
          failure(await a.getOutbox(), AppFailureCode.unavailable);
        },
      );
    },
    skip: node.isEmpty
        ? 'Pass CACHE_SQLITE_NODE to run real SQLite local/outbox tests.'
        : false,
  );
}
