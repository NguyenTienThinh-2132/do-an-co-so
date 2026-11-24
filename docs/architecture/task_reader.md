> Hiện trạng mới nhất: [Bàn giao Tasks chế độ ngày](tasks_handover.md) — 12/11/2026. Ghi chú dưới đây là lịch sử từng bước.

# TaskReader TV3

Hợp đồng đã được duyệt trong bước này, chưa có xác nhận tích hợp toàn nhóm.
Không thay đổi TaskRepository, schema, dependency hay routing.

## Vai trò

- domain/ports/task_reader.dart: quyền đọc danh sách một lần.
- domain/ports/task_dto.dart: bản sao bất biến đủ 11 trường Task, thời gian UTC.
- integration/repository_task_reader.dart: nhận TaskRepository qua constructor,
  lấy sự kiện đầu của watch rồi tự hủy subscription; không đóng repository/client.
- integration/fake_task_reader.dart: fixture cố định ngày 07/11/2026 UTC;
  không ghi database, không dùng đồng hồ hệ thống hay mạng.

getTasks trả Future<Result<List<TaskDto>>>. Danh sách kết quả không sửa được.
Rỗng là Success([]). Adapter giữ nguyên AppFailure từ repository;
stream lỗi/đóng trước dữ liệu chuyển unavailable với thông báo an toàn.
Không tự retry. Nếu repository tùy chỉnh không bao giờ phát/đóng stream,
lời gọi sẽ chờ; HttpTaskRepository hiện dùng timeout của datasource.

## Quy tắc chung

Giữ TaskQuery hiện tại:
- Chọn task khi startAt < query.end và endAt > query.start.
- AND trạng thái, ưu tiên và tìm tên; null không lọc.
- Tên tìm chuỗi con, trim query, không phân biệt hoa thường, có phân biệt dấu.
- Ký tự % và _ được tìm theo nghĩa literal.
- Sắp xếp startAt tăng dần rồi id tăng dần.
- Bên gọi tính ranh giới ngày theo múi giờ đã chọn rồi chuyển UTC.
  Không dùng ngày UTC mặc định thay cho ngày địa phương của người dùng.

Adapter tin repository tuân hợp đồng lọc/sắp xếp, không lọc lần hai.
Fake chỉ mô phỏng và không phải nguồn dữ liệu thật.

## Ví dụ gọi

Module sử dụng chỉ import hợp đồng và kiểu domain/core liên quan:

    import 'package:finai/core/types/result.dart';
    import 'package:finai/features/tasks/domain/entities/task_query.dart';
    import 'package:finai/features/tasks/domain/ports/task_dto.dart';
    import 'package:finai/features/tasks/domain/ports/task_reader.dart';

    Future<List<TaskDto>> readDemoDay(TaskReader reader) async {
      final result = await reader.getTasks(TaskQuery(
        start: DateTime.utc(2026, 11, 7),
        end: DateTime.utc(2026, 11, 8),
      ));
      return switch (result) {
        Success<List<TaskDto>>(:final value) => value,
        Failure<List<TaskDto>>(:final failure) =>
          throw StateError(failure.message),
      };
    }

Ví dụ trên đưa lỗi lên bên gọi; controller sản phẩm nên chuyển Failure thành
trạng thái lỗi phù hợp thay vì ném lỗi vào widget.

Chỉ composition root import implementation và chọn đúng một binding:

    final TaskReader reader = FakeTaskReader();
    // Khi nối thật, thay binding trên bằng:
    // final TaskReader reader =
    //     RepositoryTaskReader(repository: existingTaskRepository);

existingTaskRepository là instance được inject/khởi tạo sẵn tại composition root.
Không khởi tạo repository trong widget, không import integration từ module AI.
Chủ sở hữu repository/client vẫn chịu trách nhiệm dispose/close.
Chưa sửa composition root hoặc tạo controller/UI trong bước này.

