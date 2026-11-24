# TV3 — đọc thông báo ngân hàng (bản thử)

## Đã triển khai

- Danh mục 72 mục tên/bí danh ngân hàng, chi nhánh và thương hiệu số; không khẳng định đầy đủ mọi app.
- Kotlin dùng PackageManager lấy app label trước khi đọc notification extras. Khớp toàn bộ tên/bí danh trong asset xuất từ danh mục Dart; không dùng contains hoặc lấy title để nhận diện app.
- Nhận diện chỉ bằng tên: **chưa xác minh package/chữ ký chính chủ**. Thẻ kết quả hiển thị rõ giới hạn này. App giả đặt cùng tên vẫn có thể khớp.
- Các thông báo FinAI cục bộ vẫn dùng nhánh riêng để không ảnh hưởng nhắc việc.
- Bỏ group summary để giảm lặp. Lọc từ khóa OTP/xác thực và quảng cáo trước khi lưu; không log payload.
- Nội dung được giới hạn 500 ký tự title/2000 ký tự text; mẫu bị cắt không được tách thành kết quả chắc chắn.
- SQLite Inbox lưu trước khi phát EventChannel; MethodChannel getPending/acknowledge giữ nguyên. Không thay schema database chung.
- Chống trùng cùng sự kiện bằng hash(package + notification key + postTime) và tombstone SQLite 90 ngày, kể cả sau ack. Không khẳng định chống trùng cùng giao dịch được ngân hàng phát thành nhiều sự kiện khác nhau.
- Bộ tách Dart thu/chi, số tiền VND, số dư nếu có, mô tả và giờ giao dịch nếu đủ ngày/giờ.
- UI FinAI hiển thị kết quả tham khảo; tiền và nội dung ẩn mặc định. Raw chỉ hiện khi người dùng bật xem nội dung. Chưa ghi Transaction, không gọi API tài chính.
- Không khôi phục hai nút gửi thử đã được yêu cầu xóa.

## Quy tắc và giới hạn parser v1

- Hỗ trợ VND/VNĐ/đồng/đ sau số tiền; số nguyên, dấu nhóm nghìn phẩy/chấm, phần lẻ .00 hoặc ,00. Không làm tròn tiền, không dùng double.
- Chiều lấy từ dấu +/− hoặc ghi có/ghi nợ và một số từ khóa. Mâu thuẫn chiều, nhiều số tiền ngoài số dư, giao dịch lỗi/đang chờ => Chưa tách được.
- Số dư được nhận riêng bằng nhãn Số dư/SD/Balance, không bị lấy làm tiền giao dịch.
- Giờ giao dịch chỉ nhận dd/MM/yyyy HH:mm[:ss], giả định giờ Việt Nam UTC+7 cho dạng không offset. Thiếu/sai ngày hoặc có offset khác => null, hiển thị riêng giờ nhận thông báo; không tự lấy giờ nhận làm giờ giao dịch.
- Mô tả lấy sau ND/Nội dung/Description. Che số dài/email chỉ là hỗ trợ, không bảo đảm loại hết tên/thông tin cá nhân; mọi bằng chứng chia sẻ phải rà soát và che thủ công.
- Bộ lọc quảng cáo hiện thận trọng: hoàn tiền/cashback cũng có thể bị bỏ. Từ khóa OTP có thể loại cả thông báo có nhắc OTP trong ngữ cảnh khác. Chưa có fixture ngân hàng thật để tinh chỉnh.
- Chưa hỗ trợ mọi bố cục, ngoại tệ, số tiền phân nhóm bằng khoảng trắng, số tiền đứng sau ký hiệu tiền tệ hoặc ngày thiếu năm.
- Danh mục Kotlin là asset xuất từ Dart bằng: dart run tool/export_bank_catalog.dart. Có test kiểm tra asset đồng nhất nguồn.

## Dữ liệu mẫu và bằng chứng

- test/fixtures/native_inbox/bank_notifications_synthetic.json: hoàn toàn tự tạo; tài khoản đã thay bằng ****, số OTP 000000 là giả.
- test/unit/features/native_inbox/bank_notification_parser_test.dart: kiểm tra fixture, tiền, giờ, loại OTP/quảng cáo, mơ hồ và nguồn ngoài danh mục.
- test/widget/features/native_inbox/bank_notice_card_test.dart: ẩn tiền, hiển thị kết quả, cảnh báo nguồn và chỉ ack khi người dùng thao tác.
- Kiểm chứng Inbox FinAI trước đây xem tv3_reminders_inbox.md. Kết quả đó không phải bằng chứng ngân hàng.

## Chưa kiểm chứng / chưa hoàn thành nghiệm thu

**Chưa kiểm chứng với ngân hàng.** Chưa nhận mẫu thật đã che dữ liệu từ người dùng; ADB không thấy thiết bị tại bước triển khai này. Không tuyên bố hỗ trợ thành công bất kỳ ngân hàng thật nào chỉ vì test fixture tự tạo đạt.

Còn cần: một thông báo thật đã che thông tin + xác nhận app/package; nối điện thoại; kiểm tra nguồn app label thực tế; nhận thông báo đã được người dùng cho phép; đối chiếu tiền/chiều/giờ/nội dung/số dư; kiểm tra pending/ack và giao lại trùng. Không tự thực hiện giao dịch ngân hàng để tạo thông báo.

Các tình huống đang mở/nền/Flutter chưa sẵn sàng/hệ thống kết thúc tiến trình/force stop/thu hồi rồi cấp lại quyền phải ghi kết quả riêng. Chưa coi tất cả các trường hợp này tương đương.

## Cách chạy và tự test

