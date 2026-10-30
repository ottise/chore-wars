# Avatar — sửa lỗi và khôi phục ngày 30/10/2026

Log lỗi là GET `/api/user/avatar-image` 404 lặp lại. Kiểm tra metadata cloud chỉ thấy một avatar dạng `/avatars/...`; không có avatar Google trong các tài khoản đang lưu tại thời điểm kiểm tra. Avatar cũ lưu trên filesystem server, trong khi database chỉ giữ đường dẫn. Tìm được một bản sao tương ứng trong nơi lưu local đã biết để khôi phục riêng.

## Thay đổi

- Thêm bảng `AvatarImages` qua migration `20261029170249_AddDurableAvatarImages`. Ảnh upload mới lưu bytea trong PostgreSQL thay cho filesystem tạm; URL cũ `/avatars/{id}.ext` giữ nguyên dạng.
- Kiểm tra ảnh thực JPG/PNG/WebP bằng codec, giới hạn 5 MB và 4096 px mỗi chiều. Đọc asset cũ còn trên filesystem vẫn được hỗ trợ.
- Ảnh Google dùng proxy server giới hạn HTTPS, cổng mặc định và domain googleusercontent.com. Không chuyển bearer token/cookie; không theo redirect; giới hạn MIME, dung lượng và thời gian. Nguồn không hợp lệ hoặc ảnh không còn trả fallback.
- Avatar không có/mất file trả 204 private no-store. FE dùng chữ cái tên và cache kết quả thiếu ảnh 5 phút thay cho auto-retry liên tục; cache đổi khi session thay đổi hoặc avatar URL mới. Profile xử lý lỗi decode bằng fallback.

## Kiểm thử

- Avatar/Google/media HTTP integration: **5 đạt**. Upload → server khác với thư mục trống → đọc lại đúng byte; missing avatar 204; anonymous 401; ảnh giả bị từ chối; proxy Google không chuyển Authorization và chặn host/cổng không hợp lệ.
- Proxy unit: **3 đạt**, chặn redirect, HTML và ảnh vượt dung lượng.
- Toàn bộ Flutter: **128 đạt**, 1 live-network test bỏ qua vì cần fixture riêng. Có test cache missing avatar 204/404, đổi session, multipart upload và render profile/header.
- Flutter analyzer sạch; EF không có pending model change.

## Cloud và phục hồi

Backup riêng đã kiểm tra trước migration: `artifacts/private/core-before-avatar-20261030.dump`. SQL chỉ thêm bảng và bản ghi migration, không sửa/xóa tài khoản hay dữ liệu nhà.

Kết quả áp dụng schema: `artifacts/private/avatar-migration-result.json`. Bản ảnh khôi phục được chèn theo ID đang có trong URL, chỉ khi còn được profile tham chiếu; không đổi tên, tài khoản, URL hay thông tin khác. Kết quả đối chiếu byte/hash lưu tại `artifacts/private/avatar-recovery-result.json`. Các file này và ảnh riêng tư không được commit.

Backend cần deploy commit mới và FE cần tải lại/hot restart để dùng code fallback mới. Nếu bản sửa còn chưa deploy, server cũ vẫn đọc filesystem và có thể còn trả 404. Không coi việc khôi phục blob trong database là xác nhận người dùng đã nhìn thấy ảnh trên UI.
