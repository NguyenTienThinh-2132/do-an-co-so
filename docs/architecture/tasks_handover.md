# Bàn giao Tasks chế độ ngày — 12/11/2026

Đây là hiện trạng mới nhất, ưu tiên hơn ghi chú lịch sử trong các tài liệu bước cũ.
Phần code Tasks chế độ ngày đã triển khai/kiểm tra; chờ người dùng xác nhận UI.
Không tuyên bố toàn app FinAI hoặc phần kiểm chứng Android đã hoàn thành.

## Đã triển khai

| Phần | Hiện trạng |
|---|---|
| Model/validation | Task, TaskDraft, TaskQuery; UTC; tên trim; end > start; quá hạn suy ra |
| Data | Mapper, HTTP datasource, TaskRepository NestJS/Prisma/PostgreSQL demo thật |
| Danh sách | Ngày địa phương, popup chọn ngày, Hôm nay, loading/empty/error/retry |
| Lọc | Cả 3 trạng thái, tất cả; ưu tiên thấp/trung bình/cao; tìm theo tên debounce |
| Tiến độ | Tổng toàn ngày độc lập bộ lọc, 0 task = 0%; retry riêng khi lỗi |
| Ghi | Tạo/sửa, đổi trạng thái, xóa xác nhận; khóa gửi trùng, lỗi an toàn |
| Chi tiết | Tải theo ID; mô tả, giờ/ngày, ưu tiên, trạng thái; quay lại từ sửa tải mới |
| Quá hạn | endAt < now và chưa completed; timer cập nhật tại deadline, refresh khi resumed |
| Public port | TaskReader/TaskDto, adapter thật và FakeTaskReader fixture cố định |
| Demo routing | /tasks, /tasks/new, /tasks/:taskId, /tasks/:taskId/edit; route sai có màn lỗi |

Mọi UI nhận controller/service từ composition root. Không có SQL hoặc khởi tạo
repository trong widget sản phẩm. Không có nguồn giao dịch/số dư phụ.
Đã sửa lỗi listener gọi trước khi controller được gán khi khởi tạo demo.

Route chỉ áp dụng TasksDemoApp tại lib/dev/main_tasks_day_demo.dart;
không thay router chung, main.dart hoặc shell 5 tab của nhóm.
Route nhận ID rồi tải bản ghi. ID không hợp lệ hoặc đã xóa có thông báo rõ.
Không tự dựng route /assistant vì Assistant ngoài phần Tasks này.

## Quy ước

- Khoảng [start, end), lấy task giao khoảng; AND các bộ lọc.
- Tìm chuỗi con theo tên, không phân biệt hoa/thường, có phân biệt dấu.
- Sắp xếp startAt rồi id tăng dần. Không thêm bảng/cột quá hạn.
- Ngày hiển thị theo giờ địa phương của thiết bị; lưu/gửi UTC.
- Giữ id/status/createdAt khi sửa; giữ categoryId vì chưa có port danh mục chung.
- Không tự retry ghi sau lỗi; timeout có thể chưa xác định server đã ghi hay chưa.
- Không thay schema/API/interface nhóm, dependency hoặc git commit/push.

## Đã kiểm chứng ngày 12/11/2026

| Kiểm tra | Kết quả |
|---|---|
| flutter analyze --no-pub | Không có lỗi |
| flutter test --no-pub | 174 đạt, 5 integration opt-in bỏ qua trong lượt mặc định |
| flutter test test/integration với backend thật | 5 đạt, không skip |
| Backend unit | 88 đạt |
| Backend HTTP e2e | 42 đạt; không coi mock DB trong e2e là PostgreSQL thật |
| Script CRUD thật | CRUD/lọc/validation; đóng-mở lại NestJS vẫn đọc đúng dữ liệu |
| Script TaskReader thật | Fake/real cùng kết quả cho 9 trường hợp + đọc mới + cleanup |
| Dựng lại client/repo/details controller | 2 phiên mới đọc đúng dữ liệu đã sửa từ PostgreSQL |
| Android build debug | app-debug.apk build thành công với entry point Tasks |
| Flutter web preview | Host riêng trong build, không thêm platform vào app gốc |

