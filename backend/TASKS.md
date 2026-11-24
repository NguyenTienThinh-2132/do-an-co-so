# API Công việc demo TV3

Backend local thử nghiệm bằng NestJS + Prisma + PostgreSQL.
Schema, API và database finai_tv3_demo chưa phải hợp đồng tích hợp chung của nhóm.
Chưa có đăng nhập, phân quyền hoặc kết nối Flutter.
Server chỉ lắng nghe 127.0.0.1.

## Chạy và kiểm tra

Chạy trong backend:

    docker compose up -d postgres
    npx --no-install prisma generate
    npx --no-install prisma migrate deploy
    npm run build
    npm run start:dev

Base URL mặc định: http://127.0.0.1:3000.
Không ghi đè .env cũ; cấu hình kết nối xem DOCKER.md.
Dùng một terminal khác để gọi API khi server đang chạy.

Kiểm tra code và fake database:

    npm test
    npm run test:e2e
    npm run lint

Kiểm tra toàn bộ CRUD qua HTTP và PostgreSQL thật:

    npm run build
    node scripts/check-tasks-crud.mjs

Script tự mở app ở cổng tạm, dùng fixture có marker UUID riêng, đóng/mở lại
app để kiểm tra lưu bền vững, rồi xóa đúng fixture của lần chạy.
Không xóa bảng hoặc dữ liệu ngoài fixture; không in mật khẩu hoặc lỗi SQL thô.

## Các endpoint

| Method | Route | Thành công |
| --- | --- | --- |
| POST | /tasks | 201 và Task mới |
| GET | /tasks?start=...&end=... | 200 và mảng Task |
| GET | /tasks/:taskId | 200 và Task |
| PUT | /tasks/:taskId | 200 và Task đã sửa |
| PATCH | /tasks/:taskId/status | 200 và Task đã đổi trạng thái |
| DELETE | /tasks/:taskId | 204, không có body |

ID dùng UUID do Prisma cấp. Route theo ID dùng ParseUUIDPipe.
400: ID/input/query sai; 404: ID hợp lệ nhưng bản ghi không tồn tại hoặc đã xóa.
503: truy cập database thất bại; không trả chi tiết driver/SQL.

## Nội dung Task khi tạo hoặc thay thế

POST và PUT dùng cùng các trường:

    {
      "title": "Viết báo cáo tuần",
      "description": "Phần TV3",
      "categoryId": null,
      "startAt": "2026-11-07T09:00:00+07:00",
      "endAt": "2026-11-07T10:00:00+07:00",
      "priority": "medium"
    }

- title bắt buộc là chuỗi, trim và không rỗng.
- description/categoryId cho phép bỏ qua hoặc null.
- categoryId chưa được kiểm tra tồn tại vì chưa có bảng danh mục.
- startAt/endAt phải là ISO có Z hoặc offset dạng +07:00; endAt sau startAt.
- priority chỉ low/medium/high; bỏ qua là medium, null không hợp lệ.
- Từ chối id, status, createdAt, updatedAt và mọi trường ngoài hợp đồng.
- Response dùng camelCase và thời gian ISO UTC.
- POST tạo ID, status pending và các thời điểm quản lý bởi backend.
- PUT thay toàn bộ nội dung: bỏ description/categoryId thì thành null;
  bỏ priority thì thành medium. ID, status và createdAt được giữ nguyên.
- Prisma cập nhật updatedAt; không tự sửa timestamps trong Flutter.

Ví dụ PowerShell tạo công việc thật, bản ghi này được giữ để tự kiểm tra:

    $body = @{
      title = 'Viết báo cáo tuần'
      startAt = '2026-11-07T09:00:00+07:00'
      endAt = '2026-11-07T10:00:00+07:00'
    } | ConvertTo-Json
    $task = Invoke-RestMethod -Method Post -Uri 'http://127.0.0.1:3000/tasks' -ContentType 'application/json; charset=utf-8' -Body $body
    $task
    Invoke-RestMethod -Uri ("http://127.0.0.1:3000/tasks/" + $task.id)

