> Hiện trạng mới nhất: [Bàn giao Tasks chế độ ngày](tasks_handover.md) — 12/11/2026. Ghi chú dưới đây là lịch sử từng bước.

# Màn khung Công việc theo ngày — TV3

Nguồn tham khảo: mẫu CVTheoNgay.html do người dùng gửi.
Đã chuyển bố cục sang widget Flutter, không chạy HTML/WebView.
Chưa triển khai tuần/tháng; không thay shell 5 tab/main.dart.

## Đã triển khai

- tasks/presentation/tasks_day_page.dart: nền sáng, header, thẻ gradient tím,
  tiến độ lấy từ snapshot controller, thanh ngày/tuần/tháng và dải ngày dạng khung.
- Vùng danh sách chỉ đọc: giờ địa phương, tên, mức ưu tiên và trạng thái.
- Loading, empty, error và nút Thử lại đã được người dùng duyệt bổ sung.
- Không dùng tên người dùng hoặc số liệu minh họa trong HTML làm dữ liệu thật.
- Khi chưa tải/lỗi, số liệu hiển thị gạch ngang; ready rỗng hiển thị 0/0 và 0%.
- Chọn ngày và Hôm nay đã hoạt động; tìm kiếm và bộ lọc trạng thái đã nối; thông báo chưa có tương tác.
  Không dựng hành vi giả thành công. Chưa thêm form, FAB CRUD hoặc AI.
- Dùng font hệ thống; chưa có Plus Jakarta Sans trong assets.
- Không hiển thị tên danh mục giả từ categoryId vì chưa có port danh mục.
- Ngày hiển thị lấy từ controller.state.query.start.toLocal(), không truyền ngày riêng.
  Demo lấy ngày địa phương trên máy và tạo khoảng đầu ngày -> đầu ngày kế tiếp;
  TaskQuery chuyển UTC. Chưa áp đặt múi giờ chung của cả nhóm.
- Tiến độ hiện lấy snapshot ngày chưa lọc. Khi triển khai lọc phải giữ riêng
  tổng ngày để không biến tiến độ thành tổng của danh sách đã lọc.

## Chạy demo

Composition root: lib/dev/main_tasks_day_demo.dart.
Nó sở hữu client/repository/controller và đóng đúng vòng đời.
UI không truy vấn SQL hoặc khởi tạo repository.

Backend demo đã có .env, Docker đang chạy:

    cd D:\git\do-an-co-so\backend
    & 'D:\Docker\resources\bin\docker.exe' compose up -d postgres
    npm run start:dev

Chạy Flutter trên target đã được cấu hình (không tự tạo platform mới):

    cd D:\git\do-an-co-so
    flutter run -t lib/dev/main_tasks_day_demo.dart --dart-define=TASKS_API_BASE_URL=http://127.0.0.1:3000

Android cần adb reverse hoặc cấu hình địa chỉ phù hợp như tài liệu HTTP trước đó;
chưa kiểm chứng demo UI này trên Android. Không cần điện thoại để chạy widget test.
Không khẳng định web chạy được: chưa cấu hình CORS cho web.
Demo không seed. Ngày chưa có dữ liệu thật sẽ hiển thị empty.

## Kiểm tra không cần thiết bị

    flutter test test/widget/features/tasks/tasks_day_page_test.dart
    flutter analyze

Mong đợi 18 widget test đạt, analyze không có lỗi.
Kiểm tra loading, 0/0 không chia 0, error/retry, hiển thị từ controller,
tiến độ hoàn thành và không overflow ở 320/390 px với cỡ chữ 1.3.
HTTP trong widget test dùng repository stub, không phải backend thật.

Ảnh xem bố cục: build/tasks-day-preview.png.
Test xuất ảnh nạp Segoe UI nếu Windows có font, chỉ cho preview/test;
font sản phẩm vẫn là font hệ thống. Material icons được nạp từ assets.
Ảnh chứa fixture test và không phải bằng chứng dữ liệu thật hoặc chạy điện thoại.

