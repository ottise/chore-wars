# Kế hoạch UI/UX: Intro → Welcome → Đăng nhập/Đăng ký

Chore Wars — 23/10/2026. Trạng thái: **kế hoạch, chưa triển khai giao diện**. Tham chiếu ảnh Locket người dùng gửi: hero lớn, nền tối, nhận diện ngắn gọn và hai hành động rõ ràng. Thiết kế hình ảnh/chuyển động riêng cho Chore Wars; giữ luồng tài khoản hiện có.

## 1. Phạm vi triển khai đầu tiên

Tạo trải nghiệm mở app có animation intro, màn Welcome, sau đó đăng ký hoặc đăng nhập. Đồng bộ diện mạo hai form và native splash để không có khung trắng nháy khi khởi động. Chưa đổi dashboard, công việc, chat, payment hoặc màn AI trong đợt này; những màn đó sẽ có đợt redesign riêng sau khi luồng vào app ổn định.

Mục tiêu của Welcome: người mới hiểu app giúp chia việc và ghi nhận đóng góp trong gia đình, đồng thời biết bấm gì để tiếp tục. Nội dung mặc định tiếng Việt trong nhóm màn này; dùng một bộ copy tập trung để sau này đưa vào localization, không trộn hai ngôn ngữ trong cùng màn.

## 2. Hiện trạng source

| File/thành phần hiện có | Quan sát | Hướng xử lý |
|---|---|---|
| `mobile/lib/main.dart` | Khởi tạo SharedPreferences, MaterialApp.router, theme system | Giữ bootstrap hiện có, bổ sung launch gate qua router |
| `mobile/lib/core/router/app_router.dart` | initialLocation=/houses; chưa có token thì redirect trực tiếp /login; chỉ login/register được coi là public auth route | Thêm /launch và /welcome, sửa redirect theo launch/session state |
| Route `/` | Ngoài uiPreview đang là placeholder Splash/Home | Thay bằng entry hợp lệ, giữ hành vi UI preview phục vụ phát triển |
| `auth_providers.dart` | AuthInitial; token tồn tại chưa được xác minh; API đầu tiên mới refresh nếu 401 | Không coi token tồn tại là đã xác thực thành công; giữ interceptor refresh hiện có |
| Login/Register | Form email/password hiện có, chưa có Welcome; register Back đang go /login | Làm mới visual, cấu trúc form và back navigation; giữ API/validation |
| `app_theme.dart` | Có purple/yellow/green, theme chung toàn app | Bổ sung token/theme cục bộ launch/auth, chưa đổi theme mọi màn |
| `local_storage.dart` | Đã có SharedPreferences | Thêm version intro đã xem; không lưu token/tài khoản vào đây |
| Native splash | Android launch_background/styles; iOS LaunchScreen/LaunchImage | Đồng bộ nền/mark tĩnh với frame đầu Flutter |
| `pubspec.yaml` | Chưa khai báo font/asset intro; không có Lottie/Rive | Ưu tiên animation Flutter native, font/ảnh bundled khi cần |

`house_onboarding_screen.dart` là luồng tạo/tham gia nhà sau đăng nhập; không dùng nó làm intro trước xác thực.

## 3. Hướng thiết kế: “Cả nhà cùng vào guồng”

Hero là **bảng việc nhỏ có mái nhà**, với các thẻ việc và dấu hoàn thành được sắp vào đúng chỗ. Một chuyển động có câu chuyện: việc nhà rời rạc → cùng sắp xếp → ngôi nhà gọn gàng. Không dùng điện thoại nghiêng, logo Locket hoặc trái tim của ảnh tham khảo.

Phần ghi nhớ nằm ở hero này; khu vực chữ và nút giữ gọn. Không thêm carousel dài, nhiều badge, số liệu giả hoặc phần trăm “AI hiểu gia đình”. Minh họa trước đăng nhập là asset trình bày, không phải dữ liệu nhà thật.

### Token đề xuất

| Token | Màu | Vai trò |
|---|---|---|
| House charcoal | `#17191D` | Nền intro/Welcome và form auth |
| Chore purple | `#6C5CE7` | Thẻ việc/chi tiết thương hiệu, kế thừa màu app |
| Karma yellow | `#FDCB6E` | Nút chính và điểm nhấn; chữ nút charcoal |
| Done green | `#00B894` | Dấu hoàn thành trong minh họa |
| Chalk | `#F8F9FA` | Tiêu đề, chữ chính |
| Soft slate | `#B9BEC8` | Mô tả và chữ phụ |

Kiểm tra contrast trên nền thực tế trước khi chốt; không dùng màu purple cho chữ nhỏ trên nền tối nếu chưa đạt contrast. Trạng thái lỗi dùng token error hiện có, kèm thông báo bằng chữ.

