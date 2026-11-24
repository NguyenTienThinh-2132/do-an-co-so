/// Các nhóm lỗi dùng chung giữa các module.
enum AppFailureCode {
  validation,
  notFound,
  conflict,
  permissionDenied,
  unavailable,
}

/// Mô tả lỗi nghiệp vụ hoặc hạ tầng đã được chuyển đổi cho bên gọi.
///
/// Đây là dữ liệu lỗi, không phải exception tự động được ném hoặc bắt.
/// Không đưa SQL, khóa bí mật hay thông tin nhạy cảm vào message.
class AppFailure {
  const AppFailure({required this.code, required this.message});

  final AppFailureCode code;
  final String message;
}
