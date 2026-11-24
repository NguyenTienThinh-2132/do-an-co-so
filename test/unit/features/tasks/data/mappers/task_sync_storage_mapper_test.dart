import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:finai/features/tasks/domain/entities/task_draft.dart';
import 'package:finai/features/tasks/domain/entities/task_status.dart';
import 'package:finai/features/tasks/domain/sync/task_sync_operation.dart';
import 'package:finai/features/tasks/data/mappers/task_sync_storage_mapper.dart';
import 'package:finai/features/tasks/data/mappers/task_sync_request_mapper.dart';

const a = '00000000-0000-4000-8000-000000000001';
const b = '00000000-0000-4000-8000-000000000002';
const task = '10000000-0000-4000-8000-000000000001';
void main() {
  final at = DateTime.utc(2026, 11, 23, 9, 0, 0, 123, 456);
  TaskDraft draft() => TaskDraft(
    title: 'Lưu offline',
    startAt: at,
    endAt: at.add(const Duration(hours: 1)),
  );
  test(
    'ready operation kinds preserve identical retry bodies after JSON storage',
    () {
      final ops = [
        TaskSyncOperation.create(
          operationId: a,
          taskId: task,
          draft: draft(),
          queuedAt: at,
        ),
        TaskSyncOperation.update(
          operationId: a,
          taskId: task,
          draft: draft(),
          queuedAt: at,
          baseVersion: 3,
        ),
        TaskSyncOperation.setStatus(
          operationId: a,
          taskId: task,
          status: TaskStatus.completed,
          queuedAt: at,
          baseVersion: 4,
        ),
        TaskSyncOperation.delete(
          operationId: a,
          taskId: task,
          queuedAt: at,
          baseVersion: 5,
        ),
      ];
      for (final op in ops) {
        final restored = TaskSyncStorageMapper.fromJson(
          jsonDecode(jsonEncode(TaskSyncStorageMapper.toJson(op))),
        );
        expect(
          TaskSyncRequestMapper.toJson(restored),
          TaskSyncRequestMapper.toJson(op),
        );
        expect(restored.queuedAt, at);
      }
    },
  );
  test('unresolved dependency persists without pretending it is sendable', () {
    final op = TaskSyncOperation.update(
      operationId: b,
      taskId: task,
      draft: draft(),
      queuedAt: at,
      dependsOnOperationId: a,
    );
    final restored = TaskSyncStorageMapper.fromJson(
      jsonDecode(jsonEncode(TaskSyncStorageMapper.toJson(op))),
    );
    expect(restored.dependsOnOperationId, a);
    expect(restored.isReadyToSend, isFalse);
    expect(restored.queuedAt.microsecond, 456);
  });
  test(
    'unknown format, malformed time and contradictory payload are rejected',
    () {
      final raw = TaskSyncStorageMapper.toJson(
        TaskSyncOperation.create(
          operationId: a,
          taskId: task,
          draft: draft(),
          queuedAt: at,
        ),
      );
      for (final bad in [
        null,
        [],
        {...raw, 'formatVersion': 2},
        {...raw, 'queuedAt': '2026-11-23T09:00:00'},
        {...raw, 'baseVersion': 1},
        {...raw, 'payload': {}},
        {
          ...raw,
          'kind': 'delete',
          'baseVersion': 1,
          'payload': {'unexpected': true},
        },
      ]) {
        expect(
          () => TaskSyncStorageMapper.fromJson(bad),
          throwsFormatException,
        );
      }
    },
  );
}