Typography đề xuất: Nunito Sans bundled, có đầy đủ glyph tiếng Việt; headline/wordmark 800, nội dung 400/600, nút 700. Kiểm tra license và lưu license cùng font khi thêm asset. Nếu font chưa sẵn sàng, dùng font hệ thống làm fallback; không tải font qua mạng khi mở app.

Type scale dự kiến: wordmark32, headline28, body16/line-height1.45, caption14, button16. Khoảng lề ngang24, theo nhịp8. Card minh họa bo12; field bo14; nút chính dạng pill cao56, không áp một bán kính cho mọi thành phần.

## 4. Bố cục Welcome

```text
┌────────────────────────────────┐
│ Safe area                      │
│                                │
│        Bảng việc mái nhà        │
│    Chuyển động một lần rồi nghỉ │
│                                │
│          Chore Wars            │
│                                │
│      Chia việc nhẹ nhàng.       │
│    Cùng nhau giữ nhà vui.       │
│                                │
│      [ Tạo tài khoản ]         │
│           Đăng nhập            │
│ Safe area                      │
└────────────────────────────────┘
```

Hero chiếm khoảng nửa vùng nội dung, nhưng co theo chiều cao máy; không dùng chiều cao cố định làm đẩy nút khỏi màn hình. Nút chính tạo tài khoản, nút phụ đăng nhập. Không thêm đăng nhập Google/Apple, OTP hoặc quên mật khẩu khi backend chưa có capability tương ứng.

CTA có vùng chạm tối thiểu48dp và trạng thái pressed/focus rõ. SafeArea bảo vệ notch/thanh điều hướng; khi chữ lớn/màn thấp, bố cục cuộn được và vẫn tiếp cận hai CTA.

## 5. Storyboard animation

| Khoảng thời gian | Chuyển động |
|---|---|
| 0–300ms | Mark mái nhà/bảng việc hiện từ frame native splash, không đổi nền đột ngột |
| 300–900ms | Cụm thẻ việc vào vị trí trên bảng, chuyển động nhẹ có điểm dừng rõ |
| 900–1.300ms | Dấu hoàn thành xuất hiện, wordmark rõ dần |
| 1.300–1.600ms | Hero ổn định ở vị trí Welcome, phần mô tả/CTA xuất hiện |

Dùng một AnimationController + TweenSequence/CurvedAnimation/AnimatedBuilder cho hero; CustomPainter cho đường nét nếu cần. Tách widget minh họa khỏi điều phối router. Không dùng video, hiệu ứng âm thanh tự bật hoặc package animation mới cho bản đầu.

Animation không gọi API, không chạy inference và không mở quyền camera/micro. Asset phải bundled để chạy offline. Sau một lượt, hero nghỉ; không dùng animation vô hạn gây phân tán lúc người dùng chọn nút.

## 6. Quy tắc điều hướng và phiên

| Tình huống | Hành vi mặc định đề xuất |
|---|---|
| Cài mới, chưa có phiên | Intro tối đa1,6s → Welcome |
| Đã xem intro, chưa có phiên | Entrance ngắn khoảng300ms → Welcome; không bắt xem lại toàn bộ |
| Có token lưu trên máy | Đọc phiên song song với launch; branding ngắn, vào /houses theo luồng hiện có; lần API xác thực đầu vẫn có thể refresh/expire |
| Token hết hạn, refresh thành công | Tiếp tục màn được phép, không đưa người dùng qua Welcome lại |
| Refresh bị từ chối | Xóa phiên theo interceptor hiện có → Welcome hoặc Login theo ngữ cảnh; không replay intro dài |
| Offline khi có token | Không coi timeout là logout; hiển thị offline/retry của màn đích |
| App resume từ background | Giữ màn hiện tại; không khởi động intro lại |
| Logout | Về Welcome, xóa state theo session epoch; không giữ dữ liệu riêng của account cũ |
| Back từ Login/Register | Về Welcome nếu đi từ Welcome; link đổi login/register có back behavior thống nhất |
| Deep link | Giữ đích nội bộ hợp lệ qua auth; không ghi đè intent bằng /houses một cách vô điều kiện |

Phân biệt local session hydration với session đã xác thực; không thêm API validation chỉ để kéo dài intro. UI ready và đọc secure storage là hai điều kiện độc lập; hoàn tất cả hai mới điều hướng một lần. Nếu secure storage lỗi, có màn retry/đăng nhập lại rõ ràng, không spinner vô hạn và không tự xóa phiên vì lỗi tạm thời.

Router chỉ cho /launch, /welcome, /login, /register đi qua khi chưa đăng nhập. Thêm các route này phải giữ quyền bảo vệ toàn bộ route nhà/công việc/AI. Giữ `AppConstants.uiPreview` dùng cho phát triển.

Lưu `intro_seen_version` trong LocalStorage sau khi hoàn tất hoặc người dùng bỏ qua intro. Đây là cờ trình bày theo thiết bị, không phải trạng thái tài khoản. Bổ sung nút “Bỏ qua” nhỏ khi có full intro; không bắt người dùng chờ nếu họ muốn đăng nhập ngay.

