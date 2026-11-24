> Bước 4 (23/11/2026): đã có bảng task_tombstones và DELETE ghi marker cùng transaction. Xem [task_tombstones.md](task_tombstones.md). Chưa có receipt/API sync/engine. Phát hiện sai lệch UTC trong luồng Task cũ, cần xử lý riêng trước khi nối đồng bộ.

> Bước 3 (23/11/2026): backend đã có Task.version, migration và bộ đếm tăng nguyên tử cho PUT/PATCH. Xem [task_version.md](task_version.md). Chưa có so sánh baseVersion, receipt, tombstone, API sync hoặc engine. Các mô tả thiết kế chưa triển khai được phân biệt bên dưới.

> Bước 2 (23/11/2026): đã tạo kho local/Outbox và schema v1 riêng của Tasks, kiểm tra transaction/reopen trên SQLite host. Xem [task_local_outbox.md](task_local_outbox.md). Các mục CHƯA trong phần trạng thái bước model bên dưới là lịch sử bước 1; API/engine/UI đồng bộ vẫn chưa triển khai.

# Hợp đồng Outbox và đồng bộ Công việc — v1, 23/11/2026

## Trạng thái của bước này

Đã tạo model TaskSyncOperation, enum TaskOutboxStatus và mapper request. Đây là hợp đồng cho các bước triển khai tiếp theo. CHƯA tạo bảng/migration, CHƯA có route /tasks/sync chạy thật, CHƯA ghi offline hoặc tự đồng bộ khi mạng trở lại. Không thay Task, TaskDraft, TaskRepository, Result/AppFailure, API CRUD, reminder hay UI hiện có.

Chỉ áp dụng module Tasks. Không áp dụng tự động cho tài chính, hũ, thông báo ngân hàng hoặc AI.

## Luồng được chốt cho thiết kế

Mỗi thao tác mới ghi projection công việc local và Outbox trong CÙNG một transaction SQLite, dù hiện tại đang online hay offline. Sau commit local, sync engine mới gửi API. Như vậy mất mạng sau khi server đã commit vẫn có cùng operationId để retry, không tạo task thứ hai.

TaskStatus là nghiệp vụ (pending/inProgress/completed); TaskOutboxStatus là tình trạng gửi dữ liệu (pending/sending/synced/conflict/failed). Một việc completed vẫn có thể đang pending đồng bộ. Không coi local Success là server đã xác nhận.

PostgreSQL vẫn là nơi xác nhận phiên bản server. Local giữ bản đã tải và projection từ các thao tác chưa xác nhận; refresh từ server không được ghi đè/mất những thao tác này. Không so toàn bộ snapshot theo đồng hồ điện thoại để đoán bên nào mới hơn.

## Model thao tác (đã có Dart)

File: lib/features/tasks/domain/sync/task_sync_operation.dart.

| Field | Quy ước |
| --- | --- |
| operationId | UUID được sinh một lần cho mỗi ý định; retry giữ nguyên |
| taskId | UUID công việc, sinh từ client khi tạo offline; giữ nguyên sau sync |
| kind | create, update, setStatus, delete |
| draft | Chỉ create/update; dùng TaskDraft đã validation |
| status | Chỉ setStatus; dùng TaskStatus hiện có |
| baseVersion | Phiên bản server đã xác nhận, số nguyên >=1; create là null |
| dependsOnOperationId | Op trước của cùng task, dùng khi chưa có version của op trước |
| queuedAt | UTC, chỉ ghi nhận local; không quyết định thắng xung đột và không gửi vào API |

Các UUID chuẩn hóa lowercase, không nhận khoảng trắng. Named factories kiểm soát payload theo loại. Một thao tác sửa/status/xóa phải có CHÍNH XÁC một trong baseVersion hoặc dependsOnOperationId. Không được tự phụ thuộc chính operationId.

isReadyToSend=true khi create hoặc đã biết baseVersion. resolveDependency chỉ mở khóa bằng ACK đúng operationId phụ thuộc và đúng taskId, có serverVersion dương. Nó trả model mới, giữ nguyên ID/nội dung/queuedAt; model cũ không đổi. Đây chưa phải việc gửi request.

## Tạo rồi sửa trước khi có mạng

Ví dụ:

