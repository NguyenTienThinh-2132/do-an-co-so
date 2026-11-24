# FinAI — PostgreSQL trực tiếp, không cần Docker

Cập nhật 23/11/2026. Giữ NestJS + Prisma + PostgreSQL. Docker được rút khỏi cách chạy dự án. Flutter SQLite chỉ làm cache đọc; Native Inbox là hàng đợi riêng.

## Cấu hình đã triển khai

- PostgreSQL native 18.3, dùng binaries có sẵn ở `D:/PostgreSQL/pgsql/bin`.
- Cụm mới của riêng FinAI: `D:/FinAIData/postgres18`, chỉ nghe `127.0.0.1:5433`. Đây là tiến trình PostgreSQL chạy trực tiếp trên Windows, không phải container dù cổng vẫn là 5433.
- Database `finai_tv3_demo`, role app `finai_app`, mật khẩu ngẫu nhiên được ghi trong backend/.env; API không dùng tài khoản quản trị.
- Mật khẩu quản trị cụm mới cũng được tự sinh và giữ trong `backend/.env.native-cluster.json`; file này bị Git ignore, không chia sẻ hoặc commit. Không đổi mật khẩu/cấu hình xác thực hoặc dữ liệu của cụm cũ tại `D:/PostgreSQL/18/data`.
- `.env` cũ được giữ ở `.env.before-native-<timestamp>`. Các biến dự án khác được giữ; biến POSTGRES_* phục vụ Compose được bỏ khỏi file .env mới.
- Hai migration Tasks và Finance đã áp dụng trên database native mới. Đây là database mới, dữ liệu Docker CHƯA được nhập.
- Prisma config, PrismaModule và check-prisma chấp nhận đúng database local 127.0.0.1:5432/5433, vẫn chặn server/database khác. Giữ cổng 5432 cho nhóm dùng PostgreSQL cài sẵn nếu tự cấu hình.

## Khởi động hằng ngày

PowerShell:

```powershell
cd D:/git/do-an-co-so/backend
& 'D:/nodejs/node.exe' scripts/start-postgres-native.mjs
& 'D:/nodejs/npm.cmd' run start:dev
```

Lệnh đầu kiểm tra/mở cụm PostgreSQL riêng, đăng nhập thử bằng tài khoản app; chạy lại không tạo database hoặc đổi mật khẩu. Lệnh thứ hai chạy API NestJS cổng 3000. Cần giữ terminal API mở; server PostgreSQL chạy nền dưới tài khoản Windows hiện tại. Chưa đăng ký Windows service tự khởi động.

Nếu code/migration mới được cập nhật:

```powershell
& 'D:/nodejs/node.exe' node_modules/prisma/build/index.js generate
& 'D:/nodejs/node.exe' node_modules/prisma/build/index.js migrate deploy
& 'D:/nodejs/npm.cmd' run build
& 'D:/nodejs/node.exe' scripts/check-prisma.mjs
```

Không chạy migration reset, không xóa thư mục data để thử lại. Không sao chép thư mục dữ liệu này vào Git.

## Lần đầu trên máy khác

Cần Node/npm dependencies và PostgreSQL 18 binaries. Mặc định script tìm `D:/PostgreSQL/pgsql/bin`; có thể đặt FINAI_PG_BIN để chỉ đúng thư mục binaries trên máy đó. Vị trí dữ liệu mặc định hiện là `D:/FinAIData/postgres18`, cổng 5433 phải trống. Đây là cấu hình phát triển Windows, không phải server dùng chung qua Internet.

`start-postgres-native.mjs` chỉ khởi tạo khi đường dẫn chưa có dữ liệu. Nó ghi marker nhận diện cụm, tạo mật khẩu qua file tạm .env.* và xóa file tạm sau initdb. Nếu đường dẫn/cụm đã tồn tại ngoài cấu hình quản lý thì dừng, không xóa hoặc tái khởi tạo. Nếu có .env.native.pending sau lỗi, giữ lại để kiểm tra/khôi phục.

Tài khoản quản trị cụm PostgreSQL cũ không cần cho cách chạy này. Nếu nhóm muốn dùng một PostgreSQL có sẵn khác thay vì cụm riêng, có script tùy chọn `scripts/setup-postgres-local.ps1`: hỏi mật khẩu postgres kín trong terminal, tạo role/database mới khi chưa tồn tại, không reset tài khoản cũ. Cách tùy chọn này chưa được thử tạo DB trên cụm cũ vì người dùng không nhớ mật khẩu.

## Chạy Flutter trên điện thoại qua USB

```powershell
cd D:/git/do-an-co-so
& 'C:/Users/duong/AppData/Local/Android/sdk/platform-tools/adb.exe' reverse tcp:3000 tcp:3000
& 'D:/Flutter/3.47.7/flutter/bin/flutter.bat' run -t lib/main.dart --dart-define=TASKS_API_BASE_URL=http://127.0.0.1:3000
```

APK trước đây cấu hình cổng 3111 không tự đổi sang 3000. Nếu muốn dùng chế độ báo cáo riêng đã có, sau khi PostgreSQL native chạy, dùng `node scripts/serve-finai-report.mjs --demo-data`, API tại 3111/api và cấu hình Flutter/reverse cùng cổng 3111. Đây là lựa chọn có seed mô phỏng rõ ràng; database native bình thường không tự nhận dữ liệu tài chính mẫu.

## Docker và dữ liệu cũ

`backend/compose.yaml` không còn là cấu hình chạy mặc định. Bản khôi phục ở `backend/legacy/compose.yaml.disabled`; muốn khôi phục thì copy về tên cũ và dùng .env phù hợp. Docker Desktop không bị gỡ khỏi Windows; Docker volume, container và dữ liệu cũ không bị xóa.

Chưa export/import công việc/giao dịch cũ từ Docker sang PostgreSQL native. Không coi database mới là đã chuyển dữ liệu xong. Bước chuyển dữ liệu sẽ làm riêng khi được chốt; không tự seed bản ghi cũ vào DB mới.

## Kết quả kiểm tra thật

- Backend build/lint đạt; 92 unit test và 42 HTTP test dùng DB giả đạt.
- Prisma validate đạt; hai migration áp dụng thành công trên native 5433.
- check-prisma đọc tasks native thành công; tasks = 0 vì DB mới.
- check-nest-prisma khởi tạo NestJS/Prisma, đọc tasks và GET / trả 200 thành công, tự đóng server test.
- check-finance-postgres chạy 26 lượt HTTP với PostgreSQL native thật: ghi chi, nguồn tiền/hũ, phân bổ, tỷ lệ, xóa/giữ lịch sử, idempotency, revision, cạnh tranh và đọc lại sau restart NestJS đều đạt. Fixture dùng sổ riêng và tự dọn.
- Sáu unit test cache + một test SQLite thật trên host đạt. Đã nối cache danh sách Tasks ở bước tiếp theo, xem ../architecture/task_list_cache.md; chi tiết/tài chính chưa nối.
- Node setup/start scripts kiểm tra cú pháp đạt; PowerShell script parse AST đạt. Đã chạy nhánh tạo cụm riêng bằng initdb và tạo role/database thật thành công.
- Không chạy UI/offline trên điện thoại trong lượt này. Không commit/push/merge.
- Cụm cũ ở 5432 được khởi động trong lúc khảo sát. Lệnh dừng cụm này bị automatic approval review từ chối vì nguy cơ gián đoạn dịch vụ khác; lệnh không được thực hiện. Việc chạy cụm FinAI 5433 không phụ thuộc dừng cụm đó.
