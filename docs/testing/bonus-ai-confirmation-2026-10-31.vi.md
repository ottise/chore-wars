# Xác nhận việc AI trong Chore → Bonus

## Luồng đã nối

1. Người A yêu cầu AI lên kế hoạch và gửi yêu cầu cho các thành viên tham gia.
2. Mỗi người được mời mở **Chore → Bonus**, xem **Task requests to confirm**, phần việc của mình và hạn hoàn thành.
3. Chọn **Confirm** hoặc **Unavailable**. Người gửi không được xác nhận thay người nhận. Người đã Confirm sẽ thấy trạng thái đang chờ các thành viên còn lại.
4. Chỉ khi tất cả người được mời đồng ý, backend tạo các chore loại **BONUS**, gắn đúng người và mùa hiện tại. Các việc này xuất hiện trong Bonus, có **View chore**, không phải Claim lại.
5. Thiết bị của người xác nhận cuối làm mới ngay. Thiết bị của người đã xác nhận trước kiểm tra thay đổi mỗi 10 giây khi đang mở màn hình; có thể bấm **Refresh bonus** để kiểm tra ngay.
6. Thông báo yêu cầu và thông báo kế hoạch được chấp nhận đều mở thẳng tab Bonus.

## Kiểm tra với hai người

- A gửi kế hoạch gồm A và B; trước khi B Confirm, chưa tạo việc thực thi.
- B vào Bonus thấy lời mời, đúng việc của B, deadline và Confirm/Unavailable. A chỉ thấy trạng thái chờ.
- B Confirm: thông báo thành công; việc của cả A và B được giao đúng, xuất hiện trong Bonus của từng người; mở chi tiết để tiếp tục hoàn thành việc.
- Thử gửi lại một yêu cầu và B chọn Unavailable: không tạo việc từ yêu cầu đó.
- Yêu cầu hết hạn hoặc dành cho người khác không được hiện nút Confirm.
- API lỗi khi Confirm: không báo thành công, còn khả năng thử lại; không sinh việc.
- Kiểm tra màn hình rộng 320px, tên dài, cuộn đến nút thao tác.
- Với ba người: B Confirm trước, C Confirm cuối; Bonus của B tự cập nhật sau lần kiểm tra tiếp theo, không cần rời màn hình.

## Phạm vi dữ liệu và triển khai

- Không có migration hoặc sửa hàng loạt dữ liệu cũ.
- Các lời mời còn chờ được đọc từ API proposal hiện có.
- Việc đã được tạo trước bản sửa dưới loại NORMAL vẫn nằm trong Mine/Team. Không đoán nguồn gốc để đổi loại các việc cũ.
- Deploy backend **chore-wars** từ main mới và chạy lại/rebuild frontend. Service Python **chorewars-ai** không thay đổi trong bản sửa này.

## Kiểm tra tự động

- Backend: 160 unit tests; 2 PostgreSQL integration tests cho xác nhận đủ người, cấm người gửi xác nhận thay, tạo đúng BONUS, chặn tạo trùng, từ chối và hết hạn.
- Flutter: widget tests cho Confirm/Unavailable, quyền người nhận, profile chưa tải xong, request lỗi có Retry và dừng tự thử liên tục, phản hồi polling cũ không ghi đè xác nhận, cập nhật khi người khác đồng ý cuối cùng, màn hình nhỏ và điều hướng thông báo.
- Kết quả từng lần chạy lưu riêng trong `artifacts/test-results/bonus-*`, không đưa log hoặc thông tin tài khoản lên Git.

## Kết quả lần chạy

- Backend unit: **160 passed**, 0 failed.
- PostgreSQL integration: **2 passed**, 0 failed; database và container thử nghiệm đã được dọn sau khi chạy.
- Flutter đầy đủ: **167 passed**, 0 failed, **1 skipped** (bài live HTTP cần fixture Kestrel/Postgres riêng).
- Sau bổ sung cập nhật chéo giữa người tham gia, chạy riêng bộ Bonus cuối cùng: **9 passed**, 0 failed.
- Analyzer: **No issues found**.
- Web release JavaScript: **Built build/web**. Dry-run WebAssembly còn cảnh báo sẵn có ở dependency `flutter_tts`; bản build này không dùng Wasm.
- Chưa xác nhận thao tác thực tế bằng tài khoản người dùng trên Render sau deploy. Không coi kiểm tra tự động cục bộ là UAT cloud đã hoàn tất.