Test thêm: deadline đúng biên, completed không quá hạn, lifecycle resumed;
danh sách -> chi tiết -> sửa -> chi tiết reload; named route tạo/sai;
retry tiến độ độc lập. Unit/widget test dùng stub được phân biệt với 5 phép thử
HTTP/PostgreSQL thật. Mỗi phép thử thật dọn đúng fixture ngẫu nhiên riêng.

Bằng chứng/log:
- build/tasks-completion-test.log
- build/tasks-final-integration.log
- build/task-completion-specific.log
- build/app/outputs/flutter-apk/app-debug.apk
Các file trong build là artifact cục bộ/ignored, không phải file source để commit.

## Chạy và tự test

Backend (PostgreSQL trực tiếp đang chạy, backend/.env đã thiết lập theo ../integration/postgresql_local.md):

    cd D:\git\do-an-co-so\backend
    # Khởi động PostgreSQL trực tiếp theo docs/integration/postgresql_local.md
    npm run build
    npm run start:dev

Flutter:

    cd D:\git\do-an-co-so
    flutter run -t lib/dev/main_tasks_day_demo.dart --dart-define=TASKS_API_BASE_URL=http://127.0.0.1:3000

Android dùng adb reverse tcp:3000 tcp:3000 trước khi run.
Chính sách HTTP loopback chỉ dành bản debug, không coi là cấu hình phát hành.

Web xem thử: http://127.0.0.1:3111
Host build/tasks_preview_host và backend/scripts/serve-tasks-preview.mjs
được mô tả trong task_create_form.md. Không cấu hình CORS cho backend chung.
Named route demo có thể sử dụng fragment, ví dụ /#/tasks hoặc /#/tasks/ID/edit.
Cần test lại link trực tiếp/refresh trên trình duyệt thực tế trước khi tích hợp.

Thao tác nghiệm thu:
1. Chọn ngày, tạo task có tên/mô tả/ưu tiên và thời gian hợp lệ.
2. Mở chi tiết bằng tên task, bấm sửa rồi lưu; chi tiết và danh sách cập nhật.
3. Kết hợp trạng thái + ưu tiên + tìm tên; tiến độ vẫn tính toàn ngày.
4. Đổi trạng thái completed/pending, quan sát nhãn và tiến độ.
5. Task chưa xong có endAt đã qua hiển thị Quá hạn; completed không hiện.
6. Xóa thử: Hủy không xóa; xác nhận Xóa mới gọi API và bỏ task khỏi danh sách.
7. Tải lại/đóng mở app để tự xác nhận trên môi trường chạy thật của bạn.

Kiểm tra toàn bộ:

    flutter analyze --no-pub
    flutter test --no-pub
    flutter test test/integration --dart-define=TV3_TASKS_API_BASE_URL=http://127.0.0.1:3000

## Đang mô phỏng

- FakeTaskReader để module khác phát triển độc lập.
- Repository stub/HTTP mock trong unit/widget test.
- Header/tên thương hiệu là bố cục, chưa kết nối tài khoản người dùng.
Runtime demo Tasks dùng API/database thật, không seed lại task mỗi lần mở.

## Chưa kiểm chứng/chưa thực hiện

- Chưa thao tác trực tiếp UI trình duyệt bằng công cụ: runtime báo
  "failed to write kernel assets". Đã test widget, xem ảnh render và kiểm tra HTTP.
- Chưa chạy APK trên Android thật/emulator thành công; không coi build là chạy máy thật.
- Kiểm tra dựng lại client/controller và restart NestJS không phải kill/restart tiến trình Android.
- Chưa tích hợp shell/router nhóm, auth, offline cache, push đa thiết bị.
- Múi giờ/locale/category port và schema toàn nhóm chưa chốt; database này riêng TV3 demo.
- Tuần/tháng chưa trong phạm vi đã duyệt; Native, Assistant và module tài chính không làm ở lượt này.
- Không có lỗi còn tái hiện trong các kiểm tra đã đạt; các giới hạn trên chưa được nghiệm thu.

Chỉ xác nhận module hoàn thành sau khi người dùng duyệt kết quả và các bước
tích hợp/thiết bị thuộc tiêu chí bàn giao của nhóm được kiểm chứng phù hợp.Kiểm tra cuối: bản preview mới build thành công, trang/JavaScript/API trả HTTP 200; APK debug của entry point Tasks đã có. Tài liệu và các test là bằng chứng ở phạm vi nêu trên, chưa thay nghiệm thu UI/Android.
