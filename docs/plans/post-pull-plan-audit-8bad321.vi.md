# Đối chiếu code sau pull với kế hoạch — HEAD 8bad321

Ngày kiểm tra: 18/10/2026, theo ngày người dùng. So sánh `3284e2c..8bad321`; không dùng timezone hiển thị trong log build để đổi ngày báo cáo.

## 1. Kết luận

- Pull là fast-forward từ `3284e2c` tới `8bad321`, thay đổi 34 file; phần mới chủ yếu là backend ActionProposal và UI chat gọi action card.
- Không có Git unmerged paths; không tìm thấy merge conflict marker trong vùng source/docs đã quét. `git diff --check 3284e2c..HEAD` đạt.
- Có lỗi tích hợp Flutter chặn compile, một unit test backend fail và nhiều khoảng cách nghiệp vụ còn nguyên so với plan.
- Backend build được trong lần kiểm tra sau restore; không đồng nghĩa PostgreSQL/Kafka/API end-to-end đã được nghiệm thu.
- Chỉ thêm báo cáo này; không sửa code nghiệp vụ, không apply migration, không kết nối ngân hàng/payOS.

## 2. Kiểm tra đã thực hiện

| Kiểm tra | Kết quả |
|---|---|
| Git status/unmerged/reflog/diff | Không có conflict Git. Trước khi thêm báo cáo, chỉ thấy các tài liệu kế hoạch local untracked |
| `flutter analyze --no-pub` | **21 issues: 17 errors, 1 warning, 3 info**; các error nằm trong màn chat mới |
| NuGet restore | Thành công; khôi phục dependency mới của project IntegrationTests |
| `dotnet test backend/ChoreWars.slnx --no-restore --nologo --verbosity minimal -m:1 -nodeReuse:false -p:UseSharedCompilation=false` sau restore | UnitTests: **14 pass, 1 fail**. IntegrationTests: **3 pass**. Tổng 18 test, 17 pass, 1 fail |
| PostgreSQL/Kafka/migration/live app/payOS | Chưa chạy trong phiên review |

Lần test trước restore gặp `Moq` không được tìm thấy do assets cũ; sau restore lỗi đó hết, không phải finding còn tồn tại của source. Sandbox từng chặn compiler pipe và Flutter SDK/cache; lệnh xác minh đã chạy lại ngoài sandbox.

Build còn cảnh báo `MSB3277` xung đột EF Core Relational 10.0.4/10.0.12 và `NU1903` cho AutoMapper 12.0.1. Đây là kết quả tool hiện tại, không phải lỗi mới được chứng minh do commit pull. Cần đồng bộ dependency graph và xử lý cảnh báo theo advisory trước release.

Các test trong project IntegrationTests hiện là controller gọi trực tiếp với mock, cộng test mẫu; chưa có database/HTTP host test thật. Vì vậy 3 pass không chứng minh SQL `FOR UPDATE`, transaction và migration chạy đúng với PostgreSQL.

## 3. Findings sau pull — ưu tiên trước khi implement tiếp

### F01 — P1: Flutter không compile vì màn mới thiếu dependencies và contract

`mobile/lib/features/chat/presentation/screens/chat_room_screen.dart:4,5,8` import ba file không tồn tại trong working tree hoặc Git:

- `features/chat/data/models/action_proposal_model.dart`.
- `features/chat/providers/action_proposal_providers.dart`.
- `features/chat/presentation/widgets/interactive_action_card.dart`.

Màn còn gọi `chatNotifier.receiveMessage` tại dòng 66, trong khi ChatMessagesNotifier không có method đó; truyền `onProposalReceived/onProposalUpdated` tại dòng 67/72 nhưng `ChatRepository.connectToHub` chỉ nhận hai positional arguments. `ChatSignalRService` hiện chỉ subscribe `MessageReceived`, chưa nhận `ReceiveProposal`/`ProposalUpdated` từ BE.

Analyzer xác nhận 17 error, nhiều lỗi còn lại là hậu quả của ba type/provider/widget bị thiếu. Đây là blocker của app sau pull, không chỉ tính năng proposal chưa hoàn thiện.

