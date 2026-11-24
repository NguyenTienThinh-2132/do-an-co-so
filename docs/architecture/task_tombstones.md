# Dấu xóa Công việc — 23/11/2026

## Đã triển khai

Thêm bảng PostgreSQL task_tombstones gồm task_id (khóa chính TEXT cùng kiểu tasks.id), version INTEGER >= 2, deleted_at TIMESTAMPTZ(3). Không có FK tới task vì task đã bị xóa. Không sao chép tên, mô tả hoặc nội dung task vào marker. Migration chỉ tạo bảng mới, không đổi/xóa dữ liệu Tasks hoặc tài chính đang có.

DELETE /tasks/:id dùng Prisma interactive transaction:

1. SET LOCAL TIME ZONE UTC, chỉ hiệu lực trong transaction xóa.
2. DELETE task và lấy version mới nhất của row do PostgreSQL khóa.
3. INSERT tombstone có taskId và version = version vừa xóa + 1; database sinh deletedAt bằng CURRENT_TIMESTAMP.
4. Commit rồi trả 204 với body rỗng. Nếu bước ghi marker lỗi, toàn bộ transaction rollback và API trả 503 không chứa chi tiết SQL. Marker cũ không bị upsert/ghi đè.

Ví dụ task version=3 thì marker version=4. GET task đã xóa trả 404; danh sách không chứa task. Xóa lại hoặc sửa/status ID đã xóa vẫn trả 404, marker và timestamp giữ nguyên. Hai DELETE đồng thời chỉ một lệnh trả 204, lệnh còn lại 404 và chỉ có một marker. Khi PUT và DELETE cạnh tranh, marker dùng version của row thực sự bị xóa, không dùng snapshot đọc trước khi khóa.

DB default dùng @default(dbgenerated("CURRENT_TIMESTAMP")) thay vì @default(now()) để Prisma bỏ cột deleted_at khi INSERT; thời điểm được database quyết định. Không đổi múi giờ global/session dùng chung hoặc dữ liệu lịch sử.

## File chính

- backend/prisma/schema.prisma: model TaskTombstone.
- backend/prisma/migrations/20261123040000_task_tombstones/migration.sql: bảng/constraint.
- backend/src/tasks/tasks.service.ts: xóa và ghi marker cùng transaction.
- backend/src/tasks/tasks-management.service.spec.ts, backend/test/tasks-management.e2e-spec.ts: transaction, lỗi và HTTP cũ.
- backend/scripts/check-task-tombstones.mjs: kiểm tra NestJS/PostgreSQL thật, chỉ fixture sở hữu riêng và tự dọn.
- backend/scripts/check-task-version.mjs: bổ sung dọn tombstone do fixture của script tạo.

Không thay dependency, Flutter, UI hoặc interface dùng chung; không commit/push Git.

## Bằng chứng kiểm tra

- 94 unit test và 45 HTTP e2e test đạt sau thay đổi cuối; lint và build backend đạt.
- 20 request HTTP thật với PostgreSQL native: phiên bản 3 -> marker 4, 204/body rỗng, GET/list sau xóa, xóa/sửa/status lại ID, ID thiếu, duplicate DELETE, race PUT/DELETE.
- Ép lỗi marker bằng cách tạo trước marker trùng cho chính fixture: DELETE trả 503, task gốc còn nguyên và marker không bị thay. Sau khi dọn marker lỗi thử nghiệm, DELETE bình thường thành công.
- Mở kết nối PostgreSQL mới vẫn đọc được marker; kiểm tra thời gian theo clock database đạt và CHECK version >= 2 chặn version=1.
- Sau dọn fixture, hash/count task, tombstone cũ và sáu bảng tài chính giữ nguyên. Kết quả: build/task-tombstone-http-result.json.
- Script version cũ vẫn đạt 18 request. prisma migrate status xác nhận đủ 4 migration, database up to date.
- Backup trước migration: build/postgres-before-task-tombstones-*.dump; baseline/result: build/task-tombstone-migration-*.json. Backup có thể chứa dữ liệu riêng, không đưa lên Git. Hash/count Tasks và sáu bảng tài chính trước/sau migration giữ nguyên; bảng marker mới ban đầu rỗng.
- Chưa kiểm tra trên điện thoại; chưa cần build APK vì không thay Flutter.

## Tự kiểm tra

```powershell
cd D:/git/do-an-co-so/backend
node scripts/start-postgres-native.mjs
npm run build
node scripts/check-task-tombstones.mjs
```

Không cần Docker/điện thoại, không cần dừng API đang chạy; script mở NestJS trên cổng local ngẫu nhiên rồi đóng. Cần DATABASE_URL đúng của database demo local, migration đã áp dụng. Tránh người khác chỉnh dữ liệu trong lúc kiểm tra hash.

Mong đợi dòng PASS và các giá trị: httpChecks=20, deletedTaskVersion=3, tombstoneVersion=4, rollbackPreservesTask=true, concurrentDeleteStatuses=[204,404], freshConnectionReadsMarker=true, existingDataUnchanged=true, fixturesCleaned=true; process exit 0. Race PUT/DELETE có thể cho PUT 200 hoặc 404 hợp lệ tùy thứ tự khóa; marker tương ứng 3 hoặc 2. Nếu test lỗi, không reset database.

## Giới hạn và lỗi phát hiện

Đây chưa phải API đồng bộ hoặc receipt chống gửi trùng. Chưa có endpoint đưa tombstone về Flutter, chưa so baseVersion, chưa giữ operationId/ACK và chưa bật đồng bộ khi mạng trở lại. DELETE cũ vẫn trả 404 khi gọi lại; chưa coi retry là thành công idempotent. Chưa có quy trình dọn marker hay khôi phục ID đã xóa; endpoint sync tạo ID từ client sau này phải kiểm tra marker trước khi tạo lại. Dữ liệu bị xóa trước migration không thể tự khôi phục thành marker. SQL ngoài TasksService có thể bỏ qua marker.

Phát hiện quan trọng trong lúc test: Prisma adapter hiện tại gửi giá trị DateTime theo UTC nhưng không có offset, và PostgreSQL native session mặc định Asia/Bangkok. Luồng Tasks cũ lưu startAt của fixture lệch -25.200.000 ms (7 giờ) so với đầu vào; response POST/GET vẫn khớp đầu vào do adapter chuẩn hóa offset khi đọc. Vì vậy test chỉ round-trip HTTP có thể không phát hiện. Bằng chứng fixture đã dọn: build/task-tombstone-time-audit.json. Đây là lỗi hiện có được xác nhận, chưa sửa ngoài transaction DELETE trong bước này. Không tự cộng 7 giờ hàng loạt cho dữ liệu cũ: có thể có dữ liệu từ nhiều nguồn/môi trường và phải đối chiếu trước.

Bước nhỏ tiếp theo đề xuất: chuẩn hóa UTC cho kết nối/đường CRUD Tasks và kiểm tra bằng epoch lưu thật; xác định ảnh hưởng dữ liệu cũ trước khi sửa chúng. Sau đó mới triển khai receipt/API sync. Cần người dùng xác nhận trước khi tiếp tục.
