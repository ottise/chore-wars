# Kế hoạch sửa gốc luồng chore, bounty, chat và lịch

Ngày: 30/10/2026 — Asia/Saigon. Baseline source: `354a0d7`. Trạng thái: **đã triển khai bản sửa và kiểm thử tự động local; nghiệm thu cloud/thiết bị được ghi riêng trong release notes**. Checkbox đánh dấu các mục đã có code và bằng chứng kiểm thử local tương ứng; T01–T16 vẫn là checklist nghiệm thu thực tế, chưa đồng nghĩa đã chạy cloud. việc đã có code cũ không đồng nghĩa lỗi đã được sửa trên luồng người dùng.

## 1. Phạm vi và cách hiểu yêu cầu

- Giữ quyền cả hai người tạo nhà riêng; trong cùng nhà, owner và member ACTIVE đều có quyền thêm chore. Quyền quản trị mùa, xóa dữ liệu người khác và quản trị nhà vẫn tách riêng.
- Bỏ Routines khỏi UI. Chore có thể có quy tắc lặp nhưng người dùng không phải chọn giữa routine/template/chore hoặc import thủ công mới thấy việc.
- Nhà đang ACTIVE vẫn thêm việc được, backend sinh occurrence và phân công ngay. Người mới vào nhà có phần việc tương lai phù hợp; không sửa lịch sử việc đã làm.
- Chat có unread riêng, badge ở icon Chat và đầu trang chat; trên 10 hiển thị `10+`. Chuông trong cuộc chat chỉ mute/unmute. Chuông hệ thống chỉ đếm sự kiện hệ thống của đúng nhà.
- Bounty không phải bản sao của chore. Nhận bounty đổi người chịu trách nhiệm của occurrence gốc, không đổi loại NORMAL thành BONUS và không cộng đôi Karma.
- Người nhận theo dõi bounty trong tab Bonus bằng nhãn `Bounty`, kèm khoản tiền và hạn việc.
- Chọn phương án **giữ thống kê có ý nghĩa bằng số liệu thật**, xóa chỉ số kỹ thuật/khối trùng. Member Contributions là nơi xem từng người đã làm, còn việc gì, quá hạn gì.
- Giữ toàn bộ UI tiếng Anh, palette/font đã chốt; không thêm mock, dữ liệu mẫu vào lịch sử thật hoặc các vai trò supplier ngoài phạm vi.

### Hai quy tắc cần thể hiện rõ khi triển khai

1. **Ghi nợ lúc nhận bounty:** tạo bản ghi cam kết cho cả hai người ngay khi nhận. Trạng thái `AWAITING_COMPLETION` hiển thị là khoản chờ hoàn thành; sau khi hoàn thành mới chuyển thành khoản phải trả. Không đánh dấu đã thanh toán hoặc coi là tiền đã chi ngay lúc nhận. Đây là đề xuất xử lý yêu cầu “nhận rồi phải hiện nợ”, có thay đổi nghiệp vụ so với hiện tại.
2. **Tự chia việc và nút Confirm:** mùa ACTIVE tự chia việc hợp lệ khi join; không bắt cả nhà duyệt lại toàn bộ lịch đã bắt đầu. Nút Confirm thuộc lịch REVIEWING và thao tác chủ động “Review redistribution → Confirm” để sửa/chia lại lịch. Không để bước confirm thiếu làm người mới bị kẹt không có đường xử lý.

## 2. Nguyên nhân đã thấy trong source

