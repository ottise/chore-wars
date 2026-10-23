# Kế hoạch triển khai 10 nhóm không-AI — cập nhật sau pull, hoãn tích hợp thanh toán

Ngày cập nhật: 19/10/2026. Source đối chiếu: HEAD `8bad321`. Nhóm 4 thành viên. **Đây là kế hoạch để triển khai, chưa phải báo cáo đã hoàn thành code.**

Bản này thay các phương án thanh toán ở những kế hoạch trước. Theo quyết định mới nhất: **hoãn payOS, QR chuyển tiền, thủ quỹ và settlement để hỏi giảng viên**; không tạo adapter, bảng, màn hình hoặc cấu hình ngân hàng cho các phần đó trong đợt này. Giữ payment tracking và xác nhận nhận tiền thủ công. AI theo kế hoạch Python riêng.

## 0. Baseline sau pull và việc phải xử lý trước

Kết quả kiểm tra đã ghi tại [báo cáo sau pull](post-pull-plan-audit-8bad321.vi.md): Flutter analyze 17 errors/1 warning/3 info; backend UnitTests 14 pass/1 fail, IntegrationTests 3 pass. Đây là kết quả phiên audit trước, **không phải đã chạy lại trong lần cập nhật tài liệu này**. Các integration test hiện chủ yếu gọi controller bằng mock, chưa chứng minh PostgreSQL/Kafka/HTTP E2E.

- Không có Git conflict tại HEAD này. Conflict chính là contract FE/BE và rule nghiệp vụ.
- Màn chat import ba file chưa có: action_proposal_model.dart, action_proposal_providers.dart, interactive_action_card.dart. Method receiveMessage và named callbacks chưa khớp repository/notifier; screen và notifier cùng mở hub; card bị ẩn khi phòng chưa có text.
- Backend đã có ActionProposal/ProposalConfirmation, service, controller, repository, publisher và migration AddActionProposals. **Sửa/tái sử dụng, không tạo lại.** Swap/urgent ngoài phạm vi: chặn endpoint ghi bằng capability mặc định tắt, phản hồi rõ cho client; giữ dữ liệu và luồng đọc lịch sử. Không làm card giả có nút duyệt nhưng không execute.
- Proposal SEASON_APPROVAL chưa điều khiển lifecycle: SeasonService là nguồn chuẩn. Không cho proposal APPROVED thay thế required confirmations/revision.
- Chuẩn hóa API proposal đang /api/v1 với /api của app; giữ alias nếu client cũ cần. Bổ sung kiểm active membership khi đọc/respond, kiểm lại context khi execute; khóa occurrence dùng chung nếu mở capability sau này.
- Unit test generation mock query theo season nhưng service lấy toàn house: sửa query về snapshot đúng season và cập nhật test cùng lúc.
- Payment test hiện cho debtor tự settle: sửa acceptance theo creditor xác nhận, không giữ test sai chỉ để xanh.
- Xử lý dependency warning EF Core Relational lệch version và AutoMapper advisory bằng đánh giá graph/advisory thực tế khi implementation; không tự nâng package lớn thiếu regression.

Gate mở đầu: backend test đạt, Flutter analyze hết error, không có hai hub connection cho cùng màn; ghi kết quả thật trước khi triển khai nghiệp vụ tiếp.

## 1. Phạm vi, kiến trúc và các quyết định đã chốt

Triển khai toàn bộ 10 nhóm không-AI trên BE/FE hiện có. Không xây lại authentication, household, chore, chat hoặc gamification từ đầu; mở rộng và sửa các điểm cần thiết.

Kế hoạch bám theo tài liệu kiến trúc, UI, database, API, deployment và các bản kế hoạch trong `docs`. Với tài liệu khác nhau, áp dụng thứ tự:

1. Quyết định mới nhất của bạn.
2. Business Rules/SRS đã cung cấp.
3. Kiến trúc và design system trong `docs`.
4. Tên entity, endpoint và cấu trúc source hiện tại.

Các bản database/API cũ có tên không còn khớp source sẽ được cập nhật; không đổi code về mô hình cũ. Phân công 3 developer trong tài liệu trước được thay bằng nhóm 4 thành viên.

### Quyết định nghiệp vụ cố định

| Nội dung | Quyết định |
|---|---|
| Bounty | Được mở sau khi assignee nhận việc, không phải đợi critical overdue |
| Thời hạn bounty | Mặc định 24 giờ từ lúc tạo; không dùng deadline đã qua làm expiry |
| Forced compensation | Mỗi occurrence tối đa một compensation bắt buộc |
| Người bị forced tiếp tục thất bại | Penalty riêng theo lượt chịu trách nhiệm; không tạo thêm vòng compensation tự động |
| Thanh toán tích hợp | Hoãn payOS, thủ quỹ, quyết toán, QR tiền và cấu hình ngân hàng |
| Payment tracking | Giữ nghĩa vụ giữa debtor/creditor; chỉ creditor xác nhận đã nhận, debtor không tự PAID |
| Kết thúc mùa | Khóa Karma/ranking tại thời điểm kết thúc; việc/nợ còn tồn tiếp tục xử lý nhưng không đổi Karma mùa đã đóng |
| Chore Pass thiếu người thay | Không tiêu pass, không sửa assignment, thông báo chưa thể sử dụng |
| Thẻ swap/urgent thủ công | Không nằm trong lần triển khai này |
| AI | Theo kế hoạch Python riêng; không đưa vào 10 nhóm này |
| Nền tảng nghiệm thu | Android APK release; cấu hình iOS được cập nhật cho tính năng mới nhưng không coi là đã kiểm thử iOS |

### Kiến trúc giữ nguyên

```text
Flutter Screen
 → Riverpod Provider
 → Domain Repository
 → Data Repository / Remote DataSource
 → Dio / SignalR

ASP.NET Controller / Hub
 → Application Service
 → Domain rules + Repository interfaces
 → Infrastructure implementations
 → PostgreSQL / Private media storage / Kafka
```

Các constraint bắt buộc:

- Domain không phụ thuộc EF, HTTP hoặc Kafka.
- Application không dùng trực tiếp `AppDbContext`, SQL hoặc SDK tích hợp bên ngoài.
- Repository chỉ truy cập dữ liệu; nghiệp vụ nằm trong service.
- Controller/Hub mỏng, không chứa thuật toán hoặc ghi file trực tiếp.
- Transaction nghiệp vụ do một Application Service điều phối; service con không tự mở transaction lồng nhau.
- Sự kiện và realtime chỉ phát sau commit.
- Flutter dùng theme/widget hiện có, giữ màu và spacing theo design system; không thiết kế lại giao diện toàn app.

---

## 2. Phần dùng chung phải triển khai trước

### 2.1. Transaction, concurrency và thời gian

Thêm cơ chế khóa ghi theo household trong transaction PostgreSQL. Tất cả mutation có thể cạnh tranh trong cùng nhà phải sử dụng chung cơ chế: join, generate, confirmation, complete, claim, bounty, penalty, reward và payment confirmation.

Interface đặt trong Application; triển khai khóa nằm trong Infrastructure. Không giữ transaction khi gọi hệ thống bên ngoài hoặc upload storage.

Dùng `TimeProvider` được inject thay cho các lần đọc giờ trực tiếp trong nghiệp vụ cần kiểm thử. Múi giờ household bản đầu cố định `Asia/Ho_Chi_Minh`; timestamp là UTC, còn ngày lịch và giờ deadline được chuyển đổi tường minh.

### 2.2. Outbox và chống xử lý sự kiện lặp

Thêm outbox để ghi sự kiện cùng transaction nghiệp vụ. Worker phát Kafka sau commit. Consumer chỉ commit offset sau khi xử lý thành công và lưu dấu sự kiện đã xử lý.

