import 'package:finai/core/types/app_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Tạo lỗi với mã và thông báo để bên gọi đọc', () {
    const failure = AppFailure(
      code: AppFailureCode.notFound,
      message: 'Không tìm thấy công việc.',
    );

    expect(failure.code, AppFailureCode.notFound);
    expect(failure.message, 'Không tìm thấy công việc.');
  });

  test('Các nhóm lỗi đã chốt đều biểu diễn được bằng AppFailure', () {
    for (final code in AppFailureCode.values) {
      final failure = AppFailure(code: code, message: 'Thông báo lỗi');
      expect(failure.code, code);
    }
  });
}
