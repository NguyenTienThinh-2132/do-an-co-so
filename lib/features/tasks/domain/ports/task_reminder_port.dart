import '../../../../core/types/result.dart';

class TaskReminder {
  TaskReminder({
    required this.taskId,
    required this.title,
    required DateTime triggerAt,
    this.fired = false,
    this.taskStartAt,
  }) : triggerAt = triggerAt.toUtc();
  final String taskId;
  final String title;
  final DateTime triggerAt;
  final bool fired;
  final DateTime? taskStartAt;
}

abstract interface class TaskReminderPort {
  Future<Result<bool>> canNotify();
  Future<Result<bool>> requestNotifications();
  Future<Result<bool>> canScheduleExact();
  Future<Result<void>> openExactAlarmSettings();
  Future<Result<void>> schedule(TaskReminder reminder);
  Future<Result<void>> cancel(String taskId);
  Future<Result<TaskReminder?>> getReminder(String taskId);
}
