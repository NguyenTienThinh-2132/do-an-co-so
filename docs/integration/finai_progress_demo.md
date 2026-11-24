> Cập nhật 23/11/2026: nhóm chuyển sang PostgreSQL cài trực tiếp, không dùng Docker. Xem [postgresql_local.md](postgresql_local.md). Cụm PostgreSQL native riêng đã tạo ở D:/FinAIData/postgres18, cổng 5433; dữ liệu Docker chưa nhập vào DB mới.

# Bản gộp FinAI để báo cáo tiến độ — 13/11/2026

## Phạm vi đã triển khai

- Một app Flutter, năm tab theo thứ tự: Trang chủ, Quản lý hũ, Trợ lý AI, Công việc, Dòng tiền.
- Trang chủ/Hũ/Dòng tiền dùng lại giao diện TV1/TV2 từ `D:/DoAnChuyenNganh/dev/dev/finai`. Không sửa project nguồn.
- Giữ Công việc TV3 (ngày/tuần/tháng, CRUD, trạng thái, tìm/lọc, nhắc việc), Assistant fake và Android Native hiện có. Không thay bằng schedule/AI placeholder của nguồn.
- `lib/main.dart` là điểm chạy bản gộp. `lib/dev/main_tasks_day_demo.dart` tiếp tục chạy riêng Công việc; router hiện có nhận thêm finance bindings để dùng chung một MaterialApp/navigator.
- Home và Dòng tiền dùng cùng DashboardController: cùng tháng và trạng thái ẩn tiền. Hũ nhận cùng trạng thái ẩn tiền.
- RemoteFinanceRepository được inject tại composition root, thực thi các port DashboardReader, ExpenseWriter, JarRepository. Sau ghi thành công, cả Home/Hũ/Dòng tiền tải lại cùng nguồn.
- Không có Flutter SQLite tài chính thứ hai. Native SQLite vẫn chỉ giữ hàng đợi thông báo và lịch nhắc.

## Lưu trữ và API

NestJS + Prisma 7 + PostgreSQL local `finai_tv3_demo`, cổng 5433 trên cụm PostgreSQL native riêng của FinAI (cũng hỗ trợ 5432 nếu nhóm tự cấu hình). Migration `20261113090000_finance_shared` chỉ thêm sáu bảng finance, không đổi bảng tasks.

- finance_books: số dư khởi tạo, ngân sách, revision, nhãn demo.
- finance_jars: sáu hũ mặc định một lần, hũ tự thêm, tỷ lệ và soft delete.
- finance_transactions: sổ giao dịch duy nhất, tiền dương là thu, âm là chi.
- finance_allocations và finance_allocation_items: lịch sử phân bổ và tỷ lệ tại thời điểm phân bổ.
- finance_requests: mã yêu cầu, hash nội dung, kết quả đã commit để retry không ghi trùng.

API: GET `/finance/overview?start&end`, GET `/finance/expense-sources`, GET `/finance/jars`, POST `/finance/expenses`, POST `/finance/jars`, PUT `/finance/jars/ratios`, DELETE `/finance/jars/:id`, POST `/finance/allocations`.

VND dùng BIGINT trong DB, chuỗi số nguyên trong JSON, int có kiểm tra giới hạn an toàn ở Flutter. Ngày truyền UTC ISO 8601 có timezone, lọc `[start,end)`. Server kiểm tra nguồn tiền, tỷ lệ 100%, revision, mã yêu cầu. Ghi trong Serializable transaction có khóa sổ và retry serialization/deadlock. Phân bổ không tạo thêm thu/chi; chi từ hũ chỉ ghi đúng một giao dịch. Xóa hũ tùy chỉnh giữ lịch sử, chuyển tỷ lệ, trả phần tiền còn lại về pool; hũ mặc định không xóa.

## Hai chế độ dữ liệu

**Bình thường:** chạy backend như cũ, sổ `...0001` bắt đầu 0 VND, không tự nhập/seed dữ liệu tài chính. Không import SQLite cũ.

