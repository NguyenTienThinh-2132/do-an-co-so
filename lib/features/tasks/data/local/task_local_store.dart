import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../../core/types/app_failure.dart';
import '../../../../core/types/result.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/task_query.dart';
import '../../domain/entities/task_status.dart';
import '../../domain/sync/local_task_record.dart';
import '../../domain/sync/task_outbox_entry.dart';
import '../../domain/sync/task_outbox_status.dart';
import '../../domain/sync/task_sync_operation.dart';
import '../mappers/task_api_mapper.dart';
import '../mappers/task_sync_storage_mapper.dart';
import 'tasks_local_database.dart';

/// Feature data store only. No API calls, UI, timers or sync acknowledgements.
class TaskLocalStore {
  TaskLocalStore({required this.database, required this.namespace}) {
    if (namespace.trim().isEmpty || namespace != namespace.trim()) {
      throw ArgumentError('An explicit canonical namespace is required.');
    }
  }
  final TasksLocalDatabase database;
  final String namespace;
  static const _recordSelect = '''SELECT t.*, EXISTS (
    SELECT 1 FROM task_outbox o WHERE o.namespace=t.namespace
      AND o.task_id=t.task_id AND o.state<>'synced'
    ) AS has_pending FROM tasks_local t''';
  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$',
  );
  String _id(String value) {
    if (value.length != 36 || !_uuid.hasMatch(value)) {
      throw const _StoreFailure(
        AppFailureCode.validation,
        'ID công việc không hợp lệ.',
      );
    }
    return value.toLowerCase();
  }

  Future<Result<T>> _run<T>(Future<T> Function() action) async {
    try {
      return Success(await action());
    } on _StoreFailure catch (e) {
      return Failure(AppFailure(code: e.code, message: e.message));
    } catch (_) {
      return const Failure(
        AppFailure(
          code: AppFailureCode.unavailable,
          message:
              'Chưa đọc hoặc lưu được công việc và hàng đợi trên thiết bị.',
        ),
      );
    }
  }

  Task _task(Object? value) =>
      TaskApiMapper.fromJson(jsonDecode(value as String));
  LocalTaskRecord _record(Map<String, Object?> row) {
    final task = _task(row['local_json']);
    final server = row['server_json'] == null
        ? null
        : _task(row['server_json']);
    if (task.id != row['task_id'] || (server != null && server.id != task.id)) {
      throw const FormatException('Local task identity mismatch.');
    }
    return LocalTaskRecord(
      namespace: row['namespace'] as String,
      task: task,
      isDeleted: row['local_deleted'] == 1,
      hasPendingChanges: row['has_pending'] == 1,
      serverTask: server,
      serverVersion: row['server_version'] as int?,
      isServerDeleted: row['server_deleted'] == 1,
    );
  }

  Future<LocalTaskRecord?> _find(DatabaseExecutor db, String id) async {
    final rows = await db.rawQuery(
      '$_recordSelect WHERE t.namespace=? AND t.task_id=?',
      [namespace, id],
    );
    return rows.isEmpty ? null : _record(rows.single);
  }

  TaskOutboxEntry _entry(Map<String, Object?> row) {
    final op = TaskSyncStorageMapper.fromJson(
      jsonDecode(row['operation_json'] as String),
    );
    if (op.operationId != row['operation_id'] ||
        op.taskId != row['task_id'] ||
        op.kind.name != row['kind'] ||
        op.baseVersion != row['base_version'] ||
        op.dependsOnOperationId != row['depends_on_operation_id'] ||
        op.queuedAt.millisecondsSinceEpoch != row['queued_at_ms']) {
      throw const FormatException('Outbox metadata mismatch.');
    }
    final retry = row['next_retry_at_ms'] as int?;
    return TaskOutboxEntry(
      sequence: row['sequence'] as int,
      namespace: row['namespace'] as String,
      operation: op,
      state: TaskOutboxStatus.values.byName(row['state'] as String),
      attemptCount: row['attempt_count'] as int,
      frozenRequestJson: row['frozen_request_json'] as String?,
      lastFailureCode: row['last_failure_code'] == null
          ? null
          : AppFailureCode.values.byName(row['last_failure_code'] as String),
      nextRetryAt: retry == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(retry, isUtc: true),
      acknowledgedVersion: row['ack_version'] as int?,
      acknowledgementJson: row['ack_response_json'] as String?,
    );
  }

  Future<Result<LocalTaskRecord?>> getById(
    String taskId, {
    bool includeDeleted = false,
  }) => _run(() async {
    final id = _id(taskId), db = await database.connection;
    final value = await _find(db, id);
    return value != null && value.isDeleted && !includeDeleted ? null : value;
  });

  /// Only known local records; this method makes no claim of server completeness.
  Future<Result<List<LocalTaskRecord>>> list(TaskQuery query) => _run(() async {
    final db = await database.connection;
    final rows = await db.rawQuery(
      '$_recordSelect WHERE t.namespace=? AND t.local_deleted=0',
      [namespace],
    );
    final search = query.searchText.toLowerCase();
    final result =
        rows.map(_record).where((record) {
          final t = record.task;
          return t.startAt.isBefore(query.end) &&
              t.endAt.isAfter(query.start) &&
              (query.status == null || t.status == query.status) &&
              (query.priority == null || t.priority == query.priority) &&
              t.title.toLowerCase().contains(search);
        }).toList()..sort((a, b) {
          final date = a.task.startAt.compareTo(b.task.startAt);
          return date != 0 ? date : a.task.id.compareTo(b.task.id);
        });
    return List<LocalTaskRecord>.unmodifiable(result);
  });
  Future<Result<List<TaskOutboxEntry>>> getOutbox({
    bool includeSynced = false,
  }) => _run(() async {
    final db = await database.connection;
    final rows = await db.query(
      'task_outbox',
      where: includeSynced ? 'namespace=?' : "namespace=? AND state<>'synced'",
      whereArgs: [namespace],
      orderBy: 'sequence ASC',
    );
    return List<TaskOutboxEntry>.unmodifiable(rows.map(_entry));
  });

  /// Stores a known server version; pending local projection is never overwritten.
  Future<Result<LocalTaskRecord>> saveServerSnapshot(
    Task task, {
    required int version,
  }) => _run(() async {
    if (version < 1) {
      throw const _StoreFailure(
        AppFailureCode.validation,
        'Phiên bản server phải lớn hơn 0.',
      );
    }
    final id = _id(task.id);
    final canonical = task.id == id ? task : _copy(task, id: id);
    final json = _validatedTaskJson(canonical);
    final db = await database.connection;
    return db.transaction((tx) async {
      final current = await _find(tx, id);
      if (current == null) {
        await tx.insert('tasks_local', {
          'namespace': namespace,
          'task_id': id,
          'local_json': json,
          'server_json': json,
          'server_version': version,
        });
      } else {
        if (current.isServerDeleted) {
          throw const _StoreFailure(
            AppFailureCode.conflict,
            'ID đã xóa trên server không được tái sử dụng.',
          );
        }
        if (current.serverVersion != null && version < current.serverVersion!) {
          return current;
        }
        if (current.serverVersion == version &&
            json != jsonEncode(TaskApiMapper.toJson(current.serverTask!))) {
          throw const _StoreFailure(
            AppFailureCode.conflict,
            'Cùng phiên bản nhưng nội dung server khác nhau.',
          );
        }
        final values = <String, Object?>{
          'server_json': json,
          'server_version': version,
          'server_deleted': 0,
        };
        if (!current.hasPendingChanges) {
          values.addAll({'local_json': json, 'local_deleted': 0});
        }
        await tx.update(
          'tasks_local',
          values,
          where: 'namespace=? AND task_id=?',
          whereArgs: [namespace, id],
        );
      }
      return (await _find(tx, id))!;
    });
  });

  /// Applies projection + inserts the immutable intent in ONE SQLite transaction.
  /// Re-enqueuing the identical operation is idempotent; changed content is a conflict.
  Future<Result<LocalTaskRecord>> enqueue(
    TaskSyncOperation operation,
  ) => _run(() async {
    final encoded = jsonEncode(TaskSyncStorageMapper.toJson(operation));
    try {
      TaskSyncStorageMapper.fromJson(jsonDecode(encoded));
    } catch (_) {
      throw const _StoreFailure(
        AppFailureCode.validation,
        'Nội dung thao tác không thể lưu hợp lệ.',
      );
    }
    final db = await database.connection;
    return db.transaction((tx) async {
      final duplicate = await tx.query(
        'task_outbox',
        where: 'namespace=? AND operation_id=?',
        whereArgs: [namespace, operation.operationId],
        limit: 1,
      );
      if (duplicate.isNotEmpty) {
        final old = _entry(duplicate.single);
        if (jsonEncode(TaskSyncStorageMapper.toJson(old.operation)) != encoded) {
          throw const _StoreFailure(
            AppFailureCode.conflict,
            'Mã thao tác đã được dùng cho nội dung khác.',
          );
        }
        return (await _find(tx, old.operation.taskId))!;
      }
      final current = await _find(tx, operation.taskId);
      final tailRows = await tx.query(
        'task_outbox',
        where: "namespace=? AND task_id=? AND state<>'synced'",
        whereArgs: [namespace, operation.taskId],
        orderBy: 'sequence DESC',
        limit: 1,
      );
      final tail = tailRows.isEmpty ? null : _entry(tailRows.single);
      if (operation.kind == TaskSyncKind.create) {
        if (current != null) {
          throw const _StoreFailure(
            AppFailureCode.conflict,
            'ID công việc đã tồn tại trên thiết bị.',
          );
        }
      } else {
        if (current == null) {
          throw const _StoreFailure(
            AppFailureCode.notFound,
            'Không tìm thấy công việc trên thiết bị.',
          );
        }
        if (current.isDeleted || current.isServerDeleted) {
          throw const _StoreFailure(
            AppFailureCode.conflict,
            'Công việc đã xóa hoặc đang chờ xóa.',
          );
        }
        if (tail != null) {
          if (tail.state == TaskOutboxStatus.conflict ||
              tail.state == TaskOutboxStatus.failed ||
              tail.operation.kind == TaskSyncKind.delete ||
              operation.dependsOnOperationId != tail.operation.operationId) {
            throw const _StoreFailure(
              AppFailureCode.conflict,
              'Thao tác mới phải chờ đúng thao tác trước của công việc.',
            );
          }
        } else if (operation.dependsOnOperationId != null ||
            current.serverVersion == null ||
            operation.baseVersion != current.serverVersion) {
          throw const _StoreFailure(
            AppFailureCode.conflict,
            'Phiên bản gốc không khớp dữ liệu local đã xác nhận.',
          );
        }
      }
      final projected = _apply(operation, current?.task);
      final projectionJson = _validatedTaskJson(projected);
      if (current == null) {
        await tx.insert('tasks_local', {
          'namespace': namespace,
          'task_id': operation.taskId,
          'local_json': projectionJson,
        });
      } else {
        await tx.update(
          'tasks_local',
          {
            'local_json': projectionJson,
            'local_deleted': operation.kind == TaskSyncKind.delete ? 1 : 0,
          },
          where: 'namespace=? AND task_id=?',
          whereArgs: [namespace, operation.taskId],
        );
      }
      // If this statement fails, SQLite rolls back the projection above as well.
      await tx.insert('task_outbox', {
        'namespace': namespace,
        'operation_id': operation.operationId,
        'task_id': operation.taskId,
        'kind': operation.kind.name,
        'operation_json': encoded,
        'base_version': operation.baseVersion,
        'depends_on_operation_id': operation.dependsOnOperationId,
        'queued_at_ms': operation.queuedAt.millisecondsSinceEpoch,
        'state': TaskOutboxStatus.pending.name,
      });
      return (await _find(tx, operation.taskId))!;
    });
  });
  String _validatedTaskJson(Task task) {
    final json = jsonEncode(TaskApiMapper.toJson(task));
    try {
      TaskApiMapper.fromJson(jsonDecode(json));
    } catch (_) {
      throw const _StoreFailure(
        AppFailureCode.validation,
        'Ngày giờ hoặc dữ liệu công việc không hợp lệ.',
      );
    }
    return json;
  }

  Task _apply(TaskSyncOperation op, Task? current) {
    if (op.kind == TaskSyncKind.create) {
      final draft = op.draft!;
      return Task(
        id: op.taskId,
        title: draft.title,
        description: draft.description,
        categoryId: draft.categoryId,
        startAt: draft.startAt,
        endAt: draft.endAt,
        priority: draft.priority,
        status: TaskStatus.pending,
        createdAt: op.queuedAt,
        updatedAt: op.queuedAt,
      );
    }
    final draft = op.draft;
    return Task(
      id: current!.id,
      title: draft?.title ?? current.title,
      description: draft == null ? current.description : draft.description,
      categoryId: draft == null ? current.categoryId : draft.categoryId,
      startAt: draft?.startAt ?? current.startAt,
      endAt: draft?.endAt ?? current.endAt,
      priority: draft?.priority ?? current.priority,
      status: op.status ?? current.status,
      createdAt: current.createdAt,
      updatedAt: op.queuedAt,
    );
  }

  Task _copy(Task task, {required String id}) => Task(
    id: id,
    title: task.title,
    description: task.description,
    categoryId: task.categoryId,
    startAt: task.startAt,
    endAt: task.endAt,
    priority: task.priority,
    status: task.status,
    createdAt: task.createdAt,
    updatedAt: task.updatedAt,
  );
}

class _StoreFailure implements Exception {
  const _StoreFailure(this.code, this.message);
  final AppFailureCode code;
  final String message;
}
