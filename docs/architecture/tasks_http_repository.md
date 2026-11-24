> Cập nhật 23/11/2026: HttpTaskRepository có cache danh sách được inject trên Android, fallback khi API không khả dụng. Xem [task_list_cache.md](task_list_cache.md) để biết phạm vi, kiểm tra và giới hạn; getById/thao tác ghi vẫn dùng API.

> Hiện trạng mới nhất: [Bàn giao Tasks chế độ ngày](tasks_handover.md) — 12/11/2026. Ghi chú dưới đây là lịch sử từng bước.

# Kết nối HTTP Công việc trong Flutter

Tài liệu cho demo TV3, chưa phải hợp đồng/schema chung đã chốt.
Ứng dụng chính là Flutter trên điện thoại. HTTP dùng để trao đổi với NestJS,
không phải giao diện web.

## Các thành phần

- TaskApiMapper: chuyển JSON và model/domain; không gửi HTTP.
- TaskRemoteDatasource: gọi API CRUD/list, timeout và chuyển lỗi thành Result.
- HttpTaskRepository: thực thi TaskRepository và điều phối stream danh sách.
- Backend NestJS dùng Prisma/PostgreSQL; không có SQLite hoặc nguồn dữ liệu thứ hai.
- main.dart hiện vẫn trống; chưa nối app shell hoặc UI.

Repository, datasource và client được tạo tại composition root, truyền qua constructor.
Widget không khởi tạo repository, client hoặc database.

## Ví dụ binding và vòng đời

Đoạn minh họa dưới đây giả sử đã có apiBaseUrl và query:

    final client = http.Client();
    final datasource = TaskRemoteDatasource(
      client: client,
      baseUrl: Uri.parse(apiBaseUrl),
    );
    final repository = HttpTaskRepository(datasource: datasource);
    final TaskRepository tasks = repository;

    final subscription = tasks.watch(query).listen((result) {
      // Controller xử lý Success<List<Task>> hoặc Failure<List<Task>>.
    });

    // Khi màn không còn theo dõi:
    await subscription.cancel();

    // Khi phạm vi sở hữu repository kết thúc:
    repository.dispose();

    // Khi không còn bên nào dùng HTTP client:
    client.close();

Không hardcode địa chỉ backend trong widget.
Địa chỉ backend từ điện thoại sẽ được kiểm tra riêng; localhost trong tool hiện
là localhost của máy tính, chưa chứng minh điện thoại truy cập được.

## Quy tắc watch

- Mỗi subscription có query và trạng thái tải riêng.
- Chỉ bắt đầu GET khi có listener; phát kết quả ban đầu, kể cả danh sách rỗng.
- Ghi thành công qua cùng instance repository làm tải lại các subscription đang hoạt động.
- Ghi thất bại không tự retry hoặc kích hoạt tải lại.
- Ghi thành công vẫn trả Success nếu lần tải lại danh sách sau đó thất bại.
- Failure khi tải danh sách không đóng stream. Gọi refresh() hoặc subscribe lại để retry.
- refresh() là phương thức cụ thể của HttpTaskRepository, không đổi interface chung.
- Response GET cũ bị bỏ nếu có ghi/refresh thành công trong lúc chờ; tải lại trạng thái mới.
- Nhiều invalidation khi một GET đang chạy được gộp thành lần tải tiếp theo.
- Khi hủy subscription không phát response muộn hoặc gửi GET tiếp cho subscription đó.
- dispose() đóng stream, idempotent và không chờ listener đang pause.
- Không đóng HTTP client được inject; request đã gửi có thể hoàn tất sau dispose.
- Không hủy hoặc rollback thao tác ghi đã gửi. Không tự retry POST để tránh ghi lặp.
- Chưa có SSE/WebSocket/polling đa thiết bị. Thay đổi từ nơi khác cần refresh thủ công.
- Khoảng ngày, thứ tự và bộ lọc do API thực thi theo TaskQuery đã chốt.

## Kiểm tra bằng fake HTTP

    flutter test test/unit/features/tasks/data/repositories/http_task_repository_test.dart
    flutter test
    flutter analyze

Đã kiểm chứng:
- CRUD, trả lỗi, phát dữ liệu đầu và sau ghi.
- Nhiều bộ lọc, nhiều listener, unsubscribe.
- Ghi lỗi, danh sách lỗi, refresh/retry.
- Response cũ, gộp invalidation, dispose và listener pause.
- 15 test repository đạt; toàn bộ 87 test Flutter đạt; analyze không có lỗi.

## Kiểm tra với backend thật trên máy tính

Terminal backend, PostgreSQL trực tiếp phải chạy và .env đã có:

    cd D:\git\do-an-co-so\backend
    # Khởi động PostgreSQL trực tiếp theo docs/integration/postgresql_local.md
    npm run build
    npm run start:dev

Terminal khác tại thư mục Flutter:

    cd D:\git\do-an-co-so
    dart run tool/check_task_http_repository.dart http://127.0.0.1:3000

