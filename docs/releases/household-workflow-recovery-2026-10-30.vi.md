# Household workflow recovery — 30/10/2026

Bản sửa chung cho chore, chia việc, bounty, chat, thống kê và giao diện OTP/email. Giao diện tiếp tục dùng tiếng Anh.

## Những gì thay đổi

- Chore: owner và member ACTIVE đều thêm việc được. Lưu tạo occurrence tương lai ngay, phân công theo lịch rảnh/capacity, giữ công việc cũ. Request ID tránh tạo trùng. Không có ngày tương lai hợp lệ thì trả lỗi rõ; không thể gán thì trả `unassignedCount`, có đường owner phân công từ Summary. REVIEWING tăng revision và yêu cầu duyệt lại; nếu còn việc chưa gán thì về DRAFT. Bỏ Routines, nút thêm ở header, giữ View team schedule.
- Thành viên mới: xử lý cả DRAFT/REVIEWING/ACTIVE, không để draft tương lai che mùa đang chạy. Không khai lịch thì được xem là chưa giới hạn thời gian; lịch bận, ngoại lệ ngày, capacity và trùng giờ vẫn được tôn trọng. Không chuyển việc đã bắt đầu, hoàn thành, quá hạn, có minh chứng/phạt/bounty/nghĩa vụ tiền. Có preview, lý do khi không thể chia, owner Confirm bằng revision/context hash/request ID, lưu audit trong transaction. REVIEWING xây lại roster và approval đúng revision.
- Bounty: nguồn eligible từ backend, sort deadline. Hạn hiển thị lấy occurrence, thời hạn đăng không tự đổi deadline. Chặn tự nhận/ngoài nhà/hết hạn; retry của người đã nhận không tạo cam kết trùng. Claim tạo `AWAITING_COMPLETION`; complete chuyển cùng khoản thành PENDING; chưa hoàn thành không được thanh toán. Bonus hiển thị bounty đã nhận và mở chore thật có ảnh. OPEN thu hồi mềm; CLAIMED cần hai người đồng ý, kiểm tra tình trạng việc/capacity/nghĩa vụ tiền trước khi trả việc và hủy cam kết.
- Dữ liệu bounty cũ: khi bản mới khởi động, `LegacyBountyRecovery` bổ sung cam kết thiếu cho CLAIMED còn dang dở và đối chiếu hạn OPEN. Không suy diễn lịch sử đã thanh toán/hoàn thành, không mở lại EXPIRED/CANCELLED. Chạy dưới khóa house và idempotent. Nếu database chưa sẵn sàng, log một cảnh báo và giữ dữ liệu; restart sau khi khắc phục để chạy lại.
- Chat: unread lấy từ tin nhắn/con trỏ đọc trong DB, tách khỏi notification và mute. Badge Chat giới hạn `10+`; chuông trong phòng chỉ mute. Con trỏ chỉ cập nhật khi phòng foreground, vùng tin mới được render/hiển thị; không lùi khi nhiều tab cập nhật. Realtime báo thay đổi unread độc lập việc mute.
- Voice: thao tác Stop & send gửi trực tiếp, không preview/autoplay. Dừng do lifecycle/hết thời lượng giữ draft để gửi hoặc bỏ, không tự gửi; gửi lỗi giữ draft/request ID để retry. Dọn file lỗi sau khi server đã xác nhận không làm hiện Send lại.
- Summary: bỏ workload/Assignment Details lặp; giữ xác nhận lịch, đường xem team/ranking. Có biểu đồ số thật và chi tiết từng member theo khoảng ngày/mùa, phân trang backend; phân biệt người đang nhận và người đã hoàn thành. Avatar dùng endpoint kiểm tra membership và cache absence. Có đường xem ranking mùa cũ và House Settings.
- OTP/email: hộp trắng/tím, sáu ô mã với một input hỗ trợ paste/autofill, đổi email, cooldown và trạng thái lỗi. Email Brevo có HTML + plain text, mã nổi bật, thời hạn 10 phút. Không thêm nút copy/one-click xác thực giả trong email.

## Kiểm thử local

- Flutter: 148 bài trong lượt full suite đạt; thêm hai test Back/đăng bounty từ URL trực tiếp đều đạt. Test HTTP live được chạy riêng và đạt với Kestrel/Postgres thật; gồm OTP 320/354/390/480 px ở text scale 1.3, paste mã, đổi email, badge 0/1/10/10+, scope notification, route, role và layout hiện có.
- .NET: 129 unit tests đạt; integration suite 95 đạt, 15 bài hạ tầng ngoài bị skip. Sau thay đổi guard REVIEWING, chạy thêm 10 bài hồi quy chuyên biệt: tất cả đạt. Các bài hạ tầng bị skip ở local được phân biệt với lượt runtime integration đã đạt trên CI.
- Backend build và Flutter web release build đạt. HTTP live đối chiếu việc được phân công của hai thành viên với occurrence trong DB, quyền preview, unread/read cursor, avatar theo house và SignalR. Analyzer/diff/secret scan và SQL review là gate trước commit/push.
- SQL được chạy thử toàn bộ 36 migration trên PostgreSQL trống. Hai migration mới chỉ bổ sung cột/bảng/index; giữ index HouseId cũ. Dump cloud nằm trong vùng ignored riêng, kiểm tra định dạng/checksum/TOC trước khi áp dụng.

## Triển khai

1. Áp dụng hai migration `20261030102922_HouseholdWorkflowRecovery`, `20261030111629_BountyCancellationConsent` từ SQL đã review và backup. Migration đặt mốc đọc chat cũ tại thời điểm nâng cấp, không biến toàn bộ lịch sử cũ thành unread.
2. Deploy backend đúng commit main mới. Bản cũ không được coi là đã chạy các API/cam kết mới. Legacy recovery chỉ chạy bằng binary mới sau deploy.
3. Khởi động lại/rebuild frontend để nhận giao diện mới; giữ cấu hình port development hiện có.
4. Kiểm tra version/readiness và nghiệm thu T01–T16 bằng hai/ba tài khoản trên cloud.

## Giới hạn nghiệm thu còn lại

Computer Use bị dừng vì không xác định chắc chắn URL Chrome để kiểm tra quyền truy cập; IAB không truy cập được máy chủ local. Không dùng cách khác để vượt giới hạn này. Vì vậy chưa chốt kiểm tra trực quan bản release trong trình duyệt, thao tác mic/camera thật, thư đến inbox thật hoặc thao tác deploy qua Render UI trong lượt này. Các kiểm tra cloud/thiết bị và những mục T chưa thực hiện vẫn để trống trong plan.

Các cảnh báo dependency AutoMapper đã có từ baseline; không thay phiên bản thư viện trong đợt sửa nghiệp vụ này.