| Nhóm | Bằng chứng trong source | Hướng sửa gốc |
|---|---|---|
| Chi tiết chore trống/Unknown, không có camera | Route legacy `/chores/:occurrenceId` dựng `features/chores/.../chore_detail_screen.dart` từ query `name/due/status`, không tải occurrence. Route theo nhà dùng một màn detail khác có API và ảnh | Một route detail chuẩn theo `houseId + occurrenceId`, redirect link cũ; không dựng “Chore/Unknown” giả |
| Hạn bounty sai ngày | `BountyService.CreateBountyCoreAsync` đặt `ExpiresAt = now + 24h`; DTO không có hạn occurrence; FE dùng ExpiresAt làm Due, parser còn fallback `DateTime.now()` | Tách hạn công việc với thời gian tin đăng; đọc hạn từ occurrence, xóa fallback ngày hiện tại |
| Có việc quá hạn trong picker bounty | `bounty_board_screen.dart` cố ý nhận ASSIGNED, OVERDUE và CRITICAL_OVERDUE | Lọc điều kiện hợp lệ trên server; FE không tự suy luận bằng chuỗi status |
| Nợ chưa hiện khi nhận bounty | `ChoreService.CompleteChoreCoreAsync` mới tạo `PaymentObligation` sau khi hoàn thành | Tạo cam kết lúc claim, chuyển trạng thái khi complete, không tạo bản ghi thứ hai |
| Tự nhận bounty | Backend đã chặn `PostedByUserId == actor`; detail UI chỉ kiểm tra OPEN | Dùng quyền từ response và kiểm tra backend; test cả thao tác gọi API trực tiếp |
| Không báo nhận thành công | Hai nơi accept trên FE invalidate/pop nhưng không có success state rõ; cần tái hiện lỗi sau commit/pop | Tách write thành công, refresh và navigation; idempotency và refetch khi kết quả HTTP không rõ |
| Thêm chore bị khóa | `ChoreService` yêu cầu OWNER và khóa ngoài DRAFT; form còn `Save as reusable routine` | Sửa quyền và luồng thêm occurrence theo trạng thái mùa, không chỉ mở nút UI |
| Join chưa chia lại | Đã có `MembershipChoreRedistributor`, nhưng chỉ chạy ACTIVE, nhiều điều kiện bỏ qua và không trả lý do khi chuyển 0 việc | Tái hiện đúng trạng thái mùa/dữ liệu lịch; trả kết quả chia việc có lý do và phương án xử lý |
| Badge chat/chuông bị trộn | System unread vẫn tính cả chat; chuông mute chat gắn unread; bottom bar không nhận chat count | Tách nguồn dữ liệu unread và kênh hiển thị; cursor đọc tin độc lập mute |
| Confirm tưởng như mất | Code có nút nhưng chỉ hiện khi `_reviewing`, còn phụ thuộc tải dữ liệu/profile/revision | Dùng trạng thái typed/capability server; hiện lý do khi không thể confirm, không ẩn im lặng |
| Voice còn preview | Recorder `_stop` chỉ giữ `_path`; `_preview` và nút Send là bước riêng | Stop & send trực tiếp, giữ retry/discard khi gửi lỗi |
| Ranking/settings | Route/link đã tồn tại trong `house_more_screen.dart` và router | Rà điều kiện hiển thị/đường vào, không tạo trang trùng |

Chưa kết luận nguyên nhân runtime của “nhận rồi báo lỗi”, “join chuyển 0 việc” và “chore mới không hiện” chỉ từ ảnh. Phải gắn request/occurrence/revision vào log QA, tái hiện hai tài khoản và phân biệt API từ chối, ghi thành công nhưng refresh lỗi, đi sai route, cache cũ và deploy cũ.

## 3. Checklist công việc theo thứ tự phụ thuộc

### P0-A — Định danh occurrence, ngày giờ và điều hướng

- [ ] **A01** Inventory tất cả link từ calendar, Mine, Team, Bonus, bounty, thông báo và chat; dùng route `/houses/:houseId/chores/:occurrenceId` cho việc thực tế. Template ID không được dùng như occurrence ID.
- [ ] **A02** Redirect link legacy có đủ thông tin; nếu thiếu house, resolve bằng API có kiểm tra membership hoặc báo không tìm được đường dẫn. Không chọn nhầm nhà hiện tại và không dựng màn trống.
- [ ] **A03** Detail tải lại được bằng URL trực tiếp, refresh browser và mở từ notification; hiển thị tên, assignee, trạng thái, ngày/giờ đầy đủ và mùa đúng.
- [ ] **A04** Hiện Take photo/Choose photo cho người được phép; ảnh upload lưu bền, reload thấy ảnh, complete với evidenceId đúng occurrence. Trạng thái hoàn thành/quá hạn có capability riêng, không chỉ điều kiện ASSIGNED ở FE.
- [ ] **A05** Chuẩn hóa UTC trong API/DB, hiển thị Vietnam time có nhãn. Không dựa vào timezone máy người dùng, không fallback thời gian hiện tại khi thiếu/sai timestamp.
- [ ] **A06** Back ở bounty board/detail/create luôn có hành vi hợp lệ: pop nếu có stack, nếu không thì về board đúng nhà. Không để exception `pop` đổi một thao tác thành công thành thông báo thất bại.

### P0-B — Chore: quyền tạo, bỏ routine và thêm vào lịch đã chốt

