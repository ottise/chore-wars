# Bật đăng nhập Google

Source đã có đăng nhập và Link Google. Đã nhận Web OAuth Client ID và gắn cấu hình local/build; chưa thử tài khoản Google thực tế, chưa bật Environment trên Render. Không dùng app password Gmail hoặc Gemini API key.

Cập nhật: đã nhận và điền Web Client ID của project `chore-wars-513006` vào `mobile/config/google.json` (ID công khai). Theo yêu cầu chốt mới nhất, frontend cố định localhost:7357; helper/VS Code đọc file này; build Render cũng đọc file, biến GOOGLE_WEB_CLIENT_ID nếu có sẽ ghi đè. Backend Development đọc `appsettings.Google.local.json`; file `.env.google.local` chuẩn bị hai biến để nhập vào backend Render. Chưa thay Environment/migration trên Render và chưa thử đăng nhập Google thật.

## 1. Google Cloud

Mở [Google Auth Platform](https://console.cloud.google.com/auth/overview), chọn/tạo project. Điền Branding, support email; Audience chọn External và thêm test users nếu ứng dụng đang Testing. Data Access chỉ dùng openid, email, profile.

Tạo Client loại **Web application**. Trong Authorized JavaScript origins thêm URL frontend thực tế (ví dụ origin HTTPS của trang Flutter đã deploy), `http://localhost` và origin có port thực tế của frontend để test (ví dụ `http://localhost:50092` nếu app chạy đúng port đó). Không thêm đường dẫn `/api`, `/#/login` hoặc wildcard. Backend Render không phải frontend origin.

Copy **Client ID** có đuôi `.apps.googleusercontent.com`. Luồng ID-token hiện tại không dùng Client Secret, redirect callback hay quyền Gmail.

## 2. Backend Render

Environment của `chore-wars`:

```ini
GoogleAuth__Enabled=true
GoogleAuth__ClientIds__0=<Web OAuth Client ID>
```

Review/apply migration `20261028051203_AddGoogleIdentity` qua workflow DB hiện có, sau migration Order `20261028041556_AddSimpleOrderEmailAndPaymentLog`, rồi release backend. Chưa áp dụng cloud migration trong đợt code này; không bật migrate tự động lúc startup.

API: `POST /api/auth/google` nhận JSON `{ "idToken": "..." }`; `POST /api/auth/google/link` cần JWT Chore Wars và cùng payload. Google token được xác minh bằng thư viện Google chính thức, chỉ audience allowlist được chấp nhận. Có rate limit 10 request/phút/IP trên hai endpoint Google; password endpoints không đổi. Reverse proxy cần cấu hình trusted forwarded headers khi muốn phân biệt IP ngoài, không tin header IP tự khai.

## 3. Frontend

Environment **lúc build** frontend Render:

```ini
GOOGLE_WEB_CLIENT_ID=<cùng Web OAuth Client ID>
```

Script `mobile/scripts/build-render-web.sh` đọc mặc định từ `mobile/config/google.json`, có thể ghi đè bằng biến trên. Đây là ID công khai; không đặt OAuth secret trong frontend. Nếu thiếu ID thì nút Google ẩn. Save và rebuild frontend để thay giá trị.

Local:

```powershell
cd mobile
flutter run
```

Frontend hiện chốt http://localhost:7357 qua script/F5 và shortcut PowerShell của dự án. Mở terminal PowerShell mới để nhận shortcut; terminal đã mở trước khi cài cần nạp lại `. $PROFILE.CurrentUserAllHosts`. Giữ origin http://localhost:7357 trên Google Cloud. Nếu port bận, dừng frontend cũ, không đổi port ngẫu nhiên.

Backend local phải có GoogleAuth:Enabled và ClientIds tương ứng trong cấu hình môi trường của tiến trình. Root appsettings mặc định tắt; frontend vẫn dùng backend Render theo cấu hình API hiện có nếu không override.

## 4. Tài khoản cũ

Nếu email đã tồn tại: đăng nhập bằng mật khẩu → My Account → nút Google dưới hồ sơ → chọn Google có cùng email. Sau khi báo Google account linked, logout rồi thử Google từ màn Login. Không tự ghép tài khoản bằng email; không thay nhà/tên/avatar đã lưu.

Google user mới có tài khoản Chore Wars riêng, chưa có nhà. Người dùng tạo/join nhà theo luồng thường. Không có password mặc định cho tài khoản Google mới.

## 5. Android/iOS

SDK/wrapper có sẵn, nhưng cần tạo client theo package/SHA-1 Android hoặc bundle/reversed URL scheme iOS thật. Android dùng Web Client ID làm serverClientId; iOS thêm GOOGLE_IOS_CLIENT_ID và cấu hình URL scheme theo [hướng dẫn SDK iOS](https://pub.dev/packages/google_sign_in_ios). Chưa cấu hình ký hoặc chạy thiết bị thật trong đợt này. Windows native không được bật; Chrome/Edge trên Windows dùng bản Web.

## Kiểm thử hiện có

PostgreSQL test đăng nhập đồng thời, email trùng bắt buộc link và bảo toàn profile/membership, link sai email hoặc thay subject bị từ chối. Unit test thiếu cấu hình/malformed token/giới hạn request. Flutter test đổi ID token lấy app session, link/lỗi không ghi đè session và ẩn nút khi chưa có config. Không thay thế nghiệm thu bằng tài khoản Google thật sau cấu hình.

Kết quả local: 3 PostgreSQL test Google đạt, 118 backend unit đạt; bộ Flutter hiện hữu 104 đạt, thêm 3 test Google đạt (8 khi chạy cùng test refresh), analyzer lib/test không có issue; build Web release thành công. SQL hai migration mới để review ở `artifacts/ci/order-google-migrations.sql` (file local, không áp dụng cloud). SMTP/Order có báo cáo kiểm thử riêng.

Kế hoạch kiến trúc: [google-sign-in.vi.md](plans/google-sign-in.vi.md). Nguồn: [Google token verification](https://developers.google.com/identity/gsi/web/guides/verify-google-id-token), [Flutter Web SDK](https://pub.dev/packages/google_sign_in_web).
