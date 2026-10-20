# KẾ HOẠCH THỦ QUỸ HOUSEHOLD, PAYOS VÀ 10 NHÓM YÊU CẦU CÒN THIẾU

> **Cập nhật 19/10/2026:** áp dụng [kế hoạch không-AI hiện hành](non-ai-10-groups-implementation-plan.vi.md). payOS, QR chuyển tiền, thủ quỹ và settlement đang HOÃN để hỏi giảng viên; các mục triển khai/kiểm thử tương ứng bên dưới chỉ giữ làm lịch sử, không thuộc đợt hiện tại. Payment tracking và creditor xác nhận nhận tiền vẫn trong phạm vi.

Ngày cập nhật: 18/10/2026. Nhóm PRM393_FA26_SE1910: 4 thành viên.

## 1. Quyết định được người dùng chấp nhận

**Bổ sung thủ quỹ trong từng household để nhận tiền quyết toán qua payOS, sau đó chi trả cho các thành viên được nhận.** Có thể bù trừ các khoản nợ chéo trước khi thu/chi. Không thêm gói mua hàng, subscription hoặc phí nền tảng.

Đây là nghiệp vụ mới mở rộng trên `PaymentObligation` hiện có, chưa được implement. Chức danh thủ quỹ không mặc định thuộc developer hoặc owner. Chủ tài khoản ngân hàng nhận tiền phải là người được household chọn và đồng ý giao trách nhiệm thu/chi.

Tài liệu này là **phương án thanh toán lịch sử, hiện đang hoãn** và danh sách 10 nhóm công việc còn lại. Nó thay lựa chọn “provider thu trực tiếp cho từng creditor” trong kế hoạch bổ sung cũ. Các phần không mâu thuẫn của [kế hoạch bổ sung](missing-requirements-implementation-plan.vi.md), [test plan](non-ai-full-system-test-plan.vi.md) và [báo cáo khoảng trống](non-ai-requirements-gap-report.vi.md) vẫn dùng để triển khai/đối chiếu.

“10 yêu cầu” bên dưới là cách gom backlog để thực hiện, **không phải môn học có 10 yêu cầu bắt buộc**. Môn học đã cung cấp 5 nhóm tiêu chí: payment service, login, 12 giao diện cho 4 người, product hoàn chỉnh và ít nhất 3 ngoại vi. AI có [kế hoạch Python riêng](ai-python-full-implementation-plan.vi.md), không trộn vào 10 nhóm không-AI này.

## 2. Ngân hàng của bạn và người dùng thật được xử lý thế nào?

| Trường hợp | Kênh nhận tiền | Hành vi hệ thống |
|---|---|---|
| Nhà demo của nhóm, bạn được chọn làm thủ quỹ | Kênh payOS gắn tài khoản của bạn | Tiền thật chuyển sẽ vào tài khoản bạn; UI ghi đúng tên bạn và trách nhiệm chi trả |
| Household khác có thủ quỹ/kênh riêng đã xác minh | Kênh của thủ quỹ nhà đó | Backend chọn theo house, không dùng credential mặc định toàn app |
| Household chưa thiết lập kênh | Chưa có | Không tạo QR payOS; cho chuyển trực tiếp/ghi nhận Received theo policy riêng |
| Automated test | Adapter provider giả lập, dữ liệu test | Không chuyển tiền thật; kết quả gắn nhãn test |

**Không gắn ngân hàng của bạn cho mọi household.** Bản đầu chỉ bật payOS cho household đã cấu hình và xác minh kênh. Nếu mới onboard nhà demo thì các nhà khác vẫn dùng được nghiệp vụ cốt lõi nhưng chưa có checkout payOS.

Thiết kế theo house giúp chỉ người làm thủ quỹ phải thiết lập kênh nhận, không bắt mọi member tạo tài khoản payOS. Người được nhận chỉ cần cung cấp thông tin để thủ quỹ chuyển tiền cho họ.

Không tạo token ngân hàng/OTP đăng nhập trong Chore Wars. Credential provider ở backend và được giới hạn quyền. Không khẳng định payOS hỗ trợ sẵn mô hình marketplace/mọi kênh tùy ý; việc onboarding, lưu credential nhiều house và use case thu hộ phải được xác nhận phù hợp với dịch vụ/tài khoản được cấp trước khi mở rộng.

