# Test hai người ở hai mạng khác nhau

Hai trình duyệt phải dùng chung backend. Docker Compose giống nhau trên hai máy vẫn tạo hai database độc lập. Supabase không bắt buộc; chuyển riêng PostgreSQL sang Supabase cũng chưa chia sẻ được các ảnh đang lưu trên máy backend.

## Dùng backend và dữ liệu hiện tại trên máy chủ

Chạy từ thư mục gốc repository. Giữ một backend đang chạy cổng 5297 và các dịch vụ Docker mà backend đang dùng. Không chạy thêm service `backend` của Compose để thay backend hiện tại trong lúc test.

```powershell
cd mobile
flutter build web --release --output=build/shared-web --dart-define=UI_PREVIEW=false --dart-define=USE_SAME_ORIGIN=true
cd ..
docker compose -f docker-compose.shared-test.yml up -d
```

Mở `http://localhost:3001`. Nginx chỉ nghe loopback trên máy này; chuyển `/api/` và `/hubs/` về backend hiện tại qua `host.docker.internal:5297`, gồm WebSocket cho chat và thông báo. Nếu backend không nhận kết nối từ Docker Desktop, chạy backend duy nhất với `--urls http://0.0.0.0:5297`; giữ firewall chặn truy cập trực tiếp từ Internet.

Sau khi kiểm tra đăng nhập ở địa chỉ trên, có thể dùng HTTPS tunnel tới cổng 3001. Ví dụ khi đã cài cloudflared:

```powershell
cloudflared tunnel --url http://localhost:3001
```

Lệnh tạo địa chỉ HTTPS tạm thời và công khai ứng dụng qua dịch vụ Cloudflare. Chỉ chạy khi muốn chia sẻ ứng dụng; gửi đường dẫn cho người cùng test. Các API vẫn yêu cầu đăng nhập và kiểm tra quyền thành viên. Dừng tiến trình tunnel để đóng đường dẫn. Không tunnel cổng PostgreSQL, Redis, Kafka hoặc AI.

Cả hai mở cùng địa chỉ HTTPS, đăng nhập hai tài khoản khác nhau, dùng mã mời để vào cùng nhà. Máy người bạn không cần chạy backend hay database riêng. Máy chủ phải bật backend, Docker và tunnel trong suốt buổi test.

## Kiểm tra trước khi test

1. Đăng nhập ở hai trình duyệt; tab Network phải gọi `/api` trên cùng tên miền đang mở, không gọi `localhost:5297` của máy người bạn.
2. A tạo hoặc sửa dữ liệu; B tải lại và nhìn thấy thay đổi.
3. A nhắn tin; B nhận tin và thông báo. Kiểm tra kết nối chat/notification WebSocket trả mã 101.
4. A gửi ảnh và voice; B xem ảnh, phát voice; tải lại vẫn dùng được.
5. Chuyển sang nhà khác: danh sách, số chưa đọc và banner thông báo phải đúng nhà; Mark All Read chỉ đánh dấu nhà đang xem.
6. Tạo nhà chưa có season: Overview hiện hướng dẫn tạo season thay vì lỗi tải.

## Bản Docker đầy đủ

`mobile/Dockerfile` xây web dùng cùng origin và `mobile/nginx.conf` chuyển API/realtime sang service `backend:8080`. Chỉ một máy chạy stack này; các máy còn lại dùng đường dẫn HTTPS của máy đó. Ảnh đại diện hiện được lưu trong filesystem backend, vì vậy cần bổ sung lưu trữ bền vững cho avatar trước khi dùng container backend lâu dài. Không xóa volume database/private-media khi rebuild.

Tài liệu: [Nginx WebSocket proxy](https://nginx.org/en/docs/http/websocket.html), [Cloudflare Quick Tunnels](https://developers.cloudflare.com/tunnel/get-started/quick-tunnels/).
