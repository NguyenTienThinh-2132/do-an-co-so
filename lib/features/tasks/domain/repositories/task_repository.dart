import '../../../../core/types/result.dart';
import '../entities/task.dart';
import '../entities/task_draft.dart';
import '../entities/task_query.dart';
import '../entities/task_status.dart';

/// Hợp đồng lưu trữ công việc; không phụ thuộc Flutter hoặc SQLite.
///
/// Lỗi lưu trữ phải được chuyển thành [Failure], không để lỗi SQL thoát
/// trực tiếp tới bên gọi. Không tồn tại ID trả Failure với code notFound.
abstract interface class TaskRepository {
  /// Phát danh sách ban đầu, rồi cập nhật sau thay đổi liên quan.
  ///
  /// Tuân quy tắc lọc và sắp xếp của [TaskQuery].
  /// Danh sách rỗng là Success, không phải Failure.
  /// Bên gọi hủy subscription khi không còn sử dụng.
  Stream<Result<List<Task>>> watch(TaskQuery query);

  /// Đọc một công việc theo ID; không tồn tại trả lỗi notFound.
  Future<Result<Task>> getById(String id);

  /// Cấp ID, trạng thái pending và thời điểm tạo/cập nhật cho công việc mới.
  Future<Result<Task>> create(TaskDraft draft);

  /// Thay nội dung từ draft và cập nhật updatedAt.
  ///
  /// Giữ nguyên id, status và createdAt; không tồn tại trả lỗi notFound.
  Future<Result<Task>> update(String id, TaskDraft draft);

  /// Đổi trạng thái và cập nhật updatedAt; không tồn tại trả lỗi notFound.
  Future<Result<Task>> setStatus(String id, TaskStatus status);

  /// Xóa công việc; không tồn tại trả lỗi notFound.
  ///
  /// Thành công trả Success với kiểu void và giá trị null.
  Future<Result<void>> delete(String id);
}
