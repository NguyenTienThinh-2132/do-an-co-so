import '../../../../core/types/result.dart';
import '../entities/task_query.dart';
import 'task_dto.dart';

/// Public port chỉ đọc, không cấp quyền ghi cho module sử dụng.
///
/// Đọc một lần theo quy tắc lọc/sắp xếp của TaskQuery.
/// Danh sách rỗng trả Success; lỗi hạ tầng trả Failure.
/// Danh sách kết quả không cho phép sửa.
abstract interface class TaskReader {
  Future<Result<List<TaskDto>>> getTasks(TaskQuery query);
}