## 3. Vai trò thủ quỹ và sự đồng ý

### 3.1. Thiết lập lần đầu

1. Một member active nhận làm ứng viên thủ quỹ, cung cấp kênh payOS và thông tin nhận tiền theo quy trình server an toàn.
2. Backend kiểm chứng kênh/account phù hợp, không cho user X cấu hình hoặc đọc credential của house khác.
3. Household xem tên người giữ tiền, ngân hàng/kênh nhận, cách chi trả và trách nhiệm khi có sai lệch.
4. Required members active xác nhận cấu hình và policy version; ứng viên phải chấp nhận trách nhiệm.
5. Kênh chỉ active sau khi đủ xác nhận và cấu hình kỹ thuật hợp lệ.

Thủ quỹ là **vai trò tài chính bổ sung**, không sửa `HouseRole` thành mô hình owner có quyền quản trị tất cả. Không được vì làm thủ quỹ mà sửa Karma, xóa nợ, duyệt thay người nhận hoặc giảm workload của mình.

### 3.2. Đổi hoặc rời vai trò

- Khi còn đợt đang giữ tiền, không đổi beneficiary của đợt cũ hoặc xóa thủ quỹ khỏi audit.
- Tạm dừng tạo đợt mới, giải quyết thu/chi/hoàn trả đang tồn trước khi bàn giao; nếu cần bàn giao đặc biệt phải có consent và biên bản đối soát.
- Kênh mới có version, ngày hiệu lực và approval riêng. Mỗi đợt snapshot đúng người/kênh thu tại thời điểm được duyệt.
- Member rời nhà không xóa lịch sử, payment obligation hoặc quyền xử lý nghĩa vụ chưa kết thúc theo policy đã chốt.

## 4. Khi nào xuất hiện QR chuyển tiền?

QR xuất hiện khi **một đợt quyết toán đã được các bên duyệt** và member có số tiền ròng phải trả lớn hơn 0. Đây là QR trả tiền cho thủ quỹ theo đợt, không phải QR chứng minh creditor cuối cùng đã nhận tiền.

Nguồn khoản nợ:

- Bounty accepted và hoàn thành: số tiền bounty gốc; người thực hiện được normal Karma theo rule.
- Forced reassignment: compensation 120% snapshot; việc đã được thực hiện và đủ điều kiện nhận theo policy, forced completion vẫn +0 Karma.

Khoản tranh chấp, hủy, đã paid hoặc chưa đủ điều kiện không vào đợt. Điều kiện nhận compensation khi forced member cũng bỏ việc phải được chốt và kiểm tra bằng nghiệp vụ, không để thủ quỹ tự quyết.

### 4.1. Ví dụ bù trừ

| Khoản nợ gốc | Amount |
|---|---:|
| A nợ B | 30.000đ |
| B nợ C | 20.000đ |
| C nợ A | 10.000đ |

Với mỗi người, tính `net = tổng được nhận − tổng phải trả` trên đúng các khoản được chọn:

| Người | Net | Hành động |
|---|---:|---|
| A | −20.000đ | Thanh toán QR payOS 20.000đ vào kênh thủ quỹ D |
| B | +10.000đ | Nhận 10.000đ từ D |
| C | +10.000đ | Nhận 10.000đ từ D |
| D | 0đ | Chỉ giữ vai trò thu/chi trong ví dụ |

Tổng thu bằng tổng chi, không đổi lợi ích tài chính ròng của ai. Các khoản gốc vẫn được giữ để giải thích vì sao có số tiền ròng. Không ép bù trừ nếu người liên quan không đồng ý. Thủ quỹ có thể đồng thời là người nợ/được nhận; khi đó chỉ thu/chi chênh lệch thực cần thiết, không tạo giao dịch tự chuyển cho chính mình và phải đối soát phần tự tham gia tường minh.

### 4.2. Luồng đầy đủ