Kết quả 07/11/2026:
- Toàn bộ 128 test đạt; 1 test backend opt-in được skip khi thiếu URL.
- flutter analyze sạch.
- flutter build apk --debug -t lib/dev/main_tasks_day_demo.dart thành công.
- Đã xem ảnh preview để kiểm tra chữ, thẻ, khoảng cách và bố cục.
- Chưa chạy UI trên thiết bị hoặc nối UI demo với backend đang chạy.
- SDK XML version warning xuất hiện khi build nhưng không làm build thất bại.
- Không đổi dependency/schema/router, không commit/push.

Bước nhỏ tiếp theo: nối chọn ngày và Hôm nay theo mẫu đã có,
sau khi người dùng kiểm tra/xác nhận màn khung.
## Chọn ngày và Hôm nay

Đã nối từng ngày trong dải tuần với controller.setQuery:
- Chuyển loading ngay, không giữ danh sách ngày cũ trong ngày mới.
- Ngày được tạo từ 00:00 địa phương đến 00:00 ngày kế tiếp bằng constructor
  DateTime; không cộng cứng 24 giờ để định nghĩa một ngày.
- TaskQuery tự chuẩn hóa UTC; giữ status/priority/searchText.
- Tiêu đề và tháng hiển thị dùng query mới, không lưu ngày chọn thứ hai trong widget.
- Dải ngày có semantics button/selected và nhãn ngày đầy đủ.
- Hôm nay gọi DateTime.now lúc bấm; có thể inject clock cho widget test.
- Bấm lại Hôm nay trên cùng ngày sẽ subscribe lại để tải mới.
- Chưa tự đổi ngày lúc qua nửa đêm nếu người dùng không bấm Hôm nay.
- Dải hiện tuần của ngày chọn; đã có popup ở tiêu đề tháng để chọn ngày ngoài tuần.
- Múi giờ hiện là giờ địa phương trên thiết bị, chưa có timezone cấu hình chung.

Tự kiểm tra trên demo:
1. Bấm ngày khác trong dải: ngày được tô tím, tiêu đề đổi, danh sách tải lại.
2. Với ngày chưa có bản ghi, màn hiển thị empty sau loading.
3. Bấm Hôm nay: chọn ngày hiện tại của thiết bị và tải lại.
4. Backend không chạy: thấy thông báo lỗi; mở backend rồi bấm Thử lại.
Không cần tạo dữ liệu giả hoặc ghi database để chọn ngày.

Kiểm tra không cần điện thoại:

    flutter test test/widget/features/tasks/tasks_day_page_test.dart
    flutter analyze

11 widget test đạt, gồm 4 test mới cho chọn ngày, giữ bộ lọc, ranh giới tháng
và đồng hồ Hôm nay chuyển năm. Test dùng repository stub; chưa khẳng định
thao tác UI chọn ngày đã chạy với backend thật hay trên Android.
Không sửa backend, schema, dependency, router hoặc CRUD.
Bước tiếp theo dự kiến: nối bộ lọc trạng thái sau khi người dùng xác nhận.Kết quả sau bước chọn ngày: toàn bộ 132 test đạt, 1 test backend opt-in skip; flutter analyze không có lỗi. Chưa build lại APK trong bước chọn ngày.

## Bộ lọc trạng thái — 08/11/2026

- ChoiceChip Tất cả (status null), Đang làm (inProgress), Đã xong (completed).
- Bấm chip gửi query mới qua controller; không lọc SQL/HTTP trong widget.
- Giữ nguyên start/end, priority và searchText; bộ lọc vẫn giữ khi chọn ngày/Hôm nay.
- Trạng thái chọn lấy từ query, không lưu thêm biến trạng thái UI riêng.
- Empty dùng thông báo không có công việc phù hợp ngày/bộ lọc.
- Chưa thêm chip Chờ xử lý hoặc Quá hạn; chưa làm tìm kiếm/lọc ưu tiên.

