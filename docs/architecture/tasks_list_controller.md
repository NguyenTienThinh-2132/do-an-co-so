> Hiện trạng mới nhất: [Bàn giao Tasks chế độ ngày](tasks_handover.md) — 12/11/2026. Ghi chú dưới đây là lịch sử từng bước.

# Controller danh sách Công việc

## Đã triển khai

application/tasks_list_controller.dart dùng ChangeNotifier của Flutter SDK.
application/tasks_list_state.dart chứa snapshot bất biến:
initial, loading, ready (có thể rỗng), error kèm AppFailure.

Không thêm dependency, không tạo UI, không đổi repository/schema/router.
Controller nhận TaskRepository tại composition root; không tự tạo HTTP/SQL.

Ví dụ (repository là instance có sẵn được inject):

    final controller = TasksListController(repository: repository, query: query);
    controller.addListener(() {
      final state = controller.state;
      // UI sẽ hiển thị theo state.phase khi triển khai bước giao diện.
    });
    controller.load();          // tải lần đầu; constructor không tự tải
    controller.setQuery(query); // đổi ngày/bộ lọc, tự tải lại
    controller.retry();         // subscribe lại query hiện tại
    controller.dispose();       // chủ sở hữu gọi khi kết thúc vòng đời

Ví dụ liệt kê các lời gọi để minh họa; không gọi tất cả liên tiếp khi mở màn.
Không gọi dispose từ bên trong listener đang chạy notifyListeners:
tuân quy định vòng đời ChangeNotifier. Khi tích hợp widget, dispose tại
State.dispose của chủ sở hữu; không gọi load trong build.

Bên gọi tính start/end theo múi giờ đã chốt rồi tạo TaskQuery.
Controller không tự chọn timezone, không dùng DateTime.now để mặc định ngày.
Query được chuyển nguyên vẹn cho repository, không lọc/sắp xếp lần hai.

## Hành vi

- load/retry/setQuery chuyển loading và xóa snapshot cũ.
- Success chuyển ready; isEmpty chỉ true khi ready và không có task.
- Failure giữ nguyên AppFailure, không giữ dữ liệu cũ trong trạng thái lỗi.
- Stream exception/watch ném lỗi/stream đóng trước dữ liệu: unavailable an toàn.
- Stream đóng sau dữ liệu giữ snapshot cuối; retry để subscribe lại.
- Kết quả của subscription cũ không ghi đè query mới.
- dispose hủy subscription; không dispose repository hoặc đóng HTTP client.
- Chưa có timeout riêng; HttpTaskRepository dùng timeout của datasource.
- Chưa thêm create/update/delete, tiến độ ngày hoặc controller form.

## Kiểm tra ngày 07/11/2026

    flutter test test/unit/features/tasks/application/tasks_list_controller_test.dart
    flutter test
    flutter analyze

12 test controller: initial/loading/ready, empty/bất biến, cập nhật stream,
Failure/retry, đổi query/bỏ response cũ, giữ ranh giới UTC và bộ lọc,
exception, stream đóng, dispose và listener đổi query.
Toàn bộ 121 test Flutter đạt; analyze không có lỗi.
Kiểm tra bằng repository stub, chưa chạy controller với UI/backend/Android.
Bước tiếp theo dự kiến: nối controller với backend demo trên máy tính
hoặc nhận mẫu màn khung Công việc trước khi triển khai UI.
## Kiểm tra tích hợp controller với backend thật — 07/11/2026

File: test/integration/tasks_list_controller_real_test.dart.
Dùng flutter test (controller phụ thuộc Flutter foundation), không cần điện thoại.
Không dùng testWidgets hoặc mock HTTP cho phép thử này.

Chuẩn bị terminal backend (Docker Desktop đang mở, .env demo đã có):

    cd D:\git\do-an-co-so\backend
    & 'D:\Docker\resources\bin\docker.exe' compose up -d postgres
    npm run build
    npm run start:dev

Terminal khác:

    cd D:\git\do-an-co-so
    flutter test test/integration/tasks_list_controller_real_test.dart --dart-define=TV3_TASKS_API_BASE_URL=http://127.0.0.1:3000

Đầu ra mong đợi: 9 dòng PASS và All tests passed!
Test tạo fixture marker ngẫu nhiên, chờ listener (timeout 25 giây mỗi bước),
xác nhận rồi dọn đúng fixture trong finally và đọc lại rỗng.
Chỉ chấp nhận URL HTTP loopback 127.0.0.1 không credentials/query/fragment.
Không dùng với database chung; backend hiện có guard database demo TV3.
Nếu tiến trình bị kill hoặc backend ngừng giữa lúc dọn, cleanup có thể chưa xong.

Kết quả thực tế:
- initial -> loading -> ready empty.
- Tạo và sửa qua repository: controller nhận snapshot mới.
- Đổi trạng thái completed: controller nhận cập nhật.
- Query pending trả rỗng; chuyển ngày khác rồi quay lại đúng dữ liệu.
- retry phát loading rồi ready với dữ liệu thật.
- Xóa qua repository: controller về rỗng.
- Fixture cleanup verified.
- 1 test tích hợp đạt; dùng NestJS tạm trên cổng local trống, PostgreSQL demo thật.
  Backend tạm đã đóng sau khi thử, PostgreSQL demo được giữ chạy.
- flutter analyze không có lỗi.
- flutter test mặc định: 121 test đạt, 1 integration test được bỏ qua có lý do.

Test tích hợp tự skip nếu thiếu TV3_TASKS_API_BASE_URL để lệnh test mặc định
không phụ thuộc backend. Skip không có nghĩa là đã kiểm chứng tích hợp;
phải chạy lệnh có --dart-define phía trên để kiểm chứng lại.

Giới hạn:
- Chỉ ghi qua cùng instance HttpTaskRepository để kích hoạt stream cập nhật.
- retry được thử khi backend hoạt động, chưa phải thử mất mạng/phục hồi mạng.
- Chưa kiểm tra UI, Android, auth hoặc cập nhật đẩy đa thiết bị.
- Kết quả này bổ sung phép thử thật cho các unit test đã mô tả ở phần trước.
- Không đổi controller sản phẩm, interface, schema, dependency hoặc routing.

Bước UI tiếp theo cần nhận đúng mẫu màn khung Công việc từ người dùng;
chưa tự dựng màn thay thế hoặc tự thêm loading/empty/error vào mẫu.
