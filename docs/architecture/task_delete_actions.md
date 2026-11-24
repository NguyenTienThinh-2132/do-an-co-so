> Hiện trạng mới nhất: [Bàn giao Tasks chế độ ngày](tasks_handover.md) — 12/11/2026. Ghi chú dưới đây là lịch sử từng bước.

# Xóa Công việc có xác nhận — 08/11/2026

## Triển khai

- TaskDeleteController được inject cùng TaskRepository tại composition root.
- Mỗi ID có trạng thái đang xóa/lỗi riêng; chặn gửi trùng cùng ID.
- Nút thùng rác cạnh sửa mở AlertDialog có tên công việc, Hủy và Xóa.
- Hủy/bấm ngoài/back đóng dialog không gọi delete.
- Dialog có scrollable để tên dài không tràn ở màn nhỏ.
- Chỉ confirmed == true và thẻ vẫn mounted/không bận mới gọi controller.delete.
- Khi đang xóa: biểu tượng tròn hiển thị vòng xoay, khóa sửa/status/xóa trên thẻ.
- Không tự ẩn task trước phản hồi. Thành công qua repository refresh stream,
  danh sách và tổng ngày dùng chung instance nhận dữ liệu mới.
- Lỗi giữ task/snapshot và báo trên thẻ. Thử lại bằng nút thùng rác vẫn phải
  xác nhận lại, không có retry xóa tự động.
- NotFound báo bản ghi đã bị xóa trước đó; nút Tải lại danh sách tải cả hai
  controller danh sách/tổng ngày. Không giả lập một lần xóa thành công.
- Dispose không notify muộn; không sở hữu/đóng repository hay HTTP client.
- Không thêm undo, soft delete, schema hoặc endpoint mới.

Chặn gửi trùng áp dụng request đang chạy, không phải idempotency/version phía server.
Nếu timeout sau khi server đã xóa thì client chưa biết chắc kết quả; tải lại
danh sách để kiểm tra. Retry vẫn cần người dùng xác nhận.
Đóng trình duyệt/cưỡng bức kết thúc không đảm bảo hủy được request ghi đã gửi.

## Người dùng tự test

Tải lại http://127.0.0.1:3111 sau khi build mới hoàn tất:
1. Dùng task thử của bạn, bấm thùng rác.
2. Kiểm tra tên trên hộp thoại rồi bấm Hủy: task vẫn còn.
3. Bấm lại thùng rác, chọn Xóa: chờ lưu, task biến mất và tiến độ tính lại.
4. Tải lại trang: task đã xóa không xuất hiện trở lại.
5. Nếu backend lỗi, thẻ có thông báo; bấm lại thùng rác sẽ hỏi xác nhận lại.
Dữ liệu xóa qua preview là dữ liệu thật trong database TV3 demo.
Không tự xóa công việc khác hoặc dữ liệu của module khác.

## Kiểm tra

    flutter test test/unit/features/tasks/application/task_delete_controller_test.dart test/widget/features/tasks/tasks_day_page_test.dart
    flutter test test/integration/task_delete_controller_real_test.dart --dart-define=TV3_TASKS_API_BASE_URL=http://127.0.0.1:3111/api
    flutter analyze

Đã quan sát:
- 4 unit test delete controller đạt: khóa ID, Failure/thử lại, độc lập các ID/
  exception, dispose.
- 21 widget test màn ngày đạt, gồm xác nhận/Hủy không gọi API, chờ phản hồi,
  lỗi giữ task, xác nhận lại, notFound và màn 320px/chữ 1.3.
- Tổng nhóm test liên quan: 25 test đạt.
- 1 integration test delete controller -> HTTP -> PostgreSQL thật đạt:
  xóa fixture, stream cả ngày/completed cùng rỗng, đọc lại và xóa lại notFound.
- Chỉ fixture marker ngẫu nhiên của lần thử bị xóa; cleanup đọc lại rỗng.
- Widget test dùng repository stub, không coi là thao tác trình duyệt thật.
- Chưa tự kiểm chứng thao tác trong Chrome hoặc chạy Android/build lại APK.
- Không sửa backend/API, schema, dependency hoặc router chung; không commit/push.

Bước nhỏ tiếp theo dự kiến sau khi người dùng xác nhận:
rà soát chức năng Công việc còn thiếu và kiểm tra lưu sau khởi động lại,
chưa chuyển sang Native/Assistant hoặc tuần/tháng.Kiểm tra cuối: toàn bộ 162 test đạt, 5 test tích hợp opt-in skip trong lượt mặc định; flutter analyze sạch. Test xóa với PostgreSQL thật chạy riêng đạt.
Preview có xác nhận xóa build thành công; JavaScript qua server 3111 trả HTTP 200. Tải lại trang để nhận bản mới.
