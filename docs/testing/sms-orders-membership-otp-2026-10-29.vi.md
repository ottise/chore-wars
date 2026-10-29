# Kiểm thử SMS order, thành viên mới và OTP — 29/10/2026

Log người dùng gửi có 404 Shop từ bản backend cũ. Kiểm tra lại cloud sau khi Google deploy thành công: GET house shop suppliers và POST shop items trả 401 khi không có token, chứng minh route hiện có và vẫn được bảo vệ. Không tạo supplier thử trên database thật.

Thay đổi yêu cầu được chốt trong phiên: email chỉ cho OTP xác thực đăng ký mới/quên mật khẩu, đơn supplier lưu rồi mở SMS để người dùng tự gửi; join nhà ACTIVE tự chia việc còn lại cho người mới, không cần duyệt lại.

## Bằng chứng kiểm thử

- Backend unit: 125 đạt, gồm HTTPS OTP gửi đúng endpoint, kiểm tra provider chấp nhận, không tự fallback SMTP; SMTP loopback giữ để kiểm tra transport.
- Backend integration toàn bộ có thể chạy trong fixture: 80 đạt, 14 bỏ qua vì thiếu dịch vụ Kafka/Python riêng. Không coi test bỏ qua là đã chạy. Kiểm tra thêm các thay đổi cuối bằng bộ EmailOtpHttpTests/HouseShopTests/ShopOrderJourneyTests/MemberJoinRedistributionTests/MigrationBackfills.
- Flutter toàn bộ: 122 đạt, 1 live-network test bỏ qua vì cần fixture riêng. Ba test mới xác minh OTP dialog cho verify/reset và nội dung SMS đã chạy riêng; các flow Shop/AI order/login layout tiếp tục đạt sau thay đổi.
- CI Python: 11 đạt, 1 tùy chọn bỏ qua.
- Test migration cũ dùng seed trước khi hạ schema để tránh dùng entity mới trên bảng cũ; migration lên lại chứng minh tài khoản cũ có EmailVerifiedAt. Test urgent cũ dùng clock ban ngày cố định để tránh phụ thuộc giờ chạy gần nửa đêm.

## Các tình huống đã kiểm tra

Shop: thêm ST25 + số điện thoại → retry cùng request không thêm bản sao → đọc lại catalog → số lượng 2 tính đúng 300000 → lưu SIMPLE_SMS không có email queue → record payment retry không nhân đôi → tải lại history/detail giữ người trả và số tiền → người ngoài nhà bị từ chối.

Join: chia một phần các việc tương lai cho người mới, giữ giờ làm/hạn; hoàn thành và bounty giữ nguyên; ledger kết thúc trách nhiệm cũ và mở MEMBER_JOINED; chỉ tăng revision một lần; thông báo đúng nhà/người bị ảnh hưởng; join trùng không chia lại; lịch không rảnh được tôn trọng.

OTP: chưa xác thực không đăng nhập mật khẩu được; không lưu mã rõ; cooldown; mã dùng một lần; 5 lần sai bị khóa; hết hạn; mã VERIFY_EMAIL không reset password được và ngược lại; người không tồn tại không lộ qua response request; reset thu hồi refresh token; Google giữ luồng xác thực riêng. Email chưa cấu hình không tạo tài khoản mật khẩu không thể xác thực.

## Giới hạn nghiệm thu

Không gửi SMS hay email ra người nhận thật trong test. SMS chỉ mở ứng dụng; người dùng phải bấm gửi. Brevo cần API key và sender đã xác thực trên Render trước khi nghiệm thu thư OTP đến hộp thư. Cấu hình và hướng dẫn ở [Account email OTP](../account-email-otp.vi.md).

Backup cloud riêng: `artifacts/private/core-before-email-otp-20261029.dump`, đã kiểm tra archive và bảng Users trước migration. Kết quả áp dụng schema lưu riêng trong `artifacts/private/email-otp-migration-result.json`; không commit dữ liệu tài khoản hoặc secret. Backend cần deploy commit mới trước khi dùng các hành vi mới trên cloud.