- [x] **B01** Kiểm tra actor ACTIVE trong đúng house, nhà chưa archived. Cho OWNER và MEMBER tạo; không cấp thêm quyền quản trị nhà để mở quyền tạo chore.
- [x] **B02** UI còn Mine / Team / Bonus, mặc định Mine. Bỏ tab Routines, toggle Save as reusable routine, Create Routine và flow import thường nhật. Giữ chuyển tiếp link cũ.
- [x] **B03** Nút `Add chore` ở bên phải header, mọi member thấy; không dùng FAB che `View team schedule`. Chừa khoảng cuối danh sách cho AI shortcut/nav.
- [ ] **B04** Một form Create chore: tên, loại, effort/Karma theo rule, thời gian bắt đầu/hạn và tùy chọn lặp. Submit trả ID và kết quả phân công, thành công phải thấy việc trong đúng danh sách.
- [x] **B05** DRAFT: thêm definition rồi cập nhật lịch nháp có kiểm soát. REVIEWING: tăng revision, vô hiệu approval cũ, sinh lại phần bị ảnh hưởng và yêu cầu duyệt revision mới.
- [x] **B06** ACTIVE: sinh các occurrence mới còn trong khoảng mùa và tương lai; phân công phù hợp theo lịch rảnh/capacity. Không chạy nhánh xóa toàn bộ occurrence của mùa như flow draft cũ.
- [x] **B07** COMPLETED/CANCELLED hoặc không có mùa hợp lệ: giải thích rõ cần mùa nào để thêm; không âm thầm lưu một template không có việc thực tế.
- [x] **B08** Idempotency cho create/generate: double-click, retry và hai người thêm đồng thời không tạo trùng occurrence. Khóa mutation theo house và revision.
- [x] **B09** Nếu không thể gán, trả kết quả `needs_assignment` kèm lý do và hiển thị trong Team; có đường owner điều chỉnh. Không báo “assigned” khi chưa có người nhận.
- [ ] **B10** Chuyển dữ liệu routine cũ bằng mapping rõ ràng; chỉ sinh việc sau xác nhận khi cần, dedupe theo nguồn/ngày. Không xóa lịch sử hoặc tạo hàng loạt việc trùng trong mùa ACTIVE.

### P0-C — Thành viên mới và xác nhận chia việc

- [ ] **C01** Tái hiện join ở DRAFT, REVIEWING, ACTIVE; kiểm tra current-season có bị draft khác che ACTIVE, role/membership cache, planned start, lịch rảnh, slot, cap và các loại việc bị loại.
- [x] **C02** Tách lập kế hoạch phân chia khỏi áp dụng. Trả `movedCount`, `assignedCount`, revision, danh sách thay đổi và các lý do không thể chuyển; lưu audit có thể đối chiếu.
- [x] **C03** Join ACTIVE tự áp dụng phần chia tương lai hợp lệ trong cùng transaction membership. Người mới không khai lịch phải có chính sách kế thừa slot rõ ràng; vẫn tôn trọng ngày/giờ họ khai bận.
- [ ] **C04** Không chuyển việc hoàn thành, đã bắt đầu, quá hạn, có evidence/penalty, bounty hoặc nghĩa vụ tiền đang ràng buộc. Không ép người mới nhận việc bất khả thi chỉ để số lượng khác 0.
- [x] **C05** Nếu 0 việc có thể chia, trả và hiển thị lý do, nút Review redistribution/điều chỉnh lịch. Có việc tương lai phù hợp thì người mới phải được chia phần, không bỏ qua im lặng.
- [x] **C06** DRAFT/REVIEWING: tính lại roster và phần việc người mới; approval gắn đúng revision/roster. Mọi thành viên ACTIVE đều có nút Confirm khi cần, thông tin đang chờ ai và lý do chưa Start được.
- Confirm chỉ xác nhận phần chấp thuận của chính actor; owner không bấm thay thành viên còn chờ. Nếu đã confirm thì hiển thị trạng thái chờ đúng người, không coi đó là lỗi “mất nút”.
- [x] **C07** Thao tác chia lại chủ động có preview trước/sau và Confirm; áp dụng dưới house lock với expectedRevision/clientRequestId, chống join hoặc confirm lặp.
- Quyền áp dụng chia lại chủ động thuộc owner; member vẫn tạo chore và xác nhận lịch của mình được. Tác vụ tự động khi join dùng service nội bộ, không mở API đổi assignment tùy ý cho mọi người.
- [ ] **C08** Gửi system notification đúng người bị đổi và người mới, realtime invalidation đúng house. Rời/đổi nhà không nhận dữ liệu nhà cũ.