**Báo cáo có dữ liệu mẫu:** lệnh riêng bên dưới chọn sổ `...0002`, isDemo=true. Lần đầu tạo số dư khởi tạo 5.000.000 VND, thu mẫu 3.000.000 VND, hai khoản chi mẫu tổng 150.000 VND trong tháng chạy lệnh. Số dư ban đầu để trình diễn là 7.850.000 VND. Đây là số giả, không lấy từ ngân hàng. Những lần sau giữ thay đổi đã lưu, không seed lại. Không tự reset tháng hoặc xóa dữ liệu.

Sổ tài chính báo cáo tách khỏi sổ bình thường; Công việc vẫn dùng dữ liệu TV3 đang có. Bản này chưa có người dùng/đăng nhập nên chỉ dành cho demo local. Không mở port DB/API ra Internet.

## Chạy bản báo cáo trên điện thoại USB

Terminal PowerShell tại `D:/git/do-an-co-so/backend`:

```powershell
& 'D:/nodejs/node.exe' scripts/start-postgres-native.mjs
& 'D:/nodejs/node.exe' node_modules/prisma/build/index.js migrate deploy
& 'D:/nodejs/node.exe' node_modules/prisma/build/index.js generate
& 'D:/nodejs/npm.cmd' run build
& 'D:/nodejs/node.exe' scripts/serve-finai-report.mjs --demo-data
```

Server nghe `http://127.0.0.1:3111/api`. Chỉ chạy một server trên cổng 3111; dừng preview cũ nếu đang chiếm cổng. Giữ terminal API và PostgreSQL trực tiếp chạy.

Terminal khác tại `D:/git/do-an-co-so`:

```powershell
& 'C:/Users/duong/AppData/Local/Android/sdk/platform-tools/adb.exe' reverse tcp:3111 tcp:3111
& 'D:/Flutter/3.47.7/flutter/bin/flutter.bat' run -t lib/main.dart --dart-define=TASKS_API_BASE_URL=http://127.0.0.1:3111/api
```

APK debug đã cấu hình cùng URL USB ở `build/app/outputs/flutter-apk/app-debug.apk`. Bản APK này cần USB reverse/backend để tải dữ liệu; gửi APK qua Zalo không tự biến máy tính thành server truy cập từ xa.

## Tự kiểm tra, khoảng 5 phút

1. Mở FinAI: Trang chủ có nhãn Dữ liệu mẫu, số dư/thu/chi hiện từ server. Chuyển đủ năm tab; Công việc và chat TV3 vẫn có chức năng cũ, AI ghi Chế độ mô phỏng.
2. Hũ: phân bổ 1.000.000 VND. Tổng số dư tài khoản không đổi, tiền chưa phân bổ giảm đúng 1.000.000; lịch sử xuất hiện một lần.
3. Trang chủ hoặc Dòng tiền: thêm chi 50.000 VND từ tiền chưa phân bổ hoặc một hũ đủ tiền. Sau lưu, số dư giảm đúng 50.000, danh sách/biểu đồ và số dư nguồn cùng cập nhật.
4. Đổi tháng ở Home hoặc Dòng tiền: thu/chi theo tháng đổi, tổng số dư tài khoản giữ nguyên. Ẩn tiền ở một tab rồi chuyển tab để kiểm tra cùng trạng thái.
5. Thêm hũ tùy chỉnh, sửa tỷ lệ cho tổng 100%, thử phân bổ và xóa hũ có chuyển tỷ lệ. Lịch sử vẫn đọc được.
6. Đóng/mở app và khởi động lại backend: dữ liệu đã lưu còn. Tắt backend rồi bấm tải lại: có báo lỗi, không giả số dư 0; bật lại và thử lại.
7. Công việc: mở chi tiết/sửa/tạo qua route cũ. Native Inbox ở nút của màn Công việc; nhắc việc/nhấn thông báo cần kiểm chứng lại trên điện thoại sau khi gộp shell.

## Đã kiểm chứng bằng công cụ