- A: create task T, baseVersion=null.
- B: update task T, baseVersion=null, dependsOn=A. Không được gửi B lúc này.
- Server xác nhận A: T version=1.
- Queue giải quyết B thành request baseVersion=1, lưu request đã giải quyết vào DB trước lần gửi đầu tiên.
- C: thay đổi tiếp theo phải chờ B nếu B chưa ACK. Không dùng lại version=1 để gửi C sau khi B đã tăng version.

Storage bắt buộc kiểm tra dependency tồn tại, thuộc cùng namespace/task, có sequence nhỏ hơn và không phải delete. Quy tắc này ngăn vòng phụ thuộc; model đơn lẻ chưa truy vấn DB để kiểm tra đồ thị. Không tự gộp/sửa payload đã từng gửi.

## API đề xuất, chưa triển khai

POST /tasks/sync, từng thao tác một. TaskSyncRequestMapper.toJson chỉ dựng body; không gọi mạng và từ chối operation chưa giải quyết dependency.

```json
{
  "operationId": "00000000-0000-4000-8000-000000000002",
  "taskId": "10000000-0000-4000-8000-000000000001",
  "kind": "setStatus",
  "baseVersion": 1,
  "payload": {"status": "completed"}
}
```

- create: baseVersion=null; payload đúng TaskDraft; server đặt status=pending và timestamps do server quản lý. Sync endpoint chấp nhận client UUID, API POST /tasks cũ vẫn cấp ID như trước.
- update: baseVersion>=1; payload đầy đủ TaskDraft, giữ status/createdAt/id.
- setStatus: baseVersion>=1; payload chỉ có status.
- delete: baseVersion>=1; payload=null.
- Không gửi dependsOnOperationId, queuedAt, trạng thái Outbox hoặc timestamp local vào request. Không dùng API ghi hiện tại để thử request này.

ACK 200 (cả tạo/sửa/status/xóa), ví dụ:

```json
{
  "operationId": "00000000-0000-4000-8000-000000000002",
  "taskId": "10000000-0000-4000-8000-000000000001",
  "version": 2,
  "deleted": false,
  "task": {"...": "full Task read model from server"}
}
```

Ví dụ task là ký hiệu rút gọn để đọc tài liệu, không phải response JSON để chạy test. Khi delete: deleted=true, task=null, version là phiên bản tombstone mới. Client phải đối chiếu operationId/taskId trước khi nhận ACK.

409 trả code phân biệt version_conflict, task_deleted, task_id_exists hoặc operation_id_reused; kèm current version/snapshot hoặc tombstone khi có. Không tự đổi baseVersion rồi ghi đè. Resolver phải đọc lại server và tạo operationId MỚI nếu người dùng quyết định áp dụng một thay đổi mới. Thao tác cũ được giữ để tra cứu/giải quyết.

400/422 là validation không tự retry cùng ý định sai. 401/403 tạm dừng sync của namespace, giữ local/outbox và chờ khôi phục quyền. 429/5xx/timeout/mất kết nối được retry có backoff với đúng operationId và body đã đóng băng, không bỏ bản ghi chỉ vì đã thử nhiều lần.

## Chống gửi trùng và phiên bản server (version/tombstone đã có, receipt còn đề xuất)

Server phải kiểm tra receipt trước kiểm tra baseVersion. Receipt cùng operationId/context và cùng canonical request hash trả lại kết quả đã ghi. Cùng ID nhưng khác body trả operation_id_reused, không thực hiện dữ liệu mới.

Trong transaction server: kiểm tra receipt -> kiểm tra ID/version/tombstone -> áp dụng dữ liệu hoặc xác định conflict -> ghi receipt/kết quả -> commit. Chỉ ACK sau commit. Cần xử lý cạnh tranh request cùng operation và task, không chỉ kiểm tra ở application rồi ghi rời rạc.

Trạng thái thay đổi PostgreSQL:

1. ĐÃ TRIỂN KHAI: Task.version integer mặc định 1 cho bản ghi đang có/tạo mới; PUT và PATCH status tăng version ngay trong câu lệnh update. CHƯA có sync dùng điều kiện id+version; CRUD hiện tại vẫn chưa từ chối xung đột.
2. task_sync_receipts lưu context, operationId, hash và kết quả terminal đã xác định. Lưu cả applied và conflict của request hợp lệ để không thể đổi nội dung cùng operationId sau conflict. Lỗi trước authentication/validation không được coi là đã áp dụng.
3. ĐÃ TRIỂN KHAI: task_tombstones lưu taskId, version tăng lên và deletedAt cùng transaction DELETE /tasks/:id hiện có. Chưa có sync tạo ID từ client; endpoint đó sau này phải chặn tái sử dụng ID có tombstone.