Tool chỉ cho phép URL loopback local. Nó tạo task với marker ngẫu nhiên,
kiểm tra CRUD/watch/notFound rồi dọn đúng fixture của lần chạy.
Không in dữ liệu nhạy cảm hoặc lỗi thô. Không sửa schema hoặc bản ghi khác.
Kết quả đã kiểm chứng: bốn dòng PASS và dọn fixture thành công.

Đây là kiểm tra bằng Dart VM trên máy tính, không phải kiểm tra Flutter trên điện thoại.

## Trạng thái bàn giao và giới hạn

- Đã triển khai mapper, datasource HTTP và HttpTaskRepository.
- Đã kiểm chứng unit test/fake HTTP và Dart -> NestJS -> PostgreSQL thật.
- Fake HTTP có trạng thái ghi/đọc để test stream, không phải backend sản phẩm.
- Database/API/schema hiện chỉ là demo riêng TV3.
- Đã cấu hình INTERNET và HTTP loopback riêng cho Android debug; xem hướng dẫn bên dưới.
- Chưa chạy trên emulator hoặc điện thoại thật; chưa có UI/controller Flutter.
- Chưa có auth, TaskReader public adapter, cập nhật đẩy hoặc offline cache.
- Không sửa module Dòng tiền, Hũ, Giao dịch, Native hoặc Assistant trong bước này.
- Không ghi nhận lỗi trong các kiểm tra vừa chạy; giới hạn đa thiết bị và request đang chờ
  được mô tả ở trên, chưa có bằng chứng ngoài phạm vi kiểm thử này.

## Kiểm tra kết nối Android debug (không có UI)

Entry point riêng: lib/dev/main_tasks_api_probe.dart.
lib/main.dart và manifest main/profile không thay đổi.
Chính sách mạng debug chỉ cho HTTP tới 127.0.0.1 và localhost;
các địa chỉ khác vẫn bị chặn cleartext. Backend tiếp tục bind loopback.

1. Khởi động PostgreSQL trực tiếp và chạy backend demo theo hướng dẫn ở trên (cổng 3000).
2. Khởi động emulator và kiểm tra adb devices: trạng thái phải là device.
3. Với đúng serial emulator, chạy:

       adb -s <serial> reverse tcp:3000 tcp:3000
       flutter run -d <serial> --debug -t lib/dev/main_tasks_api_probe.dart --dart-define=TASKS_API_BASE_URL=http://127.0.0.1:3000

   Trước khi thêm reverse, kiểm tra adb -s <serial> reverse --list.
   Không ghi đè mapping đang dùng cho công việc khác.

4. Màn hình trống là đúng vì bước này không triển khai UI.
   Console phải có TV3_ANDROID_API_PROBE_RESULT: PASS sau các thông báo kiểm tra.
   Chương trình tạo fixture ngẫu nhiên, kiểm tra CRUD/watch/notFound rồi dọn fixture.
   FAIL nghĩa là chưa đạt; không có dòng PASS cũng chưa được coi là đạt.
5. Khi thử xong, dừng app rồi xóa đúng mapping đã thêm:

       adb -s <serial> reverse --remove tcp:3000

adb nằm tại C:\Users\duong\AppData\Local\Android\sdk\platform-tools\adb.exe
nếu chưa có trong PATH. Không dùng entry point này để build release.
Nếu tiến trình bị kết thúc giữa chừng, phần dọn fixture có thể chưa chạy.

### Kết quả ngày 07/11/2026

- flutter analyze: No issues found.
- flutter test: 94 test đạt (gồm 7 test chặn URL probe không hợp lệ).
- flutter build apk --debug -t lib/dev/main_tasks_api_probe.dart
  --dart-define=TASKS_API_BASE_URL=http://127.0.0.1:3000: thành công.
- APK: build/app/outputs/flutter-apk/app-debug.apk.
- Merged manifest debug có INTERNET và networkSecurityConfig.
- Emulator Medium_Phone_API_37.0 chưa boot thành công:
  AVD cũ thiếu dung lượng ổ C; thử data riêng tại D:\FinAIAndroidDemo\api37
  vẫn offline, sau đó công cụ hệ thống báo OutOfMemoryException.
  Đã dừng cây tiến trình emulator do lần thử này tạo để giải phóng bộ nhớ.
- Chưa cài/chạy APK thành công trên emulator, chưa quan sát PASS trên Android.
- Chưa kiểm chứng trên điện thoại thật. Không coi kết quả Dart VM là bằng chứng Android.
- Không thay đổi schema chung, không thêm dependency và không commit/push Git.

Cần thử lại khi có đủ bộ nhớ/dung lượng cho emulator; chỉ ghi nhận kết nối
Android hoàn thành khi console thực sự trả PASS. Cấu hình này dùng adb reverse,
không yêu cầu mở backend ra mạng LAN.