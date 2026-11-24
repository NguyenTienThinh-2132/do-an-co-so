import '../entities/task.dart';
import '../entities/task_priority.dart';
import '../entities/task_status.dart';

/// Bản dữ liệu chỉ đọc trao đổi giữa các module; mọi thời điểm là UTC.
final class TaskDto {
  TaskDto.fromTask(Task task)
    : id = task.id,
      title = task.title,
      description = task.description,
      categoryId = task.categoryId,
      startAt = task.startAt,
      endAt = task.endAt,
      priority = task.priority,
      status = task.status,
      createdAt = task.createdAt,
      updatedAt = task.updatedAt;

  final String id;
  final String title;
  final String? description;
  final String? categoryId;
  final DateTime startAt;
  final DateTime endAt;
  final TaskPriority priority;
  final TaskStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
}
