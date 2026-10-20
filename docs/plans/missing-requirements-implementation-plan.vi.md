# KẾ HOẠCH BỔ SUNG CÁC YÊU CẦU CÒN THIẾU — CHORE WARS

> **Cập nhật 19/10/2026:** áp dụng [kế hoạch không-AI hiện hành](non-ai-10-groups-implementation-plan.vi.md). payOS, QR chuyển tiền, thủ quỹ và settlement đang HOÃN để hỏi giảng viên; các mục triển khai/kiểm thử tương ứng bên dưới chỉ giữ làm lịch sử, không thuộc đợt hiện tại. Payment tracking và creditor xác nhận nhận tiền vẫn trong phạm vi.

Ngày lập: 18/10/2026. Team 4 thành viên. Trọng tâm thanh toán là **QR chuyển tiền**, theo xác nhận của người dùng.

**Trạng thái lịch sử:** phương án payment/receiver và thủ quỹ bên dưới đã được thay bởi [kế hoạch hiện hành](non-ai-10-groups-implementation-plan.vi.md). Chỉ dùng các phần không mâu thuẫn để tham khảo; chưa triển khai provider trong đợt này.

## 1. Mục tiêu

Hoàn thiện các khoảng trống còn lại để nghiệm thu môn PRM393 và nghiệp vụ SRS/Business Rules: QR thanh toán bounty/compensation, Micro/Loa, 12 giao diện có phân công rõ, các điểm lệch nghiệp vụ và bản release chạy xuyên suốt.

Không làm lại BE/FE đã có. Tái sử dụng module hiện tại, bổ sung các luồng thiếu và sửa đúng điểm chưa khớp yêu cầu. AI triển khai theo [kế hoạch AI Python riêng](ai-python-full-implementation-plan.vi.md); không đưa toàn bộ AI vào ngân sách bổ sung không-AI này.

Đây là kế hoạch code, chưa triển khai tính năng. Trạng thái được xác định bằng đọc source ngày lập tài liệu; chưa chạy runtime. Chi tiết bằng chứng: [báo cáo khoảng trống](non-ai-requirements-gap-report.vi.md). Nghiệm thu dùng [test plan không-AI](non-ai-full-system-test-plan.vi.md).

## 2. Khi nào cần QR chuyển tiền?

**QR xuất hiện sau khi đã có một nghĩa vụ trả tiền hợp lệ, tại thao tác “Thanh toán” của người phải trả.** Không hiển thị QR như bằng chứng việc đã hoàn thành hay đã trả tiền.

| Tình huống | Ví dụ | Thời điểm mở QR | Tiền vào ai? |
|---|---|---|---|
| Bounty được người khác nhận và hoàn thành | A thuê B rửa bát giá 30.000đ | Khi nghĩa vụ A trả B đủ điều kiện thanh toán theo nghiệp vụ; source hiện tạo obligation khi B complete | Tài khoản B hoặc kênh nhận tiền đã được xác minh thuộc B |
| Forced reassignment | Bounty A đặt 30.000đ không ai nhận, C được giao bắt buộc | Sau khi hệ thống tạo obligation hợp lệ và đạt điều kiện thanh toán được chốt | Tài khoản C/kênh nhận tiền thuộc C, amount snapshot 36.000đ |

Compensation cần chốt điều kiện đủ quyền nhận: nếu người bị forced cũng bỏ việc, nghĩa vụ không được tự trả/settle trái rule. Có thể tạo obligation ở trạng thái chờ điều kiện từ lúc forced, chỉ mở QR khi việc hoàn thành hợp lệ. Đây là policy triển khai đề xuất để đáp ứng flow, không khẳng định source hiện đã có trạng thái này.

Không cần QR chuyển tiền cho login, tạo nhà, phân công, confirm mùa, cộng Karma hoặc claim Chore Pass. QR invite household là chức năng khác đã có, không phải trọng tâm câu hỏi này.

### Luồng người dùng

```text
A mở “Các khoản phải trả”
 → chọn “Trả B 30.000đ — Rửa bát”
 → backend kiểm tra obligation và kênh nhận tiền
 → tạo payment attempt, trả QR/checkout
 → app hiện B, ngân hàng/kênh nhận, số tiền, nội dung, hạn thanh toán
 → A thanh toán bằng ứng dụng ngân hàng
 → provider/bank báo giao dịch cho backend
 → backend xác minh, cập nhật attempt và obligation đúng một lần
 → A/B thấy “Đã thanh toán” cùng mã giao dịch
```

