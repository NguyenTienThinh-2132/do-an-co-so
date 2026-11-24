> Hiện trạng mới nhất: [Bàn giao Tasks chế độ ngày](tasks_handover.md) — 12/11/2026. Ghi chú dưới đây là lịch sử từng bước.

# Form tạo Công việc — 08/11/2026

Người dùng đã cho phép tự tạo form theo cách bố trí Google Calendar,
dùng phong cách FinAI. Tham khảo:
https://support.google.com/calendar/answer/72143?hl=en
Không tích hợp Google Calendar hoặc chức năng ngoài hợp đồng Tasks.

## Triển khai

- application/task_create_controller.dart: inject TaskRepository,
  quản lý saving/failure, chặn submit trùng trong lúc request đang chạy.
- presentation/task_create_page.dart: tên, mô tả, ngày/giờ bắt đầu-kết thúc,
  mức ưu tiên; nền sáng, thẻ trắng/tím và bo góc.
- Tên trim không rỗng; kết thúc phải sau bắt đầu. TaskDraft chuẩn hóa UTC.
- Mặc định 09:00–10:00 của ngày được chọn; người dùng thay bằng picker.
- Không có danh mục giả, nhắc lịch, lặp lại, cả ngày, khách mời, Google Meet.
- Form không khởi tạo repository. Controller được composition root sở hữu.
- Lưu lỗi giữ nội dung; người dùng có thể bấm Lưu lại. Không tự retry request ghi.
- Lưu thành công đóng form. Cùng instance repository cập nhật stream danh sách
  và tiến độ. Task mới pending; nếu đang lọc Đã xong có thể không thấy nó,
  chọn Tất cả để xem.
- Khóa nút Lưu, dữ liệu nhập và nút đóng trong khi lưu. Không hủy request ghi
  khi cửa sổ/trình duyệt bị đóng cưỡng bức; kết quả có thể không xác định.
- Chặn bấm trùng không phải idempotency phía server. Nếu timeout nhưng server
  đã ghi, người dùng gửi lại có thể tạo thêm task; chưa thay schema/API chung.

## Bản xem thử trên máy tính

Windows hiện thiếu Windows SDK; không thêm platform vào app gốc.
Host Flutter web riêng được generate trong build/tasks_preview_host (ignored).
Chỉ phụ thuộc SDK và package finai local; không thay pubspec dự án chính.

    flutter create --platforms=web --empty --no-pub --project-name finai_preview build/tasks_preview_host

pubspec host sử dụng dependencies:
flutter: sdk flutter; finai: path ../..; uses-material-design true.
lib/main.dart host import package:finai/dev/main_tasks_day_demo.dart as demo,
và main gọi demo.main().

    cd D:\git\do-an-co-so\build\tasks_preview_host
    flutter pub get --offline
    flutter build web --no-wasm-dry-run --no-web-resources-cdn --dart-define=TASKS_API_BASE_URL=http://127.0.0.1:3111/api

Mở Docker Desktop; backend/.env demo đã có, backend đã build:

    cd D:\git\do-an-co-so\backend
    & 'D:\Docker\resources\bin\docker.exe' compose up -d postgres
    npm run build
    node scripts/serve-tasks-preview.mjs

Server preview tại http://127.0.0.1:3111:
- Chỉ bind loopback, phục vụ web host và proxy /api sang NestJS local cổng tạm.
- Không sửa CORS hoặc main backend. Backend vẫn có guard database TV3.
- Không dùng để triển khai production; không mở cổng ra LAN.
- Ctrl+C dừng server khi chạy ở terminal; phiên do agent mở là tiến trình Node
  PID 2924 (chỉ dừng sau khi xác minh PID vẫn là script preview này).
- PostgreSQL demo được giữ chạy, không xóa volume.

Đã gửi lệnh mở Chrome --app=http://127.0.0.1:3111 --window-size=460,900.
Tool điều khiển giao diện bị lỗi runtime "failed to write kernel assets",
nên chưa tự quan sát/nhấn Lưu trong cửa sổ Chrome.
Không coi HTTP 200 hoặc build web là bằng chứng đã test trình duyệt bằng mắt.

## Người dùng tự test

1. Mở link preview, bấm nút + để mở Công việc mới.
2. Bấm Lưu khi tên trống: thấy yêu cầu nhập tên, không gửi API.
3. Điền tên, mô tả, chọn giờ/ngày kết thúc trước bắt đầu:
   thấy cảnh báo, không lưu.
4. Chọn khoảng giờ hợp lệ rồi Lưu: nút chuyển đang lưu, không bấm lặp được.
5. Lưu xong về danh sách ngày đã chọn; dùng Tất cả để thấy task mới.
6. Tải lại trang: task đã lưu trong PostgreSQL vẫn được đọc.
   Bước tải lại trình duyệt cần người dùng kiểm chứng, chưa agent xác nhận.
Dữ liệu người dùng tự tạo qua preview là dữ liệu thật trong database demo,
không tự xóa dữ liệu này.

## Bằng chứng

- 5 widget test form đạt: tên rỗng, draft đúng/chặn trùng, giữ dữ liệu khi lỗi,
  320px/cỡ chữ 1.3, ngày kết thúc không hợp lệ và ảnh xem bố cục.
- 1 test tích hợp opt-in TaskCreateController -> API -> PostgreSQL đạt,
  đọc lại và dọn fixture đã được assert.
- Trang preview và API GET qua proxy trả HTTP 200.
- Build Flutter web thành công; có cảnh báo font Cupertino không được dùng,
  build không thất bại. Không thêm dependency cupertino_icons chỉ để hết cảnh báo.
- Ảnh widget render: build/task-create-preview.png, đã xem bố cục.
- Chưa thử trên điện thoại/Android, chưa tự thao tác form trong Chrome.
- Chưa build lại APK bước này, chưa commit/push.

    flutter test test/widget/features/tasks/task_create_page_test.dart
    flutter test test/integration/task_create_controller_real_test.dart --dart-define=TV3_TASKS_API_BASE_URL=http://127.0.0.1:3111/api
    flutter analyze

Test tích hợp tự skip nếu không truyền URL để test mặc định không phụ thuộc API.
Bước nhỏ tiếp theo dự kiến sau khi người dùng xác nhận: form sửa công việc.Kiểm tra cuối: flutter analyze sạch; toàn bộ 144 test đạt, 2 test backend opt-in skip trong lượt mặc định. Test tích hợp tạo thật đã được chạy riêng và đạt.
