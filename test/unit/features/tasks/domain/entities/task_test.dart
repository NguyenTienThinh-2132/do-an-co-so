import 'package:finai/features/tasks/domain/entities/task.dart';
import 'package:finai/features/tasks/domain/entities/task_priority.dart';
import 'package:finai/features/tasks/domain/entities/task_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime.utc(2026, 11, 5, 2);
  final end = DateTime.utc(2026, 11, 5, 3);

  Task createTask({
    String title = 'Viết báo cáo',
    TaskStatus status = TaskStatus.pending,
    DateTime? startAt,
    DateTime? endAt,
  }) {
    return Task(
      id: 'task-01',
      title: title,
      startAt: startAt ?? start,
      endAt: endAt ?? end,
      priority: TaskPriority.high,
      status: status,
      createdAt: start,
      updatedAt: start,
    );
  }

  test('Trim tên và cho phép bỏ trống mô tả, danh mục', () {
    final task = createTask(title: '  Viết báo cáo  ');
    expect(task.title, 'Viết báo cáo');
    expect(task.description, isNull);
    expect(task.categoryId, isNull);
    expect(task.priority, TaskPriority.high);
  });

  test('Từ chối tên rỗng hoặc chỉ có khoảng trắng', () {
    for (final title in ['', '  \t\n']) {
      expect(() => createTask(title: title), throwsArgumentError);
    }
  });

  test('Từ chối kết thúc bằng hoặc trước bắt đầu', () {
    for (final invalidEnd in [
      start,
      start.subtract(const Duration(minutes: 1)),
    ]) {
      expect(() => createTask(endAt: invalidEnd), throwsArgumentError);
    }
  });

  test('Chuẩn hóa cả bốn thời điểm sang UTC, giữ nguyên thời điểm', () {
    final localStart = start.toLocal();
    final localEnd = end.toLocal();
    final task = Task(
      id: 'task-02',
      title: 'Kiểm tra giờ',
      startAt: localStart,
      endAt: localEnd,
      priority: TaskPriority.low,
      status: TaskStatus.pending,
      createdAt: localStart,
      updatedAt: localEnd,
    );
    expect(task.startAt, start);
    expect(task.endAt, end);
    expect(task.createdAt, start);
    expect(task.updatedAt, end);
    for (final value in [
      task.startAt,
      task.endAt,
      task.createdAt,
      task.updatedAt,
    ]) {
      expect(value.isUtc, isTrue);
    }
  });

  test('Pending và inProgress chỉ quá hạn sau endAt', () {
    for (final status in [TaskStatus.pending, TaskStatus.inProgress]) {
      final task = createTask(status: status);
      expect(task.isOverdueAt(start), isFalse);
      expect(task.isOverdueAt(end), isFalse);
      expect(
        task.isOverdueAt(end.add(const Duration(microseconds: 1))),
        isTrue,
      );
    }
  });

  test('Completed không quá hạn dù đã qua endAt', () {
    final task = createTask(status: TaskStatus.completed);
    expect(task.isOverdueAt(end.add(const Duration(days: 1))), isFalse);
  });
}