## 7. Login/Register sau redesign

Giữ email/password và API hiện có. Header dùng mark nhỏ, tiêu đề “Chào mừng trở lại” / “Tạo tài khoản”, cùng nền/font/spacing Welcome. Login có email, mật khẩu, hiện/ẩn mật khẩu, nút đăng nhập và link đăng ký. Register có tên hiển thị, email, mật khẩu và xác nhận mật khẩu theo contract hiện tại.

Form hỗ trợ autofill, keyboard next/done, scroll khi bàn phím mở, submit bị khóa khi đang gửi. Lỗi mạng/tài khoản đặt ở vùng lỗi form; lỗi sai định dạng ở field liên quan. Giữ `apiErrorMessage` và interceptor, không gắn tất cả lỗi server thành lỗi mật khẩu. Không tự cắt/trim mật khẩu; email mới trim theo hành vi đang có.

Đăng ký thành công theo đúng contract hiện tại: nếu chưa được cấp phiên thì về Login với lời nhắc/điền sẵn email; không giả đã đăng nhập. Không tạo thêm thông tin nhà, payment hoặc yêu cầu quyền thiết bị ở bước này.

## 8. Manifest file dự kiến

Tất cả đường dẫn dưới đây tương đối repository root. File mới là dự kiến, chưa tạo trong bước lập kế hoạch.

| Tạo/sửa | File | Trách nhiệm |
|---|---|---|
| Tạo | `mobile/lib/features/launch/presentation/screens/launch_screen.dart` | Hiển thị intro và trạng thái đọc phiên, lifecycle/disposal |
| Tạo | `mobile/lib/features/launch/presentation/providers/launch_providers.dart` | Điều phối local session hydration/intro completion, chống điều hướng đôi |
| Tạo | `mobile/lib/features/launch/presentation/widgets/chore_house_intro.dart` | Hero animation, phiên bản tĩnh/reduced motion |
| Tạo | `mobile/lib/features/auth/presentation/screens/welcome_screen.dart` | Hero tĩnh, copy và hai CTA |
| Tạo | `mobile/lib/features/auth/presentation/widgets/auth_brand_header.dart` | Mark/wordmark dùng chung Login/Register |
| Tạo | `mobile/lib/features/auth/presentation/auth_theme.dart` | Token/theme cục bộ launch/auth, không đổi toàn bộ app |
| Sửa | `mobile/lib/core/router/app_router.dart` | Entry, public routes, redirect và back/deep-link handling |
| Sửa nếu cần | `mobile/lib/features/auth/presentation/providers/auth_providers.dart` | Phối hợp trạng thái phiên, giữ session expiry/epoch |
| Sửa | `mobile/lib/core/storage/local_storage.dart` | Cờ intro đã xem theo version |
| Sửa | `mobile/lib/features/auth/presentation/screens/login_screen.dart` | Visual/form/loading/error/back |
| Sửa | `mobile/lib/features/auth/presentation/screens/register_screen.dart` | Visual/form và đích sau đăng ký đúng contract |
| Sửa nếu cần | `mobile/lib/main.dart` | Kết nối launch/theme, không phá ProviderScope/WebPreviewFrame |
| Sửa | `mobile/pubspec.yaml` | Khai báo font/asset thực sự dùng |
| Tạo nếu chốt font | `mobile/assets/fonts/` | Font weights được dùng và file license |
| Sửa | `mobile/android/app/src/main/res/drawable/launch_background.xml` và bản `drawable-v21` | Native splash tĩnh |
| Sửa | Android `values/styles.xml`, `values-night/styles.xml`; thêm resource Android12 nếu cần | Splash trước frame Flutter ở các OS/theme |
| Sửa | `mobile/ios/Runner/Base.lproj/LaunchScreen.storyboard`, `Assets.xcassets/LaunchImage.imageset/` | Splash iOS cùng nền/mark |
| Tạo | `mobile/test/features/launch_flow_test.dart` | Luồng first launch/returning/session/reduced motion |
| Tạo | `mobile/test/features/welcome_screen_test.dart` | CTA, layout, accessibility |
| Tạo/sửa | Auth screen tests | Validation, submit đôi, error placement, back và đổi tài khoản |

Không sửa các generated plugin registrants để làm intro. Không có BE endpoint, database migration hoặc AI model mới trong scope UI này.

## 9. Accessibility, hiệu năng và kiểm thử

