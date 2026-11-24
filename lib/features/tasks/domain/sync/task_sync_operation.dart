import '../entities/task_draft.dart';
import '../entities/task_status.dart';

enum TaskSyncKind { create, update, setStatus, delete }

/// Immutable intent. This model does not persist or send anything by itself.
/// Client-generated UUID task IDs stay the same before and after sync.
class TaskSyncOperation {
  factory TaskSyncOperation.create({
    required String operationId,
    required String taskId,
    required TaskDraft draft,
    required DateTime queuedAt,
  }) => _build(
    operationId: operationId,
    taskId: taskId,
    kind: TaskSyncKind.create,
    queuedAt: queuedAt,
    draft: draft,
  );

  factory TaskSyncOperation.update({
    required String operationId,
    required String taskId,
    required TaskDraft draft,
    required DateTime queuedAt,
    int? baseVersion,
    String? dependsOnOperationId,
  }) => _build(
    operationId: operationId,
    taskId: taskId,
    kind: TaskSyncKind.update,
    queuedAt: queuedAt,
    draft: draft,
    baseVersion: baseVersion,
    dependsOnOperationId: dependsOnOperationId,
  );

  factory TaskSyncOperation.setStatus({
    required String operationId,
    required String taskId,
    required TaskStatus status,
    required DateTime queuedAt,
    int? baseVersion,
    String? dependsOnOperationId,
  }) => _build(
    operationId: operationId,
    taskId: taskId,
    kind: TaskSyncKind.setStatus,
    queuedAt: queuedAt,
    status: status,
    baseVersion: baseVersion,
    dependsOnOperationId: dependsOnOperationId,
  );

  factory TaskSyncOperation.delete({
    required String operationId,
    required String taskId,
    required DateTime queuedAt,
    int? baseVersion,
    String? dependsOnOperationId,
  }) => _build(
    operationId: operationId,
    taskId: taskId,
    kind: TaskSyncKind.delete,
    queuedAt: queuedAt,
    baseVersion: baseVersion,
    dependsOnOperationId: dependsOnOperationId,
  );

  const TaskSyncOperation._({
    required this.operationId,
    required this.taskId,
    required this.kind,
    required this.queuedAt,
    this.draft,
    this.status,
    this.baseVersion,
    this.dependsOnOperationId,
  });

  final String operationId;
  final String taskId;
  final TaskSyncKind kind;

  /// Local bookkeeping only; never used for last-write-wins conflict handling.
  final DateTime queuedAt;
  final TaskDraft? draft;
  final TaskStatus? status;

  /// Last acknowledged server version. Create has no base version.
  final int? baseVersion;

  /// An earlier operation on the same task whose acknowledgement is needed.
  final String? dependsOnOperationId;

  bool get isReadyToSend => kind == TaskSyncKind.create || baseVersion != null;

  /// Resolve once, before the first attempt; the queue must persist the resolved
  /// request before sending. Never change an already attempted request body.
  TaskSyncOperation resolveDependency({
    required String acknowledgedOperationId,
    required String acknowledgedTaskId,
    required int serverVersion,
  }) {
    if (dependsOnOperationId == null || isReadyToSend) {
      throw StateError('Operation has no unresolved dependency.');
    }
    if (_uuid(acknowledgedOperationId) != dependsOnOperationId ||
        _uuid(acknowledgedTaskId) != taskId) {
      throw ArgumentError(
        'Acknowledgement does not match the dependency/task.',
      );
    }
    return _build(
      operationId: operationId,
      taskId: taskId,
      kind: kind,
      queuedAt: queuedAt,
      draft: draft,
      status: status,
      baseVersion: serverVersion,
    );
  }

  static TaskSyncOperation _build({
    required String operationId,
    required String taskId,
    required TaskSyncKind kind,
    required DateTime queuedAt,
    TaskDraft? draft,
    TaskStatus? status,
    int? baseVersion,
    String? dependsOnOperationId,
  }) {
    final id = _uuid(operationId);
    final target = _uuid(taskId);
    final dependency = dependsOnOperationId == null
        ? null
        : _uuid(dependsOnOperationId);
    if (baseVersion != null && baseVersion < 1) {
      throw ArgumentError('Server version must be positive.');
    }
    if (kind != TaskSyncKind.create &&
        ((baseVersion == null) == (dependency == null))) {
      throw ArgumentError(
        'Specify a base version OR an unresolved dependency.',
      );
    }
    if (dependency == id) {
      throw ArgumentError('An operation cannot depend on itself.');
    }
    return TaskSyncOperation._(
      operationId: id,
      taskId: target,
      kind: kind,
      queuedAt: queuedAt.toUtc(),
      draft: draft,
      status: status,
      baseVersion: baseVersion,
      dependsOnOperationId: dependency,
    );
  }

  static final _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$',
  );
  static String _uuid(String value) {
    if (value.length != 36 || !_uuidPattern.hasMatch(value)) {
      throw ArgumentError('Expected a UUID.');
    }
    return value.toLowerCase();
  }
}