```text
PaymentObligation hợp lệ
 → Tạo đợt quyết toán và snapshot khoản nợ
 → Tính net của từng người
 → Các bên liên quan + thủ quỹ xem và đồng ý
 → Người net âm mở QR payOS, thấy rõ người giữ tiền
 → Backend xác minh payment qua webhook/query
 → “Đã thu, chờ thủ quỹ chi trả”
 → Thủ quỹ chuyển tiền cho từng người net dương
 → Người được nhận xác nhận “Đã nhận”
 → Đối soát đầy đủ
 → Hoàn tất đợt, đóng các khoản gốc theo phương thức quyết toán
```

**Webhook thu tiền không được đổi toàn bộ obligation thành PAID.** UI phải phân biệt đã đóng phần phải nộp vào đợt với đợt đã quyết toán xong. Bản đầu chỉ đóng đồng thời các khoản gốc khi toàn bộ thu/chi hợp lệ của đợt hoàn tất.

### 4.3. Không bắt buộc đợi cuối mùa

Có thể tạo đợt từ một khoản hoặc nhiều khoản đủ điều kiện, bất kỳ lúc nào các bên đồng ý. Màn cuối mùa có thể gợi ý chốt sổ, nhưng không tự gom nợ hoặc buộc mọi người chờ. Người không muốn qua thủ quỹ có thể dùng phương thức trực tiếp được hỗ trợ; khoản đó không được đồng thời tham gia đợt đang khóa.

## 5. Phạm vi phiên bản đầu và giới hạn rõ ràng

