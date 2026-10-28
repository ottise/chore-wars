# Kế hoạch đăng nhập Google

Trạng thái 28/10/2026: đã triển khai source sau khoảng chờ 5 phút được người dùng ủy quyền, sau đó nhận Web Client ID thật và gắn vào cấu hình local/build. Hướng dẫn cấu hình và các bước nghiệm thu còn thiếu: [Google sign-in setup](../google-sign-in-setup.vi.md). Chưa bật Google trên Render, chưa áp dụng migration cloud hoặc thử tài khoản Google thật.

## Mục tiêu và phạm vi

Thêm Sign in with Google vào màn đăng nhập Flutter Web/Android/iOS. Sau khi Google xác thực, backend cấp JWT/refresh token Chore Wars như đăng nhập email hiện tại. Không thay Firebase, không đổi quyền nhà, không tự thêm thành viên. Windows desktop native nằm ngoài đợt đầu; trình duyệt trên Windows được hỗ trợ.

Không dùng mật khẩu ứng dụng Gmail SMTP làm OAuth key. Cần OAuth Web Client ID từ Google Cloud; Android/iOS cần client tương ứng với package/bundle và chứng chỉ ký. Không cần client secret cho luồng đổi Google ID token lấy phiên Chore Wars này. Chỉ yêu cầu openid/email/profile, không xin quyền Gmail/Drive.

## Luồng giữa các thành phần

1. LoginScreen → GoogleSignInButton → SDK google_sign_in chính thức (Web dùng nút render của google_sign_in_web) → người dùng chọn tài khoản.
2. SDK trả ID token → AuthNotifier → AuthRepository → AuthRemoteDataSource → POST /api/auth/google.
3. AuthController → GoogleAuthService → IGoogleIdentityVerifier. Infrastructure xác minh chữ ký bằng thư viện Google chính thức; kiểm tra issuer, audience đã cấu hình, expiry, email_verified và subject.
4. GoogleAuthService tìm user theo GoogleSubject (sub), tạo tài khoản mới khi email chưa tồn tại, hoặc yêu cầu xác thực tài khoản cũ khi email đã tồn tại. Email không được coi là khóa định danh Google.
5. Ghi user/refresh token trong một transaction → LoginResponse → secure storage/session epoch hiện tại → /houses. Dùng lại logout, refresh và quyền truy cập hiện có.

### Liên kết tài khoản cũ

Không tự gắn Google vào tài khoản có cùng email. Khi email đã có mà chưa liên kết, hiển thị hướng dẫn đăng nhập bằng mật khẩu và nút Link Google trong Profile. POST /api/auth/google/link bắt buộc JWT Chore Wars, token Google hợp lệ và email trùng tài khoản đang đăng nhập. Không cho chuyển subject đã liên kết với người khác; không ghi đè liên kết cũ. Việc liên kết là thao tác người dùng bấm rõ ràng.

User mới đăng nhập Google có PasswordHash rỗng và GoogleSubject; đăng nhập mật khẩu phải trả lỗi thông thường cho trường hợp chưa có password. Không tạo mật khẩu chung/ngẫu nhiên có thể dùng đăng nhập. User cũ giữ nguyên password, nhà, lịch sử và số dư. Không tự cập nhật avatar/tên người dùng đã tự sửa mỗi lần đăng nhập Google.

## File backend

