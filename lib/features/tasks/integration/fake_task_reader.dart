import '../../../core/types/result.dart';
import '../domain/entities/task.dart';
import '../domain/entities/task_priority.dart';
import '../domain/entities/task_query.dart';
import '../domain/entities/task_status.dart';
import '../domain/ports/task_dto.dart';
import '../domain/ports/task_reader.dart';

/// Fake chỉ đọc; không phụ thuộc đồng hồ, mạng hoặc dữ liệu tài chính.
///
/// Fixture mặc định cố định ngày 07/11/2026 UTC, không seed vào database.
/// Có thể inject fixture để kiểm tra các tình huống khác.
final class FakeTaskReader implements TaskReader {
  FakeTaskReader({Iterable<TaskDto>? fixtures})
    : _fixtures = List<TaskDto>.unmodifiable(fixtures ?? defaultFixtures);

  final List<TaskDto> _fixtures;

  static final List<TaskDto> defaultFixtures = List<TaskDto>.unmodifiable([
    _task('demo-task-2', 'Kiểm tra module Công việc', 9, TaskStatus.inProgress),
    _task('demo-task-1', 'Đọc tài liệu Flutter', 9, TaskStatus.pending),
    _task('demo-task-3', 'Ghi chú khảo sát Native', 14, TaskStatus.completed),
  ]);

  static TaskDto _task(String id, String title, int hour, TaskStatus status) {
    final created = DateTime.utc(2026, 11, 6);
    return TaskDto.fromTask(
      Task(
        id: id,
        title: title,
        startAt: DateTime.utc(2026, 11, 7, hour),
        endAt: DateTime.utc(2026, 11, 7, hour + 1),
        priority: TaskPriority.medium,
        status: status,
        createdAt: created,
        updatedAt: created,
      ),
    );
  }

  @override
  Future<Result<List<TaskDto>>> getTasks(TaskQuery query) async {
    final search = query.searchText.toLowerCase();
    final matches =
        _fixtures.where((task) {
          return task.startAt.isBefore(query.end) &&
              task.endAt.isAfter(query.start) &&
              (query.status == null || task.status == query.status) &&
              (query.priority == null || task.priority == query.priority) &&
              task.title.toLowerCase().contains(search);
        }).toList()..sort((a, b) {
          final byStart = a.startAt.compareTo(b.startAt);
          return byStart != 0 ? byStart : a.id.compareTo(b.id);
        });
    return Success(List<TaskDto>.unmodifiable(matches));
  }
}
