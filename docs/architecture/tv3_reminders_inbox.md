# TV3: nhắc việc và Native Inbox — trạng thái kiểm chứng

## Đã triển khai trong demo

- Form tạo công việc và màn chi tiết có điều khiển Nhắc việc theo phong cách FinAI.
- Quyền thông báo và quyền báo thức chính xác do người dùng cấp trên Android.
- Kotlin dùng AlarmManager và thông báo cục bộ; nhấn thông báo chuyển task ID sang Flutter.
- Native Inbox SQLite riêng: ghi trước khi phát sự kiện, getPending và acknowledge.
- Mặc định listener chỉ nhận thông báo của chính FinAI, nội dung Inbox mặc định ẩn.
- Hoàn thành/xóa task hủy nhắc; sửa giờ giữ khoảng cách nhắc trước giờ bắt đầu.
- Lỗi đồng bộ Native được báo riêng sau khi server lưu thành công; retry chỉ thực hiện Native.
- Entry point demo: lib/dev/main_tasks_day_demo.dart. Shell chính chưa thay đổi.

## Kiểm thử tự động

- Consumer: chỉ ack sau khi handler nhận xử lý, giữ sự kiện chưa xử lý, retry ack không gọi handler lần hai trong cùng phiên, dispose ngừng xử lý.
- UI Inbox: Android-only khi không có port, ẩn nội dung mặc định, lỗi ack giữ sự kiện và thông báo lỗi, retry thành công cập nhật danh sách.
- Nhắc việc: chặn quá khứ/task hoàn thành, chặn lưu đồng thời, retry lỗi, hủy, từ chối quyền, sửa nhiều lần giữ khoảng cách giờ và retry đồng bộ.
- Các kiểm thử này dùng fake port. Không chứng minh SQLite/AlarmManager chạy trên thiết bị.

## Tự test trên Android (chưa thực hiện)

1. Chạy backend demo bằng cấu hình hiện có. Chạy Flutter bằng entry point demo, TASKS_API_BASE_URL trỏ đến backend mà điện thoại truy cập được (USB có thể dùng adb reverse tương ứng cổng).
2. Tạo task thử, bật Nhắc việc, chọn thời điểm sau hiện tại 2–3 phút, cấp quyền thông báo và Báo thức & nhắc việc rồi lưu. Mong đợi task được lưu một lần, cài đặt nhắc báo thành công.
3. Đợi tới giờ và nhấn thông báo. Mong đợi mở đúng ID công việc; nếu task đã xóa thì hiển thị trạng thái không tìm thấy.
4. Sửa giờ bắt đầu, kiểm tra giờ nhắc giữ khoảng cách ban đầu. Hoàn thành hoặc xóa task trước giờ nhắc và kiểm tra thông báo không còn phát.
5. Mở biểu tượng Inbox trên màn Công việc, cấp quyền đọc thông báo. Dùng thông báo FinAI thử nghiệm; nội dung mặc định ẩn. Xác nhận một mục rồi đọc lại, mong đợi mục đó biến mất.
6. Lặp lại khi app đang mở, ở nền, tiến trình bị kết thúc, force stop, thu hồi/cấp lại quyền. Ghi từng trường hợp riêng, thiết bị/Android/thời gian và bằng chứng đã che dữ liệu.

## Giới hạn hiện tại

- Đã kiểm chứng Inbox cơ bản trên TECNO LH7n / Android 14 ngày 12/11/2026, xem bảng dưới. Chưa xác minh đầy đủ nhấn thông báo mở task, boot hoặc nhận sự kiện mới trong các tình huống nền/kill/force stop.
- Force stop không được coi giống chạy nền; không cam kết phát nhắc khi app bị force stop.
- Chưa kiểm chứng với ngân hàng. Không parser, không tự tạo giao dịch.
- Nhắc việc cục bộ theo điện thoại, chưa đồng bộ nhiều thiết bị hoặc sửa task từ thiết bị khác.
- Handler chống lặp trong phiên và Native chống nguồn trùng; nếu tiến trình chết giữa mở màn và ack, lần sau có thể được giao lại (at-least-once).
- Chưa được người dùng nghiệm thu trên điện thoại thật.


