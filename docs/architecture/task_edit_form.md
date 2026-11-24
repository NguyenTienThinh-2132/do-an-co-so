> Hiện trạng mới nhất: [Bàn giao Tasks chế độ ngày](tasks_handover.md) — 12/11/2026. Ghi chú dưới đây là lịch sử từng bước.

# Sửa Công việc — 08/11/2026

## Triển khai

- TaskFormController: trạng thái saving/failure và chặn gửi trùng dùng chung.
- TaskCreateController kế thừa và ghi create như trước.
- TaskEditController nhận taskId/repository, load getById, rồi update đúng ID.
- TaskFormPage dùng chung layout/validation; TaskCreatePage là wrapper tạo.
- TaskEditPage hiển thị loading, lỗi và form điền dữ liệu bản ghi mới tải.
- Entry point demo tạo controller trong route composition root, tự load/dispose.
- Icon bút sửa trên mỗi thẻ truyền ID qua callback; UI không tạo repository.
- Không sửa router chung. MaterialPageRoute này chỉ dùng demo;
  chưa tuyên bố các URL /tasks/:id/edit đã tích hợp vào router nhóm.

## Quy tắc

- Load theo ID trước khi sửa, không dùng object từ danh sách làm nguồn chính.
- Điền tên, mô tả, start/end theo giờ địa phương, priority từ Task.
- Giữ categoryId hiện có dù chưa có giao diện danh mục.
- TaskDraft không chứa id/status/createdAt; repository giữ metadata khi update.
- Không đổi trạng thái qua form sửa.
- Tên trim không rỗng, endAt sau startAt; thời gian gửi UTC.
- Saving khóa input/nút lưu/đóng, không tự retry request ghi.
- Load validation/notFound có thông báo ID sai/bản ghi đã xóa, không mở form ghi.
- Load lỗi hạ tầng có Thử lại.
- Nếu bản ghi bị xóa khi form đang mở, update trả notFound:
  giữ nội dung nhập và báo bản ghi đã xóa, không chuyển thành create.
- Dispose bỏ response load đến muộn, không đóng repository/client của chủ sở hữu.
- Chưa có version/optimistic locking; sửa đồng thời vẫn theo backend hiện có.
- Sau sửa đổi ngày/trạng thái bộ lọc, bản ghi có thể rời danh sách hiện tại
  đúng theo query. Các stream cùng instance repository được refresh.

## Tự kiểm tra trên preview

Mở http://127.0.0.1:3111 rồi tải lại sau khi bản build mới hoàn tất.
1. Chọn Tất cả; nếu chưa có task, dùng + tạo một công việc trong ngày.
2. Bấm icon bút Sửa công việc trên thẻ.
3. Thấy loading rồi form điền sẵn; sửa tên/mô tả/ưu tiên rồi Lưu.
4. Quay về danh sách, nội dung đổi đúng, số task không tăng thêm.
5. Tải lại trang và mở sửa lần nữa để xác nhận dữ liệu đã lưu.
6. Thử tên rỗng hoặc end <= start: thấy lỗi và không gửi ghi.

Backend/proxy preview dùng script serve-tasks-preview.mjs như tài liệu tạo form.
Host web chỉ nằm trong build/tasks_preview_host, không thêm platform vào app chính.
Không có dữ liệu seed; không xóa dữ liệu người dùng tạo bằng form.

## Kiểm tra

    flutter test test/widget/features/tasks/task_edit_page_test.dart test/widget/features/tasks/task_create_page_test.dart
    flutter test test/integration/task_edit_controller_real_test.dart --dart-define=TV3_TASKS_API_BASE_URL=http://127.0.0.1:3111/api
    flutter analyze

Kết quả đã quan sát:
- 6 test edit và 5 test create đạt (11 test): điền form, update đúng ID,
  giữ category/priority/thời gian, ID validation/notFound, xóa lúc lưu,
  dispose/load muộn và chặn update trước load.
- Test tích hợp với PostgreSQL thật đạt: create fixture, đổi trạng thái completed,
  load và update qua editor, giữ id/status/createdAt, đọc lại đúng nội dung,
  xóa fixture rồi update trả notFound. Cleanup được assert.
- flutter analyze sạch.
- Widget test dùng repository stub; phép thử tích hợp dùng HTTP thật.
- Chưa tự thao tác trong Chrome do công cụ điều khiển runtime lỗi từ bước trước.
- Chưa kiểm chứng Android hoặc build lại APK.
- Không đổi schema/API chung, dependency, shell/router; không commit/push.

Bước tiếp theo dự kiến sau khi người dùng xác nhận: đổi trạng thái từ danh sách.Kiểm tra toàn dự án: 150 test đạt, 3 test backend opt-in skip khi không truyền URL. Phép thử sửa với backend thật đã chạy riêng và đạt.
Bản preview web mới build thành công; JavaScript qua server preview trả HTTP 200. Có cảnh báo font Cupertino như bước tạo, không làm build thất bại. Tải lại trang để nhận bản sửa.