- Reduced motion: chuyển thẳng sang hero tĩnh và vẫn hoàn tất launch state; không phụ thuộc animation-end callback bị bỏ qua.
- Không có audio tự phát, nhấp nháy hoặc chuyển động liên tục. Semantics cho logo/CTA; các mảnh minh họa trang trí không làm screen reader đọc từng icon.
- Kiểm tra màn nhỏ320×568, Android phổ biến360×800, ảnh tham chiếu335×725, font scale1.0/1.5/2.0 và bàn phím mở. Không overflow, che CTA hoặc mất field đang nhập.
- Đo frame timing trên Android/emulator, mục tiêu phần lớn frame trong budget của thiết bị; không tuyên bố60fps chỉ từ widget test. Background/resume và nhấn Bỏ qua liên tục không tạo navigation/controller exception.
- Full intro không chờ network. Rớt mạng vẫn vào Welcome và thấy hai CTA; auth/network lỗi có retry rõ.
- Test token thiếu/có/refresh denied/offline, logout/login account khác, Back, cold start vs resume và deep link cần đăng nhập.
- Chạy Flutter analyze/tests, kiểm tra screenshot các màn và test thiết bị trước đánh dấu nghiệm thu. Database phải sẵn sàng để phân biệt lỗi API do migration với lỗi form.

## 10. Trình tự triển khai và nghiệm thu

1. Chốt copy, token và storyboard; làm frame tĩnh Welcome trước để kiểm tra bố cục giống tinh thần ảnh tham khảo nhưng rõ Chore Wars.
2. Tạo hero reusable và animation; hỗ trợ reduced motion từ đầu.
3. Nối launch/session/router, xử lý skip/returning user/logout/deep link và test chống loop.
4. Đồng bộ Login/Register, giữ nguyên nghiệp vụ và kiểm thử validation/error/loading.
5. Đồng bộ native splash và bundled assets; đo cold start trên Android.
6. Chạy regression, kiểm tra ảnh chụp thực tế; ghi trạng thái phần đã/chưa nghiệm thu.

Tiêu chí đạt: cài mới thấy intro rồi Welcome; hai CTA đi đúng form; user có phiên không bị đưa vào luồng đăng ký; app resume không replay intro; lỗi auth/network không gây loop; không mất dữ liệu phiên hoặc lẫn tài khoản; reduced motion/màn nhỏ/chữ lớn dùng được; không thay API/nghiệp vụ để phục vụ minh họa. Đây là kế hoạch cho đợt mở app/auth, chưa đánh dấu toàn UI/UX hệ thống đã redesign.

## 11. Điều hướng, chat và ngoại vi — cập nhật theo yêu cầu 23/10/2026

Mục này thay thế cách chia Nhà/Việc/Chat/AI/Thêm của bản đầu. Intro/auth ở mục 1–10 vẫn là kế hoạch riêng, chưa đánh dấu đã triển khai.

### Bố cục và kiến trúc giao diện

`[Tên nhà + QR | Tên tôi] → [Nội dung] → [Overview | Chore | Chat | Bonus | Bounty]`.

- `HouseShell` dùng house ID từ URL. QR bên cạnh tên nhà mở mã mời lấy từ dữ liệu hiện hành; bấm tên nhà mở tổng quan, bấm tên mình mở tài khoản. Bỏ shortcut Member vì tổng quan đã có danh sách thành viên, chủ nhà quản lý tại tiêu đề danh sách.
- `ProfileScreen(houseId)` chia hai tab Hồ sơ cá nhân và Lịch trình. Karma và lịch sử nằm trong hồ sơ; lịch rảnh, sở thích/giới hạn và lịch phân công nằm trong lịch trình. Có trạng thái chưa chọn nhà/chưa có mùa và lỗi dữ liệu, không tự lấy house ID khác.
- `HouseBonusScreen` dùng mùa hiện tại, xử lý không có mùa và nối màn Bonus sẵn có. Bounty có route trong nhà; quản lý mùa/phần thưởng/thanh toán còn truy cập từ Quản lý nhà, không thêm tab thứ sáu.
- Urgent Event được mở từ Chore; banner chiến dịch nằm trong Chore, không giữ shortcut khẩn cấp ở Chat. Các proposal cần xác nhận trong Chat vẫn giữ nguyên quy trình nghiệp vụ.
- Theme dùng bảng Serene Hearth: tím `#5F3ADD`, nền kem `#FBF9F6`, chữ `#1B1C1A`, chữ phụ `#484555`, container tím `#7857F8`, lavender `#E6DEFF`, amber `#825100` và nền amber `#FFDDB8`. Thanh dưới dùng nhãn chữ, ít khung, form nền nhẹ, vùng chạm tối thiểu 48. Bỏ icon trang trí trên menu/tài khoản; giữ camera, micro, QR và chuông vì là công cụ. Các trang giữ theme sáng/tối.

### Mention và thông báo chat

