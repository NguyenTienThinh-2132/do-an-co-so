import 'package:flutter_test/flutter_test.dart';
import 'package:finai/features/tasks/domain/entities/task_draft.dart';
import 'package:finai/features/tasks/domain/entities/task_status.dart';
import 'package:finai/features/tasks/domain/sync/task_sync_operation.dart';
import 'package:finai/features/tasks/data/mappers/task_sync_request_mapper.dart';

const createId = '00000000-0000-4000-8000-000000000001';
const updateId = '00000000-0000-4000-8000-000000000002';
const taskId = '10000000-0000-4000-8000-000000000001';
void main() {
  final queued = DateTime.utc(2026, 11, 23, 9);
  TaskDraft draft() => TaskDraft(
    title: '  Báo cáo offline  ',
    startAt: queued,
    endAt: queued.add(const Duration(hours: 1)),
  );
  TaskSyncOperation create() => TaskSyncOperation.create(
    operationId: createId,
    taskId: taskId,
    draft: draft(),
    queuedAt: queued.toLocal(),
  );
  test(
    'create keeps identity and UTC, payload has no provisional timestamps',
    () {
      final op = create();
      expect(op.isReadyToSend, isTrue);
      expect(op.queuedAt, queued);
      expect(op.queuedAt.isUtc, isTrue);
      final json = TaskSyncRequestMapper.toJson(op);
      expect(json['baseVersion'], isNull);
      expect(json['kind'], 'create');
      final payload = json['payload'] as Map;
      expect(payload['title'], 'Báo cáo offline');
      expect(payload.containsKey('id'), isFalse);
      expect(payload.containsKey('createdAt'), isFalse);
      expect(payload.containsKey('updatedAt'), isFalse);
    },
  );
  test('editing an acknowledged task requires its server version', () {
    final op = TaskSyncOperation.update(
      operationId: updateId,
      taskId: taskId,
      draft: draft(),
      queuedAt: queued,
      baseVersion: 7,
    );
    expect(op.isReadyToSend, isTrue);
    expect(TaskSyncRequestMapper.toJson(op)['baseVersion'], 7);
  });
  test(
    'offline create then edit waits for the matching create acknowledgement',
    () {
      final pending = TaskSyncOperation.update(
        operationId: updateId,
        taskId: taskId,
        draft: draft(),
        queuedAt: queued,
        dependsOnOperationId: createId,
      );
      expect(pending.isReadyToSend, isFalse);
      expect(() => TaskSyncRequestMapper.toJson(pending), throwsStateError);
      final ready = pending.resolveDependency(
        acknowledgedOperationId: createId,
        acknowledgedTaskId: taskId,
        serverVersion: 1,
      );
      expect(ready.operationId, pending.operationId);
      expect(ready.taskId, pending.taskId);
      expect(identical(ready.draft, pending.draft), isTrue);
      expect(ready.queuedAt, pending.queuedAt);
      expect(ready.baseVersion, 1);
      expect(ready.dependsOnOperationId, isNull);
      expect(ready.isReadyToSend, isTrue);
      expect(pending.isReadyToSend, isFalse);
    },
  );
  test('a wrong task/operation acknowledgement cannot unlock a request', () {
    final op = TaskSyncOperation.delete(
      operationId: updateId,
      taskId: taskId,
      queuedAt: queued,
      dependsOnOperationId: createId,
    );
    expect(
      () => op.resolveDependency(
        acknowledgedOperationId: updateId,
        acknowledgedTaskId: taskId,
        serverVersion: 1,
      ),
      throwsArgumentError,
    );
    expect(
      () => op.resolveDependency(
        acknowledgedOperationId: createId,
        acknowledgedTaskId: createId,
        serverVersion: 1,
      ),
      throwsArgumentError,
    );
  });
  test('a ready request cannot silently rebase and change its retry body', () {
    final op = TaskSyncOperation.delete(
      operationId: updateId,
      taskId: taskId,
      queuedAt: queued,
      baseVersion: 3,
    );
    expect(
      () => op.resolveDependency(
        acknowledgedOperationId: createId,
        acknowledgedTaskId: taskId,
        serverVersion: 4,
      ),
      throwsStateError,
    );
  });
  test('status/delete have exact payload shapes and stable identities', () {
    final status = TaskSyncOperation.setStatus(
      operationId: updateId,
      taskId: taskId,
      status: TaskStatus.completed,
      queuedAt: queued,
      baseVersion: 2,
    );
    expect(TaskSyncRequestMapper.toJson(status)['payload'], {
      'status': 'completed',
    });
    final deletion = TaskSyncOperation.delete(
      operationId: createId,
      taskId: taskId,
      queuedAt: queued,
      baseVersion: 3,
    );
    expect(TaskSyncRequestMapper.toJson(deletion), {
      'operationId': createId,
      'taskId': taskId,
      'kind': 'delete',
      'baseVersion': 3,
      'payload': null,
    });
  });
  test('missing, ambiguous or non-positive base versions are rejected', () {
    expect(
      () => TaskSyncOperation.delete(
        operationId: updateId,
        taskId: taskId,
        queuedAt: queued,
      ),
      throwsArgumentError,
    );
    expect(
      () => TaskSyncOperation.update(
        operationId: updateId,
        taskId: taskId,
        draft: draft(),
        queuedAt: queued,
        baseVersion: 1,
        dependsOnOperationId: createId,
      ),
      throwsArgumentError,
    );
    for (final version in [0, -1]) {
      expect(
        () => TaskSyncOperation.setStatus(
          operationId: updateId,
          taskId: taskId,
          status: TaskStatus.pending,
          queuedAt: queued,
          baseVersion: version,
        ),
        throwsArgumentError,
      );
    }
  });
  test('invalid UUIDs and self dependencies are rejected', () {
    for (final id in ['', ' task ', 'not-a-uuid', '$createId\n']) {
      expect(
        () => TaskSyncOperation.create(
          operationId: id,
          taskId: taskId,
          draft: draft(),
          queuedAt: queued,
        ),
        throwsArgumentError,
      );
    }
    expect(
      () => TaskSyncOperation.delete(
        operationId: updateId,
        taskId: taskId,
        queuedAt: queued,
        dependsOnOperationId: updateId,
      ),
      throwsArgumentError,
    );
    expect(
      () => TaskSyncOperation.create(
        operationId: createId,
        taskId: 'bad',
        draft: draft(),
        queuedAt: queued,
      ),
      throwsArgumentError,
    );
  });
  test(
    'uppercase UUIDs are canonicalized without changing the entity identity',
    () {
      const id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
      final op = TaskSyncOperation.create(
        operationId: id.toUpperCase(),
        taskId: taskId,
        draft: draft(),
        queuedAt: queued,
      );
      expect(op.operationId, id);
    },
  );
}
