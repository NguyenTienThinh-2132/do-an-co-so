import 'app_failure.dart';

/// Kết quả thành công hoặc thất bại được trả tường minh cho bên gọi.
///
/// Không tự bắt exception; bên thực thi chuyển lỗi thành Failure khi phù hợp.
sealed class Result<T> {
  const Result();
}

/// Kết quả thành công chứa dữ liệu kiểu T.
///
/// Với thao tác không trả dữ liệu, dùng [Success] với kiểu void và giá trị null.
final class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;
}

/// Kết quả thất bại chứa lỗi đã được chuyển đổi cho bên gọi.
final class Failure<T> extends Result<T> {
  const Failure(this.failure);

  final AppFailure failure;
}