- `MessageInput` có nút `@`, cũng mở bộ chọn khi gõ `@`: Trợ lý, Mọi người, thành viên đang hoạt động. Các lựa chọn hiển thị bằng chip, có thể bỏ trước khi gửi. ID ổn định tránh nhận nhầm khi trùng tên.
- Contract nội dung: `@{user-guid}`, `@all`, `@agent`. Tin nhắn lưu nguyên token; frontend hiển thị tên, không đưa GUID ra UI. Backend xác minh người gửi và người được tag thuộc nhà. Không tag email hoặc tìm người theo display name.
- Text mới đi qua SignalR `SendText(roomId, content, clientMessageId)`; giữ `SendMessage` cũ tương thích client cũ. Retry cùng ID/nội dung trả lại bản đã lưu; cùng ID/nội dung khác bị từ chối. Giới hạn server/DB thống nhất 2.000 ký tự, composer chừa dung lượng cho token mention.
- `ChatMessageCreatedEvent` đi cùng transaction chat vào outbox; chỉ chứa message ID, house ID và danh sách recipient/mention ID, không chứa chat thô. `chat.message_created` được khai báo trong Kafka topic map, init script, scope resolver và consumer. Consumer lấy message đã lưu, kiểm tra lại thành viên và thời điểm tham gia, bỏ sender, tạo CHAT_MESSAGE hoặc CHAT_MENTION qua pipeline notification hiện hữu. ProcessedMessages chống lặp event, lỗi vẫn đi qua quarantine/replay hiện có.
- Thông báo chat có nút chuông và badge riêng, lọc đúng house ID; mở thông báo quay lại phòng chat, đánh dấu đã đọc chỉ áp dụng các item đang xem. Thông báo hệ thống/badge không cộng chat. Đây là hộp thư trong ứng dụng và SignalR, chưa phải Android background push/FCM.
- Realtime lấy token mới qua accessTokenFactory, đóng kết nối và loại kết quả cũ khi session đổi. HTTP inbox vẫn refresh được khi transport offline.
- `@agent` chỉ gửi yêu cầu vừa gõ của chính người dùng tới endpoint interpret theo yêu cầu; phản hồi riêng ở `AssistantChatScreen`, không giả tin nhắn AI công khai trong lịch sử. Không đọc toàn phòng hoặc tự bật đồng ý phân tích chat. Xác nhận lịch bận/rảnh vẫn qua màn review và kiểm tra quyền sẵn có.

### Micro, camera và QR

- Camera chat mở xem trước, Chụp và gửi upload qua API media riêng tư. Giữ chọn ảnh thư viện, giới hạn 5 MB và retry cùng payload/client ID. Camera giải phóng khi thoát/xuống nền.
- Ghi âm Android giữ AAC M4A; web dùng PCM WAV 16 bit mono, 16 kHz. Giới hạn 60 giây và 5 MB. Backend kiểm tra header/chunk, sample rate, byte rate, độ dài và thời lượng WAV, không chỉ tin extension. Không đổi tên WebM thành M4A. Phát theo MIME thực, web đọc blob/bộ nhớ, không dùng path_provider; hủy/gửi xong thu hồi blob.
- STT không hủy chỉ vì trạng thái inactive của hộp xin quyền; dùng vi-VN trên web thay vì đòi browser phải liệt kê tiếng Việt. Callback được gắn lại khi đổi màn; chặn callback lúc dispose, giữ kết quả cuối khi bấm Dừng ghi. Thiếu TTS không được chặn khởi động micro. Speech vẫn phụ thuộc quyền và dịch vụ nhận giọng nói của nền tảng.
- QR render đen/trắng có khoảng trống, kích thước theo chiều rộng và cuộn được trên màn nhỏ. Scanner chỉ đọc QR, quản lý start/stop theo một queue, bỏ quét lặp trong lúc preview/join, không khởi động lại sau khi join thành công. Hỗ trợ raw code 8 ký tự hoặc code trong URL mời; không tự truy cập URL quét được. Luôn preview nhà và xin xác nhận trước Join, có nhập mã thay thế và retry khi camera không mở.

### AI chưa sẵn sàng

GET settings trả cờ `configured` từ cấu hình dịch vụ, không lộ khóa. Flutter kiểm tra settings trước khi dựng các tab dữ liệu AI, hiển thị ngoại tuyến/chưa bật và nút bật đúng quyền. Tắt retry tự động cho aiDataProvider để không lặp GET 409; không gửi interpret rỗng gây 400. Không tự tạo khóa, tự bật phân tích chat hoặc giả kết quả khi Python/Gemini chưa sẵn sàng. `configured` chứng minh đủ cấu hình, không thay health check của provider.

### File và kiểm chứng

