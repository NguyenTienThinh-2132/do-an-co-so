import 'package:finai/features/tasks/domain/entities/task_priority.dart';
import 'package:finai/features/tasks/domain/entities/task_query.dart';
import 'package:finai/features/tasks/domain/entities/task_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime.utc(2026, 11, 4, 17);
  final end = DateTime.utc(2026, 11, 5, 17);

  test('Mặc định không lọc trạng thái, ưu tiên và tên', () {
    final query = TaskQuery(start: start, end: end);
    expect(query.status, isNull);
    expect(query.priority, isNull);
    expect(query.searchText, isEmpty);
  });

  test('Trim từ khóa, giữ nguyên dấu và hoa thường của đầu vào', () {
    final query = TaskQuery(start: start, end: end, searchText: '  BÁO CÁO  ');
    expect(query.searchText, 'BÁO CÁO');
  });

  test('Từ khóa chỉ có khoảng trắng trở thành không lọc tên', () {
    final query = TaskQuery(start: start, end: end, searchText: '  \t\n');
    expect(query.searchText, isEmpty);
  });

  test('Giữ đồng thời điều kiện trạng thái và mức ưu tiên', () {
    final query = TaskQuery(
      start: start,
      end: end,
      status: TaskStatus.pending,
      priority: TaskPriority.high,
      searchText: 'báo cáo',
    );
    expect(query.status, TaskStatus.pending);
    expect(query.priority, TaskPriority.high);
    expect(query.searchText, 'báo cáo');
  });

  test('Từ chối cuối khoảng bằng hoặc trước đầu khoảng', () {
    for (final invalidEnd in [
      start,
      start.subtract(const Duration(microseconds: 1)),
    ]) {
      expect(
        () => TaskQuery(start: start, end: invalidEnd),
        throwsArgumentError,
      );
    }
  });

  test('Chuẩn hóa UTC và giữ nguyên hai thời điểm ranh giới', () {
    final query = TaskQuery(start: start.toLocal(), end: end.toLocal());
    expect(query.start, start);
    expect(query.end, end);
    expect(query.start.isUtc, isTrue);
    expect(query.end.isUtc, isTrue);
  });
}