### P0-D — Bounty: post, accept, thời hạn, tiền và hủy

- [x] **D01** Một điều kiện eligible phía backend: người post là assignee, mùa đã bắt đầu, việc chưa hoàn thành/skipped, hạn việc > serverNow, không có bounty/lock xung đột. Picker chỉ đọc nguồn eligible, sort hạn tăng dần rồi ID để ổn định.
- [x] **D02** Response có `occurrenceDueAt`, `acceptUntil`, `createdAt`, người nhận và capability canAccept/canCancel/canOpenChore. “Chore deadline” dùng occurrenceDueAt. Mặc định acceptUntil là hạn việc, không tự lấy now+24h làm hạn công việc.
- [x] **D03** Accept/worker không gia hạn deadline gốc thành now+24h, không ép phân lại/phạt sớm chỉ vì tin bounty hết thời hạn. Đối chiếu và sửa BountyExpirationService cùng policy mới.
- [x] **D04** API accept nhận houseId và xác minh bounty thuộc house đó. Server chặn tự nhận, ngoài nhà, LEFT/BANNED, hết hạn hoặc đã nhận. Hai người tranh nhận: chỉ một thành công.
- [x] **D05** Claim lưu đồng bộ bounty CLAIMED, assignee/responsibility mới, cam kết nợ và outbox; trả representation sau lưu. Người nhận retry cùng request được cùng kết quả, không tạo nợ hoặc thông báo trùng.
- [ ] **D06** FE khóa nút khi submit, chỉ hiện Accept khi được phép; báo thành công bằng toast/state rõ. Refetch thất bại sau commit phải nói dữ liệu đang cập nhật, không bảo nhận thất bại và cho nhận lại.
- [ ] **D07** Sau accept, refresh đồng bộ board/detail, Mine/Team/Bonus, calendar, My Debts/Payment History và summary theo house. Có thể từ Bounty mở trực tiếp chore detail thật.
- [ ] **D08** Bonus hiển thị accepted bounty của tôi bằng loại hiển thị `BOUNTY`, không sửa Chore.Type thành BONUS; không nhân đôi assignment, completion hoặc thưởng Karma.
- [x] **D09** Người post thấy “I owe”, người nhận thấy “Owed to me” cùng một obligation. Khi claim là `AWAITING_COMPLETION`, khi complete thành PENDING/payable; hoàn thành lại không tạo thêm khoản nợ. Hiển thị riêng cam kết chờ làm và khoản đã đến bước trả.
- [x] **D10** Cập nhật finance/repayment/settle để không thanh toán khoản chưa đến trạng thái payable; tiền nhận/trả và xác nhận vẫn đi flow hiện có, không coi bấm nhận bounty là chuyển tiền.
- [x] **D11** Thu hồi OPEN: người post xác nhận cancel, backend cập nhật trạng thái mềm và audit, không xóa DB. Sau cancel không thể accept bằng link cũ. Bounty đã CLAIMED không xóa đơn phương; flow yêu cầu hủy có đồng thuận để xử lý assignment/nợ nhất quán.
- [ ] **D12** Chuyển notification tạo/nhận/hủy vào outbox và consumer idempotent. Audit consumer tạo bounty chỉ gửi đúng ACTIVE recipients; người post có success riêng, người khác có system unread.
- [ ] **D13** Reconcile dữ liệu cũ: đối chiếu bounty/occurrence/payment, sửa dữ liệu hạn hiển thị và bổ sung cam kết còn thiếu chỉ khi xác minh được. Không tạo nợ cho CANCELLED, không cộng lại khoản COMPLETED đã có nghĩa vụ/đã trả.

### P1-E — Chat, thông báo và voice