Hướng xử lý: lấy/bổ sung đủ commit frontend liên quan hoặc hoàn tất adapter/model/provider/widget tương ứng; thống nhất một chủ thể quản lý hub connection. Không tạo file placeholder rồi xem như đã tích hợp.

### F02 — P1: Check room mới vẫn cho member LEFT/BANNED vào chat

`ChatHub.JoinRoom` đã gọi `EnsureRoomAccessAsync`, là cải thiện thật. Tuy nhiên `ChatService.cs:129–135` chỉ từ chối khi `member == null`. `HouseMemberRepository.GetByHouseAndUserIdAsync` không lọc ACTIVE.

Điều kiện tái hiện: membership của user ở nhà vẫn còn nhưng status LEFT hoặc BANNED → check mới vẫn qua → được JoinRoom và các thao tác dùng cùng helper. Còn thiếu xử lý thu hồi kết nối đang ở group khi user bị kick/leave.

Hướng xử lý: check active trong helper dùng chung, áp dụng cả history/send/join/media; kiểm thử member inactive và revoke kết nối.

### F03 — P1: Proposal response không kiểm lại active membership trước thi hành

`ActionProposalService.CreateProposalAsync` kiểm active creator/targets lúc tạo, nhưng `RespondProposalAsync` tại dòng 99–124 chỉ kiểm proposal pending/expiry và target confirmation. Nếu target bị kick sau lúc tạo, người đó vẫn có thể xác nhận; creator hoặc participant khác cũng có thể đã mất quyền.

Hướng xử lý: revalidate các bên và context tại thời điểm apply; bị thay đổi thì invalidate/conflict, không execute payload cũ.

### F04 — P1: Urgent proposal có thể tạo việc cho mùa completed/draft

`ActionProposalService.cs:205–207` chỉ kiểm season tồn tại và đúng house. Nhánh execute tại dòng 241–269 không nạp/kiểm lại trạng thái season, membership hoặc eligibility; tạo NORMAL occurrence và SnapshotKarma theo payload.

Ngay từ lúc tạo có thể chọn season completed; hoặc season kết thúc trước khi target confirm nhưng vẫn tạo occurrence mới. Điều này xung đột rule khóa mùa và nguồn ledger/ranking. Payload hiện còn cho NORMAL có Karma=0.

Hướng xử lý: vì urgent ngoài phạm vi triển khai đã chốt, cần chặn bằng capability flag mặc định tắt hoặc hoàn thiện validation trước khi mở; không để API ngoài scope thành đường ghi dữ liệu không được bảo vệ.

### F05 — P1: Lock proposal chưa khóa được occurrence dùng chung

`ActionProposalRepository.GetByIdForUpdateAsync` dùng `FOR UPDATE` cho ActionProposals, bảo vệ việc hai request cùng trả lời **một proposal**. Swap vẫn nạp occurrence bằng GetByIdAsync thông thường; occurrence không có concurrency token và các use case complete/accept/manual assign không dùng cùng lock.

Hai proposal khác nhau có thể cùng tác động một occurrence, hoặc swap đụng complete/accept. Việc đọc lại assignee chưa đủ đảm bảo không có request khác commit sau bước đọc.

Đây là nguy cơ concurrency từ code, chưa tái hiện với DB thật trong phiên này. Hướng xử lý: khóa/version chung cho occurrence/house theo plan; revalidate sau khi lấy lock; test PostgreSQL thật cho competing proposals và complete/accept.

### F06 — P1: SEASON_APPROVAL mới chưa giải quyết confirmation mùa

Nhánh `SEASON_APPROVAL` chỉ parse JSON bất kỳ tại create và không làm gì ở execute (`ActionProposalService.cs:272–274`). Proposal có thể APPROVED mà season vẫn không thay đổi; không yêu cầu payload có season ID, đúng house hoặc đủ required members.

Trong khi đó `SeasonService.cs:425` vẫn chuyển ACTIVE sau một confirmation; `:111` vẫn có start từ draft. Có hai hệ thống đồng thuận nhưng chưa có một nguồn trạng thái mùa thống nhất.

