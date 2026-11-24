# Trợ lý FinAI — chat mô phỏng

## Đã triển khai

- FakeAssistantService chỉ đọc công việc qua TaskReader, không gọi LLM hoặc ghi dữ liệu.
- Ba câu hỏi nhanh: Việc trong khoảng này, Việc ưu tiên cao, Tiến độ. Dữ liệu và phần trăm lấy từ reader; danh sách rỗng có phản hồi riêng.
- Gửi tin không rỗng, chặn gửi đồng thời, trạng thái Đang trả lời, Dừng, lỗi và Thử lại, nhãn Chế độ mô phỏng.
- Kịch bản Bình thường, Chậm, Lỗi thử nghiệm chọn từ menu ba chấm.
- Controller bỏ phản hồi của lượt đã hủy hoặc kết thúc. Đã sửa lỗi AssistantDone gửi lặp có thể thêm trùng câu trả lời; retry không nhân đôi tin nhắn người dùng.

## Đã kiểm chứng tự động ngày 13/11/2026

16 unit/widget test chat đạt: trim/chặn rỗng/chặn gửi đồng thời; hủy rồi gửi mới; retry không trùng; Done lặp/lỗi sau Done; stream đóng sớm; dispose; reader hoàn thành sau hủy không phát tin; ba mẫu phản hồi đúng dữ liệu; UI chậm/Dừng và lỗi/Thử lại.

Lệnh: flutter test --no-pub --concurrency=1 test/unit/features/assistant test/widget/features/assistant

## Tự test trên điện thoại

1. Chạy backend demo, nối USB nếu dùng địa chỉ localhost; mở entry point lib/dev/main_tasks_day_demo.dart rồi vào Trợ lý FinAI.
2. Menu ba chấm → Chậm → bấm một câu hỏi nhanh → Đang trả lời và Dừng phải hiện. Bấm Dừng trước 3 giây; đợi quá 3 giây, câu trả lời cũ không xuất hiện.
3. Menu → Lỗi thử nghiệm → gửi câu hỏi → lỗi và Thử lại hiện. Bấm Thử lại, phải có một phản hồi thành công và chỉ một tin nhắn người dùng cho lần hỏi đó.
4. Gõ chỉ khoảng trắng: nút Gửi bị khóa. Khi đang trả lời không gửi thêm được.
5. Chọn Bình thường để quay lại chế độ demo thông thường.

## Giới hạn / chưa thực hiện

- Chưa LLM thật, giọng nói, OCR, thanh toán hoặc AI ghi dữ liệu.
- Hủy ngừng nhận kết quả; Future reader đang chạy có thể vẫn hoàn tất bên trong, không tuyên bố hủy được tác vụ mạng của reader.
- Chưa nghiệm thu thay đổi controller trên máy thật trong phiên này. Widget tests không thay thế kiểm chứng điện thoại.
