import '../../../core/types/app_failure.dart';
import '../../../core/types/result.dart';
import '../domain/entities/task.dart';
import '../domain/entities/task_query.dart';
import '../domain/ports/task_dto.dart';
import '../domain/ports/task_reader.dart';
import '../domain/repositories/task_repository.dart';

/// Chỉ composition root cần biết adapter này và repository cụ thể.
final class RepositoryTaskReader implements TaskReader {
  RepositoryTaskReader({required this.repository});

  final TaskRepository repository;

  @override
  Future<Result<List<TaskDto>>> getTasks(TaskQuery query) async {
    try {
      // first tự hủy subscription sau sự kiện đầu tiên.
      final result = await repository.watch(query).first;
      return switch (result) {
        Success<List<Task>>(:final value) => Success(
          List<TaskDto>.unmodifiable(value.map(TaskDto.fromTask)),
        ),
        Failure<List<Task>>(:final failure) => Failure(failure),
      };
    } catch (_) {
      // Stream lỗi hoặc đóng trước dữ liệu: không để exception hạ tầng thoát ra.
      return const Failure(
        AppFailure(
          code: AppFailureCode.unavailable,
          message: 'Không thể đọc danh sách công việc.',
        ),
      );
    }
  }
}
