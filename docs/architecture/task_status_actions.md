> Hiện trạng mới nhất: [Bàn giao Tasks chế độ ngày](tasks_handover.md) — 12/11/2026. Ghi chú dưới đây là lịch sử từng bước.

# Đổi trạng thái Công việc — 08/11/2026

## Đã triển khai

- TaskStatusController nhận TaskRepository được inject tại composition root.
- Mỗi ID có trạng thái đang ghi/lỗi riêng; không chặn công việc khác.
- Chặn gửi trùng khi cùng ID còn request đang chạy; không tự retry ghi.
- Menu ở biểu tượng tròn bên trái thẻ gồm Chờ xử lý, Đang làm, Đã xong.
- Mục tương ứng trạng thái hiện tại bị vô hiệu hóa.
- Khi ghi: vòng xoay thay menu và khóa nút sửa trên thẻ.
- UI không tự sửa task hoặc tăng tiến độ trước phản hồi.
- Repository thành công refresh stream; controller danh sách/tổng ngày dùng chung
  repository để nhận bản ghi và số liệu mới.
- Lỗi: giữ snapshot hiện tại, hiển thị thông báo trên thẻ và nút Thử lại;
  retry đúng ID/trạng thái đã yêu cầu lần gần nhất.
- NotFound có thông báo bản ghi đã xóa. Nếu bị xóa từ nguồn ngoài, thẻ có thể
  còn trong snapshot đến lần tải lại; chọn Hôm nay để tải lại danh sách.
- Dispose bỏ notify/response đến muộn; không dispose repository/client.

Đổi trạng thái có thể làm task rời bộ lọc hiện tại (ví dụ đang xem Đã xong
rồi chuyển thành Chờ xử lý). Đây là hành vi đúng theo query.
Không thêm action xóa, không sửa model/schema/router hoặc dependency.

## Người dùng tự kiểm tra

Tải lại http://127.0.0.1:3111 sau khi preview build hoàn tất:
1. Chọn Tất cả và mở một công việc có sẵn.
2. Bấm biểu tượng tròn trên thẻ để mở menu.
3. Chọn Đang làm: chờ lưu rồi thấy nhãn trạng thái đổi.
4. Chọn Đã xong: thấy gạch tên, biểu tượng hoàn thành và tiến độ tăng.
5. Chuyển về Chờ xử lý: tiến độ giảm đúng, task vẫn tồn tại.
6. Chọn bộ lọc Đã xong: chỉ còn task completed.
7. Nếu hiện lỗi, kiểm tra backend rồi bấm Thử lại trên đúng thẻ.

Controller không tạo nguồn dữ liệu thứ hai; state chỉ lưu request/lỗi.
Chặn bấm trùng trong lúc request chạy không phải cơ chế version/optimistic lock.
Chưa hỗ trợ cập nhật đẩy đa thiết bị hoặc tự phát hiện bản ghi bị xóa từ nơi khác.

## Kiểm tra

    flutter test test/unit/features/tasks/application/task_status_controller_test.dart test/widget/features/tasks/tasks_day_page_test.dart
    flutter test test/integration/task_status_controller_real_test.dart --dart-define=TV3_TASKS_API_BASE_URL=http://127.0.0.1:3111/api
    flutter analyze

Đã quan sát:
- 5 unit test controller: khóa ID, retry, độc lập giữa các ID, exception, dispose.
- 19 widget test màn ngày, gồm menu gửi đúng ID/trạng thái, giữ dữ liệu khi lỗi,
  retry và snapshot cập nhật. Tổng nhóm test liên quan: 24 test đạt.
- 1 integration test PostgreSQL thật đạt: cả ba trạng thái, stream toàn ngày
  và stream completed thêm/bớt đúng bản ghi, notFound khi bản ghi đã xóa.
- Fixture tích hợp marker ngẫu nhiên được dọn và assert đọc lại rỗng.
- flutter analyze không có lỗi.
- Chưa tự kiểm chứng thao tác UI trong Chrome hoặc chạy Android.
- Bản build web debug phục vụ xem thử; không phải build APK mới.
- Backend/API/schema không thay đổi; không commit/push.

Bước nhỏ tiếp theo dự kiến sau khi người dùng xác nhận: xóa có xác nhận.Kiểm tra toàn dự án: 156 test đạt, 4 test backend opt-in skip trong lượt không truyền URL; test đổi trạng thái với PostgreSQL thật đã được chạy riêng và đạt.
Preview web debug mới build thành công; trang và JavaScript qua server trả HTTP 200. Tải lại link 3111 để nhận bản menu trạng thái mới.
