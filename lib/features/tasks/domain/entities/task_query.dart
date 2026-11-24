import 'task_priority.dart';
import 'task_status.dart';

/// Điều kiện lấy danh sách công việc; mọi thời điểm được chuẩn hóa sang UTC.
///
/// Khoảng truy vấn là [start, end). Công việc được chọn khi:
/// task.startAt < end và task.endAt > start.
/// Các bộ lọc kết hợp bằng AND; status/priority null nghĩa là không lọc.
///
/// searchText tìm chuỗi con trong tên, không phân biệt hoa/thường nhưng có
/// phân biệt dấu. Chuỗi rỗng nghĩa là không lọc theo tên.
///
/// Bên thực thi phải sắp xếp startAt tăng dần, sau đó id tăng dần.
/// Bên gọi tính ranh giới ngày theo múi giờ đã cấu hình trước khi tạo query.
class TaskQuery {
  factory TaskQuery({
    required DateTime start,
    required DateTime end,
    TaskStatus? status,
    TaskPriority? priority,
    String searchText = '',
  }) {
    if (!end.isAfter(start)) {
      throw ArgumentError.value(
        end,
        'end',
        'Cuối khoảng truy vấn phải sau đầu khoảng.',
      );
    }

    return TaskQuery._(
      start: start.toUtc(),
      end: end.toUtc(),
      status: status,
      priority: priority,
      searchText: searchText.trim(),
    );
  }

  const TaskQuery._({
    required this.start,
    required this.end,
    required this.status,
    required this.priority,
    required this.searchText,
  });

  final DateTime start;
  final DateTime end;
  final TaskStatus? status;
  final TaskPriority? priority;
  final String searchText;
}