| File | Thay đổi |
|---|---|
| Domain/Entities/User.cs | Thêm GoogleSubject nullable. |
| Infrastructure/Data/Configurations/UserConfiguration.cs | Giới hạn subject, unique index nullable; dữ liệu cũ không đổi. |
| Infrastructure/Migrations/*_AddGoogleIdentity.cs + snapshot | Migration thêm cột/index; không xóa hoặc backfill liên kết bằng email. |
| Application/DTOs/Auth/GoogleLoginRequest.cs | ID token, giới hạn kích thước; không nhận email/sub do FE tự khai. |
| Application/DTOs/Auth/GoogleIdentity.cs | Subject/email đã xác minh, tên/avatar tùy chọn. |
| Application/Interfaces/Services/IGoogleIdentityVerifier.cs | Ranh giới xác minh bên ngoài Application. |
| Application/Interfaces/Services/IGoogleAuthService.cs | Login/link, CancellationToken. |
| Application/Services/GoogleAuthService.cs | Liên kết, tạo user, transaction và cấp session bằng IAuthTokenProvider hiện có. |
| Application/Interfaces/Repositories/IUserRepository.cs | GetByGoogleSubjectAsync. |
| Infrastructure/Repositories/UserRepository.cs | Query subject; giữ unique constraints khi có request đồng thời. |
| Infrastructure/Auth/GoogleAuthOptions.cs | Enabled, ClientIds allowlist. |
| Infrastructure/Auth/GoogleIdentityVerifier.cs | Google.Apis.Auth, xác minh audience/signature/expiry/issuer/email, map lỗi an toàn. |
| Application/Validations/Auth/GoogleLoginRequestValidator.cs | Bắt token trống/quá dài. |
| Presentation/Controllers/AuthController.cs | POST google, authorized POST google/link; capabilities chỉ trả enabled/client ID công khai nếu cần. |
| Presentation/Extensions/*ServiceExtensions.cs | DI/options; thiếu config thì feature tắt, password login vẫn chạy. |
| Infrastructure/Infrastructure.csproj | Thêm Google.Apis.Auth phiên bản ổn định đã kiểm tra. |
| Application/Services/AuthService.cs | Bắt user chưa có password an toàn, không đưa lỗi SDK lên UI. |

Tất cả đường dẫn backend trên tương đối với backend/src/. Không lưu Google ID token vào DB/log; chỉ lưu subject. Không trả token về URL/query. Endpoint theo rate limit auth đang có; kiểm tra và bổ sung nếu chưa có. Link/login lỗi không làm mất phiên hiện tại. Concurrency duplicate không tạo hai tài khoản; trả conflict thân thiện nếu email/subject vừa được dùng.

## File frontend

| File | Thay đổi |
|---|---|
| mobile/pubspec.yaml, pubspec.lock | google_sign_in và google_sign_in_web chính thức, khóa phiên bản tương thích. |
| mobile/lib/features/auth/data/google/google_identity_client*.dart | Conditional implementation Web/native/unsupported, initialize một lần, xử lý cancel/popup/network và ID token. |
| mobile/lib/features/auth/presentation/widgets/google_sign_in_button*.dart | Web dùng renderButton; native dùng nút chuẩn Google. Ẩn khi thiếu Client ID/không hỗ trợ. |
| mobile/lib/features/auth/domain/repositories/auth_repository.dart | googleLogin/linkGoogle. |
| mobile/lib/features/auth/data/datasources/auth_remote_data_source.dart | Gọi backend, map LoginResponse hiện có. |
| mobile/lib/features/auth/data/repositories/auth_repository_impl.dart | Lưu session qua cơ chế hiện tại. |
| mobile/lib/features/auth/presentation/providers/auth_providers.dart | Chặn gửi đôi, xử lý session và lỗi an toàn. |
| mobile/lib/features/auth/presentation/screens/login_screen.dart | Nút Google riêng, loading/cancel; giữ form email/password. |
| mobile/lib/features/auth/presentation/screens/profile_screen.dart | Link Google cho tài khoản có phiên, thông báo kết quả; không đưa tính năng nhà ra profile ngoài nhà. |
| mobile/web/index.html | Cấu hình cần cho SDK, không chứa secret. |
| mobile/scripts/build-render-web.sh + tài liệu cấu hình | GOOGLE_WEB_CLIENT_ID công khai từ build env → dart-define. |

Kiểm tra lại tên file/provider thật khi bắt đầu; không thêm abstraction chung nếu SDK wrapper hiện có đã đáp ứng. UI theo core hiện tại; không làm lại màn login. Không dùng nút giả/ID token giả trong production.

## Cấu hình Google Cloud và Render

1. Google Cloud → Google Auth Platform: tạo project/branding/audience External, khai báo test users nếu còn Testing. Chỉ scope openid/email/profile.
2. Tạo OAuth client Web application. Authorized JavaScript origins gồm URL FE thực tế và localhost với port thực tế dùng test. URL backend không thay thế origin FE. Chỉ thêm origin thật; không dùng wildcard.
3. Backend Render: GoogleAuth__Enabled=true; GoogleAuth__ClientIds__0=<Web Client ID>. Có thể thêm client ID hợp lệ khác theo index, không thêm secret SMTP.
4. Frontend build: GOOGLE_WEB_CLIENT_ID=<cùng Web Client ID>. Android dùng serverClientId Web và OAuth Android đúng package/SHA-1; iOS đúng bundle/client/reversed URL scheme theo SDK. Không đoán các giá trị chưa có.
5. Áp dụng migration qua workflow DB được review hiện có, rồi deploy backend/FE cùng cấu hình. Feature mặc định tắt đến khi có Client ID thật. Không tự migrate production lúc khởi động.

## Kiểm thử và nghiệm thu

- Backend unit: token sai/hết hạn/sai audience/email chưa verify; user mới; user đã link; email trùng không auto-link; link sai user/subject đang thuộc người khác; logout/refresh vẫn hoạt động.
- PostgreSQL integration: unique subject và transaction rollback/idempotency ở request đồng thời; không đổi membership/dữ liệu cũ; schema migration gate.
- FE: cancel không hiện lỗi đỏ; busy không gửi đôi; thiếu config không có nút hỏng; token/API lỗi có thông báo ngắn; thành công vào My Houses; link giữ session; narrow layout và accessibility.
- Test trình duyệt bằng tài khoản Google thật sau khi cấu hình Client ID, origin localhost thực tế đã đăng ký và FE deploy; native test chỉ sau khi có cấu hình ký. Mock verifier chỉ nằm trong test.
- CI: analyzer, tests, build Web/backend, dependency audit, migration/schema checks. Không khai báo đăng nhập Google hoạt động thật nếu mới test mock hoặc chưa có OAuth client.

## Thứ tự thực hiện

Backend contract/model → verifier/service/repository/API → migration + tests → Flutter SDK/button/session/link → cấu hình build/docs → CI và deploy có gate. Nếu hết 5 phút kể từ lúc gửi kế hoạch mà người dùng không phản hồi, tiếp tục triển khai theo ủy quyền trong chat; cấu hình OAuth chưa có được ghi rõ là bước bên ngoài còn thiếu, không dùng key Gemini/SMTP thay thế.

Tài liệu chính thức: [Verify Google ID token](https://developers.google.com/identity/gsi/web/guides/verify-google-id-token), [Google Identity setup](https://developers.google.com/identity/gsi/web/guides/get-google-api-clientid), [Flutter google_sign_in](https://pub.dev/documentation/google_sign_in/latest/), [Web SDK](https://pub.dev/packages/google_sign_in_web).