- [ ] **E01** Unread chat dùng message/read cursor theo room và member, không lấy số notification hệ thống làm số tin nhắn. Tin do chính mình gửi không tăng số chưa đọc của mình.
- [x] **E02** Badge đỏ ở icon Chat bottom bar và đầu trang chat: 0 ẩn, 1–10 đúng số, >10 `10+`. Cập nhật realtime, reload vẫn đúng, reconnect không đếm trùng.
- [ ] **E03** Chỉ mark read tới message đã hiển thị khi đang mở đúng phòng và app ở foreground; trang ẩn/mất kết nối không đánh dấu cả tin chưa được xem. Read cursor tăng đơn điệu và đồng bộ nhiều tab.
- [x] **E04** Chuông trong phòng chat chỉ toggle enabled/muted, bỏ badge và bỏ điều hướng system inbox. Mute tắt cảnh báo âm thanh/banner, không xóa tin hoặc làm sai unread.
- [x] **E05** System Notifications/bell loại CHAT_MESSAGE khỏi danh sách, filter và count. Giữ các sự kiện bounty, membership, chore, mùa và hệ thống; mark-all-system không làm mất unread chat.
- [ ] **E06** Notification badge khi post bounty và khi có thành viên mới, link mở đúng đối tượng/nhà; giới hạn đếm/duplicate theo eventId, không sinh báo lặp do retry Kafka.
- [ ] **E07** Voice: Record → Stop & send trực tiếp → bubble phát audio, bỏ nút Preview recording. Không tự phát âm thanh ra loa khi gửi.
- [ ] **E08** Giữ cancel khi đang ghi, max duration/size và quyền mic. Dừng do app background/đóng màn phải hủy hoặc giữ draft an toàn, không tự gửi vì lifecycle; chỉ thao tác Stop & send chủ động mới gửi.
- [ ] **E09** Upload/send thất bại giữ bytes/draft để Retry hoặc Discard; cùng clientMessageId chống gửi đôi. Không xóa file trước khi server xác nhận và không cho thao tác stop đôi gửi hai message.

### P2-F — Thống kê, ranking, settings và avatar

- [x] **F01** Xóa khối Assignment Details accordion trùng và chỉ số Assigned Karma Gap khỏi UI người dùng; giữ dữ liệu/audit cần cho phân công. Schedule tập trung trạng thái mùa, revision, roster, confirmation và đường xem lịch.
- [x] **F02** Chore Completion dùng bảng/biểu đồ thật: tổng, hoàn thành, quá hạn, sắp tới; mẫu số loại skipped rõ. Không có dữ liệu thì hiện empty state, không fake chart hoặc placeholder vô hạn.
- [ ] **F03** Member Contributions thành chi tiết lịch theo từng người, có việc được giao, người hoàn thành thực tế, hạn, ngày hoàn thành, overdue, ảnh minh chứng và link detail. Phân biệt người đang nhận với người đã làm khi bounty/reassignment.
- [x] **F04** Bỏ phần workload/Karma lặp ở Schedule; không cộng trùng số liệu với trang chi tiết thành viên. Filter tháng/mùa, phân trang và quyền truy cập đều ở backend.
- [x] **F05** Khôi phục đường vào bảng xếp hạng mùa hiện tại và mùa đã kết thúc cho cả owner/member. Xếp theo ledger của đúng season, không dùng số Karma toàn thời gian; mùa kết thúc xem lại được.
- [x] **F06** Khôi phục mục House Settings trong House Management và đường vào dễ thấy; view phù hợp role, các thao tác quản trị vẫn owner-only. Không trộn Settings với chuông mute chat.
- [ ] **F07** Gắn avatar vào danh sách thành viên Overview, confirmations, contributions và ranking bằng component chung. DTO cung cấp avatar reference; endpoint ảnh kiểm tra membership đúng nhà, fallback initials khi thiếu.
- [x] **F08** Cache ảnh theo session/house/user/avatar version, không retry vô hạn khi 204/404; Google photo dùng proxy whitelist đã có, không mở public tất cả ảnh riêng tư.
- [ ] **F09** Kiểm tra 320/354/390/480 px, text scale lớn và web rộng; Back, Add chore, View team schedule, AI shortcut không che nội dung và không overflow.

## 4. File thay đổi và file tạo mới dự kiến

Đường dẫn dưới đây tương đối từ repo root. Đây là inventory triển khai; tên migration timestamp chốt lúc tạo, không sửa các migration đã áp dụng.

