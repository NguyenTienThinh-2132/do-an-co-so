> Cập nhật 23/11/2026: đã inject cache vào danh sách Công việc trên Android; xem [task_list_cache.md](task_list_cache.md). Chi tiết task và tài chính chưa nối cache. Root tài chính vẫn có fallback dữ liệu fake. Các phần bên dưới mô tả nền tảng cache và trạng thái lịch sử của bước 1.

# Cache đọc — bước 1, ngày 13/11/2026

## Mục tiêu và giới hạn tại bước 1 (lịch sử)

Tạo kho cache SQLite độc lập. Bước này CHƯA nối cache vào Tasks, Home, Hũ hoặc Dòng tiền, chưa đổi UI/loading/error, chưa thêm ghi offline hoặc hàng đợi đồng bộ. Tắt mạng ở app hiện tại chưa tự hiển thị dữ liệu cache.

PostgreSQL vẫn là dữ liệu nghiệp vụ chính. `finai_read_cache.db` chỉ chứa bản sao response API; không tạo giao dịch, không tính thêm số dư và không mở database Native Inbox.

## File và trách nhiệm

- `lib/core/cache/cache_entry.dart`: CacheKey gồm namespace/resource/queryKey và CacheEntry gồm JSON, savedAt UTC, phiên bản payload.
- `lib/core/cache/response_cache.dart`: port đọc, ghi đè một khóa, xóa một khóa, xóa một namespace. Dùng Result/AppFailure hiện có.
- `lib/core/cache/cache_database.dart`: tạo/mở file SQLite riêng, tạo bảng version 1, giữ một kết nối theo owner và đóng kết nối. Không tự xóa/nâng xuống database nếu gặp phiên bản không hỗ trợ.
- `lib/core/cache/sqlite_response_cache.dart`: implementation sqflite, truy vấn có tham số; ghi thay thế một hàng nguyên tử, không xóa toàn bảng.
- `lib/dev/cache_probe.dart`: probe riêng cho plugin Android; không phải màn hình ứng dụng hoặc entry point mặc định.

Thêm dependency trực tiếp `sqflite: 2.4.6`, `path: 1.9.1`; package còn lại được pub kéo theo. Không thêm FFI hay dependency test ngoài SDK. Native/plugin hỗ trợ nền tảng theo tài liệu sqflite: https://pub.dev/packages/sqflite .

## Cách hiểu khóa cache

Ví dụ: namespace=`local-report-book-v1`, resource=`tasks`, queryKey là chuỗi JSON canonical của start/end UTC, status, priority và searchText.

- namespace phải phân biệt môi trường/API, sổ thường/sổ demo, và tài khoản khi có đăng nhập. Chỉ dùng URL là chưa đủ vì server có thể đổi sổ mà URL không đổi.
- queryKey phải chứa đầy đủ bộ lọc, thứ tự sắp xếp/phân trang nếu có, chuẩn hóa nhất quán tại repository. Bước này chưa viết bộ dựng khóa theo feature.
- Payload phải là JSON object hoặc array hợp lệ. API mapper vẫn cần kiểm tra cấu trúc model trước khi lưu; kho generic không biết field nào của Task/Finance là hợp lệ.
- PayloadVersion (schemaVersion) khác databaseVersion. Khi mapper yêu cầu phiên bản khác, read trả cache miss và không xóa dữ liệu cũ.
- savedAt ghi UTC theo thời gian lưu trên thiết bị, không phải bằng chứng thời điểm dữ liệu đã thay đổi ở server.

## Ví dụ sử dụng (chưa gắn vào app)

Chạy trong Flutter Android đã gọi WidgetsFlutterBinding.ensureInitialized():

```dart
final database = await CacheDatabase.atDefaultLocation();
final cache = SqliteResponseCache(database: database);
const key = CacheKey(
  namespace: 'local-report-book-v1',
  resource: 'tasks',
  queryKey: 'example-loaded-range-v1',
);
final writeResult = await cache.write(key, payloadJson: '[]');
final readResult = await cache.read(key);
// Xử lý Success/Failure theo Result của dự án.
// Success(null) = chưa có hoặc không tương thích phiên bản.
// Success(entry có payloadJson="[]") = đã lưu danh sách rỗng hợp lệ.
await database.close();
```

Composition root sẽ sở hữu kết nối và inject ResponseCache vào repository ở bước tiếp theo. Widget không khởi tạo hoặc truy vấn SQL. Trước khi close, owner phải ngừng/chờ các thao tác đang dùng database.

## Kiểm tra đã chạy

