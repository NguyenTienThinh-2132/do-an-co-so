import '../entities/task.dart';

/// Local projection and the latest confirmed server baseline are separate.
class LocalTaskRecord {
  const LocalTaskRecord({
    required this.namespace,
    required this.task,
    required this.isDeleted,
    required this.hasPendingChanges,
    this.serverTask,
    this.serverVersion,
    this.isServerDeleted = false,
  });
  final String namespace;
  final Task task;
  final bool isDeleted;
  final bool hasPendingChanges;
  final Task? serverTask;
  final int? serverVersion;
  final bool isServerDeleted;
}