Thẻ tiến độ:
- Demo inject thêm dailyController qua constructor, dùng chung repository.
- dailyController tải query không status/priority/searchText của cùng khoảng ngày.
- composition root đồng bộ dailyController khi khoảng ngày của danh sách thay đổi.
- Đổi riêng status không tải lại tổng ngày. Repository cập nhật cả hai stream
  khi ghi qua cùng instance.
- Thử lại ở danh sách lỗi gọi retry cho cả hai controller.
- Nếu tổng ngày chưa có, lỗi hoặc khác ngày, không dùng dữ liệu đã lọc làm tổng:
  hiển thị gạch ngang. Chưa có nút retry riêng khi chỉ tổng ngày gặp lỗi;
  cần đổi sang ngày khác rồi quay lại, hoặc khởi động lại demo để tải tổng ngày.
- Chưa ghép thành snapshot giao dịch nguyên tử giữa hai HTTP request.
- Chủ sở hữu dispose cả hai controller trước repository/client.
- Widget không tạo repository/controller và không có nguồn dữ liệu thứ hai.

Tự test:
1. Chạy demo theo hướng dẫn trên, chọn Đang làm hoặc Đã xong.
2. Chip đổi màu tím, danh sách tải và chỉ còn trạng thái tương ứng.
3. Bấm Tất cả để xóa riêng điều kiện status.
4. Đổi ngày rồi Hôm nay: bộ lọc đang chọn vẫn giữ.
5. Với ngày có nhiều trạng thái, tiến độ vẫn là tổng cả ngày, không thành 100%
   chỉ vì đang xem các task đã hoàn thành.

Kiểm tra không cần thiết bị:

    flutter test test/widget/features/tasks/tasks_day_page_test.dart
    flutter analyze

14 widget test, toàn bộ 135 test đạt; 1 backend opt-in test skip khi thiếu URL.
Analyze không có lỗi. Test mới kiểm tra query bộ lọc, total ngày độc lập và
không lấy tổng ngày cũ/danh sách lọc làm tiến độ ngày mới.
Bằng chứng dùng repository stub, chưa thử thao tác lọc UI với backend thật/Android.
Chưa build lại APK ở bước bộ lọc. Không đổi backend, schema, interface repository,
dependency, routing hoặc state/controller hiện có. Không commit/push.
Bước nhỏ tiếp theo dự kiến: nối tìm kiếm theo tên.
## Tìm kiếm theo tên — 08/11/2026

Đã nối ô nhập theo mẫu CVTheoNgay.html, không thêm dependency/API:
- Debounce 350 ms sau lần thay đổi cuối; gửi query.searchText đã trim.
- Giữ start/end/status/priority hiện tại tại lúc gửi, không chụp ngày cũ.
- Nút Xóa tìm kiếm bỏ từ khóa ngay, không xóa bộ lọc trạng thái.
- Phím tìm kiếm trên bàn phím gửi ngay và hủy lượt debounce đang chờ.
- Chuỗi sau trim giống query hiện tại thì không gửi lại.
- Không gửi khi IME đang có vùng composing chưa kết thúc.
- Widget đồng bộ lại khi query.searchText được thay đổi từ bên ngoài.
- Hủy timer/listener khi dispose hoặc đổi instance controller.
- KeepAlive giữ ô nhập và timer khi ô tìm kiếm cuộn khỏi vùng nhìn.
- Không tìm dự án/thẻ/danh mục. Quy tắc hoa thường/dấu/literal theo TaskQuery.
- Không gọi HTTP/SQL trong widget; repository xử lý lọc và sắp xếp.
- Kết quả query cũ được controller hiện có bỏ qua theo generation.
- Tiến độ dùng dailyController không có từ khóa, không đổi theo kết quả tìm.