- Backend build và lint đạt; 92 unit test và 42 HTTP test dùng fake DB đạt.
- Script `scripts/check-finance-postgres.mjs`: 26 lượt HTTP trên PostgreSQL thật với sổ ngẫu nhiên, tự dọn fixture. Kiểm tra bootstrap sáu hũ, ghi chi/pool/hũ, retry cùng key, khác payload, thiếu tiền, tên rỗng, ID sai, revision cũ, phân bổ, chuyển tỷ lệ/xóa và giữ lịch sử, cạnh tranh hai khoản chi, đọc lại sau restart.
- So sánh hash toàn bộ ba task trước/sau migration và script: dữ liệu giữ nguyên.
- Flutter analyze sạch. Lượt toàn bộ: 242 test đạt, 5 integration test bỏ qua vì chưa truyền URL trong lượt mặc định. Sáu test mới nằm trong số 242, gồm adapter và shell 5 tab. Thêm một widget test riêng đã đạt: retry khoản chi giữ nguyên thời gian và requestId khi form được rebuild.
- Lượt integration truyền URL thật: cả 6 test đạt (5 Công việc + 1 đối chiếu Home/Hũ/Dòng tiền). Một guard của test danh sách cũ được cập nhật để chấp nhận prefix `/api`, đồng nhất các test còn lại; không đổi nghiệp vụ Tasks.
- APK debug build đạt. Đã cài cập nhật qua ADB trên TECNO LH7n Android 14, package `vn.edu.finai.finai`, phiên bản 1.0.0. Chưa thao tác/quan sát UI bản gộp trên điện thoại vì người dùng đang sử dụng ứng dụng khác. Không coi cài APK thành công là nghiệm thu UI/Native.
- Có cảnh báo SDK XML của Android command-line tools/Android Studio khác phiên bản; không chặn build. Chưa nâng SDK/tools ngoài phạm vi.

## Mẫu nội dung báo cáo tiến độ

“Đã tích hợp năm tab FinAI trong một ứng dụng Flutter. Ba module Trang chủ, Hũ và Dòng tiền dùng chung backend NestJS + Prisma + PostgreSQL; triển khai ghi chi, phân bổ, tỷ lệ hũ, lịch sử và chống ghi trùng. Giữ module Công việc và Android Native TV3. Chat AI đang dùng fake service. Đã kiểm tra tự động với PostgreSQL thật, build APK và cài bản cập nhật; đang chờ kiểm tra giao diện/tình huống Native của bản gộp trên điện thoại và xác nhận của người dùng.”

## Đang mô phỏng / chưa làm / giới hạn

- AI vẫn FakeAssistantService, đọc Tasks qua TaskReader. Chưa nối LLM thật, chưa cho AI ghi dữ liệu hoặc phân tích tài chính qua reader thật.
- Thông báo ngân hàng chỉ nhận/tách/giữ tạm như phần TV3; không tự tạo giao dịch vào sổ mới.
- Chưa có form tạo thu nhập, sửa/xóa giao dịch, cấu hình số dư/ngân sách, CRUD khoản dự kiến hoặc xác nhận khoản dự kiến thành giao dịch. Không coi danh sách upcoming rỗng là đã triển khai các phần này.
- Hồ sơ/tên/avatar và vài nội dung giới thiệu giữ từ giao diện mẫu, không phải hệ thống tài khoản thật.
- Chưa import/migrate dữ liệu SQLite TV1/TV2. Chưa triển khai auth, phân quyền nhiều người dùng, đồng bộ offline, phân trang dữ liệu lớn hay cấu hình server triển khai dùng qua Internet.
- Chưa coi việc build APK là bằng chứng mọi tình huống Native hoạt động. Cần kiểm chứng lại foreground/background, tiến trình bị kết thúc, force stop, thu hồi/cấp lại quyền và nhấn nhắc việc sau khi gộp. Kết quả Native trước đây xem tài liệu riêng.
- Chưa có xác nhận nghiệm thu của người dùng. Không commit/push/merge.

## Lệnh kiểm tra

```powershell
# backend/
& 'D:/nodejs/npm.cmd' test -- --no-file-parallelism
& 'D:/nodejs/npm.cmd' run test:e2e -- --no-file-parallelism
& 'D:/nodejs/npm.cmd' run lint
& 'D:/nodejs/node.exe' scripts/check-finance-postgres.mjs
# repo root, khi server báo cáo đang chạy
& 'D:/Flutter/3.47.7/flutter/bin/flutter.bat' test --concurrency=1 test/integration --dart-define=TV3_TASKS_API_BASE_URL=http://127.0.0.1:3111/api --dart-define=TV3_FINANCE_API_BASE_URL=http://127.0.0.1:3111/api
```
