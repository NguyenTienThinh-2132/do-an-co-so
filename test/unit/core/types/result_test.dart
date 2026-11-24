import 'package:finai/core/types/app_failure.dart';
import 'package:finai/core/types/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String describe(Result<int> result) {
    return switch (result) {
      Success<int>(:final value) => 'Giá trị: $value',
      Failure<int>(:final failure) => failure.message,
    };
  }

  test('Success mang dữ liệu và được xử lý qua Result', () {
    const Result<int> result = Success<int>(42);
    expect(describe(result), 'Giá trị: 42');
  });

  test('Failure giữ nguyên AppFailure và được xử lý qua Result', () {
    const failure = AppFailure(
      code: AppFailureCode.notFound,
      message: 'Không tìm thấy công việc.',
    );
    const result = Failure<int>(failure);
    expect(result.failure, same(failure));
    expect(describe(result), 'Không tìm thấy công việc.');
  });

  test('Success phân biệt dữ liệu nullable hợp lệ với Failure', () {
    const Result<String?> result = Success<String?>(null);
    final isSuccess = switch (result) {
      Success<String?>(:final value) => value == null,
      Failure<String?>() => false,
    };
    expect(isSuccess, isTrue);
  });

  test('Result<void> biểu diễn thao tác thành công không có dữ liệu', () {
    const Result<void> result = Success<void>(null);
    final succeeded = switch (result) {
      Success<void>() => true,
      Failure<void>() => false,
    };
    expect(succeeded, isTrue);
  });

  test('Result<void> cũng có thể thất bại', () {
    const failure = AppFailure(
      code: AppFailureCode.unavailable,
      message: 'Không thể lưu thay đổi.',
    );
    const Result<void> result = Failure<void>(failure);
    final code = switch (result) {
      Success<void>() => null,
      Failure<void>(:final failure) => failure.code,
    };
    expect(code, AppFailureCode.unavailable);
  });
}
