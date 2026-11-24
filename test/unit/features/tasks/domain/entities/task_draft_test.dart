import 'package:finai/features/tasks/domain/entities/task_draft.dart';
import 'package:finai/features/tasks/domain/entities/task_priority.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime.utc(2026, 11, 5, 2);
  final end = DateTime.utc(2026, 11, 5, 3);

  test('Trim tên, cho phép bỏ trống và mặc định ưu tiên medium', () {
    final draft = TaskDraft(
      title: '  Viết báo cáo  ',
      startAt: start,
      endAt: end,
    );
    expect(draft.title, 'Viết báo cáo');
    expect(draft.description, isNull);
    expect(draft.categoryId, isNull);
    expect(draft.priority, TaskPriority.medium);
  });

  test('Giữ mô tả, danh mục và mức ưu tiên được truyền vào', () {
    final draft = TaskDraft(
      title: 'Viết báo cáo',
      description: 'Báo cáo tuần',
      categoryId: 'category-study',
      startAt: start,
      endAt: end,
      priority: TaskPriority.high,
    );
    expect(draft.description, 'Báo cáo tuần');
    expect(draft.categoryId, 'category-study');
    expect(draft.priority, TaskPriority.high);
  });

  test('Từ chối tên rỗng hoặc chỉ có khoảng trắng', () {
    for (final title in ['', '  \t\n']) {
      expect(
        () => TaskDraft(title: title, startAt: start, endAt: end),
        throwsArgumentError,
      );
    }
  });

  test('Từ chối kết thúc bằng hoặc trước bắt đầu', () {
    for (final invalidEnd in [
      start,
      start.subtract(const Duration(minutes: 1)),
    ]) {
      expect(
        () =>
            TaskDraft(title: 'Viết báo cáo', startAt: start, endAt: invalidEnd),
        throwsArgumentError,
      );
    }
  });

  test('Chuẩn hóa thời điểm sang UTC và giữ nguyên thời điểm', () {
    final draft = TaskDraft(
      title: 'Kiểm tra giờ',
      startAt: start.toLocal(),
      endAt: end.toLocal(),
    );
    expect(draft.startAt, start);
    expect(draft.endAt, end);
    expect(draft.startAt.isUtc, isTrue);
    expect(draft.endAt.isUtc, isTrue);
  });
}
