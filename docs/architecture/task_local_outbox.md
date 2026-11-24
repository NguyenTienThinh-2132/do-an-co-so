# Kho local và Outbox của Tasks — 23/11/2026

## Phạm vi đã triển khai

Đã có code database/schema SQLite v1, model bản ghi local/Outbox, mapper lưu trữ và TaskLocalStore. Không thay Task/TaskDraft/TaskRepository/Result/AppFailure chung hoặc thêm dependency. Không thay PostgreSQL, cấu hình Docker/native hoặc Native Inbox.

Bước này CHƯA inject store vào repository/UI đang chạy, chưa cho form lưu offline, chưa có API /tasks/sync hoặc engine gửi/ACK/retry. Các bảng mới đã được tạo trong database kiểm tra; trên điện thoại chúng chỉ xuất hiện khi owner mở TasksLocalDatabase ở bước tích hợp sau. Không coi schema/model là đã hoàn thành đồng bộ hai chiều.

## File và tổ chức lưu trữ

- domain/sync/local_task_record.dart: projection hiện tại, cờ xóa local/pending và baseline server/phiên bản.
- domain/sync/task_outbox_entry.dart: intent gốc, sequence, trạng thái, số lần thử, frozen request, lỗi/retry và ACK metadata.
- data/local/tasks_local_database.dart: owner kết nối, schema v1, foreign keys/index/check constraints.
- data/local/task_local_store.dart: nhập baseline server, enqueue transaction, đọc task/list/outbox theo namespace.
- data/mappers/task_sync_storage_mapper.dart: JSON storage v1 giữ cả thao tác chưa giải quyết dependency; tách khỏi JSON request API.
- TaskApiMapper thêm draftFromJson dùng cùng validation ISO/enum/domain, không đổi các mapper đang có.

Database riêng `finai_tasks_local.db` chứa CẢ tasks_local và task_outbox để ghi nguyên tử. Tách khỏi finai_read_cache.db giúp giữ cache đọc hiện tại và schema chung nguyên vẹn; không mở finai_tv3_native.db. Owner tạo một TasksLocalDatabase rồi inject cùng kết nối cho các store namespace; chỉ owner đóng DB khi các thao tác đã kết thúc.

Schema được tạo lần đầu khi mở DB version=1; chưa có phiên bản cũ để chuyển. Không có reset/drop/downgrade xóa dữ liệu. Các thay đổi schema tương lai phải tăng version và có migration rõ ràng.

## Hai bảng

### tasks_local

Khóa ghép namespace + task_id. local_json là projection dùng để hiển thị; local_deleted giữ dấu xóa đang chờ. server_json/server_version/server_deleted là baseline xác nhận từ server, độc lập projection. Namespace phải chỉ rõ môi trường/server/tài khoản; store không tự suy đoán tài khoản từ dữ liệu.

### task_outbox

Sequence tăng dần, unique(namespace, operation_id), khóa ngoại đến task và thao tác phụ thuộc cùng namespace. Lưu kind, operation_json, base_version, depends_on_operation_id, queued_at_ms, state, attempt_count, frozen_request_json, last_failure_code, next_retry_at_ms, ack_version và ack_response_json.

Constraints chặn baseVersion không dương, kind/state lạ, self-dependency, tổ hợp baseVersion/dependency không hợp lệ. Không được đặt sending khi thiếu frozen request/số lần thử hoặc synced khi thiếu ACK metadata. Đây là hàng rào DB, không thay việc xác thực ACK thật trong engine ở bước sau.

## Các phương thức có thể kiểm tra độc lập

- saveServerSnapshot(task, version): thêm/cập nhật baseline có version dương. Snapshot cũ hơn bị bỏ qua; cùng version nhưng nội dung khác trả conflict. Không tự gán version cho cache v1 không có metadata server.
- enqueue(operation): suy ra projection từ thao tác rồi ghi projection + intent trong CÙNG transaction. Lỗi ở bước insert Outbox rollback luôn projection.
- getById(id, includeDeleted=false): Success(null) khi chưa có hoặc đã xóa local; includeDeleted=true dùng để xem record/tombstone local phục vụ đồng bộ sau.
- list(query): trả các task ĐÃ BIẾT trong local, theo khoảng [start,end), overlap, trạng thái, ưu tiên, tìm tên Unicode không phân biệt hoa thường; sort startAt rồi ID. Chưa biết được toàn bộ corpus server hoặc coverage của query; chưa được dùng để khẳng định server không còn task.
- getOutbox(includeSynced=false): các thao tác chưa synced, theo sequence tăng dần. Chưa có phương thức gửi mạng hoặc chuyển trạng thái lifecycle.

Lỗi trả Result/Failure và AppFailureCode rõ ràng; không lộ SQL/payload/đường dẫn database trong message. Task không tồn tại trả notFound; ID/phiên bản sai trả validation; sai dependency/ID trùng khác nội dung trả conflict; lỗi DB/dữ liệu hỏng trả unavailable.