| Cụm | File hiện có cần sửa | File mới dự kiến |
|---|---|---|
| Chore/phân công | `backend/src/Application/Services/ChoreService.cs`, `SeasonService.cs`, `HouseService.cs`, `MembershipChoreRedistributor.cs`, `ChoreResponsibilityService.cs`; `Presentation/Controllers/ChoreController.cs`, `SeasonController.cs`; DTO/validator/interface/repository tương ứng | `Application/Services/ChoreSchedulingService.cs`, `Application/Interfaces/Services/IChoreSchedulingService.cs`, `DTOs/Chore/CreateScheduledChoreResult.cs`, `DTOs/Season/RedistributionResult.cs`, `DTOs/Season/ConfirmRedistributionRequest.cs` |
| Bounty/tài chính | `Application/Services/BountyService.cs`, `BountyExpirationService.cs`, `PersonalFinanceService.cs`, `Services/Supplies/InternalRepaymentService.cs`; `Presentation/Controllers/BountyController.cs`; `Mappings/BountyProfile.cs`; `DTOs/Bounty/BountyResponse.cs`; `Domain/Entities/ChoreBounty.cs`, `PaymentObligation.cs`, enum/config/repositories/interfaces liên quan | `DTOs/Bounty/AcceptBountyRequest.cs`, `CancelBountyRequest.cs`, `BountyEligibilityResponse.cs`; migration bổ sung trạng thái cam kết/unique source/idempotency/audit theo schema chốt |
| Notification/chat BE | `Application/Services/ChatService.cs`, `NotificationService.cs`; `Infrastructure/Repositories/ChatRepository.cs`; `Presentation/Controllers/ChatController.cs`, hub/publisher; `Kafka/Consumers/ChatMessageCreatedConsumer.cs`, `BountyCreatedConsumer.cs`, `BountyAcceptedConsumer.cs` | `Domain/Entities/ChatReadCursor.cs`, cấu hình EF; `DTOs/Chat/ChatUnreadResponse.cs`, `MarkChatReadRequest.cs`; migration cursor/index nếu chưa có cấu trúc tương đương |
| Chore/router FE | `mobile/lib/core/router/app_router.dart`; `features/chore/presentation/screens/chore_list_screen.dart`, `chore_form_screen.dart`, `chore_detail_screen.dart`; datasource/model/provider của chore; loại màn legacy `features/chores/.../chore_detail_screen.dart` sau khi redirect | `core/utils/vietnam_time.dart` nếu chưa có helper dùng chung phù hợp; widget kết quả chia việc và model typed scheduling response |
| Bounty FE | `features/bounty/domain/entities/bounty.dart`, `data/models/bounty_model.dart`, `data/repositories/bounty_repository_impl.dart`, interface, providers và cả 3 screens board/create/detail; `features/supplies` My Debts/Payment History | Widget cancellation/claim result, model capability/debt commitment; helper invalidate mutation scoped theo house nếu chưa có |
| Chat/noti FE | `features/chat/presentation/widgets/voice_note_recorder.dart`, `chat_notification_button.dart`, chat room/providers/services; `features/notifications` models/providers/screens/bell/banner; `core/widgets/app_bottom_bar.dart`, `house_shell.dart` | `features/chat/providers/chat_unread_provider.dart`, `core/widgets/unread_badge.dart`, typed unread/read-cursor API model |
| Summary/avatar/nav | `Application/Services/HouseholdSummaryService.cs`, `GamificationService.cs`; read repo/DTO summary/member; `HouseProfile.cs`; `UserController.cs` hoặc scoped house member controller; FE `review_schedule_screen.dart`, `household_summary_sections.dart`, `house_detail_screen.dart`, `house_more_screen.dart`, ranking và member model | `DTOs/House/MemberScheduleDetailResponse.cs`, endpoint/member detail query; `mobile/lib/core/widgets/member_avatar.dart`, `features/house/presentation/screens/member_schedule_detail_screen.dart` |
| Tests/docs | Mở rộng test bounty, finance, membership, season, chat/noti, router/role và layout hiện có; cập nhật `docs/assistant-user-flows.md` khi ảnh hưởng AI-generated chores | `backend/tests/IntegrationTests/Infrastructure/BountyLifecycleRecoveryTests.cs`, `MembershipRedistributionJourneyTests.cs`, `ActiveSeasonChoreCreationTests.cs`, `ChatUnreadCursorTests.cs`; Flutter test bounty routing/permissions/badge/voice; kịch bản QA hai người |

Kiểm tra và dùng lại abstraction hiện có trước khi tạo file/service mới. Không triển khai hai thuật toán phân công độc lập cho join và thêm chore; cả hai dùng chung eligibility, workload và transaction/revision rules.

## 5. Hợp đồng API cần chốt trước khi làm UI