Tự kiểm tra:
1. Trong demo nhập một phần tên công việc, ngừng gõ 350 ms.
2. Danh sách chuyển loading rồi hiện công việc phù hợp hoặc empty.
3. Chọn Đã xong: từ khóa vẫn giữ, danh sách kết hợp hai điều kiện.
4. Bấm dấu xóa trong ô nhập: từ khóa rỗng, trạng thái vẫn giữ.
5. Đổi ngày hoặc Hôm nay: tìm kiếm vẫn áp dụng trong ngày mới.
Không hardcode kết quả minh họa; demo lấy dữ liệu backend thật khi chạy.

Kiểm tra không cần thiết bị:

    flutter test test/widget/features/tasks/tasks_day_page_test.dart
    flutter analyze

18 widget test đạt; 4 test mới tập trung debounce/trim/xóa/giữ query,
ngày và trạng thái đổi trong lúc chờ, tiến độ toàn ngày, dispose hủy debounce.
Analyze không có lỗi. Các test mới dùng repository stub, chưa kiểm chứng thao tác
nhập UI với API thật, Android hoặc bàn phím tiếng Việt trên điện thoại.
Chưa build lại APK trong bước tìm kiếm; không commit/push.
Không sửa backend, schema, dependency, routing hoặc controller sản phẩm.
Bước nhỏ tiếp theo dự kiến: triển khai form tạo công việc từ đoạn modal
trong mẫu đã nhận, sau khi người dùng kiểm tra/xác nhận bước này.Kết quả toàn dự án sau bước tìm kiếm: 139 test đạt; 1 test backend opt-in skip khi thiếu URL.

## Chấm màu ưu tiên — 08/11/2026

Theo yêu cầu, thêm chấm tròn 7px giữa giờ và nhãn ưu tiên trên thẻ.
Cao: đỏ #BE123C; trung bình: tím #7C3AED; thấp: xám #64748B.
Chấm nằm cùng nhãn, tránh tách dòng riêng; nhãn chữ vẫn được giữ để đọc mức ưu tiên.
Chỉ thay đổi hiển thị, không đổi enum/dữ liệu hoặc nghiệp vụ.
19 widget test màn ngày đạt, gồm 320/390px; flutter analyze không có lỗi.
Đã xem ảnh widget preview để kiểm tra vị trí chấm; chưa tự thao tác UI trình duyệt.
Preview có chấm ưu tiên đã build thành công; JavaScript qua server 3111 trả HTTP 200. Chưa build APK ở bước chỉnh chấm màu.

## Chọn ngày bất kỳ bằng popup — 12/11/2026

- Bấm tiêu đề tháng/icon lịch để mở showDatePicker của Flutter.
- Có Hủy/Chọn, theo màu chủ đạo hiện có; không thêm dependency.
- Chặn mở nhiều popup khi popup đang hoạt động.
- Ngày ban đầu lấy từ query hiện tại; Hủy không gọi setQuery.
- Chọn ngày gọi lại luồng _selectDay hiện có: ranh giới ngày địa phương,
  chuyển UTC qua TaskQuery, giữ status/priority/searchText.
- Tiêu đề tháng, ngày và dải tuần lấy từ query mới. Không có nguồn ngày chọn thứ hai.
- Popup mặc định chọn từ năm 1900 đến 2200; nếu query hiện tại ở ngoài khoảng,
  phạm vi mở rộng để chứa năm đó, không sửa dữ liệu hoặc schema.
- Có thể chọn lịch hoặc chuyển sang nhập theo định dạng mà popup hiển thị.
  Chưa cấu hình locale chung toàn app; Hủy/Chọn/tiêu đề trợ giúp đã dùng tiếng Việt.
- Không chuyển sang chế độ xem tuần/tháng.

