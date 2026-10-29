# Rà soát kết nối frontend–backend

Ngày kiểm tra: 29/10/2026 (Asia/Saigon). Source nền: `b812c74`. Đây là báo cáo kiểm tra kết nối, không xác nhận mọi tính năng trên Render đã hoạt động.

## Kết luận

Các luồng chính có gọi backend thật, không mặc định dùng mock. FE mặc định trỏ HTTP vào `https://chore-wars-o3rm.onrender.com/api`; notification realtime vào `/hubs/notifications`. Chat dùng API base + `/chat-hub`, khớp alias `/api/chat-hub` của backend; không ghép nhầm thành `/hubs/chat-hub`.

Cloud hiện chưa sẵn sàng ở thời điểm đọc:

| Kiểm tra chỉ đọc | Kết quả quan sát |
|---|---|
| Backend `/health/version` | HTTP 200, SHA `987ba3fd3845165f30bd4888e4efa7fd7ae60854`, cũ hơn source main |
| Backend `/health/ready` | HTTP 503, `Unhealthy`. Theo implementation check này kiểm tra khả năng truy cập/schema DB; response không đủ để phân biệt lỗi kết nối với thiếu migration |
| AI `/health/ready` | HTTP 500; cần log service để xác định nguyên nhân |
| GitHub CI của `b812c74` | Completed / success |
| Deploy verified main của `b812c74` | Completed / skipped; chưa đưa commit mới lên Render |

Workflow deploy có điều kiện `CD_ENABLED == 'true'` cùng điều kiện CI thành công và không phải PR. Chưa có bằng chứng đọc trực tiếp repository variables nên không khẳng định giá trị biến cụ thể. Không tự bật deploy hay chạy migration production trong lượt audit này.

## Đối chiếu source

- Inventory tìm thấy 219 khai báo HTTP route backend (tính cả alias version). Đối chiếu 95 mẫu đường dẫn/call literal FE; các path động AI, action quản trị nhà và ảnh thumbnail được đọc riêng vì parser regex không phân tích được interpolation/nhánh điều kiện Dart. Đây là kiểm tra tĩnh, không phải 219 endpoint đã được chạy.
- Không tìm thấy API đang được gọi bị thiếu route trong phạm vi đối chiếu. Đã xóa hằng `ApiEndpoints.chatUpload` trỏ `/chat/upload` không còn tồn tại và không còn nơi dùng; upload hiện dùng `/media` rồi `/media/send`.
- `MockChoreRepository` và `MockGamificationRepository` chỉ dùng khi bật `UI_PREVIEW`; mặc định false. Provider bình thường dùng Dio và reset theo phiên.
- Call/Message mở `tel:`/`sms:` trên thiết bị; không có endpoint gửi SMS tự động và không tuyên bố đã gửi tin chỉ vì đã mở ứng dụng.
- Không coi API supplier operator, quản trị/huấn luyện AI hoặc luồng thanh toán legacy không hiển thị trên menu là tính năng UI bị quên nối: các luồng này có phạm vi riêng, một số đã được chủ động bỏ khỏi menu theo yêu cầu.

## Chạy thật code Flutter qua HTTP và SignalR

Thêm `FrontendNetworkTests.cs`: khởi tạo PostgreSQL tạm, áp dụng migrations, chạy ứng dụng thật bằng Kestrel trên cổng ngẫu nhiên, rồi gọi Flutter test bằng tiến trình riêng. Flutter dùng datasource/repository và SignalR service của ứng dụng, không mock Dio. Hai người dùng, hai nhà và ảnh QA đều được tạo trong môi trường test. Hosted workers bị tắt trong fixture; luồng Kafka/thông báo nền không được suy ra từ việc gửi chat realtime ở đây.

`mobile/test/live/backend_network_test.dart` kiểm tra:

