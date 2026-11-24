# Hợp đồng tích hợp tài chính PostgreSQL — bản đề xuất

Trạng thái: đã chốt hướng PostgreSQL chung qua NestJS; CHƯA duyệt schema/API cụ thể, CHƯA áp dụng migration. Ngày: 13/11/2026.

Đích: D:/git/do-an-co-so. Nguồn TV1/TV2 chỉ đọc: D:/DoAnChuyenNganh/dev/dev/finai. Không commit/push, không ghi đè nguồn.

## 1. Phạm vi

Giữ Trang chủ, Quản lý hũ, Dòng tiền của TV1/TV2 và Công việc, Assistant, Native Inbox của TV3. Dữ liệu nghiệp vụ nằm trong PostgreSQL qua NestJS + Prisma. Native Inbox SQLite tiếp tục chỉ giữ sự kiện/chờ xác nhận và metadata nhắc việc; không là sổ tài chính.

Không chép LocalFinanceRepository/SqliteFinanceStateStore vào đường chạy chính. Không chép TaskRepository dạng int/isCompleted của TV1/TV2 thay cho Tasks TV3. Không gộp hai danh sách giao dịch, không tự sinh Transaction từ thông báo ngân hàng.

Backend hiện chỉ có tasks demo. Các bảng dưới đây là đề xuất bổ sung vào DB demo hiện có; chưa được coi là schema sản phẩm/chung toàn nhóm.

## 2. Nguồn dữ liệu và bất biến

- Số dư tài khoản = openingBalanceVnd + SUM(transactions.amountVnd), tính toàn bộ lịch sử.
- Thu tháng = SUM(amountVnd > 0); chi tháng = ABS(SUM(amountVnd < 0)). Không đưa tiền ban đầu, phân bổ hũ, task hoặc thông báo Native vào thu/chi.
- Tiền đã phân bổ cho hũ = SUM(allocation_items.amountVnd). Tiền đã chi của hũ = ABS(SUM(transactions.amountVnd < 0 theo jarId)). Tiền còn lại = phân bổ - chi.
- Tiền chưa phân bổ = số dư tài khoản - SUM(tiền còn lại của các hũ đang dùng).
- Không có cột currentBalance/spentAmount là nguồn độc lập; API trả các giá trị tổng hợp để khớp DTO TV1/TV2.
- Chi từ hũ chỉ tạo MỘT transaction âm có jarId. Không tạo thêm một giao dịch trừ tài khoản.
- Tổng allocationBps của các hũ đang dùng luôn 10000 (100%). Đổi tỷ lệ chỉ áp dụng lần phân bổ sau.
- Xóa mềm hũ tự thêm; không xóa sáu hũ mặc định. Tiền chưa chi trở về pool, số dư tài khoản không đổi. Tỷ lệ được chuyển sang một hũ đang dùng; lịch sử vẫn tham chiếu hũ cũ.
- Chia tiền lẻ bằng largest remainder giống splitAllocation hiện có; tie-break theo ID ổn định.

## 3. Sáu bảng mới dự kiến

| Bảng | Trường chính | Vai trò |
| --- | --- | --- |
| finance_books | id UUID, opening_balance_vnd BIGINT, revision INT, budget_vnd BIGINT, is_demo BOOL, created_at, updated_at | Một sổ demo duy nhất do server chọn, thông tin gốc và revision chung |
| finance_jars | id UUID, book_id FK, default_code nullable, title, normalized_title, subtitle, style_key, allocation_bps INT, deleted_at nullable, created_at | Hũ; default_code nhận diện sáu mặc định, không phụ thuộc UUID |
| finance_transactions | id UUID, book_id FK, jar_id FK nullable, title, amount_vnd BIGINT signed, category, occurred_at TIMESTAMPTZ(3), note nullable, created_at | Sổ giao dịch duy nhất |
| finance_allocations | id UUID, book_id FK, amount_vnd BIGINT positive, created_at | Một lần phân bổ, không phải transaction thu/chi |
| finance_allocation_items | allocation_id FK + jar_id FK composite PK, amount_vnd BIGINT nonnegative, ratio_bps INT | Snapshot tiền và tỷ lệ của từng hũ tại lần phân bổ |
| finance_requests | book_id + request_key composite UNIQUE, operation, payload_hash, response JSONB, created_at | Kết quả command đã commit để retry không ghi trùng |

Ràng buộc SQL: tiền ban đầu/ngân sách không âm; transaction khác 0; allocation > 0; ratio trong 0..10000; FK lịch sử không CASCADE DELETE; unique tên chuẩn hóa cho hũ chưa xóa; unique default_code trong một sổ. Kiểm tra hũ/transaction cùng book trong transaction nghiệp vụ (không tin jarId từ client).

