import '../../domain/sync/task_sync_operation.dart';
import '../../domain/entities/task_status.dart';
import 'task_api_mapper.dart';

/// Storage format can represent an unresolved dependency; wire format cannot.
abstract final class TaskSyncStorageMapper {
  static Map<String, Object?> toJson(TaskSyncOperation op) => {
    'formatVersion': 1,
    'operationId': op.operationId,
    'taskId': op.taskId,
    'kind': op.kind.name,
    'queuedAt': op.queuedAt.toUtc().toIso8601String(),
    'baseVersion': op.baseVersion,
    'dependsOnOperationId': op.dependsOnOperationId,
    'payload': switch (op.kind) {
      TaskSyncKind.create ||
      TaskSyncKind.update => TaskApiMapper.draftToJson(op.draft!),
      TaskSyncKind.setStatus => {'status': op.status!.name},
      TaskSyncKind.delete => null,
    },
  };
  static TaskSyncOperation fromJson(Object? value) {
    try {
      if (value is! Map<String, dynamic> || value['formatVersion'] != 1) {
        throw const FormatException('Unknown task operation storage format.');
      }
      final operationId = value['operationId'] as String;
      final taskId = value['taskId'] as String;
      final kind = TaskSyncKind.values.byName(value['kind'] as String);
      final at = value['queuedAt'] as String;
      final queuedAt = DateTime.parse(at);
      if (!queuedAt.isUtc || queuedAt.toIso8601String() != at) {
        throw const FormatException('Non-canonical UTC timestamp.');
      }
      final base = value['baseVersion'] as int?;
      final depends = value['dependsOnOperationId'] as String?;
      final payload = value['payload'];
      return switch (kind) {
        TaskSyncKind.create => _create(
          operationId,
          taskId,
          queuedAt,
          payload,
          base,
          depends,
        ),
        TaskSyncKind.update => TaskSyncOperation.update(
          operationId: operationId,
          taskId: taskId,
          queuedAt: queuedAt,
          draft: TaskApiMapper.draftFromJson(payload),
          baseVersion: base,
          dependsOnOperationId: depends,
        ),
        TaskSyncKind.setStatus => TaskSyncOperation.setStatus(
          operationId: operationId,
          taskId: taskId,
          queuedAt: queuedAt,
          status: TaskStatus.values.byName(
            (payload as Map)['status'] as String,
          ),
          baseVersion: base,
          dependsOnOperationId: depends,
        ),
        TaskSyncKind.delete => _delete(
          operationId,
          taskId,
          queuedAt,
          payload,
          base,
          depends,
        ),
      };
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Invalid stored task operation.');
    }
  }

  static TaskSyncOperation _create(
    String op,
    String task,
    DateTime at,
    Object? payload,
    int? base,
    String? depends,
  ) {
    if (base != null || depends != null) {
      throw const FormatException('Create cannot have a base/dependency.');
    }
    return TaskSyncOperation.create(
      operationId: op,
      taskId: task,
      queuedAt: at,
      draft: TaskApiMapper.draftFromJson(payload),
    );
  }

  static TaskSyncOperation _delete(
    String op,
    String task,
    DateTime at,
    Object? payload,
    int? base,
    String? depends,
  ) {
    if (payload != null) {
      throw const FormatException('Delete payload must be null.');
    }
    return TaskSyncOperation.delete(
      operationId: op,
      taskId: task,
      queuedAt: at,
      baseVersion: base,
      dependsOnOperationId: depends,
    );
  }
}