## Kiểm chứng Inbox trên máy thật — 12/11/2026

Thiết bị: TECNO LH7n, Android 14. APK debug entry point Tasks demo, cài cập nhật bằng ADB. Người dùng đã cấp quyền đọc/hiện thông báo và nhắc chính xác. Không dùng ngân hàng.

Trong phiên kiểm chứng đã dùng nút debug “Gửi thông báo thử FinAI”; công cụ này đã được xóa theo yêu cầu người dùng sau khi thử. Nút gọi NotificationManager, sự kiện đi qua NotificationListenerService thật, TV3Store SQLite và bridge thật; không chèn fixture vào Flutter hoặc Inbox.

| Tình huống | Kết quả quan sát | Bằng chứng / giới hạn |
| --- | --- | --- |
| App mở, gửi thông báo thử FinAI | Inbox từ 0 lên 1 | UI có kind notification, package vn.edu.finai.finai; nội dung mặc định ẩn |
| Đối chiếu Native SQLite | Có đúng sự kiện thử | Đọc DB debug bằng run-as, chỉ xuất ID/kind của thông báo có title thử cố định |
| Force stop sau khi sự kiện đã lưu, mở lại app | Vẫn đúng 1 sự kiện cũ, cùng thời điểm | UI sau restart và SQLite; chỉ chứng minh độ bền dữ liệu đã lưu, không chứng minh nhận mới trong force stop |
| Xác nhận riêng sự kiện thử | UI từ 1 về 0 | ID thử không còn trong bảng inbox, bảng seen còn dấu chống trùng |
| Nhận sự kiện mới khi ở nền / hệ thống kết thúc tiến trình | Chưa kiểm chứng | Cần bước riêng |
| Nhận sự kiện mới trong force stop | Chưa kiểm chứng | Không suy ra từ kiểm tra độ bền dữ liệu |
| Thu hồi rồi cấp lại quyền | Chưa kiểm chứng | Cần bước riêng |
| Ngân hàng | Chưa kiểm chứng với ngân hàng | Không dùng thông báo thử làm bằng chứng ngân hàng |

Kiểm tra mã trong bước này: flutter analyze --no-pub sạch; 6 unit/widget test Inbox đạt; build APK debug thành công. Chưa chạy lại toàn bộ suite vì thay đổi giới hạn ở nút thử Inbox.

Bản hiện tại đã xóa hai nút gửi thử/gửi sau 15 giây và lệnh Native tương ứng. Có thể kiểm tra nhận sự kiện bằng thông báo nhắc việc FinAI đã đặt. Cài đặt quyền được chuyển xuống cuối màn trong mục Quyền truy cập, mặc định thu gọn. Chưa đánh dấu nghiệm thu cho đến khi người dùng xác nhận.


Lần thử chạy nền sau đó bị gián đoạn: đã quan sát sự kiện thử trong SQLite nhưng app quay lại foreground trước lần đối chiếu, nên chưa ghi nhận nhận mới khi chạy nền là đạt. Không suy ra kết quả từ lần thử này.


## Cập nhật 13/11/2026

Người dùng xác nhận đã thực hiện kiểm tra nhắc việc khi app ở nền và nhấn thông báo mở đúng công việc. Đây là xác nhận của người dùng; phiên này không chạy lại để tạo bằng chứng quan sát riêng của agent.

Bước tiếp theo là kiểm chứng sự kiện mới đến khi Flutter chưa sẵn sàng. ADB chưa nhận thiết bị trong phiên này. Bổ sung kiểm thử consumer bằng MemoryInbox: sự kiện tồn tại trước start; pending/live trùng ID không xử lý hai lần và chỉ ack sau handler; đóng consumer giữa handler giữ pending để lần mở sau xử lý lại. Đây là kiểm thử mô phỏng hợp đồng Flutter, không chứng minh vòng đời Android hoặc nhận thông báo mới sau force stop.

Tài liệu parser ngân hàng và bằng chứng hai sự kiện TPBank nằm tại bank_notifications_handover.md; các ghi chú không có parser/chưa thử ngân hàng ở phần lịch sử bên trên không còn mô tả trạng thái mới nhất.