Tổng tỷ lệ/số dư là bất biến liên bảng, không chỉ dựa vào CHECK từng dòng. Giữ nguyên bảng tasks và các migration TV3 hiện có. Chưa thêm users/auth hoặc thay đổi chủ sở hữu tasks trong bước này; môi trường demo hiện tại không được mô tả là ứng dụng nhiều người dùng đã có phân quyền.

## 4. Tiền, ngày giờ, validation

- DB dùng BIGINT VND, không float. JSON dùng chuỗi số thập phân cho mọi giá trị tiền, ví dụ "75000"; adapter chuyển sang int của DTO Flutter và kiểm tra phạm vi trước khi hiển thị.
- Lệnh nhập tiền giữ giới hạn hiện có: 1..999999999999 VND. Các tổng hiển thị cần kiểm tra giới hạn số nguyên an toàn khi hỗ trợ Web; không âm thầm mất chính xác.
- Timestamp lưu UTC TIMESTAMPTZ(3), API ISO 8601 có timezone. Flutter gửi start/end UTC của tháng tính theo giờ Việt Nam; lọc [start,end). Không dùng timezone mặc định của server để chia tháng.
- Sáu category giữ đúng enum TV1/TV2: food, transport, shopping, education, housing, other.
- Khoản chi: title trim 1..80, note trim <=500, amount dương; API tự đổi dấu sang âm. jarId=null nghĩa là tiền chưa phân bổ, không phải tài khoản/hũ mặc định thứ hai.
- Hũ: tên chuẩn hóa khoảng trắng, 1..50; mô tả <=120; styleKey giữ bảy lựa chọn của TV1/TV2; tên active không trùng không phân biệt hoa thường.
- Hạn mức budget được lưu để màn hiện tại đọc; chưa tự thêm màn chỉnh ngân sách. Chưa triển khai tạo thu nhập, sửa/xóa giao dịch hoặc lập khoản dự kiến.

## 5. API dự kiến (prefix /finance)

| Endpoint | Port/hành vi |
| --- | --- |
| GET /finance/overview?start=...&end=... | DashboardReader: số dư toàn kỳ, thu/chi tháng, budget, transactions, upcoming |
| GET /finance/expense-sources | ExpenseWriter.getExpenseSources: pool chưa phân bổ + hũ đang dùng |
| POST /finance/expenses | ExpenseWriter.recordExpense: ghi transaction âm, kiểm tra nguồn tiền |
| GET /finance/jars | JarRepository.watchJars: hũ active/deleted, số dư tổng hợp, lịch sử, revision |
| POST /finance/jars | Thêm hũ có tỷ lệ 0, tiền 0 |
| PUT /finance/jars/ratios | Toàn bộ tỷ lệ + expectedRevision; một command nguyên tử |
| DELETE /finance/jars/:id | expectedRevision + transferRatioToJarId; xóa mềm, kiểm tra mặc định |
| POST /finance/allocations | amount + requestId + expectedRevision; chia tiền, ghi history/items |

Overview/jars đọc nhất quán bằng một read transaction. Mốc dự kiến chưa có nguồn thật thì trả []; không seed hóa đơn/lương giả vào endpoint nghiệp vụ.

Mỗi mutation gửi Idempotency-Key ổn định cho một ý định người dùng. Server chuẩn hóa payload, hash cả operation + payload. Cùng key/cùng payload trả lại kết quả cũ; cùng key/khác payload trả 409, không ghi thêm. Tra kết quả cũ trước khi xét expectedRevision để retry sau commit vẫn thành công.

Giữ port TV1/TV2 ở mức tối đa: thêm requestId tùy chọn vào ExpenseDraft và tham số requestId tùy chọn của addJar/setAllocations/deleteJar để form giữ key qua retry; API ghi thật yêu cầu key. allocate dùng requestId đã có. Đây là thay đổi hợp đồng đề xuất, chưa sửa file domain nguồn hoặc đích. Cần sửa các form liên quan để key tạo một lần cho một draft; khi chưa rõ request trước đã commit hay chưa, không đổi payload rồi dùng lại key cũ.

API lỗi thống nhất: 400 validation, 404 không tồn tại, 409 revision/idempotency conflict, 503 unavailable. Không trả SQL, URL kết nối hoặc payload nhạy cảm. Flutter adapter map lỗi sang quy ước AppFailure/Result nội bộ hoặc FinanceRuleException cho các widget TV1/TV2 hiện dùng exception; không refactor nghiệp vụ UI ngoài việc nối port.

## 6. Ghi nguyên tử và chống đua

Toàn bộ thao tác ghi tài chính chạy trong Prisma transaction SERIALIZABLE, đọc/ghi revision của finance_book. Retry có giới hạn cho serialization conflict; re-check nguồn tiền/tỷ lệ/tên trước commit. expectedRevision sai trả 409 để người dùng tải dữ liệu mới.