- Flutter: `house_shell.dart`, `app_router.dart`, `app_theme.dart`, `house_detail_screen.dart`, `house_more_screen.dart`, `house_bonus_screen.dart`, `profile_screen.dart`, `qr_invite_screen.dart`, `qr_join_screen.dart`, `invite_code.dart`, `message_input.dart`, `chat_mentions.dart`, `message_bubble.dart`, `chat_home_screen.dart`, `assistant_chat_screen.dart`, `chat_room_screen.dart`, `chat_providers.dart`, `chat_repository.dart`, `chat_signalr_service.dart`, notification model/provider/screen/realtime service, `ai_repository.dart`, `ai_housekeeper_screen.dart`, `ai_setup_view.dart`, `ai_voice_controls.dart`, voice recorder/file/playback, `pubspec.yaml/lock`.
- Backend: `ChatService`, `IChatService`, `ChatHub`, `ChatMentions`, `ChatConstants`, `ChatMessageConfiguration`, `ChatMessageCreatedEvent`, `ChatMessageCreatedConsumer`, `KafkaTopics`, `EventScopeResolver`, DI extension, `NotificationType/Response`, `MediaService`, `MediaInspector`, `IAIServiceStatus/AIServiceStatus`, `AIHousekeeperService`, `docker-compose.yml`. Không cần migration mới: dùng Content, ClientMessageId, outbox và notification hiện có. Ảnh/voice note chỉ tạo event thông báo khi gửi chính thức; upload riêng không thông báo và retry không tạo event thứ hai.
- Regression có test tag cá nhân/all/agent, quyền tag và rollback, retry text, outbox không chứa chat thô, Kafka thật chống lặp/loại người đã rời, WAV hợp lệ/truncated/giả byte rate/quá 60 giây, callback micro/permission/reopen, AI offline không gọi profiles, QR parser và điều hướng đúng nhà. Thêm web build và render 354×643 trước bàn giao.
- Chưa được coi là nghiệm thu camera/micro/loa/QR trên Android thật hoặc webcam thật chỉ từ widget/platform fake. Lỗi my-houses 500 vẫn cần exception tương ứng nếu tái diễn; log SQL Executed DbCommand không phải lỗi. Phải khởi động lại cả backend lẫn Flutter để có Hub SendText, consumer mới và plugin camera.
- Kết quả kiểm chứng ngày 23/10/2026: 31 Flutter test đạt, analyzer không có issue, web debug build thành công; 80 backend unit test đạt. Lượt integration cuối gồm 10 case chat/HTTP media/SignalR revocation đều đạt với PostgreSQL và Kafka cục bộ, không có case bị skip; bao gồm ảnh/WAV retry chỉ có một event và pipeline outbox → Kafka → inbox chống lặp. Đây là bộ lọc hồi quy liên quan thay đổi, không phải tuyên bố toàn bộ hệ thống đã nghiệm thu.

### Cập nhật luồng Chat và Overview (23/10/2026)

- Giữ 5 tab: Overview, Chore, Chat, Bonus, Bounty. Overview mở tổng quan nhà tại `/houses/:houseId`; trang AI và các trang con vẫn thuộc nhóm Chat.
- `/houses/:houseId/chat` là trang chọn hai cuộc trò chuyện: Chat với trợ lý và Chat với mọi người. Phòng gia đình chuyển sang `/chat/everyone`; notification và luồng tạo urgent event mở trực tiếp route này.
- `/chat/assistant` là màn trao đổi riêng, gọi API settings rồi interpret hiện có qua C#. Không ghi yêu cầu vào phòng chung, không tự bật AI hoặc đồng thuận. Lịch bận/rảnh vẫn phải qua màn review trước khi áp dụng. Nút Quản lý AI mở hồ sơ hành vi, đánh giá, đề xuất và cài đặt tại route AI hiện hành.
- Tin nhắn trợ lý trong màn mới là lịch sử của phiên đang mở; chưa lưu thành conversation bền vững và không gửi toàn bộ lịch sử làm context. Backend interpret vẫn là chức năng diễn giải yêu cầu, không mặc định trở thành chatbot đa lượt có trí nhớ.
- Tag agent trong phòng gia đình mở màn trợ lý với yêu cầu vừa gửi. Bản nháp được giữ nếu AI chưa sẵn sàng hoặc API lỗi; màn riêng được tách theo nhà và session để không hiển thị phản hồi cũ sau đổi tài khoản.

### Bảng màu Serene Hearth

Ưu tiên token trong khối `colors` đầu tài liệu người dùng gửi, vì phần văn xuôi có vài mã màu khác. `AppTheme.lightColors` khai báo tường minh các role Material; các alias còn dùng ở màn cũ cùng trỏ về bảng này. Giữ bố cục, kiểu chữ và nghiệp vụ. Các component dùng theme chung gồm form, nút, FAB, card, dialog, bottom sheet, snackbar và navigation. Chuyển các màu xanh dương/cam/tím cố định trong bounty, proposal chat và phần thưởng sang token chung. Xanh lá trầm được giữ riêng cho thành công; đỏ theo token error. QR vẫn đen/trắng và camera vẫn giữ lớp phủ để bảo đảm khả năng quét. Theme tối dùng nền trung tính ấm dẫn xuất từ cùng màu tím; tài liệu chỉ cung cấp bảng token sáng.


### Overview ở vị trí đầu

