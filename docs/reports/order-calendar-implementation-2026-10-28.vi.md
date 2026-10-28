# Order, Account và lịch nhà — 28/10/2026

Đã triển khai luồng Order mới trong source: chọn số lượng → Send qua SMTP backend → trạng thái gửi → tự ghi nhận đã trả tiền và audit. Send idempotent theo client request ID; email queue commit cùng đơn. Không tự sinh chia phần/công nợ hoặc yêu cầu duyệt. Lịch sử/luồng legacy vẫn đọc được; không cho đơn mới đi nhầm vào checkout/approval legacy.

Bottom bar dùng Order; Bonus chuyển vào tab Chore. My Account có Chore Settings/My Debts, bỏ tên season và Season Schedule, bỏ shortcut Supplier workspace/My bank details khỏi trang chính. Thông tin nhận chuyển khoản vẫn truy cập từ trang nợ. Loại Popular Templates viết cứng. AI shortcut nhỏ tránh bàn phím và các CTA bên phải.

Overview có lịch/thông tin từng ngày, ảnh hoàn thành thật (hai preview và +N), gallery dùng endpoint được kiểm tra quyền. Group ngày theo Việt Nam: task theo hạn, ảnh theo ngày hoàn thành; không lộ ảnh nháp. API giới hạn 42 ngày, thumbnail giữ kiểm tra quyền kể cả cache hit.

## Bằng chứng local

- Backend unit: 115 passed, 0 skipped (`artifacts/ci/order-unit-final.trx`).
- PostgreSQL integration Order/calendar/legacy/evidence/schema/journey: 18 passed, 0 skipped (`order-regression.trx`); có 4 case mới (`simple-order-calendar.trx`).
- Flutter: 104 passed (`order-flutter-all-verified.log`); analyzer `lib test` không có issue (`order-analyze-lib-test.log`). Analyzer toàn thư mục mobile vẫn có hai info avoid_print trong các script bảo trì cũ ngoài lib/test.
- AI supply intent chạy Linux: 7 passed (`order-python.xml`). Không phải toàn bộ AI test suite.
- Backend build và Docker Linux build thành công. Kiểm tra image không có appsettings.OrderEmail.local.json, có Skia native Linux. Migration model check không có pending changes.
- Gmail xác thực SMTP qua STARTTLS thành công. Transport test dùng SMTP loopback. Chưa gửi email tới supplier thật.

Các log/artifact không được commit. Có cảnh báo NU1903 AutoMapper 12.0.1 hiện hữu; thay thư viện mapping toàn app không thuộc đợt này. Không tuyên bố dependency audit hoàn toàn sạch.

## Còn cần để chạy production

1. Review/apply migration `20261028041556_AddSimpleOrderEmailAndPaymentLog` qua workflow DB được bảo vệ, trước release mới. Chưa chỉnh schema Render trong đợt này.
2. Import 7 biến SMTP từ file `.env.order-email.local` vào backend Render và redeploy. File mật khẩu local bị gitignore và loại khỏi Docker/publish.
3. Nghiệm thu người dùng Send email thật, Call, Mark as paid và xem ảnh trên thiết bị. Không dùng dữ liệu supplier/mock tự tạo làm bằng chứng chức năng thật.
4. SMTP không có exactly-once: Unknown sau mất kết nối cần kiểm tra trước khi retry thủ công. Mark as paid là lời khai người dùng, không phải xác minh ngân hàng.

Hướng dẫn: [Order email setup](../order-email-setup.vi.md). Kế hoạch đăng nhập Google được lưu riêng, không sử dụng mật khẩu SMTP/Gemini làm OAuth.
