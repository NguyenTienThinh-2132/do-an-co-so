# PostgreSQL thử nghiệm riêng cho TV3

Cấu hình chỉ phục vụ thử nghiệm phần TV3; chưa chốt database, schema hoặc migration chung cho nhóm.
Backend NestJS chạy trực tiếp trên máy. Prisma CLI đã cấu hình cho demo; đã nối Prisma vào lifecycle NestJS, đã có CRUD Tasks demo TV3; xem TASKS.md.

## Ý nghĩa cấu hình

- Image postgres:17.11-bookworm: cố định phiên bản PostgreSQL và nền Debian.
- Cổng 127.0.0.1:5433 trên máy chuyển đến cổng 5432 trong container.
- Volume tv3_postgres_data giữ dữ liệu khi dừng hoặc tạo lại container.
- Healthcheck dùng pg_isready để kiểm tra server sẵn sàng nhận kết nối.
- Không có seed hay migration tự chạy trong cấu hình này.

## Chuẩn bị

Chạy trong thư mục backend. Máy cần Docker Desktop đang chạy Linux engine.

1. Sao chép .env.example thành .env nếu chưa có .env; không ghi đè cấu hình cũ.
2. Thay POSTGRES_PASSWORD bằng mật khẩu local riêng.
3. Kiểm tra cấu hình:

    docker compose config --quiet

Chỉ kiểm tra cú pháp bằng mẫu, không khởi chạy:

    docker compose --env-file .env.example config --quiet

Không đưa .env vào Git. .env.example chỉ chứa giá trị minh họa.
Không dùng lệnh config không có --quiet khi chia sẻ màn hình vì có thể in mật khẩu.

## Chạy database thử nghiệm

    docker compose up -d postgres
    docker compose ps
    docker compose exec postgres pg_isready -U tv3_demo -d finai_tv3_demo

Hai tham số cuối giả định POSTGRES_USER=tv3_demo và POSTGRES_DB=finai_tv3_demo.
Trạng thái mong đợi là healthy và accepting connections.
NestJS trên máy kết nối 127.0.0.1:5433 bằng DATABASE_URL trong .env.

Dừng mà giữ dữ liệu:

    docker compose stop postgres

Lệnh docker compose down giữ named volume. Không dùng down -v nếu cần giữ dữ liệu.
Đổi mật khẩu trong .env không tự đổi mật khẩu của database đã được khởi tạo.

## Vị trí dữ liệu

Compose không gắn cứng đường dẫn ổ đĩa Windows, nên các thành viên dùng cùng file.
Volume do Docker quản lý. Trên máy hiện tại, đĩa Docker được đặt tại D:\DockerData.
Thành viên khác tự chọn vị trí đĩa trong Docker Desktop.

## Trạng thái bàn giao

- Đã có cấu hình Compose và mẫu biến môi trường.
- Đã chạy PostgreSQL demo TV3; healthcheck healthy, SELECT 1 qua TCP có xác thực thành công, cổng local 5433 truy cập được.
- Đã có bảng tasks và migration Prisma riêng TV3; đã sinh Prisma Client và đọc thử thành công; đã có service kết nối, đã có CRUD Tasks demo TV3; xem TASKS.md.

## Lưu ý phạm vi TV3

- Project Compose: finai-tv3-demo; database: finai_tv3_demo.
- Chỉ là môi trường thử nghiệm, chưa phải quyết định kiến trúc/schema chung.
- Không dùng file sql.sql PostgreSQL dump đã gửi trước đó.
- Database có 1 bảng nghiệp vụ tasks và bảng lịch sử _prisma_migrations.
- Đã kiểm chứng lưu dữ liệu sau restart app NestJS; chưa test restart container/Windows.
- .env local được tạo bằng mật khẩu ngẫu nhiên; không ghi mật khẩu vào tài liệu.

## Prisma và bảng tasks thử nghiệm

