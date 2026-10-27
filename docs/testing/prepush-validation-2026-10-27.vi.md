# Kiểm tra trước khi push ngày 27/10/2026

## Phạm vi

- Cấu hình Kafka SASL/TLS cho producer, outbox và consumers .NET, cùng AI worker Python.
- Kiểm tra CA/hostname được giữ; không dùng kết nối SASL không mã hóa.
- Backend lắng nghe cổng `PORT` do Render cấp.
- Tính năng household supplies, supplier, AI draft/reminder, đơn hàng và sổ nợ trực tiếp.
- Các sửa đổi trước đó về ảnh đại diện/minh chứng, lịch sử ảnh chat, QR bằng ảnh và phạm vi thông báo theo nhà.

## Kết quả

| Kiểm tra | Kết quả |
| --- | --- |
| Backend unit tests | 110 đạt |
| Backend integration suite với PostgreSQL local | 56 đạt, 14 bỏ qua vì thiếu cấu hình môi trường tương ứng |
| Kafka integration bổ sung với broker local | 3 đạt: chat notification, replay không lặp side effect, poison message isolation |
| Python AI suite | 77 đạt, 3 bỏ qua do chưa cấp database PostgreSQL test cho Python |
| Flutter analyze `lib test` | Không có lỗi |
| Flutter tests | 94 đạt |
| Flutter web release | Build thành công |
| EF model / migration | Không có model change chưa có migration |
| Staged whitespace | Đạt |
| Kiểm tra key thật / file riêng trong phần staged | Không phát hiện |

Test database dùng database tạm trên PostgreSQL local; không chạy test trên database Render.
Test không xác nhận kết nối thật tới Aiven hoặc giao dịch payOS thật.

## Giới hạn còn lại

- Có cảnh báo NU1903 cho AutoMapper 12.0.1 đã tồn tại trước thay đổi này.
- Web build có cảnh báo Wasm dry-run từ plugin `flutter_tts`; bản JavaScript release build thành công.
- Database cloud mới cần migration hoặc import dữ liệu qua bước vận hành riêng. Backend không tự chạy migration lúc startup.
- Backend trên Render phải deploy commit chứa code mới; thêm biến SASL vào commit cũ không đủ.
- Kafka cần đúng broker, mật khẩu, CA secret file và topics. Xem `render-aiven-kafka.vi.md`.
- AI API, AI worker và trainer là các tiến trình khác nhau; Uvicorn không tự khởi chạy worker/trainer.
- File `.env` thật, JSON cấu hình local, backup DB và media local nằm ngoài commit.