Một điện thoại không tự dùng camera để quét QR đang hiện trên chính màn hình nó. Cần cho phép mở checkout/app ngân hàng theo khả năng provider, lưu/chia sẻ QR để app ngân hàng đọc từ ảnh khi có hỗ trợ, hoặc copy số tài khoản/số tiền/nội dung. Demo hai máy cũng được. Không giả định mọi app ngân hàng đều hỗ trợ cùng deep link hoặc đọc ảnh QR.

**Hiển thị QR không chứng minh ứng dụng Chore Wars sử dụng Camera.** Nếu camera quét thuộc app ngân hàng thì đó là hoạt động của app ngân hàng; Chore Wars vẫn cần luồng camera riêng như QR invite hoặc chụp proof để chứng minh ngoại vi.

## 3. Hai mức triển khai QR và lựa chọn cho dự án

| Phương án | Làm được gì? | Giới hạn |
|---|---|---|
| VietQR chuyển khoản trực tiếp | Điền sẵn ngân hàng, số tài khoản người nhận, amount và reference | Sinh QR không tự cung cấp bằng chứng giao dịch thành công; cần receiver xác nhận hoặc dịch vụ đối soát riêng |
| Provider QR/checkout có xác nhận server | Tạo order/payment request, QR/link, webhook và query trạng thái | Phải cấu hình kênh nhận tiền đúng beneficiary và xác minh khả năng nhiều người nhận |

