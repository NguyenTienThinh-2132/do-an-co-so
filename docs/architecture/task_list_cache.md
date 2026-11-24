# Cache danh sách Công việc — 23/11/2026

## Phạm vi bước này

Đã nối ResponseCache vào HttpTaskRepository.watch(query) và inject SqliteResponseCache tại composition root Android trong lib/dev/main_tasks_day_demo.dart. Bản gộp lib/main.dart dùng cùng root nên cũng nhận cache này. Không sửa UI, routing, schema SQLite/PostgreSQL, TaskRepository/Result/AppFailure dùng chung hoặc thêm dependency.

Chỉ danh sách Công việc có fallback cache. Chi tiết getById, form tạo/sửa/xóa/đổi trạng thái vẫn cần API. Home/Hũ/Dòng tiền vẫn đang dùng FallbackFinanceRepository và fake khi API lỗi; chưa nối cache tài chính.

## Luồng đọc và ghi

1. watch(query) gọi GET API trước. Response hợp lệ được đưa lên controller/UI và tự xếp một lệnh ghi cache. Cache ghi lỗi không đổi API Success thành Failure.
2. Lỗi http.ClientException, timeout hoặc HTTP 5xx được phân biệt bằng TaskAvailabilityFailure (subtype của AppFailure, không đổi enum chung). Chỉ các lỗi này cho phép đọc cache.
3. Nếu có bản cache hợp lệ cho đúng namespace/query, phát Success với danh sách đã lưu. Khi không có cache hoặc payload hỏng, giữ lỗi kết nối; không tạo danh sách rỗng giả.
4. HTTP 400/401/403/404/409/422/429 và payload/UTF-8/enum sai không lấy cache che lỗi. Sau permissionDenied, cache danh sách trong namespace bị xóa và owner hiện tại không đọc/ghi cache nữa; cần tạo owner mới khi đăng nhập/lấy lại quyền.
5. Response danh sách rỗng [] vẫn ghi đè cache đúng khóa. Không giữ lại task cũ khi API trả rỗng hợp lệ.
6. Khi app resume hoặc người dùng tải lại/Hôm nay, repository gọi API lại. Không thêm polling hay package theo dõi Wi-Fi; quyền truy cập API được xác định bằng kết quả request thật.

Đây là network-first có fallback, không phát cache ngay trước khi thử API. Nếu mạng bị treo, có thể chờ timeout hiện có 15 giây rồi mới hiển thị cache. Cache chỉ bảo đảm cho khoảng ngày/bộ lọc đã tải trước đó; ngày hoặc bộ lọc chưa có cache vẫn có thể báo lỗi khi offline.

## Khóa và storage

- Android mở lazy file riêng `finai_read_cache.db` qua CacheDatabase.inDefaultDirectory. sqflite tự giải quyết filename tương đối trong thư mục database riêng của app, không cần chờ native path trước khi khởi tạo UI.
- Namespace: TASKS_CACHE_SCOPE (mặc định finai-native18-v1) + endpoint API + tasks-list-v1. Đổi API hoặc nguồn database/tài khoản phải đổi scope; khi có auth thật cần đưa user ID vào scope và xóa cache khi logout.
- Resource: tasks.list.v1. Query key là JSON có thứ tự khóa cố định của start/end UTC, status, priority và searchText đúng hợp đồng HTTP. Không trộn ngày/tháng/bộ lọc hoặc server khác.
- TaskApiMapper.toJson lưu đầy đủ read model (ID, tên, mô tả, category, start/end, priority/status, created/updated). POST/PUT vẫn dùng draftToJson, không gửi các field chỉ đọc.
- Không ghi vào SQLite Native Inbox và không tạo nguồn số dư/giao dịch khác.

## Chống dữ liệu cũ

- Cache jobs chạy tuần tự. Mỗi request có thứ tự; response từ request bắt đầu trước không được ghi đè snapshot đã nhận từ request mới hơn cho cùng query.
- Refresh/mutation làm tăng revision của watcher để bỏ response đang chờ đã cũ.
- Sau một thao tác create/update/status/delete được API xác nhận thành công, tất cả cache LIST của namespace task này bị vô hiệu hóa/xóa. Các watcher đang mở tải lại và lưu snapshot mới. Cache của các khoảng ngày không mở được xóa để tránh task đã sửa/xóa xuất hiện lại.
- Ghi API thất bại không tự retry và không giả lưu offline, không xóa cache đã có. Không có hàng đợi ghi offline.
- Nếu xóa cache thất bại, owner hiện tại chặn fallback dữ liệu cũ; lần tải API thành công sau sẽ thử xóa lại trước khi ghi cache mới. Lỗi lưu trữ kéo dài không thể bảo đảm mọi snapshot mới đã được lưu; chưa có UI cảnh báo cache-error ở bước này.
- Khi owner dispose, repository ngừng nhận request mới; composition root chờ cacheSettled rồi mới đóng database.