| Nhóm | Đã chạy |
|---|---|
| Auth/profile | Đăng ký và login hai người, đọc/sửa profile, upload và đọc lại avatar |
| House | Tạo nhà, lấy danh sách, tham gia bằng invite code, đọc hai thành viên; người ngoài nhà nhận 403 |
| Season/chore | Tạo draft season, tạo template bằng model Dart, đọc lại template, đọc Mine |
| Overview/gamification | Repository dashboard tổng hợp API, Karma, history, achievements |
| Order/Shop | Thêm mặt hàng/liên hệ, đọc supplier và sản phẩm theo nhà, đọc orders |
| Finance/calendar | Đọc My Debts, Payment History, Household Summary và calendar với query ngày thật |
| Notifications/CORS | Đọc inbox, mark-all-read, negotiate hub thông báo, preflight origin localhost:7357 |
| Chat/media | Hai client SignalR: A gửi text, B nhận đúng message ID; đọc lại lịch sử, upload/send/download ảnh, đọc photo history |

Test đặt timeout mạng hữu hạn, chỉ cho phép host loopback và mặc định skip khi không được fixture gọi. File upload/keys của lượt cuối nằm trong thư mục artifact test riêng. Không phát sinh mail, SMS hay tiền thật.

Kết quả chốt: bài cross-runtime **PASS**, 47 lượt HTTP gồm một kiểm tra từ chối truy cập nhà khác (403 đúng kỳ vọng), CORS preflight, negotiate hub và upload/download ảnh; chat A→B qua SignalR đúng ID. Flutter regression **118 passed**; một bài live mạng skip trong lượt regression thông thường và đã chạy riêng thành công qua fixture, không tính skip đó thành PASS giả. Analyzer `lib test` sạch. Workflow YAML đã được parser kiểm tra. Có các lượt setup/timeout thất bại trong quá trình dựng fixture; lượt cuối đã chạy thành công, không nới assertion hay xóa kiểm tra để qua test.

Chạy lại ở máy có Flutter/.NET và Docker: tạo một PostgreSQL test loopback riêng, đặt `CHOREWARS_TEST_POSTGRES` vào DB test và `CHOREWARS_TEST_FLUTTER` là đường dẫn executable Flutter, rồi chạy `dotnet test backend/tests/IntegrationTests --filter FullyQualifiedName~FrontendNetworkTests`. Không dùng connection string production. Fixture tự tạo/xóa database con, hai tài khoản và nhà QA. Có thể đọc log HTTP đã bỏ header/token ở `artifacts/ci/frontend-network.log`.

## Tích hợp kiểm tra vào CI

Job `flutter` cài .NET, tạo DB tạm, chạy test Kestrel→Flutter và bắt buộc report TRX không fail/skip trước các bước tiếp theo. Job runtime backend lọc riêng bài cross-runtime này vì nó đã chạy ở job Flutter; không giảm các test backend khác. Report mạng và kết quả được upload thành artifact `frontend-backend-contract`.

## Giới hạn và việc cloud cần làm

- Smoke test này xác minh code Dart qua mạng thật; không thay cho thao tác end-to-end trên Chrome/Android/iOS. Google OAuth với tài khoản thật, quyền camera/microphone, thu/phát voice trên phần cứng và thông báo thiết bị vẫn cần nghiệm thu riêng.
- Các màn danh sách finance/calendar trong smoke hiện dùng trạng thái trống. Nghiệp vụ trả từng phần, không cộng trùng giao dịch, phân quyền, lịch có ảnh và concurrency đã có bộ integration/widget test riêng ở báo cáo tài chính, không giả định smoke này đã chạy mọi trạng thái đó.
- SMTP thật, Gemini thật, payOS thật và worker cloud chưa được nghiệm thu từ bài chạy này. Mật khẩu/key không được đưa vào report.
- Để app cloud hoạt động cần khôi phục DB/schema readiness, deploy đúng main qua pipeline đã cấu hình, rồi kiểm tra version/readiness/API có auth và đồng bộ hai người. AI 500 cần log riêng. Không có thao tác ghi DB/migration/đổi environment Render trong audit.

Log local: `artifacts/ci/frontend-network.log`, `frontend-network-backend.log`, `frontend-network.trx`, `frontend-audit-analyze.log`, `frontend-audit-flutter.log`; không commit log hoặc cấu hình fixture.