1. Build APK debug: flutter build apk --debug --no-pub -t lib/dev/main_tasks_day_demo.dart --dart-define=TASKS_API_BASE_URL=http://127.0.0.1:3111/api
2. Cài cập nhật lên điện thoại. Nếu dùng backend demo USB: adb reverse tcp:3111 tcp:3111, backend trên máy tính phải chạy. Native Inbox không phụ thuộc API tài chính.
3. Mở chuông trên màn Công việc. Cuối màn mở Quyền truy cập → Cấp quyền đọc thông báo → bật FinAI Native Inbox trong Android.
4. Dùng thông báo ngân hàng phát sinh hợp lệ do người dùng cho phép; app label phải khớp tên/bí danh. Nếu khác, chỉ bổ sung bí danh sau khi đối chiếu ứng dụng chính chủ. Không đoán package từ tên ngân hàng.
5. Mở Inbox, xem thẻ ngân hàng. Bật Hiện nội dung để đối chiếu tiền, thu/chi, số dư; giờ thiếu phải hiện chưa đọc được, không tự đoán.
6. Xác nhận một mục rồi Đọc lại Inbox: mục đó phải biến mất. Mẫu mơ hồ vẫn cần đối chiếu thủ công.
7. Trước gửi ảnh/log: che toàn bộ tên, tài khoản, nội dung chuyển khoản và mã tham chiếu. Không gửi OTP thật.

## Không triển khai

Widget, tự ghi giao dịch, giao dịch ngân hàng tự động, parser được quảng bá hỗ trợ tất cả ngân hàng hoặc LLM tài chính.


## Kết quả kiểm tra bản cuối — 12/11/2026

- flutter analyze --no-pub: không có vấn đề.
- flutter test --no-pub --concurrency=1: 211 đạt, 5 bỏ qua do yêu cầu cấu hình backend tích hợp riêng.
- flutter build apk --debug --no-pub -t lib/dev/main_tasks_day_demo.dart --dart-define=TASKS_API_BASE_URL=http://127.0.0.1:3111/api: thành công.
- Đã kiểm tra asset danh mục 72 mục nằm trong APK.
- Có lượt chạy song song/build bị thiếu RAM; đã dừng các lượt của tác vụ và chạy lại tuần tự thành công. Không coi kết quả các lượt gián đoạn là kiểm chứng đạt.
- Chưa cài bản ngân hàng mới lên điện thoại vì ADB chưa nhận thiết bị. Kotlin mới được kiểm tra biên dịch; lọc OTP trước lưu và PackageManager gate ngân hàng chưa được chứng minh trên máy thật.
- Chưa kiểm chứng với ngân hàng; chưa nhận fixture ngân hàng thật đã che thông tin. Không đánh dấu phần bàn giao ngân hàng thật hoàn thành.


## Điều chỉnh phạm vi theo yêu cầu mới

Dùng một bộ quy tắc cho mọi ngân hàng trong danh mục, không có nhánh parser riêng TPBank. Màn kết quả chỉ tập trung Cộng tiền/Trừ tiền, số tiền và nội dung; không hiện số dư hay giờ giao dịch. SD/SD KHA DUNG/Balance được loại khỏi ứng viên số tiền. ND/Nội dung/Description/Content/Remark nhận mô tả nhiều dòng, dừng trước mã giao dịch/số dư. Thiếu dấu hoặc từ khóa rõ ràng, nhiều số tiền hoặc chiều mâu thuẫn thì chưa xác định, không đoán.

Đã nhận ảnh mẫu TPBank từ người dùng; fixture tpbank_redacted.json chỉ giữ cấu trúc và thay toàn bộ tài khoản, điện thoại, tham chiếu và giá trị tiền. Mẫu cấu trúc này cũng được thử với tất cả ID ngân hàng để chứng minh không rẽ nhánh theo ID, không phải bằng chứng hỗ trợ thực tế mọi ngân hàng. Việc nhận và hiển thị thông báo thật trên máy vẫn cần ghi riêng.


Kiểm tra cho bản quy tắc chung: nhóm Inbox 34 kiểm thử đạt trước khi bổ sung từ khóa mới; sau đó chạy lại 6 ca quy tắc/mẫu cấu trúc đều đạt, analyze sạch. Không giữ kết luận ngày/giờ hoặc số dư là phần hiển thị hiện tại. Lần kiểm tra thiết bị cuối ADB không còn thấy điện thoại, nên chưa cài/xác nhận UI ba trường mới trên máy thật.


## Đối chiếu TPBank thật sau khi nối lại USB

- TECNO LH7n / Android 14, cài cập nhật APK quy tắc chung thành công; quyền FinAI NotificationListener bật.
- Native SQLite đang giữ 2 sự kiện bankNotification từ com.tpb.mb.gprsandroid.
- Chạy parser Dart hiện tại trên payload lấy từ SQLite qua stdin trong bộ nhớ, không ghi raw payload ra file/log. Hai kết quả parsed: một expense, một income. Cả hai amountMatchesPs=true, directionMatchesPs=true, descriptionPresent=true.
- Đây là bằng chứng nhận thông báo TPBank thật vào Native Inbox và parser đọc được số tiền/chiều theo PS. Chưa đối chiếu toàn bộ nội dung mô tả bằng mắt hoặc xác minh chữ ký app.
- Chưa ack/xóa hai sự kiện thử. Không tự tạo giao dịch ngân hàng hoặc Transaction.
- Cây accessibility FinAI không cung cấp được nhãn màn/nhãn kết quả trong phiên này; không dùng các phép kiểm tra UI không thấy nhãn để khẳng định đã quan sát thẻ kết quả. Người dùng cần mở Inbox và bật xem nội dung để nghiệm thu UI.
- Không suy rộng bằng chứng này thành hỗ trợ mọi mẫu TPBank hoặc mọi ngân hàng, cũng không suy ra các tình huống nền/kill/force stop đã đạt.
