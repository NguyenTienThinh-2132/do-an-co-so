import 'task_priority.dart';
import 'task_status.dart';

/// Công việc với các thời điểm được chuẩn hóa sang UTC.
class Task {
  factory Task({
    required String id,
    required String title,
    String? description,
    String? categoryId,
    required DateTime startAt,
    required DateTime endAt,
    required TaskPriority priority,
    required TaskStatus status,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw ArgumentError.value(
        title,
        'title',
        'Tên công việc không được rỗng.',
      );
    }
    if (!endAt.isAfter(startAt)) {
      throw ArgumentError.value(
        endAt,
        'endAt',
        'Thời điểm kết thúc phải sau thời điểm bắt đầu.',
      );
    }

    return Task._(
      id: id,
      title: trimmedTitle,
      description: description,
      categoryId: categoryId,
      startAt: startAt.toUtc(),
      endAt: endAt.toUtc(),
      priority: priority,
      status: status,
      createdAt: createdAt.toUtc(),
      updatedAt: updatedAt.toUtc(),
    );
  }

  const Task._({
    required this.id,
    required this.title,
    required this.description,
    required this.categoryId,
    required this.startAt,
    required this.endAt,
    required this.priority,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

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

  /// Tại đúng endAt chưa tính quá hạn; chỉ quá hạn khi now vượt endAt.
  bool isOverdueAt(DateTime now) {
    return status != TaskStatus.completed && endAt.isBefore(now);
  }
}