## Kiểm tra đã chạy

- 63 test datasource/mapper/repository hiện có vẫn đạt sau thay đổi ban đầu.
- 28 test mới ở test/unit/features/tasks/data/repositories/task_list_cache_test.dart đạt: online->offline qua owner mới, snapshot rỗng, miss, namespace/ngày/status/priority/search và UTC, timeout/5xx, lỗi quyền/validation/bad payload, lỗi ghi SQLite, invalidation CRUD, ghi thất bại, hai response lệch thứ tự, mutation trong lúc cache ghi, invalidate thất bại và phục hồi, cache Task hỏng.
- test/integration/tasks_list_cache_sqlite_test.dart đạt: TaskRepository + sqflite Dart + SQLite thật trên host, response HTTP là fixture. Sau khi đóng repository, database và tiến trình SQLite rồi tạo mới, controller nhận ready với Task đã lưu khi HTTP bị lỗi kết nối. Sau API trả [], restart rồi offline vẫn ra danh sách rỗng.
- Lượt đầy đủ flutter test có CACHE_SQLITE_NODE: 279 test đạt, 6 test yêu cầu backend URL thật được skip trong lượt này. Không coi test HTTP fixture là kiểm chứng backend/điện thoại thật.
- flutter analyze cuối đạt, không có vấn đề. APK debug lib/main.dart với API base URL http://127.0.0.1:3000 build thành công (79,5 giây); dùng thư mục tạm ổ D cho build. Còn cảnh báo SDK XML 3/4 không chặn build. ADB hiện chưa có điện thoại; chưa cài/kiểm chứng cache này trên thiết bị Android.

Lệnh chạy lại:

```powershell
cd D:/git/do-an-co-so
flutter test --concurrency=1 test/unit/features/tasks/data
flutter test --concurrency=1 test/integration/tasks_list_cache_sqlite_test.dart --dart-define=CACHE_SQLITE_NODE=D:/nodejs/node.exe
flutter analyze
```

## Tự test trên Android khi có thiết bị

Terminal backend:

```powershell
cd D:/git/do-an-co-so/backend
node scripts/start-postgres-native.mjs
npm run start:dev
```

Terminal Flutter, dùng bản chạy chính (không dùng cache_probe):

```powershell
cd D:/git/do-an-co-so
adb reverse tcp:3000 tcp:3000
flutter run -t lib/main.dart --dart-define=TASKS_API_BASE_URL=http://127.0.0.1:3000
```

1. Mở Công việc ở một ngày cụ thể, tải được danh sách. Nếu DB mới đang rỗng, tạo một task thử trong ngày đó rồi đợi danh sách cập nhật.
2. Dừng riêng API bằng Ctrl+C ở terminal Nest hoặc tháo USB. Khi nối API qua adb reverse, chỉ tắt Wi-Fi/chế độ máy bay chưa chắc làm API mất kết nối vì đường USB vẫn hoạt động.
3. Tải lại cùng ngày và cùng bộ lọc: task đã tải vẫn hiển thị. Đóng/mở lại app, chọn đúng ngày/bộ lọc đã tải: vẫn đọc được danh sách từ SQLite.
4. Chạy API lại, trở về app hoặc bấm Hôm nay/tải lại: dữ liệu server mới hiển thị và cập nhật cache.
5. Khi online xóa hết các task thử của ngày đó, đợi list về rỗng, rồi dừng API và mở lại cùng query: vẫn rỗng, không hồi sinh task đã xóa.

Không yêu cầu điện thoại thực hiện giao dịch ngân hàng. Trong bước này mở chi tiết task khi offline vẫn có thể báo lỗi; đó là phần chưa triển khai.

## Bước tiếp theo cần người dùng duyệt

Cache chi tiết công việc theo ID, xử lý task đã xóa và thống nhất invalidation với list. UI nhãn offline/thời gian cập nhật và cache tài chính làm ở các bước riêng; chưa triển khai hoặc tự thiết kế mới.

Bổ sung 23/11/2026: đã tạo model/hợp đồng Outbox ở [task_sync_contract.md](task_sync_contract.md); chưa tạo bảng hoặc nối sync runtime.