## Kiểm tra

Từ D:\git\do-an-co-so:

    flutter test test/unit/features/tasks/integration/task_reader_test.dart
    flutter test
    flutter analyze

15 test mới:
- 9 trường hợp đối chiếu fake và adapter nối HttpTaskRepository + HTTP mock.
  Mock trả đáp án kỳ vọng độc lập và kiểm tra query gửi đi.
- Kiểm tra đủ trường DTO, danh sách bất biến, UTC.
- Failure giữ nguyên, hủy subscription, chỉ nhận sự kiện đầu.
- Stream rỗng/lỗi, fixture mặc định ổn định và sao chép fixture đầu vào.

Đây là bằng chứng unit/HTTP mock; không khẳng định TaskReader đã kiểm tra
với PostgreSQL thật hoặc chạy trên Android. Kiểm tra backend hiện có của bước
trước không thay thế phép thử tích hợp TaskReader mới này.
Không triển khai Assistant, UI, Native hoặc schema module khác.
Kết quả 07/11/2026: 15 test TaskReader đạt; toàn bộ 109 test Flutter đạt; flutter analyze không có lỗi.

## Kiểm tra backend thật trên máy tính — 07/11/2026

Đã bổ sung:
- tool/check_task_reader.dart: tạo 6 fixture với marker ngẫu nhiên riêng;
  đối chiếu TaskReader thật và fake trên cùng dữ liệu, rồi dọn bằng marker.
- backend/scripts/check-task-reader.mjs: khởi động NestJS trên cổng loopback
  trống, chạy tool Dart và đóng backend tạm khi xong. Không đổi cổng app chính.

Cách chạy (Docker Desktop phải hoạt động; .env demo đã có):

    cd D:\git\do-an-co-so\backend
    & 'D:\Docker\resources\bin\docker.exe' compose up -d postgres
    npm run build
    $env:DART_EXECUTABLE = 'D:\Flutter\3.47.7\flutter\bin\cache\dart-sdk\bin\dart.exe'
    node scripts/check-task-reader.mjs

Nếu Node/npm chưa có trong PATH, dùng D:\nodejs\npm.cmd và D:\nodejs\node.exe.
Script sử dụng DATABASE_URL demo hiện có; không in connection string.
Nếu dart đã có trong PATH thì không cần DART_EXECUTABLE.
Không dùng dart.bat cho biến này vì runner spawn trực tiếp executable trên Windows.

Kết quả mong đợi và đã quan sát trên database PostgreSQL demo thật:
- 9 PASS cho overlap/biên khoảng, tie-break id, trạng thái, ưu tiên,
  trim/hoa thường, phân biệt dấu, ký tự literal, AND, rỗng và offset UTC
  (overlap và tie-break gộp trong một trường hợp).
- PASS: fresh read after mutation.
- PASS: fixture cleanup verified.
- TASK_READER_REAL_RESULT: PASS, exit code 0.
- Kiểm tra đủ 11 trường DTO fake/real, không chỉ so ID.
- flutter analyze: No issues found.

Kết quả này bổ sung bằng chứng backend thật cho giới hạn unit test ở phần trước.
Không khẳng định đã chạy trên Android. Chưa test auth, mất mạng,
lưu sau restart hoặc cập nhật đa thiết bị bằng tool TaskReader này.

Tool chỉ chấp nhận HTTP 127.0.0.1; backend factory tiếp tục giới hạn database
finai_tv3_demo ở 127.0.0.1:5433. Không seed dữ liệu cố định vào database.
Dọn fixture được chạy trong finally và kiểm tra đọc lại rỗng. Nếu tiến trình bị
force kill/máy tắt hoặc backend mất kết nối, cleanup có thể không hoàn tất:
không tự xóa các marker của lần chạy khác và không báo thành công khi cleanup lỗi.
Không có thay đổi UI, schema, dependency, routing hoặc module khác.