1. Sáu unit test tại `test/unit/core/cache/sqlite_response_cache_test.dart` đạt: input không hợp lệ không chạm DB; miss khác empty; phiên bản không tương thích; payload hỏng trả Failure; lỗi mở an toàn và retry mở được; close lặp không mở lại database.
2. `test/integration/cache_sqlite_host_test.dart` đạt với Node 25 có SQLite tích hợp (SQLite 3.51.3). Test dùng sqflite Dart thật, thay method-channel transport bằng `tool/testing/cache_sqlite_host.mjs` để chạy SQL trên SQLite thật ở host. Không dùng bản lưu JSON giả làm database.
3. Test host ghi file trong `build/cache_test_runs/`, đóng DB và tiến trình SQLite, mở tiến trình/kết nối mới rồi đọc lại trước khi ghi tiếp. Kiểm tra tiếng Việt/UTC, ghi đè danh sách bằng [], phân biệt namespace/resource/tháng, JSON sai không ghi đè bản tốt, schema miss, xóa đúng phạm vi.
4. `flutter analyze` cuối đạt, không có vấn đề. APK debug từ `lib/main.dart` build thành công (50,5 giây) sau khi dùng thư mục tạm ổ D; native dependency sqflite biên dịch cùng app. Không cài lên điện thoại vì hiện ADB chưa nhận thiết bị.
5. Lượt build đầu thất bại do hết chỗ thư mục tạm/cache trên ổ C. Lượt đạt dùng TEMP/TMP và Java java.io.tmpdir tại `D:/tmp/finai-cache-build-temp`, chỉ áp dụng cho tiến trình build, không sửa cấu hình hệ thống hoặc Gradle của dự án. Nếu build lại gặp cùng lỗi, đặt ba biến này trong terminal đó trước khi build. Còn cảnh báo SDK XML phiên bản 3/4, không chặn build; chưa nâng SDK ngoài phạm vi.

Lệnh chạy lại trên máy hiện tại:

```powershell
& 'D:/Flutter/3.47.7/flutter/bin/flutter.bat' test --concurrency=1 test/unit/core/cache
& 'D:/Flutter/3.47.7/flutter/bin/flutter.bat' test --concurrency=1 test/integration/cache_sqlite_host_test.dart --dart-define=CACHE_SQLITE_NODE=D:/nodejs/node.exe
& 'D:/Flutter/3.47.7/flutter/bin/flutter.bat' analyze
```

Host test mặc định skip nếu chưa truyền CACHE_SQLITE_NODE. Bộ kết nối Node chỉ phục vụ kiểm tra, không được import vào app. Không phải bằng chứng plugin Android/iOS hoạt động trên thiết bị.

## Kiểm tra plugin Android khi có thiết bị

Hiện ADB chưa nhận điện thoại. Emulator API 37 có hypervisor nhưng không khởi động được do giới hạn dung lượng/bộ nhớ. Đã thử chuyển userdata sang ổ D; chưa kiểm chứng SQLite native trên Android.

Ưu tiên chạy probe trên emulator riêng vì entry point này chỉ có màn trống để in kết quả, không phải giao diện FinAI:

```powershell
& 'D:/Flutter/3.47.7/flutter/bin/flutter.bat' run -d <EMULATOR_ID> -t lib/dev/cache_probe.dart
```

Lần đầu mong đợi log `CACHE_PROBE_SQLITE_PASS` và `CACHE_PROBE_RESTART_READY`. Probe kiểm tra đọc/ghi/ghi đè/khóa và đóng mở DB; để lại một fixture kiểm tra restart trong thư mục riêng `read_cache_probe`.

Dừng chạy app, mở lại cùng probe trên cùng emulator. Mong đợi `CACHE_PROBE_PROCESS_RESTART_PASS` (đọc fixture cũ trước khi ghi mới, sau đó tự xóa fixture). Log `CACHE_PROBE_FAIL` là thất bại, không được tính là đạt.

Nếu chạy probe trên điện thoại dùng cùng applicationId, APK probe thay entry point của bản FinAI đang cài; cần chạy lại `lib/main.dart` với TASKS_API_BASE_URL đúng để trở về app chính. Probe dùng database trong thư mục con riêng, không ghi vào live cache/Native Inbox/backend.

## Bước nhỏ tiếp theo sau khi được duyệt

Nối ResponseCache vào danh sách Công việc: định nghĩa khóa query, đọc cache trước, tải API sau, chỉ cập nhật cache khi response hợp lệ; giữ danh sách đã lưu khi lỗi kết nối. Cần phân biệt lỗi mạng với quyền truy cập/ID đã xóa và chống response cũ ghi đè response mới. Chưa làm bước đó trong lượt này.