Tab đầu mở tổng quan nhà. Trang dùng nền Serene Hearth, header Overview và Quản lý nhà; thẻ mùa hiện tại hiển thị riêng các trạng thái chưa có mùa, draft, reviewing, active và kết thúc. Nút tạo/chuẩn bị mùa chỉ hiển thị cho owner; xác nhận lịch giữ luồng review hiện có. Danh sách chỉ đếm thành viên active, mỗi người có avatar chữ cái và vai trò; bấm chính mình mở tài khoản. Nhóm Trong nhà liên kết hồ sơ/lịch trình và lịch phân công nếu có season ID. Không suy ra thống kê task, bounty, tiền hoặc online khi API chưa cung cấp. Giữ kéo xuống để tải lại cả house, members và season.


### Header Overview và chạy Chrome khi debugger timeout

Overview dùng header tên nhà dạng pill, QR cạnh tên và Quản lý nhà bên phải; phần nội dung giữ một tiêu đề Overview, không lặp nút quản lý. Các màn khác vẫn có tên người dùng để mở tài khoản. Khi Flutter lỗi `WebkitDebugger.enable` timeout, dùng `mobile/scripts/run-web.ps1`, chờ app được serve rồi mở localhost:8080 trong Chrome. Đây là đường chạy web-server tránh tự kết nối Chrome debugger, không phải bản vá SDK. Có thể đổi port bằng tham số Port; breakpoint Dart bị giới hạn.


### Giao diện chat trợ lý và gia đình

Trong `/chat/assistant` và `/chat/everyone`, ẩn header chung và thanh 5 tab; nút Quay lại Chat mở danh sách hai cuộc trò chuyện. Trợ lý có header tên nhà, Quản lý AI, phần giới thiệu riêng, chip gợi ý lịch bận/rảnh điền vào bản nháp, bong bóng có thời gian phát sinh và composer với Nói/Đọc/Dừng gọn. Không dùng gợi ý đặt bounty tự động vì chưa có contract cho hành động đó. Chat gia đình dùng nền lavender, header tên nhà và số thành viên active đã tải, badge thông báo thật; composer có @Mọi người, chọn ảnh, tag người, camera, voice note và lối vào bảng Bounty. Nút Bounty chỉ mở bảng để chọn/xử lý bằng luồng hiện hữu. Không hiển thị Online, Read hoặc số dư giả từ mẫu thiết kế. Giữ retry idempotent và kiểm tra quyền hiện có; đây là thay đổi giao diện.


### Header chung, Chores và thông báo theo mẫu mới

Ngoài hai phòng chat toàn màn hình, header chung dùng pill chọn nhà (mở danh sách nhà), QR và chip tài khoản có avatar chữ cái. Overview đưa Quản lý nhà về cạnh tiêu đề để giữ một lối vào. Chores giữ Routines/Mine/Team, nút khẩn cấp đúng trạng thái mùa và lối vào việc cần xử lý, badge thông báo thật. Routine trống có CTA tạo cho owner ở mùa draft; không thêm routine gợi ý hay streak thưởng chưa có dữ liệu. Mine và Team dùng thẻ mềm, ngày và Karma thật. Team đọc occurrence DTO có kiểu, sắp theo dueDate, giữ tên từ phân công khi assignee không còn trong danh sách active, không gán tên người đầu tiên thay thế; lỗi tải có retry. Thông báo hệ thống lọc Tất cả/Bounty/Việc nhà/Khác, phân biệt đã/chưa đọc và icon theo loại. Đọc tất cả chỉ áp dụng tập đang hiển thị, vẫn tách chat theo house; batch dừng nếu session đổi.


### Review Schedule, My Account, Settings và Availability

Theo mẫu cream/lavender, dùng thẻ bo góc trắng, badge mềm và CTA tím. Review hiển thị revision thực, tải Karma/phút/số việc theo thành viên, tỷ lệ Karma và trạng thái xác nhận (kể cả từ chối); xác nhận gửi đúng scheduleRevision. Cảnh báo fairness lấy nguyên từ backend, không dùng ngưỡng 15% trong ảnh. Giữ thao tác draft/review và quyền owner hiện có.

My Account có thẻ danh tính/vai trò, Karma và ba nhóm việc thường/bonus/phạt, lịch sử và đăng xuất có xác nhận. Settings dùng slider sức chứa cùng chip sở thích từ chore thật; lưu chỉ constraints/preferences, không ghi đè availability. Giá trị cũ vượt phạm vi trình bày vẫn được giữ. Availability có banner GMT+7, thẻ từng ngày, chip interval có thể xóa, tổng giờ tuần và nút lưu cố định; tổng giờ gộp giao nhau để không đếm trùng, payload vẫn giữ từng interval. Chặn lưu dữ liệu mặc định sau lỗi tải.

Launcher web-server nay tự mở Chrome sau khi bootstrap sẵn sàng; có -NoBrowser và kiểm tra port. Cấu hình VS Code tại root/mobile dùng web-server. Đây là cách tránh DWDS timeout; không thay SDK hay khẳng định đã sửa breakpoint debugger.


