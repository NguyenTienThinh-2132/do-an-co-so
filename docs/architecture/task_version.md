> Cập nhật sau bước version: [tombstone đã triển khai](task_tombstones.md) ở bước 4, thay hành vi DELETE mô tả tại thời điểm bước 3 bên dưới. Chưa có sync/receipt. Có lỗi UTC trong CRUD Task cũ đã được ghi rõ tại tài liệu tombstone.

# Phiên bản Task phía backend — 23/11/2026

## Mục đích và phạm vi

`version` là số lần ghi thành công do server quản lý, dùng làm nền cho kiểm tra xung đột đồng bộ ở bước sau. Ví dụ: tạo task version=1, sửa nội dung version=2, đổi trạng thái version=3. Không dùng giờ điện thoại để quyết định dữ liệu nào thắng.

Bước này chỉ thay backend Tasks, thêm migration/test và test tương thích Flutter. Không thêm dependency, không đổi Task/TaskDraft/TaskRepository/Result/AppFailure chung, không sửa bảng tài chính hoặc Native Inbox. PostgreSQL chạy trực tiếp, không cần Docker.

## Quy tắc đã triển khai

- Cột tasks.version INTEGER NOT NULL DEFAULT 1, CHECK version >= 1. Migration: `backend/prisma/migrations/20261123030000_task_version/migration.sql`.
- Bản ghi tồn tại trước migration và bản ghi mới bắt đầu ở 1.
- PUT nội dung và PATCH status tăng 1 ngay trong cùng câu lệnh Prisma update. Không đọc version rồi cộng tại application; hai request đồng thời không làm mất lượt tăng.
- Mọi lần ghi được chấp nhận đều tăng, kể cả gửi lại cùng nội dung/trạng thái. Đây chưa phải cơ chế chống gửi trùng.
- GET/list không tăng version. Request sai validation hoặc ID không tồn tại không thay đổi bản ghi.
- API không cho client đặt version: gửi trường version trong POST/PUT/PATCH bị từ chối 400.
- Response create/read/list/update/status có thêm trường version. Flutter Task hiện có vẫn đọc được; chưa giữ metadata này trong domain/cache v1 hoặc tự chuyển vào TaskLocalStore.
- DELETE vẫn xóa vật lý và trả 204 như trước. Chưa có phiên bản xóa/tombstone.

## Migration và bảo toàn dữ liệu

Đã tạo pg_dump custom backup trước migration trong `build/postgres-before-task-version-*.dump`, và baseline hash/count trong `build/task-version-migration-baseline.json`. Các file này nằm ngoài Git và có thể chứa dữ liệu riêng; không đưa lên repository.

Migration đã chạy trên database demo PostgreSQL native tại 127.0.0.1:5433. Có 0 task người dùng tại thời điểm kiểm tra; đã thêm một task giả sở hữu riêng trước migration để chứng minh row cũ nhận version=1, sau đó xóa đúng fixture này. Hash/count các task gốc và sáu bảng tài chính trước/sau không thay đổi. Kết quả: `build/task-version-migration-result.json`.

Migration chỉ ALTER TABLE thêm cột/constraint, không reset/drop database. Với môi trường khác cần backup và dùng `prisma migrate deploy`; không tự coi database khác đã được nâng cấp.

## Kiểm tra

- Backend: 92 unit test, 44 HTTP e2e test đạt; lint và build đạt.
- API thật với NestJS và PostgreSQL native: 18 request kiểm tra create/read/list/update/status, ghi bị từ chối, ID sai, ghi đồng thời và delete. Tạo=1, sửa=2, status=3; ghi cùng status=4; hai PUT đồng thời nhận 5 và 6. Ghi sai không tăng version; SQL version=0 bị constraint chặn. Fixture được dọn và hash task gốc giữ nguyên. Kết quả: `build/task-version-http-result.json`.
- Flutter: 24 test TaskApiMapper đạt, gồm response thêm version; flutter analyze đạt.
- Chưa kiểm chứng trên điện thoại và chưa có bằng chứng đồng bộ offline/online qua UI trong bước này.

## Tự kiểm tra

```powershell
cd D:/git/do-an-co-so/backend
node scripts/start-postgres-native.mjs
npm run build
node scripts/check-task-version.mjs
```

Script dùng DATABASE_URL trong .env, chỉ cho phép database demo local, mở NestJS tạm trên cổng ngẫu nhiên rồi đóng. Chỉ tạo/sửa/xóa fixture có marker riêng. Không cần dừng backend hiện có; tránh thao tác task đồng thời khi kiểm tra hash dữ liệu.

Mong đợi report có httpChecks=18, newTaskVersion=1, afterEditVersion=2, afterStatusVersion=3, concurrentVersions=[5,6], rejectedWritesKeepVersion=true và existingTasksUnchanged=true; process exit 0. Nếu lỗi, giữ nguyên output để đối chiếu, không reset database.

```powershell
cd D:/git/do-an-co-so
flutter test --concurrency=1 test/unit/features/tasks/data/mappers/task_api_mapper_test.dart
flutter analyze
```

Mong đợi 24 test đạt và No issues found.

## Giới hạn và bước kế tiếp

CRUD hiện tại vẫn áp dụng lần ghi sau; version tăng nguyên tử chưa đồng nghĩa từ chối xung đột. Chưa so sánh baseVersion, chưa có idempotency receipt, tombstone hoặc POST /tasks/sync. Mất kết nối sau server commit vẫn có thể dẫn tới ghi lại bằng CRUD cũ. Chưa inject local Outbox vào UI, chưa ACK/retry hoặc tự đồng bộ khi mạng trở lại. Không áp dụng chức năng này cho tài chính/hũ.

Bước nhỏ tiếp theo dự kiến: lưu tombstone cùng transaction xóa Task để giữ ID/version đã xóa phục vụ sync. Trình bày phạm vi và chờ xác nhận trước khi làm.