Tự test:
1. Tải lại http://127.0.0.1:3111 rồi bấm tiêu đề tháng.
2. Chuyển tháng/năm, chọn ngày và bấm Chọn.
3. Thấy tiêu đề và dải tuần đổi, danh sách tải đúng ngày.
4. Từ khóa/bộ lọc đang chọn vẫn giữ. Ngày không có task hiển thị empty.
5. Mở lại rồi Hủy: ngày và danh sách không bị tải lại do thao tác Hủy.
6. Bấm Hôm nay để trở về ngày hiện tại.

    flutter test test/widget/features/tasks/tasks_day_page_test.dart
    flutter analyze

Kết quả: 24 widget test màn ngày đạt, gồm 3 test popup mới.
Toàn bộ 165 test đạt; 5 test backend opt-in skip khi thiếu URL.
Analyze không có lỗi. Test popup dùng repository stub, chưa kiểm chứng thao tác
popup trong trình duyệt hoặc Android. Chưa build lại APK.
Không đổi backend/API, schema, dependency hoặc router chung; không commit/push.
Bước nhỏ tiếp theo dự kiến: bổ sung bộ lọc ưu tiên/Chờ xử lý, sau khi người dùng xác nhận.Preview popup mới build thành công; trang/JavaScript/API local đều trả HTTP 200. Docker demo và server preview đã được khởi động lại.

## Hoàn thiện lọc ưu tiên và Chờ xử lý — 12/11/2026

- Đủ chip trạng thái: Tất cả/null, Chờ xử lý/pending, Đang làm/inProgress,
  Đã xong/completed.
- Menu ưu tiên: Mọi mức/null, Cao/high, Trung bình/medium, Thấp/low.
- Menu dùng giá trị all riêng để bỏ lọc ưu tiên; không xóa điều kiện status.
- Chọn một bộ lọc giữ ngày, từ khóa và các bộ lọc còn lại.
- TaskQuery kết hợp các điều kiện AND; widget không tự lọc lại dữ liệu.
- Tiến độ tiếp tục dùng dailyController không lọc, không đổi thành tỷ lệ
  của danh sách đang lọc.
- Nhãn menu dùng Flexible/ellipsis khi màn hẹp/chữ lớn, menu mở vẫn đủ tên mức.
- Không thay schema, API, dependency hoặc router; không ghi dữ liệu khi lọc.

Tự test trên http://127.0.0.1:3111 sau khi tải lại:
1. Chọn Chờ xử lý rồi ưu tiên Cao: chỉ còn task thỏa cả hai điều kiện.
2. Chọn Mọi mức ưu tiên: chỉ bỏ priority, vẫn lọc Chờ xử lý.
3. Nhập từ khóa: ngày/trạng thái/ưu tiên vẫn kết hợp.
4. Đổi ngày hoặc Hôm nay: các điều kiện lọc vẫn giữ.
5. So sánh thẻ tiến độ trước/sau lọc: vẫn tính toàn ngày.
Nếu danh sách rỗng thì có thể không có task đáp ứng bộ lọc; không seed dữ liệu giả.

    flutter test test/widget/features/tasks/tasks_day_page_test.dart
    flutter analyze

26 widget test màn ngày đạt, gồm 2 test mới cho ưu tiên/Chờ xử lý và tổng ngày.
Analyze không có lỗi. Bằng chứng UI dùng repository stub; chưa tự kiểm chứng
click trong trình duyệt hoặc Android, chưa build lại APK.
Không commit/push. Đây chỉ là hoàn thiện phần lọc, chưa tuyên bố module Tasks
hoàn thành toàn bộ: còn quá hạn, màn chi tiết/routing chung và kiểm chứng thiết bị.
Bước nhỏ tiếp theo dự kiến: hiển thị công việc quá hạn sau khi người dùng xác nhận.Kiểm tra cuối bước bộ lọc: toàn bộ 167 test đạt, 5 test backend opt-in skip; flutter analyze sạch.
Bản xem thử bộ lọc mới build thành công; trang/JavaScript trả HTTP 200. Đã xem ảnh widget render để kiểm tra bố cục.