| API đề xuất | Mục đích/điều kiện |
|---|---|
| `POST /api/houses/{house}/chores` | ACTIVE member tạo chore; response có chore/occurrence IDs, assignment result, revision và reasons nếu chưa gán |
| `GET /api/houses/{house}/bounties/eligible-chores` | Danh sách chỉ việc của tôi chưa quá hạn, đủ điều kiện, sort server-side; tránh trùng route `{bountyId}` bằng route constraint |
| `POST /api/houses/{house}/bounties/{id}/accept` | `clientRequestId`/expectedVersion; trả bounty + occurrence + obligation sau commit; verify house scope |
| `POST /api/houses/{house}/bounties/{id}/cancel` | Thu hồi có audit, role và state hợp lệ; không hard-delete |
| Proposal hủy bounty CLAIMED | Tận dụng ActionProposal hiện có nếu phù hợp: đề nghị → người còn lại approve/reject → cancel trong transaction. Kiểm tra lại version/completion/payment lúc apply; không xóa khoản đã trả, không trả task về người cũ nếu task đã hoàn thành |
| `GET /api/houses/{house}/chat/unread` | Count chính xác + cursor; không phụ thuộc inbox notifications có bị phân trang/mute hay không |
| `PUT /api/houses/{house}/chat/read` | Đánh dấu đến messageId/cursor hợp lệ trong phòng, tăng đơn điệu, không tùy ý mark future message |
| `GET /api/houses/{house}/seasons/{season}/redistribution-preview` | Preview read-only + baseRevision, eligible/blocked reasons; có cap range/size |
| `POST /api/houses/{house}/seasons/{season}/redistribute` | Confirm payload preview, expectedRevision/clientRequestId; request stale trả conflict, join ACTIVE dùng cùng service |
| `POST .../seasons/{season}/confirm` | Giữ API hiện có, sửa capability/revision và UI, không tạo API confirm thứ hai mâu thuẫn |
| `GET /api/houses/{house}/members/{user}/schedule` | Chi tiết việc theo tháng/mùa/trạng thái, phân trang, backend kiểm tra house scope |
| `GET /api/houses/{house}/members/{user}/avatar` | Proxy ảnh theo membership, 204 khi thiếu; cache/version và quyền target được kiểm tra |

Tên endpoint có thể điều chỉnh để tận dụng API đã có; phải cập nhật BE DTO → Dart model → repository → provider → UI → contract tests cùng một đợt. Không chữa bằng query string giả hay fallback `now`.

## 6. Luồng đi qua các file

1. **Create chore:** form → Dart repository → ChoreController → ChoreService (membership/season) → shared scheduling service (eligibility/load) → repositories/house mutation transaction → occurrence/responsibility/revision/outbox → typed response → invalidate đúng house → Mine/Team/calendar.
2. **Join:** join/QR → HouseController/HouseService → membership transaction + scheduling service → phân chia hợp lệ → cập nhật revision/responsibility/outbox → API kết quả → UI người mới/người cũ nhận update. REVIEWING đi nhánh xác nhận revision mới.
3. **Claim bounty:** board/detail → accept API → BountyService khóa và kiểm tra state/deadline/scope → đổi assignee + cam kết nợ + outbox trong cùng transaction → success response → toast + Bonus/detail/debts refresh. Complete chuyển cam kết thành payable; consumer chỉ xử lý tác vụ phụ idempotent.
4. **Chat unread:** gửi text/voice → lưu message có clientMessageId → hub/outbox → unread source theo cursor → Chat badge. Mở phòng → mark read đến message đã thấy → API/hub đồng bộ thiết bị. Mute là preference cảnh báo, không phải read cursor.
5. **Member detail:** Summary → chọn member → query có house/season/range → read repository → DTO actual assigned/completedBy/evidence → màn danh sách/charts + link occurrence chuẩn.

## 7. Checklist nghiệm thu hai người A/B (thêm C cho join)