**Hướng triển khai đề xuất: provider có QR + xác minh server; khảo sát payOS làm adapter đầu tiên.** Tài liệu payOS có payment request trả QR/checkout, query payment link và signature/webhook. Đây là cơ sở chọn thử nghiệm, chưa khẳng định tài khoản dự án đã được cấp quyền hoặc luồng nhiều beneficiary đã được provider hỗ trợ. [API payOS](https://payos.vn/docs/api/), [luồng thanh toán](https://payos.vn/docs/).

### Điều kiện phải chứng minh trước khi code cố định provider

1. Kênh thu tiền nào thuộc receiver B/C? Provider có cho onboard/link kênh của từng người nhận phù hợp use case không?
2. Backend có thể tạo và đối soát giao dịch cho kênh đó với credential server phù hợp không?
3. Có môi trường test và hình thức demo được chấp nhận không? Xác nhận theo tài khoản/provider thực tế, không suy ra từ tài liệu chung.
4. Người trả có hoàn tất thanh toán từ điện thoại và quay lại app được không?

Kết quả của bước khảo sát là một giao dịch thử gắn với receiver đã xác định, request/response đã che secret và receiver mapping. Có thể demo với receiver đã onboard trước, nhưng phải ghi giới hạn, không báo mọi member đều nhận tự động nếu chưa có.

**Không dùng một tài khoản thu tiền chung rồi đánh dấu A đã trả B nếu tiền mới chỉ vào tài khoản chung.** Thu hộ rồi chi trả là một luồng khác, cần payout và đối soát riêng. Kế hoạch ưu tiên chuyển trực tiếp tới receiver để giữ đúng nghiệp vụ nợ giữa thành viên.

Nếu adapter đầu tiên không đáp ứng beneficiary, giữ abstraction để chọn dịch vụ đối soát phù hợp. QR trực tiếp + receiver xác nhận có thể làm luồng thủ công, nhưng không tự coi là đã đạt yêu cầu môn về dịch vụ thanh toán. Không âm thầm đổi nghiệp vụ thành thu phí nền tảng chỉ để có một checkout.

## 4. Hạng mục P1 — QR chuyển tiền từ BE đến FE

### 4.1. Dữ liệu cần bổ sung

Giữ `PaymentObligation` là bản ghi **ai nợ ai bao nhiêu và vì sao**. Thêm bảng riêng cho việc thu/xác minh tiền để không trộn nghĩa vụ với request tới provider.

| Entity | Field chính |
|---|---|
| `PaymentRecipientAccount` | UserId, bank code/account reference, display name, provider channel reference, verification status, version, active flag |
| `PaymentAttempt` | ObligationId, payer/receiver snapshot, amount/currency, receiver account version, provider, order/reference, checkout URL/QR payload, status, expiry, provider transaction ID, created/verified time, idempotency key, version |
| `PaymentWebhookReceipt` | Provider/channel, event/transaction ID, signature verification result, processed time và nội dung đối soát tối thiểu |

Credential provider lưu server-side qua cấu hình/secret store phù hợp; không đưa vào recipient DTO, APK hoặc log. Không lưu password/OTP ngân hàng. Hiển thị account được che phù hợp ngoài màn xác nhận cần đầy đủ thông tin nhận tiền.

Attempt: `CREATING → PENDING → SUCCEEDED / CANCELLED / EXPIRED / FAILED`, thêm `REVIEW_REQUIRED` cho tình huống cần đối soát. Payment obligation chỉ `PAID` sau bằng chứng hợp lệ hoặc receiver xác nhận trong luồng manual được phân biệt rõ.

Webhook/query báo chuyển tiền đến trễ hoặc sau expiry vẫn phải đối soát, không bỏ qua khoản tiền đã thực nhận vì attempt từng bị đánh expired. Lưu provider status riêng với trạng thái xử lý nội bộ khi cần.

### 4.2. API dự kiến

| Method/path | Quyền và tác dụng |
|---|---|
| `GET/PUT /api/me/payment-recipient-account` | User quản lý kênh nhận tiền của mình, quy trình verify riêng |
| `POST /api/houses/{houseId}/payments/{obligationId}/checkout` | Debtor tạo/reuse attempt cho obligation pending đủ điều kiện |
| `GET /api/houses/{houseId}/payments/{obligationId}` | Bên liên quan đọc trạng thái và audit được phép |
| `POST /api/houses/{houseId}/payments/{obligationId}/refresh-status` | Backend query provider có rate limit; không tin app tự báo success |
| `POST /api/payments/webhooks/{provider}` | Provider callback, xác minh signature và channel; không dùng JWT user cho callback |
| `POST /api/houses/{houseId}/payments/{obligationId}/confirm-received` | Receiver xác nhận thủ công nếu sản phẩm vẫn hỗ trợ đường manual |

Map sang controller/API hiện có khi phù hợp, tránh tạo hai endpoint “settle” với quyền khác nhau mà UI không phân biệt. Debtor có thể bấm “Tôi đã chuyển”, nhưng thao tác này chỉ tạo tín hiệu chờ kiểm tra, **không tự đổi PAID**.

### 4.3. File BE sẽ tạo/sửa

- Domain: `PaymentAttempt`, `PaymentRecipientAccount`, enum status và audit cần thiết.
- Application: `IPaymentGateway`, `PaymentService`, DTO checkout/status/account và validator.
- Infrastructure: provider adapter, repository, entity configuration và migration; typed HTTP client, signature verification, timeout.
- Presentation: payment controller, webhook controller, DI/options cấu hình.
- `BountyService`/`ChoreService`: nối obligation đã có với lifecycle payment; không tạo nghĩa vụ bounty trùng lúc accept và complete.
- `BountyExpirationService`: gắn đúng OccurrenceId/SeasonId, compensation snapshot và điều kiện đủ quyền nhận; không lặp obligation khi retry.

### 4.4. Luồng tạo QR an toàn

1. Load obligation đúng house, debtor và beneficiary; kiểm tra amount >0, currency, chưa paid/cancelled/disputed, đủ điều kiện trả.
2. Nếu đã có attempt pending còn hạn và đúng receiver snapshot thì reuse. Lock/concurrency đảm bảo hai lần bấm không tạo hai active attempt trái policy.
3. Lưu attempt ở trạng thái creating, gọi provider ngoài transaction DB dài, gắn reference/idempotency ổn định.
4. Lưu response QR/link/expiry và trả cho app; nếu timeout query lại provider bằng reference trước khi tạo order mới.
5. Nếu receiver đổi tài khoản sau đó, không âm thầm đổi QR của attempt đang tồn tại; cancel/recreate khi provider cho phép, vẫn đối soát thanh toán đến muộn.

### 4.5. Webhook và đối soát

- Kiểm tra signature theo hướng dẫn provider, transaction/order/channel, amount thực nhận, currency, status và beneficiary mapping.
- Reference của attempt liên kết một obligation; không dùng chuỗi description tự do làm bằng chứng duy nhất.
- Event/transaction unique; transaction DB khóa attempt/obligation, cập nhật receipt/audit/PAID đúng một lần.
- Sai amount, trả thiếu/thừa, giao dịch lặp ở attempt khác hoặc tiền về sau manual settle → `REVIEW_REQUIRED`, không im lặng bỏ dấu vết; policy xử lý được ghi rõ.
- Return URL, ảnh chuyển khoản, QR vừa được quét hay bấm “đã chuyển” không thay thế xác nhận server.
- Outbox/notification sau commit; app query lại sau reconnect. Không cộng/trừ Karma khi thanh toán.

### 4.6. File FE và giao diện

- Sửa `payment_obligations_screen.dart`: chia “Tôi cần trả”/“Tôi được nhận”, nút theo vai trò và trạng thái.
- Thêm `payment_checkout_screen.dart`: tên receiver, amount, reason, reference, QR/link, expiry, copy/save/mở checkout và hướng dẫn thanh toán cùng máy.
- Thêm `payment_status_screen.dart` hoặc view trạng thái trong detail: đang chờ, thành công, hết hạn, cần đối soát; hiển thị nguồn verified/manual.
- Thêm `payment_account_screen.dart`: cấu hình kênh nhận tiền và trạng thái xác minh.
- Bổ sung repository/datasource/model/provider/endpoints/router; app foreground refresh có giới hạn và dừng polling khi rời màn.

### 4.7. Nghiệm thu payment

Bounty A→B 30.000đ và forced A→C 36.000đ đều hiện đúng QR/receiver; verified payment đóng đúng nghĩa vụ một lần. Kiểm thử webhook giả/lặp, sai tiền, sai receiver, cancel, late payment, provider timeout, hai checkout đồng thời, mất mạng sau commit và đổi tài khoản nhận. Dùng PAY-01…09/BOU-10 trong test plan và bổ sung case beneficiary/late payment.

## 5. Hạng mục P2 — Micro và Loa không phụ thuộc AI

**Phương án thực hiện: voice note trong chat.** Một chức năng sử dụng được cả Micro để ghi âm và Loa để phát lại, gắn trực tiếp với chat hiện có.

### BE

- Mở rộng `ChatMessage`/DTO với loại `TEXT/IMAGE/AUDIO`, media reference, duration, MIME, size; không nhét URL audio vào content rồi mong app tự đoán.
- Upload audio qua media service có kiểm quyền house/room, giới hạn duration/size/MIME, lưu storage bền vững.
- Tái sử dụng `ChatService` persist trước broadcast; audio chỉ truy cập bởi người có quyền. Upload không gửi thành công thì không phát message giả thành công.
- Migration tương thích message text cũ; xử lý file chưa được gắn message và cleanup theo policy.

### FE

- Thêm audio recording/playback service và chọn plugin Flutter sau khi kiểm tra tương thích Android mục tiêu.
- Nút mic trong `message_input.dart`: ghi → stop → nghe trước → gửi hoặc hủy.
- `message_bubble.dart`: duration, play/pause/retry, chỉ một voice note phát tại một thời điểm.
- Quyền Micro, app pause/resume, audio focus, cuộc gọi chen vào; không tự autoplay message nhận được.

Nghiệm thu: A ghi âm thật, B nhận message và nghe được trên loa điện thoại; deny permission không crash; mất mạng/retry không gửi trùng. Camera sẵn có cộng Micro và Loa tạo thành **3 loại ngoại vi**, chứng minh trên APK thật. Không tính QR chuyển tiền hiện trên màn hình là một ngoại vi bổ sung.

## 6. Hạng mục P3 — Sửa các điểm lệch nghiệp vụ có ưu tiên cao

Các mục này bắt đầu bằng kiểm chứng case nguồn; nếu capability tương đương đã có thì nối/reuse và cập nhật bằng chứng, không code trùng.

| Work package | Việc sẽ thực hiện | Source chính | Điều kiện xong |
|---|---|---|---|
| W01 — Quyền | Kiểm membership active/house/entity trên summary, warnings, bounty accept, chat JoinRoom; xử lý kết nối sau leave/kick | Controllers, ChatHub, services/repositories | X không đọc/nghe/sửa H1 qua REST hoặc hub |
| W02 — Confirmation | Chỉ ACTIVE khi đủ required confirmations; chặn đường start bỏ qua; reject lưu reason, thay lịch phải review lại | SeasonService, SeasonConfirmation, review screen | SEASON-03…07 đạt |
| W03 — Generate đúng mùa | Tách build/persist, scoping template tường minh, delete theo occurrence.SeasonId; transaction/idempotency cho generate và review | ChoreGenerationService, occurrence repo, SeasonService | Không lẫn mùa, không dữ liệu dở/duplicate |
| W04 — Manual/auto | Manual không tự chạy auto; availability manual chỉ cảnh báo theo BR; auto không bỏ hard constraint khi fallback | SeasonService, ChoreAllocationService, review UI | ALLOC-03…06 đạt |
| W05 — Karma fairness | Summary và score theo assigned snapshot Karma, tính tải cũ; phút dùng cho capacity, bonus ngoài mandatory fairness, rotation có lịch sử | Allocation service/DTO/mobile summary | 2×20 và 4×10 đều là 40 workload |
| W06 — Lịch giờ/frequency | Timezone, availability interval, deadline cấu hình; đủ 9 frequency với anchor/tháng ngắn/custom rule | Entities/DTO/migration, generation, form/availability UI | Deadline 20:00 không thành 23:59; GEN-01…06 đạt |
| W07 — Ghi đúng một lần | DB constraint/conditional update/version/lock phù hợp cho complete, claim, accept, penalty/reward; transaction ledger | Services, entity configurations, repos | Request đồng thời không double Karma/payment |
| W08 — Bounty/forced | Chốt mở bounty/TTL; kiểm expiry server; chọn active/feasible member; audit obligation đầy đủ; failure episode độc lập, giới hạn chain | BountyService, BountyExpirationService, penalty service | BOU-01…13 và PEN-07 đạt |
| W09 — Overdue | Chuyển overdue đúng sau deadline; tách mốc cảnh báo với mốc phạt 12/24/36h; job retry an toàn | Penalty/repository/workers/noti | Không chờ 12h mới biết overdue; không phạt vô hạn |
| W10 — Membership | Cap 6 atomic, leave/rejoin, owner transfer, policy nợ/assignment/reward khi rời; invitation management/disband theo SRS | HouseService/controller/UI | HOUSE-04…10 đạt, không mất lịch sử |
| W11 — Rewards | Create reward tùy chỉnh, redeem cost bằng ledger; final rank snapshot/tie-break; Chore Pass chọn người hợp lệ | Gamification/SeasonEnd/services/UI | REWARD/PASS/RANK test đạt |
| W12 — Hoàn thiện UX | Clone đủ field, share achievement, route trùng, deep link thiếu extra, trạng thái lỗi/loading/empty | SeasonService, router, achievement/profile UI | Màn thật truy cập được và dữ liệu không sai |

Với W06, recurring interval và exception phải có model tường minh. Không tự đổi dữ liệu bool cũ thành giờ rảnh tùy đoán; migrate theo policy giữ tương thích, người dùng có thể xác nhận cấu hình giờ. Với W08, lưu responsibility episode/assignee history hoặc cấu trúc tương đương để penalty người mới không dùng counter người trước.

Không cần Python/AI để thực hiện W01–W12. Bộ rule chuẩn sau sửa cũng là nền dữ liệu/validation để AI nối vào về sau.

## 7. Các policy cần chốt trong lúc thiết kế

Theo decision log D01–D15 của test plan. Đề xuất thực hiện: tất cả required members confirm; auto dùng Karma và hard constraints; manual chỉ warning availability; bounty có TTL tính từ lúc mở; manual receipt do creditor xác nhận; QR verified payment theo nguồn provider; tiền về khác điều kiện cần đối soát.

Hai điểm không tự chọn bừa: thời điểm bounty được mở (assigned hay critical overdue), và giới hạn compensation chain/đủ điều kiện nhận của forced assignee. Chốt trong decision log trước khi code test kỳ vọng, không sửa rule để khớp source hiện tại. Phần không phụ thuộc vẫn tiếp tục triển khai được.

## 8. Lộ trình triển khai và phân công 4 người

Ước lượng theo **ngày công**, không cộng đơn giản thành số ngày lịch nếu có phụ thuộc. Bốn người có thể làm song song sau khi thống nhất contract. Không phải cam kết mọi capability hoàn tất trong 8 ngày cũ.

| Giai đoạn | Công việc | Phụ thuộc | Dự toán |
|---|---|---|---:|
| A | Provider/beneficiary spike, quyết định nghiệp vụ, contract payment/audio | Bắt đầu | 1–2 ngày công |
| B | W01/W02/W03/W07: quyền/lifecycle/concurrency | Policy và baseline | 4–6 ngày công |
| C | QR payment BE+FE, recipient mapping, webhook/status/reconcile | A, obligation audit của W08 | 4–6 ngày công |
| D | Voice note BE+FE, permissions, storage, device | Chat quyền W01 | 2–4 ngày công |
| E | W04/W05/W06: manual/auto/Karma/deadline/frequency | Policy, schema đã chốt | 4–6 ngày công |
| F | W08/W09/W10/W11/W12 còn lại | Lifecycle/schema tương ứng | 4–6 ngày công |
| G | Regression/e2e/release/12 màn/demo | Các nhánh tích hợp | 3–4 ngày công |

Tổng dự toán 22–34 ngày công, cần điều chỉnh sau A và baseline test. Thời gian chờ cấp tài khoản provider/onboarding không tính là code xong. Đây là toàn bộ phần thiếu/không khớp được liệt kê, nên lịch có thể lớn hơn khi chỉ làm QR và audio.

| Vai trò tạm thời | Phạm vi chính | Trách nhiệm tích hợp |
|---|---|---|
| Bạn | Core BE: season/allocation/generation | Oracle nghiệp vụ và migration |
| Thành viên 2 | Payment BE/provider/ledger/concurrency | Beneficiary, webhook, đối soát |
| Thành viên 3 | Flutter payment/account/QR, route/reward UX | API contract và cùng máy/two-device payment |
| Thành viên 4 | Chat audio BE+FE, permissions, release testing | Micro/Loa/storage và E2E |

Đây là phân công đề xuất, chưa gán tên thật hoặc khẳng định đóng góp. Bảng 3 giao diện/người cần xác nhận riêng từ công việc thực; QR/account/status/audio có thể thêm màn nhưng không thay bằng chứng 12 màn cho 4 người.

## 9. Thứ tự nghiệm thu và bộ bàn giao

1. Payment demo A→B đúng receiver/amount, QR → xác minh server → audit; forced 120% đúng điều kiện. Không dùng tiền thật trong test tự động.
2. Micro ghi được, Loa phát được, Camera có luồng riêng chạy thật, permission deny có fallback.
3. Confirmation/quyền/concurrency/Karma/compensation đạt trước khi gắn nhãn product ổn định.
4. Generation/manual/auto/availability/frequency/reward/reuse chạy từ đầu tới cuối theo test plan.
5. APK release dùng API/SignalR thật; không preview, không chỉ emulator URL; kiểm merged manifest và storage bền vững.
6. 12 màn/4 người có route, ảnh/video và phần đóng góp; có version backend/APK/migration khớp nhau.

Bàn giao: migration tương thích và backup, env example không secret, API/docs, test report có PASS/FAIL/BLOCKED, fixture, tài khoản demo, video camera/mic/loa/payment, known limitations và rollback.

## 10. Trả lời ngắn: hiện còn thiếu gì?

- **Thanh toán:** QR chuyển tiền gắn obligation, kênh nhận tiền, tạo attempt/provider, xác minh server, giao diện trạng thái và audit. Source hiện mới tracking/settle thủ công.
- **Ngoại vi:** Micro và Loa chưa thấy luồng hoạt động trong source khảo sát; camera đã có implementation cần test.
- **Nghiệp vụ:** W01–W12 có phần chưa thấy capability và phần code chưa khớp rule; cần thực hiện/test theo từng work package.
- **Bàn giao môn:** ownership 12 màn, APK/server end-to-end, evidence và regression chưa được xác nhận trong phiên khảo sát.
- **AI:** toàn bộ service Python/ML/Gemini và adapter theo kế hoạch AI riêng; không coi là đã có chỉ vì đã viết tài liệu.

## 11. Nguồn cho quyết định QR/provider

- [payOS — luồng QR checkout và webhook](https://payos.vn/docs/).
- [payOS — tạo/query payment request, signature và payload QR](https://payos.vn/docs/api/).
- [VietQR Kit — API tạo QR/chuyển khoản](https://www.vietqr.io/).

Đã tham khảo tài liệu ngày 18/10/2026. Khi code adapter cần kiểm chứng trực tiếp account/channel, beneficiary, môi trường thử nghiệm và contract provider mà dự án được cấp; không hứa khả năng P2P nhiều người nhận từ một credential duy nhất.