Ghi chi: đọc nguồn tiền -> kiểm tra đủ -> insert transaction -> tăng revision -> lưu request/response -> commit. Phân bổ: kiểm tra pool và tỷ lệ -> chia tiền -> insert allocation/items -> revision/request -> commit. Xóa hũ: kiểm tra mặc định/đích nhận tỷ lệ -> chuyển tỷ lệ + soft delete -> revision/request -> commit. Bất kỳ bước nào lỗi đều rollback.

Không cho client gửi số dư cuối, tiền đã chi, số dư hũ hoặc phần trăm tổng hợp để server tin và lưu. Không nhập nguyên snapshot JSON của client làm nguồn nghiệp vụ mặc định.

## 7. Adapter và shell khi đến bước UI

Một RemoteFinanceRepository tại composition root thực thi DashboardReader, ExpenseWriter, JarRepository. Ba tab dùng CÙNG instance, do đó cùng nguồn giao dịch, tháng đang chọn và ẩn tiền. Sau mutation thành công invalidate cả overview và jars; lỗi đọc không biến thành số dư 0 giả. Khi nối UI, các nhãn “Đã lưu trên thiết bị” của nguồn phải đổi thành “Đã lưu trên máy chủ” cho adapter remote; không đặt isPersistent=false để giả dữ liệu chỉ ở bộ nhớ.

Shell giữ năm tab: Trang chủ, Hũ, AI, Công việc, Dòng tiền. Gắn Tasks/Assistant TV3, không dùng schedule/AI placeholder của nguồn. Một MaterialApp/navigator chính; giữ routes Tasks và Native Inbox, tap reminder vẫn mở đúng task. Refactor điểm nối sẽ được kiểm tra riêng, không nhét MaterialApp demo lồng vào tab.

Không cần thêm sqflite/path vào Flutter cho tài chính khi chốt PostgreSQL. Có thể cần flutter_localizations SDK để giữ lịch/form tiếng Việt; sẽ trình bày tại bước nối UI. Backend tiếp tục dùng dependency Prisma/pg hiện có (Prisma 7.10.1 đã khóa); không nâng lên ORM 8 hoặc đổi client API theo tài liệu phiên bản khác.

## 8. Dữ liệu cũ và dữ liệu mẫu

Không xóa/ghi đè hai repository hoặc database SQLite nguồn. Không tự chuyển fixture tài chính thành tiền thật. Sổ mới bắt đầu openingBalance=0, không giao dịch, sáu hũ mặc định một lần, có budget mặc định 0. Không tự seed lại khi mở app.

Nếu cần trình diễn đúng số liệu TV1/TV2: làm fixture demo riêng, gắn isDemo=true, khởi tạo bằng lệnh demo có guard và không trộn dữ liệu người dùng. Nếu cần chuyển SQLite cũ: bước import riêng, preview/backup, kiểm tra tổng, stable importId/idempotency, xác nhận trước khi ghi. Chưa nhập dữ liệu trong bước này.

## 9. Kiểm tra bắt buộc khi triển khai

- Migration chỉ thêm bảng tài chính, tasks cũ giữ nguyên.
- Chi từ pool/hũ đúng một lần; vượt nguồn không ghi; tiền/lịch sử/revision không đổi khi rollback.
- Hai lệnh chi/phân bổ đồng thời không tạo số dư âm hoặc phân bổ vượt tiền.
- Retry cùng key, khác key, cùng key khác payload; timeout sau commit rồi retry.
- Đổi tỷ lệ đủ 100%, snapshot lịch sử giữ tỷ lệ cũ; làm tròn chính xác từng đồng.
- Xóa hũ custom chuyển tỷ lệ/tiền đúng, hũ mặc định không xóa, lịch sử còn đọc được.
- Tổng thu/chi theo [start,end), timezone VN, số dư toàn kỳ; đổi tháng không đổi số dư toàn kỳ.
- Đóng/mở backend vẫn còn dữ liệu; adapter fake/real cùng hợp đồng; shell không làm hỏng Tasks, chat, tap thông báo.

## 10. Trình tự triển khai đề xuất

1. Người dùng duyệt hợp đồng này (schema sáu bảng + API + tiền/giờ + requestId).
2. Migration sáu bảng và kiểm tra giữ nguyên tasks; chưa gộp UI.
3. API read/bootstrap sổ rỗng, sáu hũ và adapter chỉ đọc; test riêng.
4. API ghi chi + idempotency; test riêng.
5. API thêm hũ, tỷ lệ, phân bổ, xóa; chia nhỏ từng command.
6. Đưa ba tab TV1/TV2 vào shell TV3, nối cùng adapter, test hồi quy và điện thoại.

Cập nhật 13/11/2026: người dùng đã duyệt PostgreSQL chung và triển khai bản gộp cơ bản. Xem `../integration/finai_progress_demo.md` để biết phần đã triển khai, kiểm chứng và giới hạn. Schema này vẫn là bản thử nghiệm tích hợp, chưa phải hợp đồng production đa người dùng của nhóm.
