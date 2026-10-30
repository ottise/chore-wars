# Đăng ký email và giới hạn auth — 30/10/2026

## Nguyên nhân quan sát

Cloud trả 409 `Account email is not available yet` khi gọi OTP cho địa chỉ QA không tồn tại. Nhánh này chạy trước lookup tài khoản và cho thấy transport email chưa được cấu hình đầy đủ trên service backend; không phải lỗi mật khẩu hay mất kết nối database.

Brevo đã được kiểm tra chỉ đọc với khóa mới: API xác thực 200, sender `cquynh638@gmail.com` tồn tại và active. File `.env.account-email.local` đã cập nhật riêng, được Git ignore. **Render vẫn cần nhập các biến từ file này**; push source không tự đưa khóa local lên cloud. Không tắt xác thực email để vượt lỗi cấu hình.

Hai log đính kèm chủ yếu là lỗi media/layout từ bản cũ và các SELECT worker định kỳ; không có bằng chứng rằng tất cả những dòng đó là lần đăng nhập thất bại. Production config mới chỉ giảm log EF command thường lệ xuống Warning, không tắt worker và không giấu lỗi database thật.

## Bản sửa

- FE: chặn gửi trùng đăng ký khi đang xử lý; giữ nội dung và chờ 30 giây sau lỗi, tôn trọng `Retry-After` nếu server trả về. Lỗi transport hiển thị riêng thay vì gắn nhầm vào ô xác nhận mật khẩu. Các ô không thay đổi trong lúc request đang chạy.
- Gửi/resend OTP: chờ 60 giây kể cả khi gửi thất bại; xác minh mã sai chờ 10 giây; 429 dùng thời gian server trả về. Có đếm ngược và vô hiệu nút trong thời gian chờ.
- Sau khi refresh thất bại, interceptor hết hạn phiên một lần và chặn mọi request bảo vệ tiếp theo trước khi ra mạng; public login/register/OTP không bị đưa vào vòng refresh. User profile không retry tự động.
- Retry chung của app: không tự thử lại 4xx/cancel/chứng chỉ lỗi; lỗi mạng/5xx tối đa một lần sau 2 giây. Không thêm retry tự động cho thao tác đăng ký hoặc gửi mã.
- Backend: login/register/refresh chung ngân sách 20 request/phút trên IP backend quan sát; OTP và Google giữ ngân sách riêng 10/phút. Trả 429 và `Retry-After`, không xếp hàng đợt request dư. Các client dùng chung IP/proxy cũng dùng chung ngân sách.
- Lỗi gửi email vẫn lưu mốc cooldown trong database; yêu cầu lặp không gọi provider tiếp trong một phút. Mã đã gửi thành công trước đó không bị vô hiệu nếu lần resend thất bại. OTP vẫn tối đa 5 lần đoán sai và hết hạn sau 10 phút.
- Thông báo lỗi toàn cục giãn từ 5 lên 30 giây. Đây là giới hạn thông báo UI, không phải cơ chế thay thế rate limiting server.

## Kiểm thử

Test HTTP kiểm tra login sai 20 lần rồi lần 21 trả 429 có Retry-After. Test PostgreSQL kiểm tra lỗi provider giữ cooldown, chặn lặp và giữ mã cũ còn dùng được. Widget/core tests kiểm tra register một lần, OTP lỗi bị chặn 60 giây, không refresh sau khi hết phiên và retry policy có trần. Các bài OTP verify/reset hiện có tiếp tục chạy.

Kết quả: 139 test Flutter đạt (1 live-network bài cần fixture bỏ qua trong lượt này); 86 integration backend đạt, 14 bài worker/Kafka/AI cần môi trường riêng bỏ qua. Bộ tập trung auth/OTP có 15 test Flutter và 5 test backend đạt. Analyzer sạch. Không có migration/schema mới trong bản sửa này.

## Cấu hình cần làm trên web

Render → service `chore-wars` → Environment → Add from .env: nhập nội dung file riêng `.env.account-email.local`, gồm `AccountEmail__Provider`, `AccountEmail__ApiKey`, `AccountEmail__FromAddress`, `EmailVerification__Required`. Save/redeploy. Không nhập khóa vào service AI hoặc đưa `.env` lên GitHub.

Kiểm tra cấu hình bằng endpoint OTP với email QA không tồn tại: sau cấu hình đúng trả 200 generic; phép thử này **không chứng minh thư thật đã đến inbox**. Gửi/xác thực OTP với hộp thư thật cần nghiệm thu riêng qua giao diện, không ghi mã OTP hoặc key vào report/log.