Duy trì unique constraint cho nghiệp vụ gốc; dedup Kafka không thay thế chống ghi trùng completion, obligation hoặc reward.

### File dùng chung

Trong [Application](D:/FPT/Semester_8/PRM393/project/chore-wars/backend/src/Application):

- **Sửa:** `IUnitOfWork.cs` trong `Interfaces/Repositories`, các service interfaces và DTO bị ảnh hưởng.
- **Tạo:** `IHouseAccessService.cs`, `HouseAccessService.cs`.
- **Tạo:** `IOutboxWriter.cs` và event envelope có `EventId`, thời điểm, house/entity reference.
- **Sửa:** cách phát sự kiện của các service để ghi outbox trong transaction.

Trong [Domain](D:/FPT/Semester_8/PRM393/project/chore-wars/backend/src/Domain):

- **Tạo entity:** `OutboxMessage.cs`, `ProcessedMessage.cs`.
- **Thêm version:** các aggregate cần optimistic check như season, occurrence và reward redemption.

Trong [Infrastructure](D:/FPT/Semester_8/PRM393/project/chore-wars/backend/src/Infrastructure):

- **Sửa:** `UnitOfWork.cs`, `AppDbContext.cs`.
- **Tạo:** triển khai outbox writer và `OutboxDispatcherWorker.cs`.
- **Sửa:** `KafkaEventPublisher.cs`, `KafkaConsumerBase.cs` và consumer liên quan.
- **Tạo configuration:** `OutboxMessageConfiguration.cs`, `ProcessedMessageConfiguration.cs`.

Trong [Presentation Extensions](D:/FPT/Semester_8/PRM393/project/chore-wars/backend/src/Presentation/Extensions):

- **Sửa:** `ApplicationServiceExtensions.cs`, `InfrastructureServiceExtensions.cs`, `PresentationServiceExtensions.cs`.
- Đăng ký clock, service, repository, HTTP client, outbox và workers.

---

## 3. Nhóm 1 — Payment tracking và xác nhận nhận tiền

### 3.1. Phạm vi hiện tại

Tái sử dụng PaymentObligation: house, season/occurrence, người trả, người nhận, số tiền, lý do, trạng thái, created/paid time. Không thu tiền qua app trong đợt này. Màn nghĩa vụ thể hiện ai phải trả ai, vì sao và đã được người nhận xác nhận hay chưa.

Luồng: hoàn thành bounty hợp lệ → tạo obligation PENDING cùng transaction completion → debtor xem khoản phải trả → các bên tự thanh toán bên ngoài → **creditor xác nhận đã nhận** → backend kiểm quyền/eligibility, cập nhật PAID và PaidAt đúng một lần → hai bên thấy trạng thái mới. Forced compensation chỉ đủ điều kiện xác nhận sau completion hợp lệ của người được hưởng; không được đóng nợ trước điều kiện này.

- Giữ ID và lịch sử nghĩa vụ; không chuyển creditor thành tài khoản developer.
- Chỉ active member có liên quan mới đọc/ghi dữ liệu nhà; kiểm entity thuộc đúng house route. Không cho leave/kick khi còn nghĩa vụ mở, tránh khóa khoản nợ không ai xử lý.
- Debtor và người thứ ba gọi settle trả 403. PAID retry của đúng creditor trả cùng kết quả, không ghi lịch sử/notification lần hai. Obligation CANCELLED/DISPUTED hoặc chưa đủ điều kiện trả conflict.
- Amount/creditor/occurrence lấy từ server; không nhận lại từ payload xác nhận. Dùng decimal, validate amount >0.
- Lưu ConfirmedByUserId và thời điểm; PaidAt là mốc xác nhận trong app, không được ghi thành thời gian ngân hàng xác minh. UI dùng “Người nhận đã xác nhận”, không dùng “Ngân hàng xác minh”.
- Không thêm endpoint ngân hàng, QR tiền, checkout, webhook, treasury, batch, payout hoặc migration cho chúng.

### 3.2. File sửa/tạo

**BE sửa:** Domain/Entities/PaymentObligation.cs; Application/Services/BountyService.cs, ChoreService.cs, BountyExpirationService.cs; Application/Interfaces/Services/IBountyService.cs; Application/Interfaces/Repositories/IPaymentObligationRepository.cs; Application/DTOs/Bounty/PaymentObligationResponse.cs; Application/Mappings/BountyProfile.cs; Infrastructure/Repositories/PaymentObligationRepository.cs; Infrastructure/Data/Configurations/PaymentObligationConfiguration.cs; Presentation/Controllers/BountyController.cs. Bổ sung confirmation actor/audit và eligibility cùng responsibility ở nhóm 8; không tạo service payment gateway.

**FE sửa:** mobile/lib/features/payment/domain/entities/payment_obligation.dart; domain/repositories/payment_repository.dart; data/models/payment_obligation_model.dart; data/repositories/payment_repository_impl.dart; presentation/providers/payment_providers.dart; presentation/screens/payment_obligations_screen.dart. Tái sử dụng endpoint hiện có, document rõ method/path thực tế trong API spec; không tạo API trùng chỉ đổi tên.

Ẩn action xác nhận với debtor; backend vẫn kiểm quyền. Sau xác nhận invalidate danh sách và badge liên quan. Hiển thị loading/error/retry và tránh double tap.

**Test sửa:** backend/tests/UnitTests/Services/PaymentObligationTests.cs. **Test tạo:** Services/PaymentConfirmationTests.cs và IntegrationTests/Payments/PaymentConfirmationConcurrencyTests.cs; mobile/test/features/payment/payment_confirmation_test.dart. Kiểm đúng creditor, sai creditor, khác house, chưa eligibility, retry, hai request cùng lúc và giữ nguyên nợ sau season end.

### 3.3. Yêu cầu môn đang chờ

Payment tracking không phải bằng chứng đã tích hợp **dịch vụ thanh toán**. Yêu cầu này vẫn ghi **chưa hoàn tất/chờ giảng viên xác nhận phương án**; không đánh dấu 10/10 hoàn tất môn khi mới có tracking. Sau khi hỏi thầy, bổ sung một kế hoạch riêng dựa trên quyết định mới.

---

## 4. Nhóm 2 và 3 — Microphone và Loa

### Kiến trúc

Dùng voice note trong chat. Micro ghi âm, Loa phát lại; không phụ thuộc AI.

