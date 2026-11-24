import 'task_priority.dart';

/// Dữ liệu nhập khi tạo hoặc sửa công việc.
///
/// ID, trạng thái và thời điểm tạo/cập nhật do repository quản lý.
/// Các thời điểm trong draft được chuẩn hóa sang UTC.
class TaskDraft {
  factory TaskDraft({
    required String title,
    String? description,
    String? categoryId,
    required DateTime startAt,
    required DateTime endAt,
    TaskPriority priority = TaskPriority.medium,
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

    return TaskDraft._(
      title: trimmedTitle,
      description: description,
      categoryId: categoryId,
      startAt: startAt.toUtc(),
      endAt: endAt.toUtc(),
      priority: priority,
    );
  }

  const TaskDraft._({
    required this.title,
    required this.description,
    required this.categoryId,
    required this.startAt,
    required this.endAt,
    required this.priority,
  });

  final String title;
  final String? description;
  final String? categoryId;
  final DateTime startAt;
  final DateTime endAt;
  final TaskPriority priority;
}