- [ ] **T01** A và B tạo nhà riêng thành công; vào chung nhà A owner/B member, cả hai thêm chore được; ngoài nhà/LEFT/BANNED bị chặn API.
- [ ] **T02** Thêm chore trong DRAFT/REVIEWING/ACTIVE đúng nhánh; việc mới xuất hiện sau response và reload. Hai người tạo đồng thời không mất/trùng việc cũ.
- [ ] **T03** A post occurrence hạn 26/11 → B thấy đúng 26/11 và giờ VN ở picker, board, detail, notification; ngày tạo tin không trở thành deadline.
- [ ] **T04** Việc quá hạn không xuất hiện trong eligible; gửi API thủ công, đồng hồ client sai hoặc bounty vừa hết hạn vẫn bị backend chặn.
- [ ] **T05** A không thấy nút nhận của mình và API tự nhận bị chặn. B nhận thành công một lần, toast đúng, refresh/direct link vẫn CLAIMED. B/C tranh nhận chỉ có một người thắng.
- [ ] **T06** Sau claim: Bonus của B có task, deadline/camera đầy đủ; A/B thấy cùng cam kết tiền, hướng nợ ngược nhau. Complete một lần hoặc retry chỉ tạo một khoản payable, Karma một lần.
- [ ] **T07** Cancel OPEN không nhận được bằng link cũ; cancel đua với accept cho một kết quả hợp lệ. CLAIMED không bị xóa mất assignee/nợ ngoài flow đồng thuận.
- [ ] **T08** C vào ACTIVE có future eligible tasks → nhận phần việc; completed/overdue/evidence/bounty không bị chuyển. Trường hợp không thể chia có lý do và đường Review redistribution.
- [ ] **T09** C vào REVIEWING → roster/revision cập nhật, hiện đúng nút Confirm cho các thành viên cần duyệt; approval cũ không dùng để start revision mới.
- [ ] **T10** A gửi 11 tin → B thấy `10+` ở icon/header Chat; chuông mute không có badge. Mở đúng phòng mới reset, mute vẫn giữ unread; reload/reconnect/multi-tab không đếm đôi.
- [ ] **T11** B nhận system notification khi A post bounty; inbox hệ thống không chứa chat; đổi nhà không lẫn count/list, mark-all-system không xóa unread chat.
- [ ] **T12** Voice Stop & send ra một bubble audio; không có Preview, không tự phát loa. Upload lỗi retry cùng ID không tạo hai tin; background/permission denied không tự gửi.
- [ ] **T13** Mọi link chore/bounty có Back, mở URL trực tiếp không ra Chore/Unknown; ảnh chụp lưu lại và chỉ người đúng quyền đọc/hoàn thành được.
- [ ] **T14** Member detail phản ánh đúng task đã làm/quá hạn/ảnh của từng người; tổng dashboard khớp danh sách và không cộng hai lần việc chuyển bằng bounty.
- [ ] **T15** Xem được ranking mùa đã kết thúc và House Settings; avatar member đúng, ảnh thiếu fallback; không có Routine/Assignment Details/Karma Gap trùng.
- [ ] **T16** Layout 320/354/390/480 và desktop, text scale 1,3: nút add bên phải, View team schedule/AI/nav không đè; không overflow.

## 8. Triển khai, dữ liệu và tiêu chí hoàn tất

1. Tái hiện và ghi failing tests A/D trước; khóa rõ nghiệp vụ nợ chờ hoàn thành và confirm/chia việc.
2. Sửa model/DTO/transaction/state machine và quyền; migration additive, giữ giá trị enum cũ, không reorder số enum hoặc sửa migration cũ.
3. Sửa route/detail + chore creation/join + bounty; sau đó unread/voice; cuối cùng summary/navigation/avatar.
4. Với dữ liệu cũ: backup riêng, dry-run báo số bounty/debt/cursor cần xử lý, review mẫu; không suy đoán lịch sử đã đọc hoặc việc đã làm. Chọn mốc cursor legacy rõ ràng, không tự biến toàn bộ lịch sử thành hàng nghìn unread.
5. Chạy unit, Postgres HTTP/integration, race/idempotency, Flutter widget/contract thật hai client, recorder lifecycle, release build và QA browser/thiết bị. Không gọi mọi bài “đạt” nếu Kafka/AI/hardware test bị skip.
6. Push chỉ sau kiểm tra secret/diff/tests; deploy schema tương thích trước code phụ thuộc; kiểm tra version/readiness rồi T01–T16 với dữ liệu QA. Không coi CI xanh hoặc health 200 là đủ xác nhận các luồng tiền/ảnh/đọc tin.
7. Rollback bằng code tương thích schema additive và khôi phục nghiệp vụ có audit, không xóa DB để reset lỗi. Không tự sửa số tiền/khoản đã trả trong backfill.

**Definition of done:** từng checkbox có test/ảnh hoặc request trace nghiệm thu; không còn duplicate route detail, dữ liệu giả ngày giờ, thiếu confirm im lặng, nhận bounty hai lần, nợ trùng, unread lẫn nhà/kênh hoặc ghi việc thành công nhưng UI báo lỗi.

## 9. Bằng chứng và phần còn cần nghiệm thu

Bản triển khai được mô tả tại `docs/releases/household-workflow-recovery-2026-10-30.vi.md`. Các mục còn để trống có thể đã có code nhưng chưa đủ bằng chứng nghiệm thu toàn luồng/thiết bị để đánh dấu hoàn tất. Không đánh đồng health 200 hay build thành công với nghiệm thu tất cả thao tác người dùng.
