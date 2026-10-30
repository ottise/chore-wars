# Gộp main và hotfix/fixbugs

Nguồn: `main` tại `fba119ee82ca5fa2b01340682e169171461ccd4e` và `hotfix/fixbugs` tại `0b5bb2930c140c0523dbd12ccdf6683bc75615b7`.

## Kết quả ghép

- Giữ Cloudinary cho upload mới, database cho media cũ; bổ sung tìm thư mục upload legacy, đưa bytes còn tồn tại vào database, không xóa media đang được tin nhắn/minh chứng tham chiếu dù thiếu `AttachedAt`.
- Worker khôi phục legacy bỏ qua locator Cloudinary, tránh tải lại ảnh/voice cloud mỗi giờ. File mất hẳn hiển thị trạng thái rõ ràng; retry dành cho lỗi kết nối tạm thời.
- Chore detail dùng occurrence thật và house/season thật, không cần tải danh sách definition của mùa hiện tại để mở task cũ. Backend trả quyền hoàn thành/upload ảnh theo người thực hiện và trạng thái mùa.
- Giữ tự chia lại việc khi có thành viên mới, xác nhận revision, nghĩa vụ bounty và badge chat của main. Thêm chống dùng cùng create request ID với payload khác, kiểm tra expected revision và phản hồi lý do task cần phân công.
- Thêm chore vào lịch tự động sẽ được chia theo lịch rảnh/capacity; lịch thủ công giữ task chờ owner phân công. Lịch REVIEWING có task bắt buộc chưa phân công quay về DRAFT, lịch đã phân công đầy đủ cần mọi người xác nhận revision mới.
- Import routine cũ giữ template nguồn, dùng lại snapshot chưa có occurrence và tạo task đúng một lần. Giao diện tạo chore tiếp tục không có bước routine riêng.
- UTC trong model, UTC+7 khi hiển thị; không cộng múi giờ hai lần. Deep link cũ chuyển qua occurrence API; navigation bounty dùng route household chuẩn.
- Giữ SDK `10.0.302` đã đồng bộ với Dockerfile và CI, thay vì nhận riêng pin `10.0.401` của hotfix trong khi Docker còn dùng SDK cũ.

## Kiểm tra

- 156 backend unit test qua. Các test mới của hotfix được giữ và cập nhật fixture để khai báo rõ automatic/manual.
- 105 integration test khác nhau đã qua trong lượt full và kiểm tra lại 15 test chore/household; 15 test cần dịch vụ ngoài được bỏ qua ở full local.
- Test Flutter → Kestrel → PostgreSQL và SignalR thật qua riêng; lịch test tự động khai báo `AllocationMethod.AUTOMATIC`.
- 159 Flutter test khác nhau qua trong lượt full và kiểm tra lại 2 test route bounty; live HTTP test chạy riêng.
- Flutter analyzer sạch và web release build qua. EF không có model change thiếu migration; bản merge không thêm migration sau `AddCloudinaryFiles`.
- Kiểm tra source không có credential thật; ảnh, voice, backup và log riêng không được commit.

Chưa xác nhận avatar/ảnh/voice trên tài khoản Cloudinary thật: người dùng đã cấu hình Render nhưng yêu cầu tiếp tục merge trước khi thử thủ công. Mic/camera thiết bị thật và delivery vào hộp thư OTP chưa được kiểm tra lại trong lượt merge này.