### English UI và House Management theo mẫu

Theo yêu cầu mới, nền sáng đổi sang be #F7F3ED; thẻ có viền và trường nhập dùng nền trắng #FFFFFF. App mặc định giao diện sáng và locale tiếng Anh. Toàn bộ nhãn, trợ giúp, tooltip, trạng thái rỗng và lỗi được khai báo trong Flutter chuyển sang tiếng Anh. Định dạng tiền hiển thị theo en_US nhưng giữ đơn vị VND; trường nhập bounty nhận dấu phẩy phân nhóm và dấu chấm thập phân. Voice nhận/đọc tiếng Anh. Backend tạo thông báo và thẻ đề xuất mới bằng tiếng Anh; AI nhận cả tiếng Anh/Việt, diễn giải bằng tiếng Anh nhưng giữ nguyên evidence quotes. Không sửa tên, nội dung người dùng hoặc bản ghi lịch sử đã lưu.

House Management chia nhóm Season Management, Rewards & Recognition, System & Preferences bằng thẻ trắng bo góc, icon màu nhẹ và mũi tên. Badge mùa đọc trạng thái thật; Create New Season chỉ dành cho owner. Giữ các route lịch, leaderboard, thưởng cuối mùa, rewards/achievements, notifications, Karma history, settings, payments và đổi nhà. Không thêm số mẫu Available/Badges hoặc màn audit chưa có API.


### Chuông thông báo chat và CTA Bounty

Header chung có một chuông mở inbox, badge đếm tất cả thông báo chưa đọc, gồm cả chat. Inbox thêm bộ lọc Chat; chạm View Details mở occurrence/bounty hoặc bảng xếp hạng đúng mùa theo target của backend. Banner chỉ xuất hiện khi nhận sự kiện chat mới qua SignalR, không phát lại lịch sử khi tải inbox và không hiện trùng khi đang xem chính phòng chat đó. Nút Open đánh dấu đã đọc và mở phòng chat. Chuông riêng trong phòng chat vẫn là công tắc mute theo nhà/tài khoản; consumer tiếp tục bỏ qua người đã tắt thông báo.

Routines trống dùng thẻ trắng bo góc, nút Create First Routine và ba preset mở form có thể sửa trước khi lưu. Owner tạo reusable routine khi có mùa active hoặc chưa có mùa; chỉ import/generate vào mùa draft, không đổi phân công đã chốt. Link tạo routine đặt sẵn asRoutine=true. Trạng thái AI chưa cấu hình hiển thị Assistant Setup Required, không gán nhãn mất kết nối cho lỗi cấu hình máy chủ.

Chuông trong Household Chat là nút bật/tắt trực tiếp Messages & Mentions: chạm một lần để đổi trạng thái, không mở bottom sheet. Tooltip và biểu tượng có gạch chéo phản ánh trạng thái đã lưu. Tùy chọn lưu theo tài khoản/nhà qua API kiểm tra active membership; mặc định bật. Khi tắt, consumer không tạo thông báo CHAT_MESSAGE/CHAT_MENTION mới cho thành viên đó, kể cả @all. Thông báo đã lưu và thông báo việc nhà vẫn giữ nguyên. Đây là tùy chọn trong ứng dụng, không thay quyền camera/micro/thông báo của trình duyệt. Bounty giữ một FAB Post Bounty, bỏ nút đăng lặp ở header và empty state.

### Leaderboard, Rewards, Achievements và cài đặt theo mẫu

Tám trang dùng nền be, thẻ trắng bo góc, tiêu đề gọn và CTA tím: Leaderboard, Season Rewards, Household Rewards, House Achievements, Karma History, Start New Season, House Settings, Payment Obligations. Podium chỉ hiện thành viên có dữ liệu; phần đóng góp là tỷ lệ việc đã hoàn thành của cả mùa, không dựng số việc được giao. Rewards giữ API claim/use pass/redeem hiện hữu và request ID cho retry. Achievements hiển thị số đã mở khóa thật; bỏ XP và tiến độ riêng chưa có API. Karma History lọc Earned/Penalties/Spent từ transaction type. Thanh toán tách khoản đang mở và lịch sử, chỉ người nhận có nút xác nhận khoản pending; bổ sung route trong house để giữ header/thanh điều hướng.

Không thêm quỹ chi tiêu chung, nhập chi phí, phần thưởng XP, công tắc carry-over/penalty hoặc badge AI Active từ ảnh. Create Season vẫn dùng clone và allocation hiện có; Settings giữ xác nhận rotate/archive/leave và chuyển quyền qua quản lý thành viên. Kiểm tra layout ở 320px với text scale 1.2; ảnh render mẫu được xuất tùy chọn trong build/ui-review bằng bộ dữ liệu kiểm thử.
