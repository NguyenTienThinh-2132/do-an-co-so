import '../../../../core/types/app_failure.dart';
import 'task_outbox_status.dart';
import 'task_sync_operation.dart';

/// Durable queue row; operation intent is immutable, lifecycle changes later.
class TaskOutboxEntry {
  const TaskOutboxEntry({
    required this.sequence,
    required this.namespace,
    required this.operation,
    required this.state,
    required this.attemptCount,
    this.frozenRequestJson,
    this.lastFailureCode,
    this.nextRetryAt,
    this.acknowledgedVersion,
    this.acknowledgementJson,
  });
  final int sequence;
  final String namespace;
  final TaskSyncOperation operation;
  final TaskOutboxStatus state;
  final int attemptCount;
  final String? frozenRequestJson;
  final AppFailureCode? lastFailureCode;
  final DateTime? nextRetryAt;
  final int? acknowledgedVersion;
  final String? acknowledgementJson;
}