- payOS dùng cho **thu tiền** vào kênh thủ quỹ, tạo QR/link và xác minh server. API có các chức năng tạo/query payment request và webhook. [API payOS](https://payos.vn/docs/api/), [webhook](https://payos.vn/docs/du-lieu-tra-ve/webhook/).
- **Chi trả thủ công qua ngân hàng** trong bản đầu; receiver xác nhận. App lưu reference/bằng chứng hỗ trợ, không tuyên bố đã tự xác minh ngân hàng ở chiều chi.
- Không bắt buộc Kênh chi payOS để hoàn thành bản đầu; nếu làm tự động sau này phải là adapter/policy riêng và chỉ báo thành công sau xác nhận chiều chi.
- Không làm ví nạp/rút, số dư tiêu dùng, lãi, phí giao dịch hoặc thu phí nền tảng. Sổ đối soát chỉ theo dõi tiền của từng đợt.
- Mỗi đợt dùng một currency VND, tính bằng giá trị tiền chính xác phía C#/DB; không dùng double để đối soát. FE định dạng không được tự đổi amount.
- Demo tiền thật phải giới hạn người tham gia biết rõ kênh nhận/chi, có quy trình hoàn trả. Test tự động dùng mock. Chỉ gọi môi trường sandbox/test khi tài khoản/provider thực tế hỗ trợ và đã xác nhận.

Mô hình thủ quỹ vẫn có trách nhiệm giữ và chi tiền thật. Có consent, audit và tranh chấp làm trách nhiệm rõ ràng; không biến nó thành luồng hoàn toàn không cần tin tưởng.

## 6. Dữ liệu và trạng thái sẽ code

Giữ `PaymentObligation` làm nguồn ai nợ ai; thêm liên kết quyết toán, không ghi đè payer/creditor thành thủ quỹ.

| Entity | Nội dung |
|---|---|
| `HouseTreasuryConfiguration` | HouseId, TreasurerUserId, channel reference, version, trạng thái kỹ thuật/consent, effective time |
| `TreasuryApproval` | Member, config version, accepted/rejected time; không lưu thay bằng một bool toàn nhà |
| `SettlementBatch` | House, snapshot thủ quỹ/kênh, policy version, revision, created time, currency, trạng thái |
| `SettlementItem` | Batch, obligation ID, amount và payer/creditor snapshot; khóa tham gia đợt active |
| `SettlementMemberBalance` | Tổng nợ/được nhận/net; số đã thu/đã chi được xác nhận; không phải ví có thể rút |
| `SettlementConsent` | Participant, batch revision, decision/time |
| `PaymentAttempt` | Member cần nộp, amount, provider order/payment link/QR, expiry, transaction ID, status, idempotency key |
| `SettlementDisbursement` | Beneficiary, amount, account snapshot, transfer reference, submitted/confirmed/rejected time |
| `SettlementAuditEvent` | Ai làm gì, khi nào, reference nào; không xóa lịch sử để sửa lỗi |

Trạng thái batch: `DRAFT → AWAITING_APPROVAL → COLLECTING → DISBURSING → COMPLETED`. Nhánh phụ: `REJECTED`, `CANCELLED` trước khi có tiền, hoặc `REVIEW_REQUIRED` khi phát sinh sai lệch. Hoàn tiền là giao dịch có trạng thái riêng, không đổi về CANCELLED rồi quên khoản đã thu.

Trạng thái thu: `CREATING/PENDING/VERIFIED/FAILED/EXPIRED/REVIEW_REQUIRED`. Trạng thái chi: `PENDING/TRANSFER_REPORTED/RECEIVER_CONFIRMED/DISPUTED`. `TRANSFER_REPORTED` là thủ quỹ báo đã chuyển, chưa phải receiver đã nhận.

Đợt net bằng 0 toàn bộ vẫn có thể hoàn tất bằng bù trừ sau đủ consent, không tạo QR 0đ. Ghi settlement method/audit là bù trừ, không giả giao dịch ngân hàng.

## 7. API và file giao tiếp

### 7.1. API dự kiến

| API | Tác dụng/quyền |
|---|---|
| `GET /api/houses/{houseId}/treasury` | Member xem thủ quỹ/kênh đã che thông tin phù hợp; không trả secret |
| `POST /api/houses/{houseId}/treasury/proposals` | Đề cử cấu hình thủ quỹ/kênh; đây là cấu hình tài chính thường, không phải AI proposal |
| `POST /api/houses/{houseId}/treasury/proposals/{id}/approve` | Member active xác nhận đúng version |
| `POST /api/houses/{houseId}/settlements` | Tạo batch từ danh sách obligation hợp lệ |
| `GET /api/houses/{houseId}/settlements/{id}` | Preview/net/progress/audit được phép |
| `POST /api/houses/{houseId}/settlements/{id}/approve` | Participant/thủ quỹ duyệt revision cụ thể |
| `POST /api/houses/{houseId}/settlements/{id}/reject` | Từ chối trước thu; hủy/thu lại consent theo policy |
| `POST /api/houses/{houseId}/settlements/{id}/checkout` | Đúng người net âm tạo/reuse QR cho phần phải nộp |
| `POST /api/payments/webhooks/payos/{channelReference}` | Xác minh provider/channel/order, không dựa JWT member |
| `POST /api/houses/{houseId}/settlements/{id}/refresh-payment` | Backend query trạng thái theo member có quyền, rate limit |
| `POST /api/houses/{houseId}/settlements/{id}/disbursements` | Thủ quỹ báo chi khoản hợp lệ |
| `POST /api/houses/{houseId}/settlements/{id}/disbursements/{payoutId}/confirm` | Chỉ beneficiary xác nhận nhận đúng khoản |
| `POST .../disbursements/{payoutId}/dispute` | Beneficiary báo chưa nhận/sai amount, giữ audit |

Checkout không nhận receiver/amount tùy ý từ app. Backend tính lại theo batch được duyệt. Quyền thủ quỹ không cho xem toàn bộ credential hoặc giao dịch nhà khác.

### 7.2. BE

- Application: `TreasuryService`, `SettlementService`, `SettlementCalculator`, `IPaymentGateway`, DTO/validator/repository interfaces.
- Infrastructure: `PayOSPaymentGateway`, typed HTTP/options/secret resolver, EF configs/repos/migration và cơ chế outbox nếu đã chọn.
- Presentation: `TreasuryController`, `SettlementController`, `PaymentWebhookController`, DI và error mapping.
- `BountyService.SettlePaymentAsync`: chặn settle riêng khi obligation đang khóa trong batch; giữ phương thức trực tiếp với quyền/audit tường minh.
- `BountyExpirationService`: sửa audit OccurrenceId/SeasonId và điều kiện eligibility trước khi khoản được quyết toán.
- `AppDbContext`/UnitOfWork: thêm entity/repository, transaction/version/unique constraint tương ứng.

### 7.3. Flutter

- Sửa `payment_obligations_screen.dart`: hiển thị khoản gốc, trạng thái tham gia quyết toán, tránh nút “MARK AS SETTLED” vượt luồng.
- Thêm `treasury_setup_screen.dart`: người giữ tiền, kênh nhận, consent/config status.
- Thêm `settlement_review_screen.dart`: khoản gốc → net của từng người → approve/reject.
- Thêm `settlement_checkout_screen.dart`: QR, tên thủ quỹ, amount/reference, expiry, trạng thái thu.
- Thêm `settlement_detail_screen.dart`: bảng ai đã nộp, ai còn chờ nhận, khoản chi và xác nhận của chính beneficiary.
- Map repository/datasource/provider/endpoints/router; xử lý cùng máy qua checkout/copy/save QR tùy khả năng ngân hàng/provider, không giả định mọi app hỗ trợ deep link.

### 7.4. Chuỗi file gọi nhau

```text
payment_obligations_screen.dart
 → payment/settlement repository + datasource
 → SettlementController.cs → SettlementService.cs
 → SettlementCalculator.cs + UnitOfWork: snapshot/net/consent
 → PayOSPaymentGateway.cs: tạo checkout
 → settlement_checkout_screen.dart hiện QR
 → payOS callback → PaymentWebhookController.cs
 → SettlementService.cs: ghi VERIFIED chiều thu
 → settlement_detail_screen.dart hiện “chờ chi trả”
 → thủ quỹ báo chuyển → beneficiary confirm
 → SettlementService.cs đối soát và hoàn tất transaction
 → refresh/SignalR cập nhật các bên
```

Không cần Python, Gemini hoặc ML cho luồng tài chính này.

## 8. Quy tắc dữ liệu và xử lý ngoại lệ

1. Bảng net phải thỏa `tổng net = 0`; tổng tiền cần thu bằng tổng phải chi, điều chỉnh rõ phần thủ quỹ cũng là participant. Không đổi amount compensation/Karma.
2. Một obligation tối đa một active batch; khóa/version ở DB, không chỉ disable nút FE. Mutation direct settle và batch reserve dùng chung cơ chế.
3. Mọi sửa thành phần/amount/channel của batch làm đổi revision và vô hiệu consent cũ; sau khi có tiền không chỉnh snapshot tùy ý.
4. Tạo checkout có idempotency; webhook unique theo provider/channel/transaction. Timeout phải query theo reference trước khi tạo order khác.
5. Chỉ xác nhận thu khi signature, order, amount, currency, beneficiary channel và batch/member khớp. Return URL/ảnh chuyển tiền/nút đã chuyển không phải xác nhận provider.
6. Chưa thu đủ thì bản đầu chưa chi; một người không nộp giữ batch chờ, có thời hạn nhắc và luồng hủy/hoàn tiền được duyệt, không tự đóng nợ người khác.
7. Sai/thiếu/thừa tiền, thanh toán sau expiry/cancel hoặc thu lại ở attempt cũ chuyển đối soát; không bỏ event vì trạng thái từng EXPIRED.
8. Thủ quỹ báo chi nhưng B chưa nhận: khoản vẫn chờ/disputed. Ảnh chuyển khoản là tài liệu hỗ trợ, không cho thủ quỹ tự confirm thay B.
9. Bản đầu đóng đồng thời các obligation trong batch khi thu đủ và mọi beneficiary nhận đủ theo thỏa thuận; giữ snapshot/ledger cũ và paid/settled method để truy vết.
10. Không giữ DB transaction khi gọi HTTP provider. Ghi trạng thái tạo/gọi/reconcile phù hợp; hoàn tất nghiệp vụ bằng transaction ngắn, phát notification sau commit.
11. Nếu phải dừng batch sau thu, theo dõi refund từng khoản và confirmation/xác minh tương ứng. Chỉ release obligation khỏi batch khi tiền/consent đã được xử lý, không cho người dùng trả lần hai vì UI tưởng đã hủy sạch.
12. Kênh/config đổi hoặc member leave không chuyển tiền về account mới âm thầm. Chặn batch mới khi kênh lỗi và bảo toàn cách đối soát batch cũ.

## 9. Đúng 10 nhóm yêu cầu còn thiếu và trạng thái

Trạng thái dưới đây dựa trên source đã đọc, **không phải kết quả chạy test**. “Có một phần” gồm phần đã có module nhưng cần sửa/kiểm chứng. Không đánh dấu hoàn thành vì đã có tài liệu.

| # | Nhóm yêu cầu | Hiện trạng/khoảng trống | Việc cần code/hoàn thiện | Đạt khi nào? |
|---|---|---|---|---|
| **1** | **Thủ quỹ + payOS + quyết toán** | Có PaymentObligation và settle thủ công; chưa có treasury, batch, QR/provider/webhook/consent thu–chi | Toàn bộ mục 2–8; quyết toán có thể 1 khoản hoặc bù trừ nhiều khoản | Thu verified, chi receiver-confirmed, audit đúng, không đóng nợ sớm |
| **2** | **Microphone** | Chưa thấy luồng ghi âm/STT hoạt động trong source khảo sát | Voice note chat: record/stop/preview/cancel/upload; permission và media type/storage | A ghi âm thật, gửi được, deny/mất mạng không crash/duplicate |
| **3** | **Loa** | Chưa thấy audio playback/TTS hoạt động | Phát voice note từ nhóm 2, play/pause/retry/audio focus/lifecycle | B nghe trên loa thật; không tự autoplay/lẫn audio, stop đúng khi rời màn |
| **4** | **Season/review/generation đúng vòng đời** | Có module; quan sát một confirm đã active, start bypass, scoping generate/delete, clone thiếu field | All required confirm, reject reason/review lại, đúng mùa, transaction/retry, copy đủ field | SEASON/GEN scoping tests đạt, không ảnh hưởng lịch sử mùa khác |
| **5** | **Manual/auto và fairness Karma** | Có allocator; dùng phút, fallback vi phạm hard constraints, manual bị can thiệp/chặn availability | Manual/auto tách đúng, snapshot Karma summary/tải cũ/rotation, auto giữ hard constraints, manual warning | ALLOC-02…12 đạt, không tự giao người bận để lấp lịch |
| **6** | **Availability theo giờ, deadline và đủ frequency** | Có ngày/bool; chưa thấy giờ/deadline tùy chỉnh đầy đủ, switch thiếu loại | Interval/timezone, deadline input, 9 frequency và anchor/custom policy, migration/UI | Deadline đúng giờ, month/year/custom và boundary có oracle/test |
| **7** | **Phân quyền và membership** | Có auth/house/chat; còn dấu hiệu hub join thiếu check, cap/rejoin và route/entity checks chưa đủ | Active membership REST/SignalR, max6/rejoin, owner/invite/disband theo BR, xử lý leave/kick | User nhà khác không đọc/nghe/sửa; lịch sử/obligation giữ đúng |
| **8** | **Completion/Karma/penalty/bounty/forced an toàn** | Có nghiệp vụ; concurrency chưa chứng minh, forced audit/selection/episode, bounty expiry và overdue cần sửa | Chống ghi trùng DB, đúng mốc −5/−10/−15, expiry hợp lệ, responsibility mới, compensation120% có reference | Race/worker replay không double credit/debt; accepted đúng Karma, forced +0 |
| **9** | **Reward/leaderboard/achievement hoàn chỉnh** | Có read/claim/pass; chưa thấy create/redeem tùy chỉnh/share đầy đủ; tie/pass eligibility cần kiểm chứng | Create/redeem ledger, ranking snapshot/tie-break, pass reassign hợp lệ, share card | RANK/REWARD/PASS/ACH tests đạt, không làm việc biến mất |
| **10** | **Product release, 12 màn và bằng chứng test** | Có 38 file màn hình nhưng chưa xác nhận ownership/route/E2E; có route trùng và test mẫu | Route/UX/auth-refresh/realtime/upload/release config; 3 màn/người; regression + deploy/backup/demo | APK thật end-to-end, camera+mic+loa, test report/build ID/video, không lỗi chặn |

### Đối chiếu với 5 yêu cầu môn

- Payment service: nhóm 1; demo thể hiện rõ payOS chiều thu và xác nhận thủ công chiều chi.
- Login: đã có implementation; nghiệm thu trong nhóm 7/10, không xây auth mới nếu không có lỗi.
- 12 giao diện: nhóm 10; 4 người ×3, chỉ tính màn hoạt động có phân công thật.
- Product hoàn chỉnh: nhóm 4–10 và phần tài chính chạy xuyên suốt.
- 3 ngoại vi: camera đã có code (QR invite/proof, cần test), nhóm 2 bổ sung Micro, nhóm 3 bổ sung Loa. QR chuyển tiền hiển thị không tự tính là dùng camera trong Chore Wars.

### Không bỏ sót các finding cũ

G01/G08/G17 → nhóm 4; G02/G03/G04/G05 → nhóm 5; G06/G07 → nhóm 6; G09/G10/G14 → nhóm 7 (G10 phối hợp nhóm 8); G11/G12/G13/G19/G20 → nhóm 8; G15/G16 → nhóm 9; G18 và cấu hình release → nhóm 10. Payment/mic/loa từ yêu cầu môn → nhóm 1/2/3.

## 10. Lộ trình thực hiện

### Giai đoạn A — Chốt model tiền và contract

- Viết rule treasury/consent/thu–chi vào đặc tả; chốt điều kiện nhận compensation và xử lý tranh chấp.
- Khảo sát account payOS của thủ quỹ nhà demo; xác minh receiver/channel và callback với giao dịch test được cho phép.
- Thiết kế entity/API và fixture bù trừ; không chuyển tiền thật tự động trong bước code/test.
- Đầu ra: decision log, schema, API examples, sơ đồ state; 1–2 ngày công dự kiến.

### Giai đoạn B — Code nhóm 1 theo các lát hoàn chỉnh

1. Treasury config/approval và house-scoped channel resolver; migration/permission.
2. Settlement calculator + reserve obligations + batch revision/consent.
3. Checkout/attempt/idempotency + webhook/query xác minh thu.
4. Chi thủ công + receiver confirmation/dispute + đối soát/hoàn tất.
5. Flutter setup/review/QR/detail, lỗi/mất mạng/reopen.

Đầu ra: demo một khoản A→B qua thủ quỹ, sau đó ví dụ net ba người; dự toán 7–10 ngày công cho BE+FE+test, phụ thuộc onboarding thực tế. Phần late/refund không được ghi “đã hỗ trợ” nếu chỉ có thông báo mà chưa có trạng thái xử lý đúng.

### Giai đoạn C — Nhóm 2/3 và các lỗi nền

Làm voice note Micro/Loa sau khi chat permission đạt. Đồng thời xử lý nhóm 4/7/8 trước các flow tài chính end-to-end vì ảnh hưởng quyền, dữ liệu và nghĩa vụ. Nhóm 5/6 dùng chung schema lịch, cần phối hợp tránh migration xung đột.

### Giai đoạn D — Nhóm 9/10 và nghiệm thu

Hoàn thiện reward/share/route, chạy toàn bộ test không-AI, release trên thiết bị, kiểm bảng 12 màn/4 người và video. Ước lượng lại sau baseline; không cộng kế hoạch AI vào cùng mốc và không cam kết 10 nhóm xong trong 8 ngày cũ.

### Phân công đề xuất cho 4 người

| Người | Phần chính | Phối hợp |
|---|---|---|
| Bạn | Chốt rule; season/allocation/generation nhóm 4–6 | Review schema lịch và treasury consent |
| Thành viên 2 | Treasury/payOS/settlement BE + concurrency tiền | Group 7/8, migration/ledger |
| Thành viên 3 | Flutter payment/treasury/review/QR/detail | Reward/share/router và UI 12 màn |
| Thành viên 4 | Voice note Micro/Loa, chat permission/realtime | Device testing/release và E2E |

Chưa gán tên thật hoặc xác nhận ai đã code màn nào. Mỗi người cần 3 giao diện có đóng góp được nhóm xác minh; không dùng bảng vai trò này làm bằng chứng thay commit/route/demo.

## 11. Test nghiệm thu riêng cho thủ quỹ/payOS

| ID | Ca kiểm thử | Kết quả bắt buộc |
|---|---|---|
| TRE-01 | Chưa có thủ quỹ/kênh/đủ approval | Không tạo QR tới ngân hàng developer mặc định |
| TRE-02 | User X đổi config/đọc batch nhà khác | Bị từ chối REST và realtime |
| TRE-03 | Net ví dụ 30k/20k/10k | A nộp20k, B/C nhận10k; tổng net0, giữ ba khoản gốc |
| TRE-04 | Sửa batch sau một consent | Revision tăng, consent cũ không đủ để checkout |
| TRE-05 | Hai batch chọn cùng obligation; direct settle cạnh tranh | Một đường reserve/settle hợp lệ, không dùng nợ hai lần |
| TRE-06 | Người nộp bấm checkout hai lần/provider timeout | Reuse/reconcile đúng reference, không tạo thu trùng |
| TRE-07 | Webhook đúng/lặp/giả/sai house channel/sai amount | Chỉ ghi thu hợp lệ một lần; mismatch chờ đối soát |
| TRE-08 | Đã thu đủ, chưa chi | UI “chờ chi trả”; obligation chưa PAID |
| TRE-09 | Thủ quỹ báo đã chuyển, receiver chưa nhận | Không hoàn tất; chỉ receiver có quyền confirm/dispute |
| TRE-10 | B confirm, C pending/disputed | Batch chưa complete, không đóng cả ba khoản gốc |
| TRE-11 | Thu/chi đầy đủ, confirm lặp hoặc đồng thời | Complete một lần, obligation/audit/link nhất quán |
| TRE-12 | Một người không nộp, tiền đến muộn, thu thừa, hủy sau thu | Không mất dấu tiền/ép xóa nợ; reconcile/refund rõ |
| TRE-13 | Thủ quỹ đổi tài khoản/rời nhà giữa batch | Batch cũ giữ snapshot, không chuyển checkout sang kênh mới tùy ý |
| TRE-14 | Thủ quỹ có net âm/dương hoặc batch toàn net0 | Không tự chuyển tiền cho mình, ghi số thực nhận/chi đúng; net0 vẫn cần consent |
| TRE-15 | App đóng/reopen/mạng mất sau commit | Tải trạng thái server, không yêu cầu nộp lại vì mất response |

Các case PAY cũ dùng cho adapter thu; oracle riêng của mô hình treasury là **payOS VERIFIED ≠ toàn bộ nghĩa vụ đã PAID**. Test trực tiếp A→B chỉ áp dụng đường thanh toán trực tiếp ngoài batch, không áp dụng QR kênh thủ quỹ.

## 12. Điều kiện bàn giao

- Source BE/FE và migration có kiểm quyền, transaction/idempotency, đồng bộ enum/model.
- Env/secret setup theo house; không commit key hoặc thông tin ngân hàng cá nhân thật vào tài liệu demo công khai.
- Đủ bằng chứng thu payOS, chi receiver-confirmed, tình huống chờ/dispute; màn hiển thị rõ người giữ tiền.
- Test report cho TRE-01…15 và test plan không-AI; phân biệt PASS/FAIL/BLOCKED/NOT RUN.
- APK/backend commit/migration version, tài khoản demo giả lập, 12 màn/4 người, video 3 ngoại vi và thanh toán.
- Tài liệu chốt rule mới và giới hạn: chi thủ công, kênh theo household, phạm vi onboard thật, mock/sandbox/production được ghi đúng.

**Hiện trạng sau lần cập nhật này:** đã thống nhất hướng và viết kế hoạch; chưa tạo treasury, kết nối ngân hàng, cấu hình payOS, chạy test hoặc thay đổi code nghiệp vụ. Cả 10 nhóm vẫn là backlog cần triển khai/kiểm chứng, có các phần nền đã tồn tại như bảng hiện trạng đã nêu.