Ứng viên thư viện là `record` cho recording và `just_audio` cho playback; kiểm tra tài liệu publisher, quyền Android/iOS và khóa version tương thích Flutter SDK khi triển khai: [record](https://pub.dev/packages/record), [just_audio](https://pub.dev/packages/just_audio).

Bản đầu ghi AAC-LC trong M4A, tối đa 60 giây, dung lượng tối đa 5 MB. Không ghi nền, không tự phát tin nhắn mới. Cập nhật 23/10/2026: Android giữ AAC M4A; web dùng PCM WAV 16 bit mono 16 kHz, backend kiểm tra cấu trúc và thời lượng thực. Cùng giới hạn 60 giây/5 MB, không chỉ đổi extension.

### BE

Trong [Domain Entities](D:/FPT/Semester_8/PRM393/project/chore-wars/backend/src/Domain/Entities):

- **Sửa:** `ChatMessage.cs`.
- **Tạo:** `MediaAttachment.cs`.
- **Tạo enum:** `ChatMessageType`, `MediaAttachmentType`.

Message mới có type, attachment reference, client message ID. Media có owner/room/house, MIME, size, duration và storage key.

Trong [Application](D:/FPT/Semester_8/PRM393/project/chore-wars/backend/src/Application):

- **Tạo:** `IMediaStorage.cs`, `IMediaService.cs`, `MediaService.cs`.
- **Tạo:** media repository interface, DTO/validator.
- **Sửa:** `IChatService.cs`, `ChatService.cs`, chat DTO.

Trong [Infrastructure](D:/FPT/Semester_8/PRM393/project/chore-wars/backend/src/Infrastructure):

- **Tạo:** `FileMediaStorage.cs`, media repository và EF configuration.
- Storage nằm ngoài public `wwwroot`, đặt trên persistent volume.
- **Tạo:** `MediaCleanupWorker.cs` xóa upload chưa gắn message sau 24 giờ.

Trong [Presentation](D:/FPT/Semester_8/PRM393/project/chore-wars/backend/src/Presentation):

- **Tạo:** `MediaController.cs` với upload và download có authorization.
- **Sửa:** `ChatController.cs` bỏ ghi file trực tiếp.
- **Sửa:** `ChatHub.cs` xác thực room và hỗ trợ attachment.
- Upload nhận room ID, kiểm membership, MIME thực và giới hạn.
- Download audio hỗ trợ range request để playback/seek.

Giữ text message cũ hoạt động. Các link ảnh cũ được backfill attachment khi xác định được room; dữ liệu không map được giữ nguyên, không tự xóa.

### Flutter

Trong [Chat Feature](D:/FPT/Semester_8/PRM393/project/chore-wars/mobile/lib/features/chat):

- **Tạo:** `voice_recorder_service.dart`, `audio_playback_service.dart`.
- **Tạo:** `voice_note_provider.dart`, `voice_note_recorder.dart`, `audio_message_bubble.dart`.
- **Sửa:** `chat_message_model.dart`, API service, repository, provider.
- **Sửa:** `message_input.dart`, `message_bubble.dart`, `chat_room_screen.dart`.
- Regenerate Freezed/JSON files từ model; không sửa generated files thủ công.

Luồng: ghi → stop → nghe trước → gửi/hủy. Chỉ một audio được phát cùng lúc. Rời màn/logout dừng playback; mất quyền room không tiếp tục tải audio.

Sửa `pubspec.yaml`, Android main manifest và iOS `Info.plist` cho quyền cần thiết. Không xin quyền mic khi người dùng chưa sử dụng chức năng.

---

## 5. Nhóm 4–6 — Season, phân công, lịch và frequency

### 5.1. Vòng đời và snapshot

- Routine template là chore có `SeasonId=null`.
- Khi chọn routine cho mùa draft, tạo bản sao thuộc season; thêm `SourceTemplateId` để truy nguồn.
- Occurrence sinh từ chore snapshot của chính season, không lấy mọi chore theo house.
- Draft cho sửa và generate lại; reviewing khóa cấu hình, reject đưa về draft và lưu reason.
- Khi đủ required confirmations mới chuyển active.
- Membership hoặc schedule revision đổi trước activation thì confirmation cũ không còn hiệu lực.
- Active/completed không sửa template hoặc assignment qua API manual thông thường. Chỉ cho các use case đã định nghĩa: bounty, forced reassignment và Chore Pass.
- Không thực thi occurrence trước thời điểm bắt đầu mùa, dù đã đủ xác nhận.

### 5.2. File BE cần sửa/tạo

Trong [Domain Entities](D:/FPT/Semester_8/PRM393/project/chore-wars/backend/src/Domain/Entities):

- **Sửa:** `Chore.cs`: source template, deadline local time, anchor recurrence.
- **Sửa:** `ChoreSeason.cs`: schedule revision và lock/finalized time.
- **Sửa:** `SeasonConfirmation.cs`: schedule revision được xác nhận.
- **Sửa:** `ChoreOccurrence.cs`: snapshot effort/difficulty cần thiết, completion actor và planned interval.
- **Sửa:** `MemberAvailability.cs` giữ tương thích dữ liệu ngày/bool cũ.
- **Tạo:** `MemberAvailabilitySlot.cs`, `ChoreCustomDate.cs`.

Trong [Application Services](D:/FPT/Semester_8/PRM393/project/chore-wars/backend/src/Application/Services):

- **Sửa:** `SeasonService.cs`, `ChoreService.cs`, `ChoreGenerationService.cs`, `ChoreAllocationService.cs`, `SeasonEndService.cs`.
- **Tạo:** `RecurrenceCalculator.cs`, `AllocationPlanner.cs`, `AllocationEligibilityService.cs`, `WorkloadCalculator.cs`.
- Các calculator/planner không ghi DB; service điều phối một transaction.

Trong Application DTO/validation/mapping:

- Sửa nhóm `Chore`, `Season`, workload summary và availability.
- Thêm `SubmitSeasonReviewRequest`, `RejectSeasonRequest`, `AvailabilitySlotRequest`.
- Summary giữ field phút cũ và bổ sung `TotalAssignedKarma`, unassigned count, fairness warnings.

Trong [Infrastructure Repositories](D:/FPT/Semester_8/PRM393/project/chore-wars/backend/src/Infrastructure/Repositories):

- Sửa `ChoreRepository.cs`, `ChoreOccurrenceRepository.cs`, `ChoreSeasonRepository.cs`.
- Sửa availability và confirmation repositories.
- Truy vấn/xóa occurrence bằng `occurrence.SeasonId`.
- Bổ sung query mùa cần kết thúc, không sử dụng query active chung rồi lọc thiếu điều kiện.

Trong [Presentation Controllers](D:/FPT/Semester_8/PRM393/project/chore-wars/backend/src/Presentation/Controllers):

- Sửa `SeasonController.cs`, `ChoreController.cs`.
- Thêm `submit-review`; giữ `generate-schedule` để chuẩn bị lịch draft.
- Endpoint start cũ chỉ được hoàn tất cùng policy confirmation, không có bypass.

### 5.3. Manual và auto

- Manual: generate occurrence chưa gán, user phân chia; availability chỉ cảnh báo.
- Auto: không giao người inactive, bận hoặc vượt capacity.
- Không có ứng viên thì giữ unassigned và báo lý do; chưa được submit review nếu còn mandatory unassigned.
- Fairness dùng tổng snapshot Karma, tính cả assignment đã có.
- Preference/rotation là tiêu chí phụ; phút dùng cho sức tải.
- BONUS không tham gia phân công mandatory.
- Tie-break ổn định bằng workload, lịch sử rồi user ID; không random không giải thích được.

### 5.4. Lịch theo giờ và frequency

Availability lưu một hoặc nhiều khoảng không giao nhau trong ngày. Khoảng qua nửa đêm được chia hai ngày. Automatic phải tìm được khoảng đủ thời lượng trước deadline.

Giữ constraint tài liệu cũ về form: không bắt người dùng nhập duration thường ngày. Backend mặc định theo difficulty: EASY 15, MEDIUM 30, HARD 45 phút. Duration không thay tiêu chí fairness Karma.

Quy tắc recurrence:

| Loại | Quy tắc |
|---|---|
| DAILY | Mỗi ngày trong khoảng mùa |
| EVERY_X_DAYS | Cách X ngày từ anchor |
| WEEKLY | Thứ của anchor hoặc các thứ đã chọn |
| X_TIMES_PER_WEEK | X thứ khác nhau được chọn, số ngày phải khớp X |
| SPECIFIC_DAYS | Các thứ được chọn |
| MONTHLY | Ngày theo anchor, tháng ngắn dùng ngày cuối tháng |
| EVERY_X_MONTHS | Cách X tháng từ anchor; áp dụng quy tắc tháng ngắn |
| YEARLY | Theo tháng/ngày anchor; 29/2 sang năm không nhuận dùng 28/2 |
| CUSTOM | Danh sách ngày cụ thể do user chọn; không tự chạy code/biểu thức tùy ý |

Khoảng mùa dùng ngày địa phương, bao gồm cả ngày đầu và cuối. Deadline được đổi sang UTC đúng timezone.

### 5.5. File Flutter

Trong [House Screens](D:/FPT/Semester_8/PRM393/project/chore-wars/mobile/lib/features/house/presentation/screens):

- Sửa `create_season_screen.dart`, `availability_screen.dart`, `review_schedule_screen.dart`, `member_settings_screen.dart`, `house_detail_screen.dart`.
- Review hiển thị tổng Karma, unassigned, status từng required member và reject reason.

Trong [Chore Feature](D:/FPT/Semester_8/PRM393/project/chore-wars/mobile/lib/features/chore):

- Sửa form create/edit, DTO/entity/repository/datasource/provider.
- Thêm lựa chọn deadline, anchor và custom dates.
- Tách thao tác generate draft và submit review.

---

## 6. Nhóm 7–8 — Quyền, membership, completion và bounty

### 6.1. Phân quyền và membership

Sử dụng `HouseAccessService` cho REST và Hub. Không chỉ kiểm JWT hoặc sự tồn tại của membership; phải kiểm active và quan hệ entity–house.

- Join tối đa 6 người, kiểm trong transaction.
- Rejoin kích hoạt lại membership LEFT; BANNED không tự rejoin bằng invite.
- Tạo nhà một người vẫn hợp lệ; submit review cần tối thiểu 3 active members.
- Owner muốn rời phải transfer ownership.
- Chặn leave/kick khi người đó còn mandatory responsibility hoặc nghĩa vụ tài chính chưa xử lý.
- Disband là archive, không cascade xóa history; chỉ khi không còn nghĩa vụ mở.
- Invite QR bổ sung preview và confirm trước join; không join ngay khi camera phát hiện.
- Khi leave/kick, ngắt các kết nối SignalR tương ứng để không nghe tiếp room.

### File cần sửa/tạo

Trong Application:

- Sửa `HouseService.cs`, `ChatService.cs`, `AuthService.cs`, các service đang thiếu user/house context.
- Sửa house/chore/bounty interfaces và DTO.
- Thêm invite preview/rotate và archive use case.

Trong Domain/Infrastructure:

- Sửa `House.cs` thêm archived state và invite version.
- Sửa house/member repositories, FK delete behavior và unique constraints.
- Tạo abstraction tracking/disconnect realtime connection; triển khai trong Presentation/Infrastructure phù hợp.

Trong Presentation:

- Sửa `HouseController.cs`, `ChoreController.cs`, `SeasonController.cs`, `BountyController.cs`, `ChatHub.cs`, `NotificationHub.cs`.
- Bổ sung kiểm tra entity nằm đúng house của route.

Flutter sửa QR join, member management, house settings, logout và provider invalidation để không giữ dữ liệu user/house cũ.

### 6.2. Responsibility episode

Thêm `ChoreResponsibility.cs` trong Domain và repository/configuration tương ứng.

Một episode lưu:

- Occurrence, assignee, assignment reason.
- Thời điểm nhận, deadline trách nhiệm, kết thúc.
- Penalty đã áp dụng, completion actor.
- Quan hệ với bounty/forced/pass nếu có.

Chỉ một episode đang mở cho một occurrence.

Penalty dùng từng episode: tối đa 3 mốc ×5 Karma. Counter cũ chỉ là cache/compatibility; không dùng lại penalty người trước cho người mới.

Forced reassignment có deadline trách nhiệm mới sau 24 giờ. Compensation tạo một lần theo occurrence và chỉ đủ điều kiện chi trả khi người forced hoàn thành hợp lệ.

Nếu forced member tiếp tục fail:

- Áp penalty riêng tối đa −15.
- Không tạo compensation tự động lần hai.
- Đưa việc vào danh sách cần household xử lý.
- Member khác có thể tự nhận trách nhiệm không kèm compensation mới; ghi audit. Khi thay người forced chưa hoàn thành, hủy quyền nhận compensation chưa được hưởng, không xóa lịch sử.

### 6.3. File cần sửa/tạo

Trong [Application Services](D:/FPT/Semester_8/PRM393/project/chore-wars/backend/src/Application/Services):

- Sửa `ChoreService.cs`, `KarmaService.cs`, `OverduePenaltyService.cs`.
- Sửa `BountyService.cs`, `BountyExpirationService.cs`.
- Tạo `ChoreResponsibilityService.cs`.
- Tạo `HouseholdResolutionService.cs` cho nhận việc cần xử lý; không tạo thẻ swap/urgent.

Repository/configuration cần sửa:

- Occurrence, bounty, Karma transaction và obligation.
- Unique active bounty/occurrence.
- Unique completion credit/occurrence.
- Unique penalty/episode/mốc.
- Unique forced compensation/occurrence.
- Unique active responsibility/occurrence.

### 6.4. Completion và season end

Complete khóa/read lại trạng thái trong transaction; ghi completion, ledger và obligation cùng một transaction.

Sau khi mùa đóng:

- Không cộng/phạt thêm Karma của mùa đó.
- Vẫn ghi completion/outcome, xử lý bounty và obligation còn hợp lệ.
- Ranking/reward đã snapshot không tính lại.
- Worker end-season chốt các penalty đến cutoff trước khi đóng mùa.
- Manual end trước ngày dự kiến bị chặn; không có đường kết thúc sớm để tránh penalty hoặc thay ranking.

Bounty expiry, accept và complete cạnh tranh phải có đúng một kết quả hợp lệ. Người accept phải active cùng nhà, không tự nhận bounty mình đăng và chưa quá expiry.

---

## 7. Nhóm 9 — Rewards, leaderboard và achievements

### Hành vi

- Rank tính từ ledger của season, không dùng `HouseMember.KarmaBalance` tổng của nhiều mùa.
- Tie-break: tổng Karma → số mandatory completed → tổng bonus Karma → joined time → user ID.
- Chỉ một hạng nhất nhận Chore Pass theo tie-break cố định.
- Rank/reward snapshot một lần khi hết mùa.
- Balance dùng để redeem là tổng ledger household; không reset trực tiếp về 0 sau mỗi season.
- Debit khi redeem gắn season đang mở nếu có; khi không có season mở thì ghi house-level ledger. Không thêm debit vào season đã khóa.
- Custom reward có cost >0, member active được tạo theo BR.
- Redeem khóa balance để không tiêu vượt số dư khi hai request đồng thời.
- Chore Pass chỉ dùng cho việc chưa quá hạn của chính user.
- Người thay hợp lệ nhận normal completion Karma; assignment reason `CHORE_PASS`, không dùng cờ forced-bounty để vô tình cho +0.
- Không có người thay: giữ pass và assignment.
- Share card dùng dữ liệu server, không tự cho user sửa con số thành tích.

### File cần sửa/tạo

Trong Domain:

- Sửa `Reward.cs`: cost, enabled state.
- Sửa `RewardRedemption.cs`: loại redemption, cost snapshot và thời điểm.
- Sửa `KarmaTransaction.cs` cho house-level ledger khi không có season.
- Giữ rank reward và custom redemption phân biệt.

Trong Application:

- Sửa `GamificationService.cs`, `SeasonEndService.cs`, `AchievementCheckService.cs`.
- Tạo `RewardService.cs`, DTO/validator tạo/sửa/redeem reward.
- Sửa mapping và repository interfaces.

Trong Infrastructure/Presentation:

- Sửa reward, redemption, ranking, user achievement configurations/repositories.
- Tạo `RewardController.cs`.
- Sửa `GamificationController.cs`.
- Unique constraint chống trao achievement/rank reward lặp.

Trong [Gamification Feature](D:/FPT/Semester_8/PRM393/project/chore-wars/mobile/lib/features/gamification):

- Sửa reward/pass/leaderboard/achievement screens và data layer.
- Tạo `reward_catalog_screen.dart`, `reward_form_screen.dart`, `achievement_share_card.dart`.
- Share PNG bằng `RepaintBoundary` và [share_plus](https://pub.dev/packages/share_plus); không xây social feed.

---

## 8. Nhóm 10 — Release, route, 12 màn và tài liệu

### Flutter core cần sửa

Trong [Flutter Core](D:/FPT/Semester_8/PRM393/project/chore-wars/mobile/lib/core):

- `router/app_router.dart`: bỏ route khai báo trùng, thêm reward routes và giữ payment tracking route.
- `network/api_endpoints.dart`: bổ sung endpoint thống nhất.
- `network/interceptors/auth_interceptor.dart`: refresh single-flight, retry có giới hạn, không retry vô hạn mutation.
- `constants/app_constants.dart`: release bắt buộc cấu hình API/SignalR hợp lệ.
- Reuse theme, empty/error/loading widgets; không thêm một design system thứ hai.

Giữ một màn làm nguồn chính cho các chức năng trùng giữa `chore/chores`, profile và leaderboard. Route cũ chuyển tới màn chính; chỉ xóa implementation trùng sau khi kiểm tra không còn import/reference.

### Build và hạ tầng

Sửa:

- `pubspec.yaml`, `pubspec.lock`.
- Android main manifest và cấu hình build cần thiết.
- iOS `Info.plist` cho camera/mic nếu build iOS.
- Backend Dockerfile, `docker-compose.yml`, `.env.example`.
- Health live/ready; readiness kiểm dependency cốt lõi, không tạo giao dịch hoặc thay đổi dữ liệu.
- Persistent volume cho media; không lưu upload quan trọng trong filesystem tạm.
- Reverse proxy/HTTPS và forwarded headers để URL media đúng.

### Tài liệu cần cập nhật khi triển khai

Trong [Docs](D:/FPT/Semester_8/PRM393/project/chore-wars/docs):

- `architecture/backend-architecture.md`: transaction, outbox, payment tracking/private media.
- `architecture/mobile-architecture.md`: payment tracking/audio modules.
- `architecture/system-architecture.md`: payment tracking và private media storage.
- `database/database-design.md`: entity thực tế, FK, index và ledger.
- `api/api-specification.md`: endpoint/DTO/error thực tế.
- `deployment/deployment-guide.md`: sửa tên env khớp source, secret server, media volume và migrations.
- Các kế hoạch cũ ghi rõ phần đã được thay thế; không để hai policy payment cùng có hiệu lực.

Tạo tài liệu mới:

- `business-decisions.vi.md`: các quyết định đã chốt trong kế hoạch này.
- `screen-ownership-and-demo.vi.md`: 4 người ×3 giao diện, route và evidence.
- `release-acceptance-report.vi.md`: kết quả thật sau kiểm thử.

Không ghi tên người sở hữu màn hình khi nhóm chưa xác nhận đóng góp.

---

## 9. Migration và tương thích dữ liệu

Không sửa hoặc xóa các migration đã tồn tại. Tạo các migration bổ sung theo thứ tự:

| Migration dự kiến | Nội dung |
|---|---|
| `AddConcurrencyOutboxAndAudit` | Outbox, processed events, version, index |
| `AddSeasonSnapshotsAndScheduleTime` | Source template, schedule revision, deadline, availability slots, custom dates |
| `AddChoreResponsibilitiesAndFinancialEligibility` | Episode, completion actor, eligibility và audit |
| `AddPrivateChatMedia` | Attachment, message type/client ID |
| `AddCustomRewardCostAndLedgerScope` | Reward cost, redemption và house-level ledger |

Mỗi migration kèm script kiểm tra/backfill:

- Giữ nguyên occurrence ID và transaction reference lịch sử.
- Legacy occurrence thiếu snapshot không được tự lấy Karma hiện tại để viết lại lịch sử.
- Availability true cũ chuyển thành khoảng cả ngày; false thành không có khoảng, vẫn đánh dấu đã khai báo.
- Không có availability record là chưa khai báo, không tự hiểu rảnh cả tuần.
- Deadline cũ 23:59 được giữ; giá trị mới không tự áp ngược lên mùa locked.
- Trách nhiệm lịch sử không đủ dữ liệu gắn nguồn legacy, không bịa các lần reassignment.
- Chore/template không phân loại được theo season phải xuất danh sách cần xử lý; không tự chọn tất cả chore trong nhà.
- Trước khi thêm unique index, báo cáo duplicate để sửa có kiểm soát; không xóa ledger/payment trùng một cách tự động.
- Không hard-delete house, completed chore, ledger, obligation hoặc audit.

---

## 10. Thứ tự triển khai, kiểm thử và điều kiện hoàn thành

### Thứ tự bắt buộc

1. Sửa blocker sau pull, đồng bộ proposal contract/lifecycle và test generation.
2. Decision log, authorization/house scope, clock, transaction/lock và outbox.
3. Season snapshot, generation, all-member confirmation, cutoff cuối mùa.
4. Allocation, availability theo giờ và đủ 9 frequency.
5. Responsibility, completion/penalty/bounty, one-compensation và payment tracking.
6. Private media, microphone và loa.
7. Reward, pass, ranking/achievement/share.
8. Router/auth refresh, cấu hình release, 12 màn và regression.

Mỗi bước có PR nhỏ kèm contract/migration/test liên quan. Không tính một mốc là xong chỉ vì BE build; phải có FE flow và test phù hợp. Không apply migration lên database thật trong khi soạn/duyệt plan.

### Test cần sửa/tạo

- UnitTests/Services: sửa ChoreGenerationServiceTests.cs, PaymentObligationTests.cs, BountyCompensationTests.cs, ActionProposalServiceTests.cs, ChatHubProposalTests.cs. Thêm SeasonLifecycleTests.cs, RecurrenceCalculatorTests.cs, AllocationPlannerTests.cs, ResponsibilityPenaltyTests.cs, RewardEligibilityTests.cs, PaymentConfirmationTests.cs.
- IntegrationTests: thêm Infrastructure/PostgresFixture.cs, Infrastructure/ApiFactory.cs; Payments/PaymentConfirmationConcurrencyTests.cs; Chores/CompletionBountyConcurrencyTests.cs; Seasons/SeasonConfirmationConcurrencyTests.cs, SeasonEndRankingTests.cs; Chat/ChatAuthorizationAndMediaTests.cs; Infrastructure/MigrationBackfillTests.cs; Messaging/OutboxRecoveryTests.cs. Sửa controller proposal tests cho policy/route thực tế. Dùng PostgreSQL thật trong môi trường test cô lập để kiểm lock/unique, không dùng mock hoặc EF in-memory làm bằng chứng concurrency.
- Flutter: model/repository, all-confirm review, availability/frequency form, creditor-only button, recorder/player lifecycle, reward/pass, router và refresh concurrent401.
- mobile/integration_test: login → house → season → đủ confirmations → complete → reward; bounty → completion → obligation → creditor confirm; forced120% → completion eligibility → confirm, không compensation vòng2; camera proof/invite; máy A ghi audio → máy B phát.
- Acceptance matrix dùng [test plan BE/FE](non-ai-full-system-test-plan.vi.md), áp dụng override ở bản này: bỏ ca provider/QR tiền/thủ quỹ trong đợt hiện tại, giữ chúng ở danh sách chờ. Kết quả thật lưu release-acceptance-report.vi.md; không điền PASS trước khi chạy.

### Ca tiền bắt buộc hiện tại

Creditor xác nhận; debtor/người lạ bị từ chối; cross-house bị từ chối; chưa đủ điều kiện không PAID; complete retry không sinh obligation thứ hai; confirmation retry không ghi lần hai; compensation120% dùng snapshot; không có vòng compensation thứ hai; đóng mùa không xóa nợ hoặc đổi creditor/amount. Xác nhận thủ công không được hiển thị là provider verified.

### Điều kiện hoàn thành cả 10 nhóm

- Có implementation BE/FE, migration, API và test cho từng nhóm.
- Không còn lỗi sai quyền, double Karma, double obligation, xác nhận nhận tiền sai quyền hoặc đóng nợ sớm.
- Ranking mùa đã đóng bất biến; các việc/nợ còn tồn được xử lý đúng policy.
- APK release dùng backend thật, có Camera + Micro + Loa hoạt động trên điện thoại.
- Có tối thiểu 12 giao diện hoạt động và phân công thật cho 4 người.
- Có build/commit/migration version, test report, video demo và rollback runbook.
- Phạm vi code của 10 nhóm có thể hoàn thành theo bản này; tiêu chí môn về dịch vụ thanh toán vẫn CHỜ, chỉ đóng khi có phương án giảng viên chấp nhận. Không tự tuyên bố đạt toàn bộ môn.


## 11. Manifest file cụ thể để giao việc

Đường dẫn tính từ root repository. Các mục **Sửa** dưới đây đã kiểm tra tồn tại tại HEAD đối chiếu. Các bảng trước mô tả hành vi; manifest bổ sung đường dẫn chính xác để tránh nhầm thư mục. Một file dùng nhiều nhóm chỉ sửa theo một contract chung. Không có danh sách tĩnh nào thay thế kiểm tra impact từ compiler: khi DTO/entity đổi, phải tìm mọi caller, mapping, validator, mock và test liên quan trước merge.

### P0 — Tích hợp proposal/chat sau pull — Sửa

- `backend/src/Application/Services/ActionProposalService.cs`
- `backend/src/Application/Interfaces/Services/IActionProposalService.cs`
- `backend/src/Application/DTOs/Proposal/ActionProposalDTOs.cs`
- `backend/src/Infrastructure/Repositories/ActionProposalRepository.cs`
- `backend/src/Presentation/Controllers/ActionProposalController.cs`
- `backend/src/Presentation/Hubs/ActionProposalRealtimePublisher.cs`
- `mobile/lib/features/chat/presentation/screens/chat_room_screen.dart`
- `mobile/lib/features/chat/providers/chat_providers.dart`
- `mobile/lib/features/chat/data/repositories/chat_repository.dart`
- `mobile/lib/features/chat/data/services/chat_signalr_service.dart`
- `mobile/lib/features/chat/data/services/chat_api_service.dart`

### Dùng chung/season/lịch/phân công — Sửa

- `backend/src/Application/Interfaces/Repositories/IUnitOfWork.cs`
- `backend/src/Infrastructure/Repositories/UnitOfWork.cs`
- `backend/src/Infrastructure/Data/AppDbContext.cs`
- `backend/src/Presentation/Extensions/ApplicationServiceExtensions.cs`
- `backend/src/Presentation/Extensions/InfrastructureServiceExtensions.cs`
- `backend/src/Presentation/Extensions/PresentationServiceExtensions.cs`
- `backend/src/Application/Services/SeasonService.cs`
- `backend/src/Application/Services/ChoreService.cs`
- `backend/src/Application/Services/ChoreGenerationService.cs`
- `backend/src/Application/Services/ChoreAllocationService.cs`
- `backend/src/Application/Services/SeasonEndService.cs`
- `backend/src/Application/Interfaces/Services/ISeasonService.cs`
- `backend/src/Application/Interfaces/Services/IChoreService.cs`
- `backend/src/Application/Interfaces/Services/IChoreGenerationService.cs`
- `backend/src/Application/Interfaces/Services/IChoreAllocationService.cs`
- `backend/src/Application/Interfaces/Services/ISeasonEndService.cs`
- `backend/src/Domain/Entities/Chore.cs`
- `backend/src/Domain/Entities/ChoreSeason.cs`
- `backend/src/Domain/Entities/SeasonConfirmation.cs`
- `backend/src/Domain/Entities/ChoreOccurrence.cs`
- `backend/src/Domain/Entities/MemberAvailability.cs`
- `backend/src/Application/Interfaces/Repositories/IChoreRepository.cs`
- `backend/src/Infrastructure/Repositories/ChoreRepository.cs`
- `backend/src/Infrastructure/Data/Configurations/ChoreConfiguration.cs`
- `backend/src/Application/Interfaces/Repositories/IChoreOccurrenceRepository.cs`
- `backend/src/Infrastructure/Repositories/ChoreOccurrenceRepository.cs`
- `backend/src/Infrastructure/Data/Configurations/ChoreOccurrenceConfiguration.cs`
- `backend/src/Application/Interfaces/Repositories/IChoreSeasonRepository.cs`
- `backend/src/Infrastructure/Repositories/ChoreSeasonRepository.cs`
- `backend/src/Infrastructure/Data/Configurations/ChoreSeasonConfiguration.cs`
- `backend/src/Application/Interfaces/Repositories/ISeasonConfirmationRepository.cs`
- `backend/src/Infrastructure/Repositories/SeasonConfirmationRepository.cs`
- `backend/src/Infrastructure/Data/Configurations/SeasonConfirmationConfiguration.cs`
- `backend/src/Application/Interfaces/Repositories/IMemberAvailabilityRepository.cs`
- `backend/src/Infrastructure/Repositories/MemberAvailabilityRepository.cs`
- `backend/src/Infrastructure/Data/Configurations/MemberAvailabilityConfiguration.cs`
- `backend/src/Infrastructure/Workers/ChoreAllocationWorker.cs`
- `backend/src/Infrastructure/Workers/SeasonEndWorker.cs`
- `backend/src/Presentation/Controllers/SeasonController.cs`
- `backend/src/Presentation/Controllers/ChoreController.cs`
- `mobile/lib/features/house/data/datasources/season_remote_data_source.dart`
- `mobile/lib/features/house/domain/entities/house_models.dart`
- `mobile/lib/features/house/domain/repositories/house_repository.dart`
- `mobile/lib/features/house/data/repositories/house_repository_impl.dart`
- `mobile/lib/features/house/presentation/providers/house_providers.dart`
- `mobile/lib/features/house/presentation/screens/create_season_screen.dart`
- `mobile/lib/features/house/presentation/screens/availability_screen.dart`
- `mobile/lib/features/house/presentation/screens/review_schedule_screen.dart`
- `mobile/lib/features/house/presentation/screens/member_settings_screen.dart`
- `mobile/lib/features/house/presentation/screens/house_detail_screen.dart`
- `mobile/lib/features/chore/domain/entities/chore_models.dart`
- `mobile/lib/features/chore/domain/repositories/chore_repository.dart`
- `mobile/lib/features/chore/data/datasources/chore_remote_data_source.dart`
- `mobile/lib/features/chore/data/repositories/chore_repository_impl.dart`
- `mobile/lib/features/chore/presentation/providers/chore_providers.dart`
- `mobile/lib/features/chore/presentation/screens/chore_form_screen.dart`

### Quyền/trách nhiệm/bounty/Karma/reward — Sửa

- `backend/src/Application/Services/HouseService.cs`
- `backend/src/Application/Services/ChatService.cs`
- `backend/src/Application/Services/AuthService.cs`
- `backend/src/Application/Services/BountyService.cs`
- `backend/src/Application/Services/BountyExpirationService.cs`
- `backend/src/Application/Services/OverduePenaltyService.cs`
- `backend/src/Application/Services/KarmaService.cs`
- `backend/src/Application/Services/GamificationService.cs`
- `backend/src/Application/Services/AchievementCheckService.cs`
- `backend/src/Domain/Entities/House.cs`
- `backend/src/Infrastructure/Repositories/HouseRepository.cs`
- `backend/src/Infrastructure/Data/Configurations/HouseConfiguration.cs`
- `backend/src/Domain/Entities/HouseMember.cs`
- `backend/src/Infrastructure/Repositories/HouseMemberRepository.cs`
- `backend/src/Infrastructure/Data/Configurations/HouseMemberConfiguration.cs`
- `backend/src/Domain/Entities/PaymentObligation.cs`
- `backend/src/Infrastructure/Repositories/PaymentObligationRepository.cs`
- `backend/src/Infrastructure/Data/Configurations/PaymentObligationConfiguration.cs`
- `backend/src/Domain/Entities/Reward.cs`
- `backend/src/Infrastructure/Repositories/RewardRepository.cs`
- `backend/src/Infrastructure/Data/Configurations/RewardConfiguration.cs`
- `backend/src/Domain/Entities/RewardRedemption.cs`
- `backend/src/Infrastructure/Repositories/RewardRedemptionRepository.cs`
- `backend/src/Infrastructure/Data/Configurations/RewardRedemptionConfiguration.cs`
- `backend/src/Domain/Entities/KarmaTransaction.cs`
- `backend/src/Infrastructure/Repositories/KarmaTransactionRepository.cs`
- `backend/src/Infrastructure/Data/Configurations/KarmaTransactionConfiguration.cs`
- `backend/src/Infrastructure/Repositories/SeasonRankingRepository.cs`
- `backend/src/Infrastructure/Repositories/UserAchievementRepository.cs`
- `backend/src/Presentation/Controllers/HouseController.cs`
- `backend/src/Presentation/Controllers/BountyController.cs`
- `backend/src/Presentation/Controllers/GamificationController.cs`
- `backend/src/Presentation/Hubs/ChatHub.cs`
- `backend/src/Presentation/Hubs/NotificationHub.cs`
- `mobile/lib/features/house/presentation/screens/qr_join_screen.dart`
- `mobile/lib/features/house/presentation/screens/qr_invite_screen.dart`
- `mobile/lib/features/house/presentation/screens/member_management_screen.dart`
- `mobile/lib/features/house/presentation/screens/house_settings_screen.dart`
- `mobile/lib/features/house/data/datasources/house_remote_data_source.dart`
- `mobile/lib/features/auth/presentation/providers/auth_providers.dart`
- `mobile/lib/features/gamification/presentation/screens/season_reward_screen.dart`
- `mobile/lib/features/gamification/presentation/screens/chore_pass_screen.dart`
- `mobile/lib/features/gamification/presentation/screens/leaderboard_screen.dart`
- `mobile/lib/features/gamification/presentation/screens/achievements_screen.dart`
- `mobile/lib/features/gamification/domain/entities/gamification_models.dart`
- `mobile/lib/features/gamification/domain/repositories/gamification_repository.dart`
- `mobile/lib/features/gamification/data/repositories/gamification_repository_impl.dart`
- `mobile/lib/features/gamification/data/datasources/gamification_remote_data_source.dart`
- `mobile/lib/features/gamification/presentation/providers/gamification_providers.dart`

### Media/outbox/release — Sửa

- `backend/src/Domain/Entities/ChatMessage.cs`
- `backend/src/Application/Services/ChatService.cs`
- `backend/src/Application/Interfaces/Services/IChatService.cs`
- `backend/src/Application/DTOs/Chat/SendMessageRequest.cs`
- `backend/src/Application/DTOs/Chat/ChatMessageResponse.cs`
- `backend/src/Infrastructure/Repositories/ChatRepository.cs`
- `backend/src/Infrastructure/Data/Configurations/ChatMessageConfiguration.cs`
- `backend/src/Presentation/Controllers/ChatController.cs`
- `backend/src/Infrastructure/Messaging/Kafka/KafkaEventPublisher.cs`
- `backend/src/Infrastructure/Messaging/Kafka/Consumers/KafkaConsumerBase.cs`
- `mobile/lib/features/chat/data/models/chat_message_model.dart`
- `mobile/lib/features/chat/presentation/widgets/message_input.dart`
- `mobile/lib/features/chat/presentation/widgets/message_bubble.dart`
- `mobile/lib/core/router/app_router.dart`
- `mobile/lib/core/network/api_endpoints.dart`
- `mobile/lib/core/network/interceptors/auth_interceptor.dart`
- `mobile/lib/core/constants/app_constants.dart`
- `mobile/pubspec.yaml`
- `mobile/pubspec.lock`
- `mobile/android/app/src/main/AndroidManifest.xml`
- `mobile/ios/Runner/Info.plist`
- `backend/src/Infrastructure/Infrastructure.csproj`
- `backend/src/Presentation/Program.cs`
- `backend/Dockerfile`
- `docker-compose.yml`
- `.env.example`

### File dự kiến tạo thêm

Tên mới là contract đề xuất để implement; nếu implementation tìm được abstraction tương đương đã có thì mở rộng nó và cập nhật manifest thay vì tạo trùng. Ba file proposal còn thiếu phải tích hợp luồng thật; capability ngoài scope phải hiển thị disabled rõ.

- `backend/src/Application/Interfaces/Services/IHouseAccessService.cs`
- `backend/src/Application/Services/HouseAccessService.cs`
- `backend/src/Application/Interfaces/Services/IHouseMutationLock.cs`
- `backend/src/Infrastructure/Concurrency/PostgresHouseMutationLock.cs`
- `backend/src/Application/Interfaces/IOutboxWriter.cs`
- `backend/src/Application/Events/EventEnvelope.cs`
- `backend/src/Domain/Entities/OutboxMessage.cs`
- `backend/src/Domain/Entities/ProcessedMessage.cs`
- `backend/src/Infrastructure/Messaging/OutboxWriter.cs`
- `backend/src/Infrastructure/Workers/OutboxDispatcherWorker.cs`
- `backend/src/Domain/Entities/MemberAvailabilitySlot.cs`
- `backend/src/Domain/Entities/ChoreCustomDate.cs`
- `backend/src/Domain/Entities/ChoreResponsibility.cs`
- `backend/src/Application/Services/RecurrenceCalculator.cs`
- `backend/src/Application/Services/AllocationPlanner.cs`
- `backend/src/Application/Services/AllocationEligibilityService.cs`
- `backend/src/Application/Services/WorkloadCalculator.cs`
- `backend/src/Application/Services/ChoreResponsibilityService.cs`
- `backend/src/Application/Services/HouseholdResolutionService.cs`
- `backend/src/Application/Services/RewardService.cs`
- `backend/src/Application/Services/MediaService.cs`
- `backend/src/Application/Interfaces/Services/IMediaStorage.cs`
- `backend/src/Application/Interfaces/Services/IMediaService.cs`
- `backend/src/Application/Interfaces/Services/IRewardService.cs`
- `backend/src/Domain/Entities/MediaAttachment.cs`
- `backend/src/Domain/Enums/ChatMessageType.cs`
- `backend/src/Domain/Enums/MediaAttachmentType.cs`
- `backend/src/Infrastructure/Storage/FileMediaStorage.cs`
- `backend/src/Infrastructure/Workers/MediaCleanupWorker.cs`
- `backend/src/Presentation/Controllers/MediaController.cs`
- `backend/src/Presentation/Controllers/RewardController.cs`
- `backend/src/Application/Interfaces/Repositories/IMemberAvailabilitySlotRepository.cs`
- `backend/src/Infrastructure/Repositories/MemberAvailabilitySlotRepository.cs`
- `backend/src/Infrastructure/Data/Configurations/MemberAvailabilitySlotConfiguration.cs`
- `backend/src/Application/Interfaces/Repositories/IChoreCustomDateRepository.cs`
- `backend/src/Infrastructure/Repositories/ChoreCustomDateRepository.cs`
- `backend/src/Infrastructure/Data/Configurations/ChoreCustomDateConfiguration.cs`
- `backend/src/Application/Interfaces/Repositories/IChoreResponsibilityRepository.cs`
- `backend/src/Infrastructure/Repositories/ChoreResponsibilityRepository.cs`
- `backend/src/Infrastructure/Data/Configurations/ChoreResponsibilityConfiguration.cs`
- `backend/src/Application/Interfaces/Repositories/IMediaAttachmentRepository.cs`
- `backend/src/Infrastructure/Repositories/MediaAttachmentRepository.cs`
- `backend/src/Infrastructure/Data/Configurations/MediaAttachmentConfiguration.cs`
- `backend/src/Infrastructure/Data/Configurations/OutboxMessageConfiguration.cs`
- `backend/src/Infrastructure/Data/Configurations/ProcessedMessageConfiguration.cs`
- `backend/src/Application/DTOs/Season/SubmitSeasonReviewRequest.cs`
- `backend/src/Application/DTOs/Season/RejectSeasonRequest.cs`
- `backend/src/Application/DTOs/Season/AvailabilitySlotRequest.cs`
- `backend/src/Application/DTOs/Media/UploadMediaRequest.cs`
- `backend/src/Application/DTOs/Media/MediaAttachmentResponse.cs`
- `backend/src/Application/DTOs/Gamification/CreateRewardRequest.cs`
- `backend/src/Application/DTOs/Gamification/RedeemRewardRequest.cs`
- `backend/src/Application/Validations/Gamification/CreateRewardRequestValidator.cs`
- `backend/src/Application/Validations/Season/AvailabilitySlotRequestValidator.cs`
- `backend/src/Application/Mappings/MediaProfile.cs`
- `mobile/lib/features/chat/data/models/action_proposal_model.dart`
- `mobile/lib/features/chat/providers/action_proposal_providers.dart`
- `mobile/lib/features/chat/presentation/widgets/interactive_action_card.dart`
- `mobile/lib/features/chat/data/services/voice_recorder_service.dart`
- `mobile/lib/features/chat/data/services/audio_playback_service.dart`
- `mobile/lib/features/chat/providers/voice_note_provider.dart`
- `mobile/lib/features/chat/presentation/widgets/voice_note_recorder.dart`
- `mobile/lib/features/chat/presentation/widgets/audio_message_bubble.dart`
- `mobile/lib/features/gamification/presentation/screens/reward_catalog_screen.dart`
- `mobile/lib/features/gamification/presentation/screens/reward_form_screen.dart`
- `mobile/lib/features/gamification/presentation/widgets/achievement_share_card.dart`
- `docs/plans/business-decisions.vi.md`
- `docs/plans/screen-ownership-and-demo.vi.md`
- `docs/plans/release-acceptance-report.vi.md`

### File phụ thuộc cần cập nhật đồng bộ

- DTO/validator/mapping hiện hữu: `backend/src/Application/DTOs/Chore/{CreateChoreRequest,UpdateChoreRequest,ChoreResponse,ChoreOccurrenceResponse}.cs`; `DTOs/Season/{MemberAvailabilityRequest,SeasonResponse,WorkloadSummaryResponse}.cs`; `DTOs/Bounty/PaymentObligationResponse.cs`; `Mappings/{ChoreProfile,SeasonProfile,BountyProfile,GamificationProfile}.cs`; `Validations/Chore/{CreateChoreRequestValidator,UpdateChoreRequestValidator}.cs`. Dấu ngoặc nhọn chỉ là cách liệt kê nhiều file, không phải tên file thật.
- Repo/service interfaces của mọi use case đổi chữ ký phải sửa cùng implementation; không để controller gọi contract cũ. Kafka consumers ở `backend/src/Infrastructure/Messaging/Kafka/Consumers` cập nhật envelope/dedup; các Events hiện hữu cập nhật hợp đồng có version khi cần.
- `backend/src/Infrastructure/Migrations/<timestamp>_<name>.cs`, file Designer tương ứng và `AppDbContextModelSnapshot.cs` do EF sinh cho từng migration trong mục9; thêm script kiểm tra/backfill riêng. Không tạo lại `20261015131034_AddActionProposals`.
- Freezed/JSON generated files tương ứng model thay đổi do build_runner sinh. Chỉ sửa nguồn model, kiểm diff generated; mock repositories cũng phải giữ đúng interface và không đưa vào release.
- Test project/package manifests cập nhật khi thêm HTTP host/Testcontainers. Package audio/share chỉ chốt version sau khi kiểm SDK và build; kế hoạch không khẳng định version mới nhất.

## 12. Giao việc cho 4 thành viên và chứng minh 12 giao diện

Bảng sau là **phân công đề xuất**, chưa phải xác nhận đóng góp cá nhân. Mỗi người phụ trách cả kết nối API, state/error và test cho ba màn được giao; các màn khác vẫn phải regression.

| Thành viên | Ba giao diện đề xuất | Phần triển khai chính |
|---|---|---|
| 1 | Login; Register; Profile/Edit profile (chỉ tính một giao diện ở đây) | Auth refresh, session, quyền và release config |
| 2 | Create season; Availability; Review schedule | Lifecycle, recurrence, allocation và confirmation |
| 3 | Chore detail; Bounty board; Payment obligations | Responsibility, bounty, penalty và creditor confirmation |
| 4 | Chat room; Reward catalog; Leaderboard | Media Micro/Loa, reward/pass, ranking/share |

Mỗi màn ghi route thật, người phụ trách đã xác nhận, commit/PR, ảnh/video và ca test. Không tính dialog, đổi tab hoặc hai bản duplicate cùng nghiệp vụ thành màn mới. Nếu giảng viên yêu cầu cách tính khác, cập nhật bảng theo xác nhận đó. Camera demo bằng chụp proof hoặc scan invite; Micro bằng ghi voice note; Loa bằng phát audio trên thiết bị thật. QR ngân hàng ngoài app không tính vào bằng chứng camera Chore Wars.

## 13. Gate nghiệm thu và điều còn thiếu

| Gate | Bằng chứng phải có | Trạng thái lúc viết plan |
|---|---|---|
| Compile sau pull | Analyzer hết error, BE build/test | Còn blocker theo audit trước |
| Core nghiệp vụ | All-confirm, không double write, đúng house/actor, không vượt hard constraints | Chờ implementation/test |
| Dữ liệu | Migration test trên DB mới và bản sao legacy, rollback/backup runbook | Chưa chứng minh |
| Ngoại vi | Camera + Micro + Loa trên APK thật, cả deny/revoke permission | Chưa nghiệm thu đủ3 |
| 12 giao diện/4 người | Bảng ownership được nhóm xác nhận và flow demo | Mới là đề xuất |
| Dịch vụ thanh toán | Phương án được thầy chấp nhận và bằng chứng tích hợp tương ứng | **Đang hoãn; chưa đạt chỉ bằng tracking** |
| AI | Kế hoạch Python riêng | Ngoài phạm vi tài liệu này |

Bản kế hoạch không tự chứng minh BE/FE hoàn chỉnh hoặc 10 nhóm đã hoàn thành. Khi code xong phải điền báo cáo chạy thật, bao gồm commit, môi trường, số test, lỗi còn tồn và người kiểm chứng. Không sửa code nghiệp vụ, package hay database chỉ để cập nhật tài liệu này.

## Tiến độ code hiện tại

Xem [báo cáo triển khai và kiểm thử 20/10/2026](../reports/non-ai-implementation-progress-2026-10-20.vi.md). Bản plan giữ nguyên tiêu chí đích; các bảng trạng thái dự kiến trong plan không phải kết quả test. APK/deploy và payOS đang hoãn theo yêu cầu người dùng.