Hướng xử lý: SeasonService là nguồn chuẩn của lifecycle. Không dùng proposal APPROVED làm bằng chứng mùa đã active; nếu hiển thị card season thì nó phải phản ánh và gọi đúng use case với schedule revision/required confirmations. Không tạo hệ thống treasury consent bằng cách ép vào enum SEASON_APPROVAL.

### F07 — P1: Test payment mới khóa cứng rule trái kế hoạch thủ quỹ

`backend/tests/UnitTests/Services/PaymentObligationTests.cs:20,34–36` đặt caller là DebtorUserId rồi assert PAID. Source `BountyService.SettlePaymentAsync` vẫn cho debtor hoặc creditor settle.

Theo plan mới: debtor không tự chứng minh đã trả; đường direct chỉ creditor confirm; đường batch phải hoàn tất thu/chi. Test mới pass nhưng không phải acceptance đúng cho mô hình đã thống nhất.

Hướng xử lý: giữ test hành vi legacy khi cần ghi nhận hiện trạng, nhưng acceptance mới phải kiểm quyền creditor/batch lock và không PAID sau mỗi webhook thu. Cập nhật test cùng lúc đổi use case, không sửa test để che bug.

### F08 — P2: API proposal dùng prefix khác phần còn lại

`ActionProposalController.cs:11` dùng `/api/v1`; API hiện có và plan dùng `/api`. FE chưa có proposal datasource để nối contract.

Hướng xử lý: chọn `/api` làm canonical theo plan; nếu cần giữ endpoint đã có client dùng thì thêm alias chuyển tiếp, không gọi `/api/proposals` trong FE khi BE chỉ nhận `/api/v1/proposals`.

### F09 — P2: Card bị ẩn khi phòng chưa có text message

`chat_room_screen.dart:126–129` return “No messages yet” trước khi tính danh sách proposal. Khi sửa đủ lỗi compile, phòng chỉ có proposal nhưng chưa có message sẽ vẫn không render card.

Ngoài ra notifier tự connect ở `_init`, screen lại gọi connect một lần nữa. Cần thống nhất một connection lifecycle, tránh connection cũ không được stop. Đây là vấn đề tĩnh, chưa chạy app sau pull do compile blocker.

### F10 — P1: Unit test generation thực sự đang fail

`GenerateOccurrences_ValidSeason_GeneratesCorrectNumberOfOccurrences` mock `GetBySeasonIdAsync` tại dòng 135, còn service gọi `GetByHouseIdAsync` tại dòng 47 và throw ở dòng 49. Test fail vì không lấy được fixture chore.

Không chỉ đổi mock cho test xanh: chốt generator theo snapshot của season như plan, sau đó sửa service/query và fixture cùng lúc. Nếu đổi fixture để dùng mọi chore trong house thì bỏ sót lỗi lẫn season.

## 4. Phần mới đã có và nên giữ/tái sử dụng

- Có Domain ActionProposal/ProposalConfirmation, DTO/service/repository/controller, EF configuration và migration `20261015131034_AddActionProposals`.
- Có transaction cho proposal response, unique target confirmation và lock theo proposal.
- Có publisher gửi `ReceiveProposal` và `ProposalUpdated` vào đúng room group, sau commit.
- Có helper check room trước JoinRoom; cần bổ sung active status, không làm lại từ đầu.
- Forced payment đã được gán `OccurrenceId`; finding G12 cũ chỉ còn thiếu `SeasonId` và các phần eligibility/dedup liên quan, không còn thiếu cả hai field như báo cáo trước pull.
- Có unit tests mới cho proposal, compensation, payment và room publisher. Các test mock này là nền tốt nhưng chưa chứng minh race/SQL với DB thật.

Không tạo lại ActionProposal entities/migration như thể chưa có. Không xóa tính năng vừa merge chỉ vì ngoài scope plan: giới hạn capability khi chưa đủ validation, và giữ phần hạ tầng có thể tái sử dụng.

## 5. Ma trận 10 nhóm so với code HEAD

