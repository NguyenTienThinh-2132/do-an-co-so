import '../../domain/sync/task_sync_operation.dart';
import 'task_api_mapper.dart';

/// Proposed /tasks/sync request only. Does not call the existing CRUD routes.
abstract final class TaskSyncRequestMapper {
  static Map<String, Object?> toJson(TaskSyncOperation operation) {
    if (!operation.isReadyToSend) {
      throw StateError('Resolve and persist the dependency before sending.');
    }
    final Object? payload = switch (operation.kind) {
      TaskSyncKind.create ||
      TaskSyncKind.update => TaskApiMapper.draftToJson(operation.draft!),
      TaskSyncKind.setStatus => {'status': operation.status!.name},
      TaskSyncKind.delete => null,
    };
    return {
      'operationId': operation.operationId,
      'taskId': operation.taskId,
      'kind': operation.kind.name,
      'baseVersion': operation.baseVersion,
      'payload': payload,
    };
  }
}