## Quy tắc enqueue

- Create dùng UUID cố định từ TaskSyncOperation, projection status=pending và timestamp local tạm bằng queuedAt. Các thời điểm tạm không phải phiên bản/timestamp xác nhận của server.
- Với task đã tải: operation đầu phải có baseVersion đúng baseline local.
- Nếu đang có thao tác chờ/sending, thao tác mới phải phụ thuộc CHÍNH XÁC tail trước của cùng task. Không dựa lại vào version cũ hoặc phụ thuộc task/tài khoản khác. FK và kiểm tra append-only giữ thứ tự đồ thị.
- Không sửa lại task đang chờ xóa; không tái sử dụng ID của task đã tồn tại/tombstone. Xóa local là soft delete, vẫn giữ projection và Outbox.
- Cùng operationId và cùng intent lưu trữ trả record HIỆN TẠI, không tạo thêm row hoặc quay projection về bản cũ. Cùng ID nhưng đổi intent (kể cả queuedAt) trả conflict. Lần thử gửi lại sau này phải đọc row đã lưu, không tạo queuedAt mới rồi enqueue lại.
- Update có thể xóa description/categoryId bằng null; không vô tình giữ field cũ. Status là thao tác riêng.

## Refresh và request đã đóng băng

Nếu có thao tác chưa ACK, refresh server chỉ cập nhật baseline/version, giữ nguyên local_json/local_deleted và các intent đang chờ. Không tự đổi baseVersion của intent cũ cho khớp bản server mới; engine sẽ xử lý conflict sau.

operation_json lưu ý định ban đầu bất biến, có thể còn dependsOnOperationId. Khi engine giải quyết được dependency, nó dùng bản TaskSyncOperation đã resolve để tạo frozen_request_json trước lần gửi đầu. Bản request này chứa baseVersion đã biết; không cần sửa operation_json/dependency gốc. Retry dùng nguyên frozen request.

Parent Outbox được giữ vì FK; cleanup sau này phải xét dependency/ACK và thứ tự leaf-first. Chưa có cleanup, ACK handler, resolve dependency trong DB hoặc phục hồi sending->pending tự động trong bước này. Các test dựng row sending bằng SQL là fixture kiểm tra schema, không phải bằng chứng engine đã triển khai.

## Kết quả kiểm tra

- 3 test mới cho mapper storage, gồm round-trip cả bốn kind, giữ microsecond/UTC, dependency chưa sẵn sàng, format/time/payload sai.
- 17 test SQLite thật trên host: save baseline, enqueue/durable reopen cả tiến trình, chuỗi create->edit->status->delete, idempotent enqueue, ID reuse, base version, nullable clearing, dependency sai, namespace isolation, refresh không đè local, rollback khi ép lỗi INSERT (cả create và update), duplicate enqueue đồng thời, lọc/sort, dữ liệu hỏng, check sending/synced/frozen và lỗi input/DB đóng.
- Chạy cùng 23 test API mapper + 9 test model sync đang có: 52 test đạt.
- Bộ test dùng sqflite Dart thật, method-channel transport kiểm tra nối tới SQLite của Node. Không dùng một fake JSON file thay database; nhưng không phải kiểm chứng plugin Android/điện thoại thật.
- flutter analyze cuối đạt: No issues found. Chưa tạo APK mới vì code store chưa nối vào app; chưa chạy thao tác UI hoặc API sync.

## Tự kiểm tra

```powershell
cd D:/git/do-an-co-so
flutter test --concurrency=1 test/unit/features/tasks/data/mappers/task_sync_storage_mapper_test.dart test/integration/tasks_local_outbox_sqlite_test.dart --dart-define=CACHE_SQLITE_NODE=D:/nodejs/node.exe
flutter analyze
```

Mong đợi 20 test đạt và No issues found. Máy kiểm tra cần Node có module node:sqlite (máy hiện tại dùng D:/nodejs/node.exe); không cần Docker, backend hoặc điện thoại. File test nằm dưới build/task_local_test_runs/, dùng dữ liệu giả và không ghi vào database ứng dụng/native/server.

Nếu không truyền CACHE_SQLITE_NODE, các test SQLite host được skip; không coi lượt skip là kiểm chứng lưu bền.

## Bước nhỏ tiếp theo dự kiến

Backend version đã hoàn tất ở bước riêng: xem [task_version.md](task_version.md). Tombstone đã triển khai ở bước riêng: xem [task_tombstones.md](task_tombstones.md). Trước khi làm receipt/API sync, cần xử lý lỗi UTC được phát hiện trong CRUD Task cũ; sau đó mới nối adapter metadata và engine gửi/ACK. Phần UI pending/conflict phải được duyệt riêng theo mẫu. Chưa bật đồng bộ hai chiều trong app.