Version đã có trong Prisma, PostgreSQL và response CRUD; domain Flutter Task giữ nguyên và đọc được response thêm trường. Receipt vẫn chỉ là thiết kế; tombstone đã triển khai ở bước 4. Chưa nối adapter đọc version từ API vào TaskLocalStore; cache đọc v1 vẫn không giữ version.

Cache v1 hiện chưa có server version: sau nâng cấp, task cũ phải được tải online ít nhất một lần để có version trước khi sửa offline. Không tự đoán baseVersion=1 từ bản cache không có version.

## Outbox SQLite (đề xuất cho bước sau)

Task local và Outbox phải dùng cùng kết nối/file để ghi nguyên tử. Chỉ thêm bảng thuộc Tasks, không sửa dữ liệu hũ/tài chính hoặc Native Inbox.

- tasks_local: namespace+taskId; bản server/phiên bản đã tải; projection local; cờ xóa local/server và metadata thay đổi local. Projection chưa ACK không bị refresh đè mất. Thời gian tạm của task mới không phải timestamp server.
- task_outbox: sequence, namespace, operationId unique trong namespace, taskId, kind, payload, baseVersion/dependsOn, queuedAt, state, attemptCount, frozenRequestJson, lastFailure, nextRetryAt, ackVersion/ackResponse.
- Cache query snapshot/coverage hiện có dùng để biết khoảng dữ liệu nào đã tải đủ. Không suy ra server đã xóa task chỉ từ một response lọc ngày/trạng thái/tìm kiếm không chứa task đó.

Request sau khi resolve dependency được ghi frozenRequestJson trước lần gửi đầu. Retry dùng lại request này. Khi ACK: transaction local ghi bản server/version + giữ/replay projection của các op tiếp theo + đánh dấu synced; chỉ sau đó mới xét dọn Outbox. Không xóa op cha khi op con chưa nhận được version cần thiết.

Trạng thái:

- pending: chờ gửi, phụ thuộc hoặc backoff.
- sending: request đã đóng băng và đang gửi; khởi động lại app đưa sending về pending để retry cùng request.
- synced: ACK đã được lưu local; chưa có cleanup tự động trong bước này.
- conflict: giữ thay đổi, chặn các op phụ thuộc cùng task; các task độc lập có thể tiếp tục.
- failed: lỗi validation/protocol không tự sửa và gửi lại. Giữ để người dùng xử lý.

Chưa triển khai kho local, transaction, query overlay, scheduler, retry hoặc conflict UI ở bước này.

## Khi mạng trở lại

Sync engine trong các bước sau chạy khi app mở/resume, có lệnh chờ và API có thể truy cập; retry có backoff trong lúc app hoạt động. Wi-Fi là tín hiệu, không phải bằng chứng API đã kết nối. Khi app bị đóng/OS kết thúc tiến trình thì đồng bộ ở lần mở sau; chưa có Android background job để đánh thức app.

UI sẽ cần nhãn Chờ đồng bộ/Đang đồng bộ/Xung đột và xử lý lỗi; phải trình bày theo quy trình UI đã chốt trước khi thực hiện. Không tự làm màn mới trong bước model này.

## Kiểm tra và hướng dẫn tự test

9 test mới kiểm tra UUID/UTC, payload theo kind, version bắt buộc, tạo->sửa phụ thuộc, ACK sai task/operation, không đổi base đã đóng băng, chống self-dependency và canonical UUID. Chạy kèm 23 test mapper hiện có: 32 test đạt. flutter analyze cuối đạt: No issues found.

```powershell
cd D:/git/do-an-co-so
flutter test --concurrency=1 test/unit/features/tasks/domain/sync test/unit/features/tasks/data/mappers
flutter analyze
```

Mong đợi All tests passed và No issues found. Không có thao tác UI mới để thử; app vẫn chưa lưu thay đổi offline hoặc đồng bộ hai chiều.

## Bước nhỏ tiếp theo dự kiến

Tạo migration SQLite và kho local/Outbox tối thiểu theo hợp đồng, kiểm tra transaction lưu task+operation và đọc lại sau restart. Sau đó mới làm API chống trùng/version và engine gửi. Mỗi bước kiểm tra riêng; chưa đánh dấu toàn bộ tính năng hoàn thành.