## Lọc danh sách

Query bắt buộc: start và end có múi giờ, end phải sau start.
Query tùy chọn: status, priority, searchText; trường khác bị từ chối.

- Khoảng [start, end), lấy công việc giao nhau:
  task.startAt < end AND task.endAt > start.
- Công việc kết thúc đúng start hoặc bắt đầu đúng end không được chọn.
- Công việc kéo dài qua ngày xuất hiện ở các ngày mà nó giao nhau.
- Trạng thái, ưu tiên và từ khóa được kết hợp bằng AND.
- searchText được trim; rỗng là không lọc tên.
- Tìm chuỗi con trong title: không phân biệt hoa/thường, có phân biệt dấu.
- Ký tự %, _ và \ trong từ khóa được tìm như ký tự thường.
- Sắp xếp startAt tăng dần rồi id tăng dần.
- Danh sách rỗng trả 200 với []; chưa phân trang.

Ngày 07/11/2026 theo UTC+7 tương ứng khoảng UTC
2026-11-06T17:00:00Z đến 2026-11-07T17:00:00Z.

Ví dụ PowerShell, tự encode query để dấu + và ký tự tìm kiếm không bị hiểu sai:

    $query = @{
      start = '2026-11-06T17:00:00Z'
      end = '2026-11-07T17:00:00Z'
      status = 'pending'
      priority = 'medium'
      searchText = 'báo cáo'
    }
    $parts = $query.GetEnumerator() | ForEach-Object {
      [Uri]::EscapeDataString($_.Key) + '=' + [Uri]::EscapeDataString($_.Value)
    }
    Invoke-RestMethod -Uri ('http://127.0.0.1:3000/tasks?' + ($parts -join '&'))

## Đổi trạng thái và xóa

PATCH /tasks/:taskId/status chỉ nhận:

    { "status": "completed" }

Status hợp lệ: pending/inProgress/completed.
Quá hạn là giá trị suy ra từ endAt và trạng thái, không lưu thành status overdue.
Đổi trạng thái không sửa nội dung hoặc createdAt.
Chưa áp đặt thứ tự chuyển trạng thái riêng.

DELETE /tasks/:taskId xóa đúng bản ghi.
Xóa lại, sửa hoặc đổi trạng thái bản ghi đã mất trả 404.
Chưa có UI xác nhận xóa; giao diện sau này phải thực hiện xác nhận trước khi gọi.

## Kết quả kiểm chứng

- Build, format, lint đạt.
- 88 unit test và 42 HTTP e2e test đạt tại bước hoàn tất CRUD.
- Fake kiểm chứng validation, mapping, HTTP 201/200/204/400/404/503.
- PostgreSQL thật kiểm chứng tạo/đọc/sửa/trạng thái/xóa.
- Kiểm chứng lọc giao ngày, ranh giới, AND, rỗng, sắp xếp ổn định,
  tìm tên có dấu, hoa/thường và ký tự đặc biệt.
- Sau đóng app NestJS và khởi tạo app NestJS mới, dữ liệu đã sửa còn nguyên.
- Dữ liệu thử tự động đã được dọn; migration không thay đổi trong bước CRUD.

## Chưa kiểm chứng hoặc chưa thực hiện

- 503 mới kiểm tra bằng fake, chưa chủ động ngắt database thật.
- Chưa kiểm chứng sau restart container PostgreSQL/Windows.
- Chưa có phân trang, tài khoản người dùng, phân quyền hoặc deploy công khai.
- Chưa nối Flutter, HTTP TaskRepository, stream cập nhật hoặc UI.
- Chưa có TaskReader/TaskDto public adapter, danh mục công việc hoặc nhắc việc.
- Chưa triển khai Dòng tiền, Android Native hoặc Assistant trong bước này.
- Cảnh báo phiên bản Node/công cụ và npm audit trước đó chưa được xử lý ở bước CRUD.
