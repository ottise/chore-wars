# Cloudinary trên Render

Áp dụng cho backend `chore-wars`, không phải `chorewars-ai` hay Flutter.

1. Vào Render → `chore-wars` → **Environment** → **Edit** → **Add Environment Variable**.
2. Key: `CLOUDINARY_URL`.
3. Value: `cloudinary://API_KEY:API_SECRET@mfzuees8`, thay `API_KEY` và `API_SECRET` bằng đúng hai giá trị trong Cloudinary → Settings → API Keys. Không giữ dấu `< >`, không thêm `CLOUDINARY_URL=` vào ô Value, không có khoảng trắng hay xuống dòng.
4. **Save, rebuild, and deploy**. Bản backend phải chứa migration `AddCloudinaryFiles`; chạy migration trước khi deploy bằng quy trình migration của dự án. Nếu chỉ lưu biến mà không deploy code mới thì chưa chuyển storage.
5. Đợi Live, kiểm tra `/health/version` đúng commit mới và `/health/ready` trả 200. Đăng nhập lại ứng dụng; tải avatar mới, gửi ảnh và voice mới; tải lại trang rồi mở lại bằng một thành viên khác cùng nhà. Người ngoài nhà không được xem media riêng tư.

Không cần upload preset, SMTP hay biến Cloudinary trên frontend. Không dán API secret vào source hoặc GitHub. Biến không có giá trị → các upload mới tiếp tục dùng database; cấu hình sai định dạng → backend báo lỗi cấu hình an toàn khi khởi động.

## Cách lưu và quyền truy cập

- Avatar, ảnh chat, ảnh minh chứng và voice mới được upload bằng chữ ký server với delivery type `authenticated`. Cloudinary nhận dạng ảnh là `image`, audio thường là `video`; locator lưu đúng resource type để xóa đúng file.
- Backend giữ locator trong bảng `CloudinaryFiles`; nội dung file mới nằm tại Cloudinary. File cũ trong `PrivateMediaFiles`, `AvatarImages` hoặc ổ đĩa cũ tiếp tục đọc như trước; không tự chuyển dữ liệu lịch sử.
- Frontend tiếp tục dùng API media/avatar hiện tại. Backend kiểm tra quyền trước khi tải bytes qua POST có chữ ký và hạn dùng ngắn; không trả API secret hoặc URL có chữ ký cho client. Không có retry upload tự động làm lặp request khi provider lỗi.
- Giữ tài khoản Cloudinary và cấu hình sau khi bắt đầu upload. Gỡ biến hay đổi cloud name sẽ khiến file của cloud cũ tạm thời không đọc được; dữ liệu trong DB cũ vẫn đọc được. Xoay API key trong cùng cloud được hỗ trợ.
- Không xóa asset trực tiếp trong dashboard nếu ứng dụng còn dùng. Locator chứa ID thật; xóa ảnh trong dashboard không tự phục hồi dữ liệu.
- Upload và transaction PostgreSQL là hai hệ thống riêng: lỗi lưu locator được bù bằng xóa asset; rollback transaction bên ngoài hoặc mất kết nối đúng lúc có thể để lại asset không được tham chiếu. Không dùng tác vụ tự động xóa toàn bộ folder; đối chiếu locator trước khi dọn thủ công.

Tài liệu chính thức: [Cấu hình Cloudinary .NET](https://cloudinary.com/documentation/dotnet_integration), [kiểm soát truy cập](https://cloudinary.com/documentation/control_access_to_media), [Upload API](https://cloudinary.com/documentation/image_upload_api_reference).

## Kiểm tra triển khai ngày 30/10/2026

- Full backend: 143 unit và 98 integration test qua; 15 integration test cần Kafka/Python/Flutter ngoài tiến trình được bỏ qua ở local.
- Lượt bổ sung cuối: 15 test Cloudinary client và 4 test Cloudinary storage/avatar qua, gồm chặn upload trùng, chữ ký, bytes ảnh/voice, database locator, file DB cũ và proxy Google.
- SQL từ migration 36 → 37 đã chạy trên PostgreSQL dùng một lần; chỉ thêm bảng và ghi migration history. EF không còn model change chưa có migration.
- Các test Cloudinary dùng HTTP giả lập; chưa xác nhận upload/download thật trên tài khoản người dùng. Sau khi nhập biến Render và deploy, cần kiểm tra avatar/ảnh/voice mới rồi tải lại như bước 5.