| Nhóm | Sau pull | Còn thiếu hoặc conflict |
|---|---|---|
| 1. Thủ quỹ/payOS/settlement | Chưa thấy implementation | Chưa có treasury/batch/consent/attempt/webhook/QR/chi-confirmation; settle debtor còn trái rule mới |
| 2. Microphone | Chưa thấy implementation | Chưa có recorder/permission/media audio/upload pipeline |
| 3. Loa | Chưa thấy implementation | Chưa có player/audio focus/voice bubble |
| 4. Season/review/generation | Core cũ gần như giữ nguyên, có proposal riêng mới | Một confirm active, start bypass, auto gọi khi generate, sai scoping; season proposal không execute lifecycle |
| 5. Manual/auto/Karma fairness | Chưa có thay đổi trong pull | Workload phút, fallback bỏ hard constraints, manual availability chặn, tải cũ chưa tính đúng |
| 6. Availability giờ/deadline/frequency | Chưa có thay đổi | Availability bool; generation deadline23:59; frequency switch chưa đủ9 loại |
| 7. Quyền/membership | Sửa được bước check JoinRoom một phần | LEFT/BANNED vẫn qua helper; proposal apply không revalidate; household cap/rejoin còn backlog |
| 8. Completion/penalty/bounty/forced | Thêm OccurrenceId và test compensation | Chưa có responsibility episode/one-compensation guard; SeasonId còn thiếu; concurrency/expiry và penalty độc lập còn backlog |
| 9. Reward/ranking/share | Chưa có thay đổi | End-season vẫn lấy KarmaBalance, bonus count và reset balance; chưa có create/redeem cost/share theo plan |
| 10. Release/12 màn/test | Có test mới nhưng FE regression | Analyzer17errors, unit1fail, EF dependency conflict; route trùng vẫn còn, chưa có E2E mobile/ownership12 màn |

Không nhóm nào được đánh dấu hoàn tất chỉ dựa trên pull này. Auth/camera và các module đã có không bị đổi thành “chưa code”; trạng thái ở đây là so với phần backlog được yêu cầu bổ sung.

## 6. Conflict về phạm vi và tài liệu

- Bạn đã chốt không triển khai thêm thẻ swap/urgent trong đợt 10 nhóm, nhưng pull mới đưa hai loại đó vào API/UI. Đây là **scope divergence**, không phải merge conflict Git. Cần bảo vệ/tắt capability chưa nghiệm thu trước khi sử dụng chung dữ liệu mới.
- Proposal hiện có không phải AI proposal hoặc treasury consent: enum chỉ swap/urgent/season approval, thiếu context revision và payload tài chính. Không reuse mù quáng để apply payment.
- Plan mới cần tích hợp với hệ thống proposal đã có, không tạo entity cùng tên lần hai và không sửa migration cũ.
- Các file kế hoạch tạo trong các lượt chat trước vẫn untracked. Team pull từ remote chưa chắc có chúng; hiện chỉ `detailed-3dev-execution-and-testing-plan.md` trong nhóm plan là Git-tracked. Đây là lý do có thể dẫn tới người khác làm theo phạm vi 3dev cũ.
- Rule mới nhất từ cuộc trao đổi: bounty sau assigned, một forced compensation/occurrence, kênh payOS cấu hình server, khóa Karma khi hết mùa, pass thiếu người giữ lại, chỉ10nhóm. Cần lưu các quyết định này vào tài liệu authoritative được commit; bản plan chi tiết vừa trao đổi chưa có file riêng được lưu trong lượt Plan Mode.

## 7. Thứ tự xử lý đề xuất

1. Khôi phục Flutter compile bằng bộ dependency proposal hoàn chỉnh và thống nhất connection lifecycle; không thêm placeholder chỉ để hết lỗi.
2. Fix membership active và validation/locking khi apply proposal; không mở urgent/season approval chưa có đầy đủ policy.
3. Đồng bộ source/test generation; chạy lại UnitTests và xử lý EF dependency warning.
4. Công bố/commit plan và decision log cho cả4người; đánh dấu các phần sửa một phần để không làm lại.
5. Tiếp tục10nhóm theo kế hoạch, ưu tiên core integrity trước treasury/payment. Giữ1luồng season confirmation và1nguồn payment status chuẩn.

Báo cáo này không xác nhận provider, migration hoặc app trên thiết bị đã chạy thành công. Kiểm tra lại sau khi sửa build blockers và bổ sung PostgreSQL/Kafka/E2E tests.
