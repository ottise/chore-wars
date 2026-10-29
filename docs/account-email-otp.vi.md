# OTP tài khoản và đơn hàng SMS

## Luồng tài khoản

- Đăng ký mới bằng mật khẩu: tạo tài khoản chưa xác thực → Verify email → Send code → nhập mã → Confirm → đăng nhập.
- Trang đăng nhập có Verify email để tiếp tục khi đã đóng hộp xác thực, và Forgot password để gửi mã đặt lại mật khẩu.
- Tài khoản Google dùng email đã được Google xác thực, không yêu cầu mã OTP bổ sung.
- Migration `20261029162034_AddEmailVerificationAndOtp` thêm `Users.EmailVerifiedAt`, cập nhật **các tài khoản tồn tại tại thời điểm migration** thành đã xác thực và tạo bảng `EmailOtpChallenges`. Không đặt default verified cho tài khoản mới.
- OTP sáu chữ số, tồn tại 10 phút, tối đa 5 lần đoán sai; resend cách ít nhất 60 giây, vô hiệu mã cũ. Mỗi mục đích có challenge riêng. Database chỉ lưu HMAC gắn với ID challenge, không lưu mã gốc.
- OTP đặt lại mật khẩu chỉ gửi cho tài khoản có mật khẩu và đã xác thực email. Google-only dùng Google. Response gửi mã không tiết lộ tài khoản có tồn tại hay không.
- Đặt lại mật khẩu thu hồi refresh token cũ; access token đã cấp vẫn chịu thời hạn JWT hiện có.

## Gửi email trên Render

Render Free chặn SMTP 25/465/587: https://render.com/docs/free . Đổi email supplier thành OTP không loại bỏ giới hạn này.

Code hỗ trợ HTTPS Brevo. Tạo API key tại tài khoản Brevo và xác thực sender trước; dùng **API key**, không phải SMTP key. Sau đó nhập các biến sau vào Environment của backend **chore-wars**, không phải AI/FE:

```ini
AccountEmail__Provider=Brevo
AccountEmail__ApiKey=<nhập API key trực tiếp trên Render>
AccountEmail__FromAddress=<sender đã được Brevo xác thực>
EmailVerification__Required=true
```

Hướng dẫn chính thức: [API key và quickstart](https://developers.brevo.com/docs/quickstart), [xác thực sender](https://help.brevo.com/hc/en-us/articles/208836149-Create-a-new-sender-From-name-and-From-email).

Mẫu không chứa secret ở `deploy/account-email.env.example`. API key và sender thật chưa được cấu hình/kiểm tra trên cloud trong lượt code này. Không coi transport test với HTTP giả hoặc SMTP loopback là thư đã tới hộp thư người dùng. Khi email chưa được cấu hình, đăng ký mật khẩu mới và yêu cầu OTP trả thông báo email chưa sẵn sàng; tài khoản đã xác thực và Google vẫn đăng nhập được.

Nếu dùng SMTP trên hạ tầng cho phép cổng đó, đặt `AccountEmail__Provider=SMTP`; các biến `OrderEmail__Host/Port/EnableSsl/Username/Password/FromAddress/FromName` hiện có được giữ để tái sử dụng transport, **không dùng để gửi supplier**.

## Luồng Shop → đơn hàng

Thêm món và thông tin liên hệ trong đúng nhà → chọn số lượng → Save & open SMS. Backend lưu snapshot tên món, số lượng, giá, người đặt và điện thoại supplier trước khi FE mở `sms:` có nội dung đơn. Người dùng tự bấm gửi trong ứng dụng SMS. Desktop không có ứng dụng SMS có thể Copy message hoặc Call. Không đánh dấu SMS đã gửi chỉ vì mở ứng dụng.

Order detail vẫn có thông tin người đặt, món, số lượng, tổng và Mark as paid. Chỉ người đặt được ghi nhận thanh toán. Số tiền, người ghi nhận, thời gian và tham chiếu lưu bền vững; không coi khai báo là ngân hàng xác minh và không tự tạo nợ cho người khác. Request ID chống trùng khi retry. Không tạo queue email supplier mới; retry email supplier cũ bị từ chối, dữ liệu cũ giữ để tra cứu.

## Thành viên mới

Join nhà đang ACTIVE tự chia phần việc NORMAL còn lại cho người mới khi làm giảm chênh lệch tải Karma. Giữ nguyên giờ làm và hạn; chỉ xét việc ASSIGNED chưa bắt đầu, chưa có bằng chứng, phạt, bounty hay nghĩa vụ thanh toán. Không chuyển việc hoàn thành, quá hạn, bonus hoặc việc đang làm.

Người mới chưa khai lịch rảnh kế thừa khung giờ của lịch nhà cho phần việc được chia; lịch bận đã khai, ngoại lệ theo ngày, giới hạn phút/ngày, số việc/tuần và trùng giờ đều được tôn trọng. Không ép chuyển nếu không có phương án phù hợp. Lưu episode trách nhiệm MEMBER_JOINED, tăng revision một lần và thông báo người cũ/người mới có việc thay đổi. Join, phân việc và thông báo nằm trong cùng transaction dưới khóa household; join trùng không chia lại.