- prisma/schema.prisma mô tả Task, TaskPriority và TaskStatus.
- prisma.config.ts đọc DATABASE_URL bằng Node loadEnvFile, không thêm dotenv.
- Cấu hình CLI chỉ chấp nhận 127.0.0.1:5433/finai_tv3_demo.
- Khi sao chép .env.example, thay mật khẩu trong cả POSTGRES_PASSWORD và DATABASE_URL.
- CHECK trong migration chặn tên trắng và end_at không sau start_at.
- category_id cho phép null, chưa có khóa ngoại hoặc bảng danh mục.
- uuid() và @updatedAt do Prisma quản lý, không phải default/trigger tự động của PostgreSQL.
- Thời điểm dùng timestamptz(3); timezone hiển thị vẫn do application/UI xử lý.
- Đã sinh Prisma Client; script Node đọc tasks thành công. Đã có đầy đủ API CRUD Tasks; chưa có seed tự động.
- Kiểm thử schema đã ghi thử trong transaction rồi ROLLBACK; tasks còn 0 dòng.

Kiểm tra schema và migration:

    npx --no-install prisma validate
    npx --no-install prisma migrate status

Áp dụng migration có sẵn vào database demo:

    npx --no-install prisma migrate deploy

Xem bảng:

    docker compose exec postgres psql -U tv3_demo -d finai_tv3_demo -c "\d tasks"

Chạy lại test schema trong PowerShell, không giữ dữ liệu thử:

    Get-Content test/database/tasks-schema.sql -Raw | docker compose exec -T postgres psql -U tv3_demo -d finai_tv3_demo -v ON_ERROR_STOP=1

Schema và migration ở đây vẫn là mẫu riêng TV3, chưa chốt cho nhóm.
Đã kiểm chứng CRUD qua HTTP/Prisma thật và dữ liệu sau restart NestJS; chưa restart container/Windows.

## Kiểm tra Prisma Client từ Node

Generator trong schema.prisma sinh TypeScript ESM tại src/generated/prisma.
Các import trong code sinh dùng đuôi .js để bản build Node ESM chạy được.
Thư mục generated được ignore; không sửa trực tiếp hoặc commit code sinh.
Sau khi lấy code hoặc đổi model, sinh lại client trước khi build:

    npx --no-install prisma generate
    npm run build
    node scripts/check-prisma.mjs

Script kiểm tra chỉ cho phép database finai_tv3_demo tại 127.0.0.1:5433.
Dùng PrismaPg và PrismaClient, đếm tasks rồi đóng kết nối trong finally.
Không tạo/sửa/xóa dữ liệu, không in DATABASE_URL hoặc mật khẩu.
Kết quả đã kiểm chứng: PASS, số công việc 0; migration vẫn up to date.
Đã nối Prisma vào vòng đời NestJS và API CRUD Công việc; xem TASKS.md.

## PrismaModule và vòng đời NestJS

- PrismaModule tạo adapter/client ở provider factory, chỉ cho phép database demo TV3.
- PrismaService được export để các module khác inject qua NestJS.
- onModuleInit mở kết nối; onModuleDestroy đóng kết nối.
- main.ts bật shutdown hooks; đã có POST /tasks; xem TASKS.md.
- HTTP e2e mẫu override PrismaService bằng fake, không yêu cầu database chạy.
- Unit test kiểm tra mở/đóng kết nối, dọn khi mở lỗi và thông báo lỗi an toàn.

Kiểm tra NestJS cùng PostgreSQL thật:

    npx --no-install prisma generate
    npm run build
    node scripts/check-nest-prisma.mjs

Script mở HTTP trên cổng local ngẫu nhiên, đếm tasks, kiểm tra GET / và app.close().
Kết quả đã kiểm chứng: tasks=0, GET / trả 200 Hello World!, app đóng sạch.
Chưa kiểm chứng signal shutdown trên điện thoại hoặc môi trường deploy.

API CRUD/lọc Công việc local đã được kiểm chứng qua HTTP và PostgreSQL thật; xem TASKS.md để chạy/test và đọc giới hạn.
