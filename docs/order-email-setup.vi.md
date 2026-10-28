# Gửi email đơn hàng

## Trạng thái triển khai

Đơn mới: chọn sản phẩm/số lượng → Send → queue email backend → Sent → Mark as paid → log người ghi nhận, số tiền, thời gian. Không tạo công nợ hay cần người khác duyệt. Mark as paid là USER_REPORTED, không phải ngân hàng xác minh. Order cũ/payOS giữ luồng legacy riêng.

Đã kiểm tra Gmail SMTP authentication qua TLS thành công trên máy phát triển, không gửi email ra ngoài. Kiểm thử transport gửi vào SMTP loopback, không tới supplier thật. Chỉ hành động Send của người dùng mới tạo email gửi nhà cung cấp.

## Máy phát triển

Thông tin đã điền ở `backend/src/Presentation/appsettings.OrderEmail.local.json` (gitignored). Restart backend môi trường Development để đọc. File này không copy vào publish/Docker. Không commit password hoặc upload file này lên GitHub.

Nếu tự chạy Docker Compose từ workspace này, truyền file SMTP riêng: `docker compose --env-file .env.order-email.local up -d --build backend`. Nếu đã có `.env` riêng cho DB/dịch vụ thì truyền **cả hai**: `docker compose --env-file .env --env-file .env.order-email.local up -d --build backend`. Workspace hiện chưa có `.env`, nên không dùng ví dụ hai file khi chưa tạo file đó. Compose đã có binding SMTP/Google nhưng không tự đọc file `.env.order-email.local` nếu thiếu cờ trên. Kiểm tra đúng checkout/cấu hình DB; các lệnh up này chưa được thực thi lên backend/DB đang dùng trong đợt này.

## Render backend

Import file `.env.order-email.local` bằng Add from .env trong Environment của **backend**. File có 7 dòng riêng: OrderEmail__Host, OrderEmail__Port, OrderEmail__EnableSsl, OrderEmail__Username, OrderEmail__Password, OrderEmail__FromAddress, OrderEmail__FromName. Cấu hình local không tự đồng bộ lên Render. Save/redeploy sau khi nhập. Không cần đặt SMTP ở AI service hay frontend.

Migration mới: `20261028041556_AddSimpleOrderEmailAndPaymentLog`. Review/apply qua workflow database được bảo vệ hiện có trước release; không bật tự migrate production. Local test chỉ áp dụng lên PostgreSQL tạm, không chỉnh cloud DB.

Worker gửi email bằng snapshot của đơn và có lease. Nếu kết nối mất khi chưa biết SMTP đã nhận hay chưa, trạng thái Unknown yêu cầu người dùng kiểm tra trước khi Retry. SMTP không bảo đảm exactly-once; không tự resend các lần bất định. Log không chứa mật khẩu/nội dung mail. Thiếu SMTP thì Send trả thông báo cấu hình, không báo Sent giả.

## Nghiệm thu thủ công

1. Dùng catalog/supplier contact thật có email, chọn số lượng rồi Send một lần. Refresh vẫn thấy đơn và trạng thái gửi.
2. Kiểm tra hộp thư supplier, tên món/số lượng/người đặt; nút Call mở tel: đúng số.
3. Sau khi chuyển khoản thực tế, người đặt chọn Mark as paid. Refresh xem log; không sinh nợ tự động, không cộng hai lần khi bấm lặp.
4. Đổi nhà/tài khoản: không lộ đơn/ảnh/nợ nhà khác. Overview hiển thị ảnh bằng chứng đã gắn vào chore hoàn thành đúng ngày Việt Nam; draft không xuất hiện.

UI đã chuyển Bonus vào Chore, Order vào bottom bar; My Debts nằm trong My Account, Chore Settings bỏ tên season/Season Schedule. AI là nút nhỏ; Popular Templates cố định đã bỏ.
