# Kế hoạch triển khai AI Housekeeper bằng Python

Chore Wars — cập nhật **22/10/2026**, đối chiếu baseline source **`0e55613`**. Tích hợp góp ý về ưu tiên bàn giao, checkpoint dữ liệu 3 tháng, Target/label, thực nghiệm, Evaluation Store/Dashboard và Evaluation Specification. Chưa có thuật toán/model hay cấu hình học cuối cùng được chọn.

> Đây là kế hoạch, không thay thế bằng chứng nghiệm thu. Source AI đang được triển khai; xem [báo cáo triển khai và kiểm chứng 22/10/2026](../reports/ai-implementation-status-2026-10-22.vi.md) và [hướng dẫn chạy](../../ai-service/README.md). Bản này thay thế thiết kế cũ về timer, hai Random Forest cố định và trọng tâm dự đoán người nhận bounty.

## 0. Cơ sở và quyết định đã chốt

Đọc cùng [biên bản đồng bộ main](../reports/main-sync-2026-10-20.vi.md), [API](../api/api-specification.md), [database](../database/database-design.md), [system architecture](../architecture/system-architecture.md), [backend architecture](../architecture/backend-architecture.md), [mobile architecture](../architecture/mobile-architecture.md), SRS/Business Rules/Full System Flow và báo cáo AI người dùng đã cung cấp. Các nhãn future vẫn thuộc phạm vi. Khi tài liệu lịch sử khác source đã merge, đối chiếu source và quyết định trong bản này; planned không chứng minh đã có implementation.

**Mục tiêu chính:** hồ sơ hành vi có bằng chứng theo thành viên/season, ghi nhận đúng đóng góp và dùng lịch sử để cải thiện phân công. Demo gia đình dùng hơn một năm bằng dữ liệu giả lập có kiểm soát.

Bounty là bằng chứng về việc chủ động nhận trách nhiệm có thưởng, không phải lý do tiếp tục đẩy việc cho người hay nhận. Gợi ý bounty là chức năng riêng. Phân biệt ba cơ chế: cập nhật thống kê theo event; pretrained model trích xuất ngôn ngữ/ảnh; train model tabular có feature/outcome và đánh giá riêng. Không gọi mọi cập nhật thống kê là train.

### 0.1. Constraint

- C# sở hữu quyền, transaction nghiệp vụ, assignment, Karma, season, payment, consent và proposal. Python không ghi database nghiệp vụ. Flutter chỉ gọi C#, API key/model ở server; bản đầu CPU, không yêu cầu GPU điện thoại.
- DRAFT owner preview/accept rồi vẫn submit REVIEWING và all-active confirmation cùng revision để ACTIVE. Không bật chat SEASON_APPROVAL để bỏ qua flow.
- ACTIVE replan cần owner và tất cả người mất/nhận việc đồng ý; một reject/stale thì không áp dụng phần nào.
- Chat mặc định gọi chủ động; auto cần owner bật và chính sender consent, mặc định false. Public profile chỉ dữ kiện trung tính được phép, inference riêng tư/chưa xác nhận có quyền riêng.
- Chưa triển khai timer/work session/regressor thời lượng. Giữ effort chuẩn, chỉ mở lại khi có nhu cầu và cách thu dữ liệu đáng tin.
- Không train model ai sẽ nhận bounty; không dùng số lần nhận/giúp/thắng mùa để tăng quota bắt buộc. Giữ notification bounty chung, không thêm push nhắm người hay nhận, không siết manual accept bằng rule AI.
- Không đưa payOS/thủ quỹ/deploy/APK release vào scope. Provider/Android thật có nghiệm thu riêng.

### 0.2. Source tái sử dụng

| Đã có | Điểm nối AI |
|---|---|
| ActionProposalService, CHORE_SWAP, URGENT_EVENT | Candidate/preview đi qua validator, consent và transaction hiện có |
| Swap thủ công | Giữ ACTIVE/same-season/normal/unexpired, membership, availability/capacity và bounty/payment locks |
| Urgent UI/card/countdown | Thêm decomposition/timeline, không xây chiến dịch thứ hai; approved ExpiresAt là campaign deadline |
| AllocationEligibilityService, ScheduleTime, SnapshotKarma/Minutes/Difficulty | Chung fixture/constraint; không dùng số dư Karma làm tải |
| ChoreResponsibility, CompletedByUserId | Episode/actual completer; legacy thiếu lịch sử phải có quality |
| Outbox/dedup/quarantine/replay/house coordinator | Reuse crash safety, không publish Kafka trực tiếp thay transaction |
| Private media/voice note/native share | Reuse storage/auth/session; voice note chưa phải STT/TTS |

## 1. Phạm vi chức năng

| Nhóm | Kết quả |
|---|---|
| A — NLU/voice | Hiểu tiếng Việt, hỏi lại ngày/giờ/thực thể thiếu, transcript sửa được |
| B — Prediction | Khảo sát Target đúng hạn/yêu cầu chuyển; chỉ bật model có dữ liệu và giá trị đã kiểm định, fallback rõ nguồn |
| C — Allocation/replan | Baseline xác định và adaptive có gate công bằng/cải thiện |
| D — Swap | Ứng viên hợp lệ, giải thích trước/sau, consent hiện có |
| E — Urgent/Blitz | Micro-task, dependency, người/tài nguyên, timeline có ngân sách |
| F — Risk insights | Cảnh báo có evidence, không tự penalty/đổi assignment |
| G — Chat intelligence | Báo bận/nhờ giúp/xin đổi thành candidate, không tự ghi nghiệp vụ |
| H — Behavioral learning | Đóng góp/trách nhiệm/sở thích/kinh nghiệm theo thời gian |
| I — Season evolution | Source COMPLETED → target DRAFT đã có, owner/review bình thường |
| J — Vision | Nhận xét ảnh có quyền, mức liên quan và bất định |
| K — ML lifecycle và Evaluation Dashboard | Dataset, registry, promotion/rollback, Evaluation Store và lịch sử so sánh baseline/adaptive |

### 1.1. Ưu tiên theo khả năng bàn giao

| Mức ưu tiên | Đầu ra và cách báo cáo |
|---|---|
| P0 — Luồng chính cần hoàn chỉnh | Telemetry → contribution facts → behavior profiles → baseline/adaptive allocation → persist evaluation → dashboard; nghiệm thu end-to-end, không theo số file đã tạo |
| P1 — ML experiment | Ít nhất một Target có task card, readiness, thực nghiệm và báo cáo trung thực; kết luận chưa đủ dữ liệu/không chọn learned model vẫn là kết quả hợp lệ, không gọi là đã có model production |
| P2 — Adapter/capability còn lại | NLU/chat/voice/swap/replan/evolution/Blitz/vision và bounty suggestions vẫn trong phạm vi, có phụ thuộc, trạng thái và checkpoint riêng; không tự xóa tính năng vì ưu tiên P0 |

**Thời gian còn lại:** khoảng **2 tuần tính từ 22/10/2026** theo thông tin chủ dự án. **Ngày/giờ nộp chính thức: CHƯA_XÁC_NHẬN**, cập nhật ngay khi biết; không tự coi ngày cộng 14 ngày là deadline giảng viên đã chốt. Tuần đầu ưu tiên snapshot/telemetry/facts/profile và đường baseline–evaluation; tuần sau ưu tiên dashboard/end-to-end/demo/regression, P1 theo readiness và báo trạng thái adapter P2. Đây là phân bổ dự kiến, không cam kết mọi capability đủ dữ liệu/provider/device trong hai tuần.

P0 phải truy đóng góp đúng người/event, không trùng completion/effort; baseline/adaptive cùng context; kết quả persist/xem được; có ví dụ lịch/lý do/evidence; core vẫn chạy khi AI lỗi. Khi lịch thực tế không đủ làm toàn bộ A–K, bàn giao ma trận phần đã/đang/chưa thực hiện và bằng chứng, không đánh dấu toàn hệ thống hoàn tất. P0/P1/P2 là ưu tiên theo quỹ thời gian này, không tự loại scope.

## 2. Dữ liệu và chỉ số hồ sơ

### 2.1. Đơn vị dữ liệu

Occurrence là đơn vị công việc/chống đếm trùng; responsibility episode là giai đoạn ai chịu trách nhiệm; action event ghi hành động và nguyên nhân; opportunity/observation ghi cơ hội/tương tác thực sự quan sát; evidence liên kết về nguồn có kiểm tra quyền.

Envelope: `eventId`, `schemaVersion`, `houseId`, `actorId`, `subjectMemberId`, `seasonId`, `entityId`, `occurredAt`, `recordedAt`, `correlationId`, `houseSequence`, `eventType`, `payload`. Lưu UTC, tính lịch Asia/Ho_Chi_Minh. Feature chỉ dùng dữ liệu biết tại cutoff. Event muộn tạo profile version mới, không sửa âm thầm manifest báo cáo đã đóng.

Tách missing/unknown khỏi zero. Notification gửi không chứng minh đã đọc. Backfill không tạo giả impression, lý do chuyển, StartedAt hoặc feature quá khứ không tồn tại.

### 2.2. Nguồn cần instrument

| Nguồn | Nội dung |
|---|---|
| Assignment/activation | Actor, assignee, snapshot effort/Karma/difficulty, deadline/start, context lúc giao |
| Responsibility | Started/ended, reason, initiator, người chịu trách nhiệm và actual completer |
| Swap/replan/pass/forced | Các bên ảnh hưởng, consent, chuyển trách nhiệm và kết quả |
| Bounty/payment | Poster/receiver, amount, vòng đời, completion, người/thời điểm xác nhận tiền |
| Availability/preference | Giá trị, hiệu lực, thay đổi; exception ngày khác lịch tuần |
| Season/Karma/rank | Thành viên đủ điều kiện, ledger breakdown và snapshot mùa |
| Chat | Message references, consent, candidate/xác nhận và giao dịch liên quan |
| UI | Hiển thị/mở/phản hồi rõ ràng, request/session ID |

Core events hiện ngắn, chưa đủ dataset; thêm telemetry riêng, không phá wire notification/achievement hiện tại.

### 2.3. Đóng góp thực tế và cách đếm

Theo dõi độc lập **nguồn nhận trách nhiệm** và **kết quả thực hiện**. Một occurrence nhiều episode vẫn chỉ tính một completion/effort cho actual completer. Phân rã theo nguồn episode hoàn thành là các bucket không chồng; lịch sử đường đi là evidence phụ, không cộng lại vào tổng.

Nhận bounty chưa phải hoàn thành. Chuyển một việc có sẵn không làm tăng số việc cả nhà. Chỉ nói nhận thêm so với phần được giao khi có snapshot chứng minh; mặc định dùng nhận trách nhiệm qua bounty.

| Nhóm | Chỉ số |
|---|---|
| Hoàn thành | Occurrence count theo actual completer; legacy fallback có căn cứ và quality |
| Khối lượng | Tổng SnapshotMinutes/SnapshotKarma của việc thực sự hoàn thành, tách NORMAL/BONUS và nguồn |
| Đa dạng | Category có completion, số mẫu/phân bố; chưa taxonomy đáng tin dùng chore/template, không giả category |
| Đúng hạn | Episode đúng hạn / episode đủ điều kiện; transfer trước deadline không mặc định failure |
| Chuyển việc | Yêu cầu do chính assignee / episode được giao; pending/rejected/accepted riêng |
| Giúp đỡ | Tách bounty/swap/pass/forced/urgent, luồng A → B có evidence |
| Điểm | CHORE_COMPLETED/BOUNTY_REWARD/BONUS, penalty, spend riêng; balance không thay đóng góp |
| Rank | Wins/bottom / seasons đủ điều kiện; `1-(rank-1)/(memberCount-1)` khi memberCount >=2 |
| Tiền | Amount distribution/payment confirmed; không gọi xác minh ngân hàng |

SnapshotMinutes 15/30/45 là **effort chuẩn**, không phải phút lao động đo được. Forced completion 0 Karma vẫn có đóng góp nếu source chứng minh.

Metric trả `value`, `numerator`, `denominator`, `sampleCount`, `period`, `asOf`, `source`, `quality`, `evidenceIds`, `profileVersion`. Windows: current season/30 ngày/90 ngày/all-time. Zero denominator trả null/insufficient data.

### 2.4. Bounty trong hồ sơ

Báo riêng lượt nhận và occurrence duy nhất đã nhận. Mỗi cặp member–occurrence có một outcome hiện tại: tự hoàn thành; người khác hoàn thành; chưa hoàn thành/chưa đến hạn; chưa hoàn thành/quá hạn; hủy; không rõ. Completed không đồng thời thuộc pending/overdue-open.

Đã chuyển tiếp là đường đi, có thể cùng kết quả cuối người khác hoàn thành; không cộng hai cột thành tổng outcome. Chuyển rồi quay lại hoàn thành vẫn ghi actual completer đúng.

Tỷ lệ tự hoàn thành trên tập kết quả xác định đủ điều kiện: `self_completed/(self_completed+other_completed)`. Luôn hiển thị denominator và pending/overdue-open/cancelled/unknown; không dùng tỷ lệ này một mình đo reliability. Tỷ lệ đúng hạn riêng có cả failure đủ điều kiện theo episode.

Ví dụ: “Mùa này A nhận trách nhiệm qua bounty cho 8 việc: tự hoàn thành 7; 1 việc chưa đến hạn.” Không kết luận chỉn chu/lười/động cơ tiền bạc. Chất lượng chưa có rubric/outcome riêng thì ghi chưa đủ dữ liệu; vision không tự thành quality label.

### 2.5. Sở thích và bằng chứng

- Preference khai báo hiện tại ưu tiên hơn suy luận. Assigned completion không chứng minh thích. Kinh nghiệm khác sẵn sàng nhận thêm.
- Phản hồi thích/không thích rõ ràng: `(positive+1)/(positive+negative+2)`, kèm số mẫu; làm trơn không tự tạo confidence. Chỉ hiển thị khoảng bất định nếu phương pháp ước lượng đã được version hóa, chưa có thì NOT_COMPUTED, không giả confidence từ score; không phải xác suất nhận bounty.
- Nonaccept không là negative nếu chưa thấy/chưa quyết định/người khác nhận trước. Không train acceptance model.
- Busy/free chính thức dùng khai báo/exception đã xác nhận. Chat chưa xác nhận là candidate riêng tư.
- Levels: confirmed fact, observed interaction, inferred, insufficient data. Public profile không lộ private context/inference.
- Làm nhiều/rank trung bình được giải thích bằng effort/loại việc/Karma/bonus/penalty, không tự bù điểm.
- Không tạo điểm đóng góp tổng hợp hoặc phần trăm AI hiểu gia đình.

## 3. Kiến trúc, model và training

### 3.1. Stack và luồng

Python 3.12/FastAPI/Uvicorn/Pydantic, SQLAlchemy/psycopg/Alembic, confluent-kafka, pandas/NumPy, scikit-learn/joblib, google-genai/httpx, pytest/pytest-asyncio. Lock dependency sau compatibility check khi implementation.

API, telemetry/chat workers, trainer là process riêng. Không train HTTP/startup hoặc tạo consumer theo API replica. Database chorewars_ai riêng, Python không có credential core. Persistent artifacts, đa instance dùng object storage/registry chung.

```text
Flutter → C# auth/controller → context snapshot dưới lock ngắn → release
→ Python API → profile/engine/predictor/Gemini khi cần
→ C# semantic validation → persisted recommendation → preview
→ accept/final approval revalidate dưới house lock → core transaction/outbox
→ SignalR/notification sau commit

Core outbox → Kafka → Python inbox → episode/contribution/profile/evidence
→ AI outbox → C# insight consumer → readonly suggestion

AI data → dataset/feature/label → train/evaluate → registry
→ explicit promotion → predictor nạp artifact được duyệt
```

Application C# chỉ interface/DTO, không EF/HTTP/Kafka/provider SDK. Giữ DI/UoW/CancellationToken/controller mỏng; không thêm generic framework khi use case không cần.

### 3.2. Phương pháp và model ứng viên, chưa chốt thuật toán cuối cùng

**Nguyên tắc:** Target và quyết định sản phẩm cần cải thiện quyết định cách thu dữ liệu, label, baseline và phương pháp thử. Model chỉ được chọn sau thử nghiệm có đối chiếu và phải tạo giá trị khi đưa vào hệ thống. Không có yêu cầu bắt buộc triển khai hai Random Forest đúng hạn/thời lượng. Tên model, cửa sổ thời gian và hyperparameter dưới đây là cấu hình thử nghiệm ban đầu, không phải kết luận về thuật toán tốt nhất.

| Thành phần | Lựa chọn |
|---|---|
| Profile | Thống kê/làm trơn/evidence, cập nhật event, không classifier phẩm chất |
| NLU/chat | gemini-3.5-flash-lite, structured output + semantic validation, không fine-tune chat |
| Vision | gemini-3.8-flash, nhận xét có bất định |
| Đúng hạn | Thử tỷ lệ nền/làm trơn, Logistic Regression, Random Forest, HistGradientBoosting; có thể không chọn learned model |
| Yêu cầu chuyển | Target thử nghiệm riêng, không bắt buộc có model production; so cùng các họ phương pháp trên nếu label hợp lệ |
| Allocation/swap/replan | Baseline greedy xác định; local search là adaptive candidate đầu tiên, phải vượt policy gate |
| Bounty suggestions | Filter/gợi ý theo khai báo/thời gian/kinh nghiệm, không acceptance predictor |
| Duration | Effort chuẩn, chưa timer/regressor |

Model ID trong GEMINI_TEXT_MODEL/GEMINI_VISION_MODEL, giữ lựa chọn catalog đã đối chiếu 20/10/2026; quota/access và chất lượng phải eval bằng project thật trước bật. Không đổi model âm thầm. Tham khảo [Flash-Lite](https://ai.google.dev/gemini-api/docs/models/gemini-3.5-flash-lite), [Flash](https://ai.google.dev/gemini-api/docs/models/gemini-3.8-flash), [structured output](https://ai.google.dev/gemini-api/docs/structured-output).

### 3.3. Feature/label

**T1 bản đầu chỉ phục vụ thử nghiệm risk insight cho trách nhiệm đã thực sự phát sinh.** Mẫu duy nhất theo `(house_id,episode_id,prediction_time,target_version)`, prediction_time là StartedAt đáng tin. Không score lại giữa episode bằng cùng Target nếu feature/horizon đã khác. Ứng viên chưa được giao không có outcome phản thực: không sao chép label của assignee thật sang mọi người. Đưa T1 vào allocation là capability thử nghiệm riêng, mặc định chưa được bật, cần specification/đánh giá policy mới. Không suy ra khả năng giao cho người B chỉ từ model đánh giá người A sau khi đã nhận việc.

Feature T1: loại việc/effort/difficulty, thời gian tới episode deadline, ngày/giờ, tải, availability đã xác nhận, reason và lịch sử trước đó. Feature phải thuộc **context source đã có trong transaction nhận trách nhiệm**, không phải đã tới Python trước prediction_time. Core knowledge/version tại snapshot là mốc as-of; Kafka publishedAt/consumedAt và Python processedAt có thể muộn hơn StartedAt. Thiếu lịch sử/snapshot thì missing/insufficient data, không điền bằng live state hoặc outcome sau này. Label dương là late trên trách nhiệm đủ điều kiện, theo decision table bên dưới.

T2 mẫu episode lúc giao với cùng quy tắc ID/cutoff. Dương khi chính assignee gửi yêu cầu chuyển hợp lệ trong episode; âm khi cửa sổ đã đóng, không có yêu cầu và telemetry đủ. Request bị reject vẫn là đã có request; forced transfer hoặc request của người khác không tự thành dương. Nhãn này không đại diện tính cách né tránh.

Không dùng completion/payment/rank cuối mùa hoặc future feature. Không one-hot user/house ID để học thuộc. Bản đầu train trong nhà và trong từng simulation seed độc lập; không pool cross-house/cross-seed để đạt ngưỡng mẫu.

### 3.3.1. Label Decision Table bắt buộc cho label_builder

T1: y=1 late, y=0 self-completed-on-time. T2: y=1 valid self-request, y=0 observed-no-request. T2 observation window là `[StartedAt, min(EndedAt, Deadline)]`; một yêu cầu hợp lệ trong cửa sổ xác định positive sớm, còn negative chỉ khi cửa sổ đã đóng và watermark/reconciliation xác nhận đầy đủ. Không biến open/missing thành negative. Outcome nghiệp vụ muộn vẫn được lưu nhưng ngoài horizon không đổi nhãn T2 v1.

Ranh giới: CompletedAt <= Deadline là đúng hạn; transfer kết thúc E đúng Deadline được xử lý cùng transfer trước deadline (censored nếu chưa self-complete), transfer sau Deadline chỉ khi EndedAt > Deadline. Quá hạn mở chỉ xác định khi cutoff > Deadline và dữ liệu deadline đủ. Event trùng thời gian được giải theo sequence/transaction ordering; không suy ra thứ tự từ thời gian nhận Kafka.

| Tình huống của episode E | T1 | T2 | Episode/lý do |
|---|---|---|---|
| Chính assignee hoàn thành trước hoặc đúng deadline | 0 | 1 nếu có self-request trong window, không có thì 0 khi đủ telemetry | E kết thúc, feature giữ nguyên tại StartedAt |
| Chính assignee hoàn thành sau deadline | 1 | Theo self-request trong window | E còn trách nhiệm tại deadline; không dùng CompletedAt làm feature |
| Deadline đã qua, E còn mở, chưa hoàn thành | 1 khi dữ liệu tại deadline đủ; thiếu watermark thì UNKNOWN | Đóng window tại deadline, xác định 1/0 chỉ khi đủ dữ liệu | Không chờ completion mới ghi nhận late; episode occurrence khác nhau |
| Transfer trước deadline, E chưa tự hoàn thành | CENSORED_TRANSFER, không gán 1 hay 0 | 1 nếu có self-request; nếu không chỉ 0 khi transfer đóng window và telemetry đầy đủ | Episode mới là sample riêng, không sao chép outcome người mới sang E |
| Transfer sau deadline | 1 nếu E thực sự còn trách nhiệm/chưa hoàn thành tại deadline và nguồn đủ | Theo request trong window; request sau deadline ngoài T2 v1 | Không xóa failure đã xác định của E vì người sau hoàn thành |
| Người khác hoàn thành trước deadline, E không tự hoàn thành | CENSORED_NON_SELF_COMPLETION | Theo window/request, missing linkage thì UNKNOWN | Ghi đóng góp actual completer; không tự gán self-completion cho E |
| Người khác hoàn thành sau deadline | 1 cho E nếu E chịu trách nhiệm tại deadline; nếu đã chuyển trước deadline thì censored | Theo episode/request đúng actor | Phân biệt deadline exposure với completer cuối |
| Hủy hoặc skipped | EXCLUDED_CANCELLED_OR_SKIPPED | Loại khỏi cohort T2 v1, vẫn giữ raw request audit | Không diễn giải cancel/skip là năng lực; trường hợp phân tích khác cần target version khác |
| Deadline đổi trước outcome freeze | EXCLUDED_DEADLINE_CHANGED đối với sample cũ | EXCLUDED_DEADLINE_CHANGED đối với sample cũ | Không thay feature/deadline quá khứ bằng giá trị mới; tái dự đoán cần target/prediction-time contract khác |
| Event đến muộn hoặc sequence gap | PENDING/UNKNOWN tới reconciliation | PENDING/UNKNOWN, không mặc định 0 | Label/data version mới khi đủ dữ liệu; không sửa manifest đã đóng |
| Self-request bị từ chối | T1 độc lập theo kết quả E | 1 nếu request hợp lệ trong window | Reject không xóa việc đã xin chuyển |
| Self-request được chấp thuận/áp dụng | T1 theo thời điểm transfer so deadline | 1 nếu trong window | Liên kết request → applied transfer → old/new episode |
| Forced transfer, không có self-request | Theo transfer trước/sau deadline | 0 chỉ khi window đủ telemetry, nếu thiếu UNKNOWN | Không dùng forced làm nhãn self-request |
| Prediction cho candidate chưa được chọn | NOT_APPLICABLE | NOT_APPLICABLE | Không có responsibility episode thực tế; không train trên nhãn giả |

Nếu nhiều điều kiện cùng đúng: lỗi provenance/gap/unknown chặn label; cancel/skip/deadline-changed áp exclusion; sau đó xét transfer/completion/deadline; T2 xác định actor/request theo window. Raw facts không bị xóa vì loại khỏi dataset. Event đến sau run đã finalize hoặc deadline đổi sau freeze chỉ tạo correction/new dataset version khi cần, không rewrite báo cáo lịch sử.

### 3.3.2. Context snapshot trong transaction nhận trách nhiệm

Tại mọi đường mở episode (activation/claim/bounty/swap/pass/forced/urgent), C# dưới house mutation coordinator và cùng UoW transaction:

1. Validate quyền/constraint, xác định assignee/episode. Chọn StartedAt bằng server clock làm logical prediction time; ghi nhận episode và snapshot thuộc cùng quyết định nghiệp vụ, không đòi timestamp commit nhỏ hơn StartedAt.
2. Chụp context version nhất quán qua repository/transaction, chứa facts source đã đọc hợp lệ và trạng thái **sau khi nhận việc** trong chính transaction: deadline/effort/Karma/difficulty snapshots, reason, assignee, tải có tính việc vừa nhận, membership, constraint, preference và availability/exception versions. Không có completion/outcome episode mới. Historical facts chỉ dùng trạng thái source đã biết tại snapshot, không chỉ lọc occurredAt rồi nhận correction tới sau đó.
3. Lưu AIResponsibilityContextSnapshot bất biến theo episode/prediction_time: snapshot_id, schema/version, captured_at, source house sequence, source record/version references, context hash và feature-context payload tối thiểu. Episode, snapshot và outbox telemetry tham chiếu snapshot **commit/rollback cùng nhau**. CapturedAt sau StartedAt vài mili giây trong cùng transaction không tự là future leakage; kiểm tra provenance theo transaction/version.
4. Sau commit mới dispatcher gửi Kafka; Python xử lý muộn được đọc snapshot đã persist/nhận payload và kiểm tra ID/hash/house. Snapshot chưa hydrate được thì retry/incomplete, không query live state thay quá khứ. Feature lịch sử tái dựng theo source snapshot/event knowledge cutoff; gap thì reconciliation hoặc missing theo spec, không dùng facts source chưa biết tại snapshot.

Phân biệt source_occurred_at, source_recorded_at/source_version, snapshot_captured_at, published_at, consumed_at, processed_at. recordedAt trong envelope là source recording, Python không overwrite bằng arrival time. Core transaction/version chứng minh knowledge: event xảy ra cũ nhưng source chỉ biết sau snapshot không làm feature quá khứ; facts đã trong snapshot vẫn hợp lệ khi Kafka đến chậm.

Derived profile dựng sau chỉ hợp lệ cho sample StartedAt nếu dùng đúng historical source cutoff và feature recipe đã khóa; không dùng latest profile chứa tương lai. Live serving chỉ dùng profile/model available tại execution time, ghi versions/lag thật; retrospective reconstruction để train/eval không được giả là đã phục vụ đúng giờ. Episode đã kết thúc lúc worker xử lý thì chỉ retrospective/shadow, không cảnh báo live cho trách nhiệm không còn mở.

Ví dụ: E StartedAt 10:00:00, snapshot cùng transaction chứa tải/availability lúc nhận; commit 10:00:00.020, Python nhận 10:00:03 vẫn hợp lệ. Availability đổi 10:00:01 không vào feature E dù Python đã thấy; completion 10:10 là label, không feature. Legacy thiếu snapshot/provenance không backfill như đã có prediction as-of.

### 3.4. Điều kiện dữ liệu, training và promotion

Fit preprocessing chỉ train, xử lý missing/unseen category, lưu pipeline cùng artifact. Cấu hình và ngân sách so sánh ở mục 3.7 là ứng viên, không cố định Logistic/RF làm người thắng. Hyperparameter chỉ chọn train/validation, không test.

Tách **OFFLINE_ELIGIBLE** và **PRODUCT_ELIGIBLE**. Offline được thử nếu provenance/label/cutoff hợp lệ, train có hai lớp và còn dữ liệu về sau để đối chiếu; số ít vẫn có thể khảo sát với nhãn exploratory/không đủ kết luận. Không vì chưa đạt 500 mà cấm mọi nghiên cứu; cũng không vì chạy được fit mà đủ dùng sản phẩm.

Các giá trị dưới đây là **cấu hình thực nghiệm ban đầu v1**, không phải định luật khoa học hoặc cỡ mẫu bảo đảm cho mọi gia đình:

| Ngưỡng | Mục đích/lý do ban đầu | Phạm vi và capability bị chặn khi thiếu |
|---|---|---|
| Train >=500 mẫu hợp lệ, >=50 mỗi lớp | Tránh promote từ vài trường hợp hoặc một lớp quá thưa; heuristic cần pilot | Từng Target/từng house hoặc seed; chưa đạt chỉ exploratory/shadow, không bật learned prediction production |
| Holdout >=20 mỗi lớp | Ngăn kết luận quality từ quá ít positive/negative | Báo cáo acceptance cho từng Target, không cộng 20 seed thành một nhà đủ mẫu; thiếu thì INSUFFICIENT_EVIDENCE |
| Brier giảm >=5% tương đối, PR-AUC không giảm | Đòi lợi ích dự đoán đáng kể hơn baseline, tránh chỉ thay model cho phức tạp | Quality gate, chưa là product gate; baseline Brier=0 không chia phần trăm |
| Cấu hình/calibration/threshold có tập thời gian đúng vai trò | Tránh dùng lại validation như kiểm định độc lập | Thiếu tập đủ hai lớp/số mẫu phù hợp thì không phát xác suất/cảnh báo đã kiểm chứng, giữ offline/shadow |

Mọi threshold có config/version, purpose, rationale, scope, blocked capabilities, người/thời điểm thay đổi và lý do trong audit. Có thể sửa từ kết quả pilot/validation **trước khi khóa test**, phải version lại và chạy lại đối chiếu liên quan; không giảm ngưỡng sau xem test để promote. Learning Status báo readiness riêng T1/T2, counts từng lớp, time coverage, pending/exclusion và reason; đủ 3 tháng không đồng nghĩa đủ train. Calibration acceptance/alert budget được đặc tả ở mục 10 trước khi bật capability.

Promotion: Brier giảm >=5% tương đối so baseline xác suất, PR-AUC không giảm, đủ mẫu và calibration được kiểm tra. Baseline Brier=0 không chia tỷ lệ/không promote theo gate này. So cả tỷ lệ train lịch sử và active model nếu có; không đạt giữ baseline/active. Registry lưu cutoff/data/schema/feature/model versions, metrics, data source, hash và audit.

Model tốt hơn chưa chứng minh lịch tốt hơn; muốn tác động lịch phải có specification đúng scope và qua policy gates mục 4. Risk insight chỉ xét gate đúng capability mục 10, không phải giả đã cải thiện lịch. Không train acceptance/duration. DEMO_SYNTHETIC không tự promote REAL.

### 3.5. Định nghĩa Target trước khi chọn thuật toán

Target là kết quả cần ước lượng hoặc quyết định cần cải thiện; không phải tên model. Mỗi Target có task card trong task_registry/target_specs: product decision/capability; sample ID và dedup; prediction time; feature availability/knownAt; label/version; observation window/label-ready cutoff; exclusions/decision table; baseline và primary/secondary metrics; offline/product gates; usage limits và điều kiện dừng. T1/T2 dùng specification mục 3.3 và không tự đổi scope trong code. Hai Target là giả thuyết khảo sát, không thay mục tiêu chính bằng hai model bắt buộc.

| Target | Phương pháp ban đầu và đầu ra | Nơi sử dụng và cách chứng minh giá trị |
|---|---|---|
| T0 — Ghi nhận đúng đóng góp | Tổng hợp occurrence/episode, provenance, evidence; không cần label dự đoán | Dashboard/giải thích đóng góp; đối chiếu facts với giao dịch, không cộng trùng. Đây là yêu cầu chính dù ML chưa đủ dữ liệu |
| T1 — Rủi ro trễ | Ước lượng `p_late` lúc nhận trách nhiệm thực tế; lớp dương là late | Risk insight trên episode đã nhận. Dùng cho ứng viên chưa được giao/allocation là experiment riêng, chưa được hỗ trợ bản đầu |
| T2 — Yêu cầu chuyển trách nhiệm | Ước lượng `p_transfer_request` với label yêu cầu được ghi nhận, không phải tính cách | Cảnh báo/xem xét phương án ít cần đổi; đo PR/Brier, false alerts và yêu cầu chuyển. Chưa qua kiểm định thì chỉ thử offline/shadow, không dùng để giảm nghĩa vụ |
| T3 — Theo kịp thay đổi thói quen | So cửa sổ thống kê, làm trơn và trọng số thời gian trên cùng facts | Profile thích nghi với thay đổi; đo dự báo hành vi tương lai đủ nhãn và adaptation lag trong scenario, không chỉnh sửa số liệu đóng góp đã xảy ra |
| T4 — Lịch khả thi, công bằng và phù hợp hơn | Greedy baseline đối chiếu adaptive search, đầu ra là assignment/start và reason | Gate theo từng đề xuất và policy evaluation mục 4; đây là thuật toán tối ưu, không tự gọi là model đã train |
| T5 — Hiểu lệnh/chat/ảnh | Provider pretrained + schema/rule/clarification, không train bằng chat gia đình | Bộ eval có đáp án: đúng intent/thực thể/thời gian, evidence, uncertain; đo chi phí/latency và hành động sai bị chặn |

Nếu chưa định nghĩa được label quan sát đáng tin hoặc chưa có nơi sử dụng output, chưa mở training job cho Target đó. Bounty là dữ liệu cho T0/T3 và kinh nghiệm có context; không phát sinh Target ai sẽ nhận bounty hoặc ai chỉn chu.

### 3.6. Thuật toán thử nghiệm và lý do đưa vào đối chiếu

| Phương pháp | Cơ chế | Giả thuyết cần kiểm chứng, giới hạn |
|---|---|---|
| Tỷ lệ nền theo train | Cùng một xác suất bằng tỷ lệ outcome lịch sử chỉ trên train | Mốc tối thiểu: model phải hơn việc chỉ đoán tỷ lệ chung; không biểu diễn hiểu từng người |
| Tỷ lệ nhóm có làm trơn | Rate theo loại việc, fallback tỷ lệ trong nhà khi nhóm thưa; prior chỉ từ train | Có thể đủ cho dữ liệu ít; phải báo số mẫu, không suy diễn nhóm thưa thành cá nhân chắc chắn |
| Logistic Regression | Quan hệ tuyến tính trên log-odds với regularization | Mốc learned model đơn giản, kiểm tra được dấu/hệ số nhưng không diễn giải thành nguyên nhân |
| Random Forest Classifier | Ensemble cây học các tương tác/ngưỡng phi tuyến | Kiểm tra phi tuyến có thêm giá trị so logistic; có nguy cơ học thuộc dữ liệu ít, không mặc định thắng |
| HistGradientBoostingClassifier | Boosting cây theo bước trên feature bảng | Challenger thứ hai cho quan hệ phi tuyến; chỉ giữ nếu lợi ích bù độ phức tạp và đáp ứng CPU/RAM/latency |
| Hồ sơ theo thời gian | Window aggregate và exponential decay trên cùng outcome | Kiểm tra lịch sử gần giúp thích nghi hay chỉ tăng nhiễu; contribution facts không bị decay |
| Greedy/local search | Xây lịch hợp lệ rồi thử insert/move/swap dưới constraint | Kiểm tra có cải thiện policy với ngân sách hữu hạn; không phải bằng chứng tối ưu toàn cục |

Không thêm clustering/RL/neural network chỉ để gọi là AI. Nếu nghiên cứu sau này cần họ phương pháp khác, phải có Target, baseline và experiment card mới trước khi chạy; không lấy test hiện tại để tiếp tục tìm người thắng.

Tham chiếu cơ chế/API, đã đối chiếu ngày 22/10/2026: [Logistic Regression](https://scikit-learn.org/stable/modules/generated/sklearn.linear_model.LogisticRegression.html), [Random Forest](https://scikit-learn.org/stable/modules/generated/sklearn.ensemble.RandomForestClassifier.html), [Histogram Gradient Boosting](https://scikit-learn.org/stable/modules/generated/sklearn.ensemble.HistGradientBoostingClassifier.html). Những giả thuyết hiệu quả với Chore Wars trong bảng là thiết kế thí nghiệm của dự án, không phải kết luận từ tài liệu thư viện.

### 3.7. Cấu hình ứng viên và ngân sách thử

Giữ cùng dataset manifest, Target, feature cutoff và temporal folds. Đầu tiên chỉ đổi thuật toán; sau đó mới ablation feature/window để tránh không biết cải thiện đến từ đâu. Mỗi Target dùng cùng danh sách ứng viên tối đa dưới đây, không mở tìm kiếm vô hạn.

| Ứng viên | Cấu hình thử ban đầu |
|---|---|
| B0 — Tỷ lệ chung | Tỷ lệ train, không tune; baseline không dùng outcome test |
| B1 — Nhóm làm trơn | `p=(s+alpha*p_house)/(n+alpha)`, alpha thuộc {5,20}; s/n là outcome dương/known samples theo loại việc trong train, p_house là tỷ lệ train của nhà |
| L — Logistic | C thuộc {0.1,1,10}, max_iter=1000, solver lbfgs, L2 theo API tương thích phiên bản đã lock |
| R — Random Forest | n_estimators=200, max_depth thuộc {4,8}, min_samples_leaf thuộc {5,10}, max_features=sqrt, random_state=42, n_jobs=1: 4 tổ hợp |
| G — HistGradientBoosting | learning_rate thuộc {0.05,0.1}, max_leaf_nodes thuộc {7,15}, max_iter=100, min_samples_leaf=20, l2_regularization=1, early_stopping=false, random_state=42: 4 tổ hợp |

Tổng tối đa 14 cấu hình/Target, gồm 1 B0 + 2 B1 + 3 L + 4 R + 4 G. Không dùng random internal validation của booster thay cho temporal folds. Bản đầu class_weight không reweight, không oversample trước chia tập; dùng PR-AUC để theo dõi imbalance. Thay đổi xử lý imbalance là experiment version khác và phải calibration lại.

Logistic dùng numeric imputation + scaling, categorical one-hot unknown-safe. RF dùng numeric imputation, categorical unknown-safe, không cần ép scaling. G dùng preprocessing riêng tương thích: categorical ordinal với unknown/missing riêng và numeric imputation; bản đầu coi mã category là input số, ghi nhận giới hạn thứ tự giả và không gọi là native categorical. Preprocessor được fit trong từng fold, không lấy vocabulary tương lai. Giới hạn cardinality/category mapping phải nằm trong manifest, không mã hóa member ID.

Với T3, so windows 30 ngày/90 ngày/all-time với decay half-life thuộc {30,90} ngày: `w=2^(-age_days/half_life)`, `weighted_rate=sum(w*y)/sum(w)` trên outcome đủ điều kiện. Báo raw n và effective sample size `(sum(w))^2/sum(w^2)`. Đây là estimate hành vi gần đây, không phải số việc/effort thực tế; không dùng beta confidence interval của count nguyên cho weighted estimate. Unknown không có outcome y để đưa vào mẫu số.

Ngân sách/resource đo trên cùng CPU/process profile, ghi train time, batch inference p50/p95, peak RAM, artifact size. Model nằm trong deadline prediction 5 giây của hệ thống kể cả overhead context/HTTP; không kết luận đủ nhanh chỉ từ benchmark predict() riêng.

### 3.8. Thiết kế đối chiếu và quyết định chọn

1. **Khóa Target/data:** xác nhận task card/label, quality và eligibility gate mục 3.4. Không dùng số lượng synthetic để tuyên bố đủ real data.
2. **Checkpoint sau tháng 3:** profile cập nhật từ event đầu tiên. Tháng 1–3 tạo facts/samples và kiểm tra readiness riêng từng Target. Nếu đủ dữ liệu thì thử expanding folds 1 → 2 và 1–2 → 3, chỉ dùng label sẵn có tại cutoff từng fold. Fold thiếu hai lớp/không đủ tin cậy thì báo exploratory/không thể so, không đổi random split hoặc tăng việc giả để đạt ngưỡng.
3. **Chọn một config mỗi họ:** Brier trung bình thấp nhất, PR-AUC không giảm so baseline trong folds. Nếu Brier chênh dưới 1% tương đối, ưu tiên phương pháp ít phức tạp, rồi latency thấp hơn. Nếu best Brier=0 chỉ exact tie mới dùng tie-break. Không dùng test để quyết định.
4. **Validation tháng 4–5:** feature/config shortlist chỉ chọn bằng folds quá khứ; fit candidate trên tháng 1–3 với label biết tại cutoff. Tháng 4 dùng calibration sigmoid nếu đủ điều kiện. Tháng 5 tách A (ngày 1–15, theo thời điểm dự đoán) để chọn phương pháp/policy và B (ngày 16–cuối tháng) để chọn threshold theo budget đã ghi trước. Chỉ sample có outcome biết trước lúc khóa test mới được dùng; pending vẫn pending. Không gọi A/B hoặc tập fit calibration là kiểm định độc lập cuối. Nếu thiếu mẫu cho các vai trò thì không ép chia, giữ offline/shadow/không chọn learned model. Dùng [hướng dẫn calibration](https://scikit-learn.org/stable/modules/calibration.html), không coi probability cây là tự chuẩn.
5. **Khóa trước tháng 6:** chốt Target/feature/config/calibration method/threshold-selection rule/policy/gates/schedule/scenario manifest. Các phương pháp thua và lý do được lưu; không chọn lại bằng test. Thay đổi do lỗi dữ liệu phải ghi invalidated run, không âm thầm sửa để đạt.
6. **Test walk-forward tháng 6–14:** prediction/profile chỉ dùng quá khứ; báo Brier/PR-AUC/calibration/raw counts theo Target. Retrain theo mục 3.11, giữ cấu hình và không tự promote. Target chưa ready ở tháng 3 có thể tích lũy thêm, nhưng không dùng outcome test để chọn họ model/config/threshold mới; thử nghiệm lựa chọn mới cần holdout/dữ liệu tương lai khác.
7. **Kiểm tra giá trị theo capability:** tách baseline greedy, cùng local search không history và cùng local search có history theo mục 4.7, rồi mới xét chat/learned model đúng scope. P0 không phụ thuộc T1 allocation. Gate preference chỉ kết luận preference; giảm late/request chỉ được tuyên bố nếu có specification và bằng chứng riêng. T1/T2 metric đẹp không đủ cho optimizer, risk/rotation-only chưa được hỗ trợ promotion lịch theo gate hiện tại.

Primary metric predictive là Brier; PR-AUC tính lớp dương đúng Target (T1 late, T2 request). Nếu UI cần p_on_time thì bằng 1-p_late, không đổi nhãn âm/dương giữa các báo cáo. Ngưỡng cảnh báo được chọn theo false-alert budget ghi trước trên validation, khóa trước test; không mặc định 0.5 hoặc tự giảm ngưỡng để báo nhiều insight. Chưa có quyết định budget thì capability cảnh báo xác suất chưa được bật.

### 3.9. Hai cửa xét duyệt và kết quả bàn giao thuật toán

- **Cửa 1 — predictive quality:** label đúng, không leakage, đủ dữ liệu, calibration, Brier/PR gate. Qua cửa này model mới là candidate đủ chất lượng để thử tích hợp.
- **Cửa 2 — product value:** output đúng scope và qua acceptance của capability tương ứng mục 10. Nếu ảnh hưởng lịch phải vượt proposal/policy gates, nếu chỉ risk insight thì kiểm định alert value/budget/operation riêng; không tuyên bố đã cải thiện lịch.
- Winner có thể là thống kê/làm trơn hoặc Logistic, RF, G; cũng có thể chưa có phương pháp đủ tốt. T0/profile vẫn triển khai và manual/baseline vẫn hoạt động.
- Trạng thái theo Target: PROPOSED → DATA_READY → EXPERIMENTED → VALIDATED → SHADOW → PROMOTED; nhánh INSUFFICIENT_DATA/REJECTED. DATA_READY phải có readiness_scope=OFFLINE/PRODUCT và reasons, không ngụ ý đã đạt production chỉ vì được thử. Quyền bật capability do core/ops policy, không do trainer tự quyết.
- Algorithm decision record phải ghi Target/use case, candidates/config đã chạy, dataset/cutoff, cách chọn, baseline, metric/CI, cost/latency, ablation, phương pháp thắng/thua và lý do, feature/model/policy version, capability được phép dùng, rollback và giới hạn real/synthetic.
- Không ghi thuật toán cuối cùng trong tài liệu trước khi có decision record và bằng chứng hai cửa. Khung chọn/phương pháp thử đã xác định; kết luận mô hình nào tốt nhất vẫn là kết quả thực nghiệm.
- Readiness/validation/shadow/promotion gắn từng Target và từng capability, không một cờ AI-ready cho cả hệ thống. T1 có thể đủ offline trong khi T2 thiếu positive. Shadow ghi prediction nhưng không phát cảnh báo/đổi lịch cho người dùng; không coi shadow là đã nghiệm thu production.

### 3.10. Evaluation Store — lưu lịch sử đánh giá trong AI PostgreSQL

Tách **Behavior Profiles** (hành vi/đóng góp của thành viên, mục 2) và **Evaluation Results** (chất lượng lịch/đề xuất/model). Demo cho giảng viên chủ yếu đọc Evaluation Results, không lấy việc profile có nhiều sự kiện hơn làm bằng chứng chất lượng tăng. Cả hai ở AI PostgreSQL nhưng khác bảng, vòng đời và contract đọc.

Python Evaluation Runner là bên tính và ghi kết quả. C# cung cấp API đọc có kiểm tra quyền, Flutter hiển thị; không có công thức đánh giá quan trọng thứ hai trên Flutter. Dữ liệu outcome thật lấy từ telemetry đủ điều kiện; outcome synthetic lấy từ diễn biến simulator, không từ lời giải thích/model tự nhận xét.

**Một Evaluation Run** đại diện một arm/policy trong một giai đoạn, dataset và scenario/seed xác định. Một comparison group ghép baseline với các adaptive arms. Không ghi đè một bộ số mới nhất; chạy lại sau sửa công thức/dữ liệu tạo run/version mới, giữ tham chiếu run cũ. Có thể có baseline và adaptive không dùng model (`model_version=null`), không gán model giả để trông như đã train.

| Bảng dự kiến | Dữ liệu và trách nhiệm |
|---|---|
| evaluation_runs | run_id, comparison_group_id, job/idempotency key, house_id, evaluated_at, evaluation_period_start/end, run_kind (POLICY/MODEL), arm, status, data_source, policy_version, model_version nullable, profile_version/cutoff, data_cutoff, outcome_cutoff, dataset_version/manifest, scenario_id nullable, seed nullable, metric_definition_version, evaluation_config_hash, code/config versions, supersedes_run_id và error metadata |
| evaluation_metrics | run_id + metric_key, value, numerator/denominator, eligible/pending/excluded counts, exclusion breakdown, unit, higher/lower-is-better, definition_version, status VALID/INSUFFICIENT_DATA/NOT_APPLICABLE; không chỉ JSON số rời rạc |
| evaluation_examples | run_id, example_id, house-scoped occurrence/season/recommendation references, before/after snapshot đã lọc, reason/evidence references và snapshot version/hash |
| evaluation_aggregates | aggregate_id, comparison_group/config/period/arms, planned/completed/failed/missing seeds, source run IDs, cách aggregate, paired differences, interval type/level, dispersion/CI, metric versions và manifest hash |
| learning_status_snapshots | house_id, period/asOf, source cutoff, valid unique events, profile evidence count, eligible labeled samples theo Target/lớp, time coverage/earliest-latest prediction/label-ready dates, offline/product readiness + reasons, pending/excluded theo lý do, profile updates, training/model/validation/gate references |

data_cutoff/profile cutoff giới hạn dữ liệu được phép biết lúc tạo đề xuất; outcome_cutoff là thời điểm đủ quan sát để đánh giá kết quả sau đó. Run nhiều quyết định lưu cutoff/version từng decision trong manifest, không giả một profile/model cuối cùng đã phục vụ cả giai đoạn. Run nhiều model do retrain lưu version mapping hoặc tách run con; không lấy model mới nhất đè metadata lịch sử.

Hai chiều nguồn độc lập: `data_source` thuộc REAL/DEMO_SYNTHETIC; `inference_source` thuộc RULE/PROFILE/MODEL/FALLBACK. Fallback ghi thêm intended capability/source và reason; không dùng fallback che synthetic. Pipeline phối hợp có component_sources manifest, trường chính là nguồn quyết định output. Không aggregate lẫn real/synthetic hoặc model-validation với policy-outcome metrics.

Evaluation run/metric exports/recommendation DTOs cùng mang hai trường nguồn trên và `evaluation_mode` khi có optimizer; không chỉ thêm nhãn ở UI trong khi metadata persisted vẫn trộn enum.

Run so B0/S0/H1 lưu thêm search_version, history_enabled, history_feature_set_version, source_context_snapshot IDs/hash và attribution_pair (SEARCH/HISTORY/TOTAL). Source knowledge cutoff khác transport ingestion cutoff, để replay chậm vẫn chứng minh input as-of đúng. Snapshot thu lúc nhận trách nhiệm là dữ liệu core; Evaluation Store chỉ tham chiếu/bản chiếu được phép, không tự tạo lại bằng state hiện tại.

RUNNING có thể cập nhật tiến độ; chỉ SUCCEEDED đủ metric mới xuất kết quả chính thức. FAILED/CANCELLED giữ audit và thông báo thiếu, không hiển thị như 0 hoặc PASS. Ghi metrics/examples và finalize atomically; unique evaluation job + arm + period + seed + definition version ngăn retry tạo hai kết quả. Explicit rerun có job/run ID mới và liên kết supersedes, không tự xóa lịch sử.

Metric definitions được khóa trước run. Sửa công thức tạo definition version mới, không sửa kết quả cũ tại chỗ. Backfill/event đến muộn tạo dataset/run mới nếu muốn đánh giá lại. File CSV/JSON/report export là bản xuất, AI PostgreSQL là nguồn kết quả cho dashboard.

**Learning Status** là snapshot dữ liệu và tiến trình: valid event count dedup theo event ID; evidence count theo evidence duy nhất đủ quyền; labeled sample counts theo Target; pending/excluded counts có lý do; training/model/validation references. Tăng counts chỉ chứng minh tích lũy dữ liệu. Dashboard chỉ gọi cải thiện khi metric đối chiếu/gate tương ứng đạt.

### 3.11. Training Schedule, promotion theo capability và rollback

- Đầu mỗi season, kiểm tra theo Target: cutoff/label readiness, dữ liệu mới hợp lệ, quality/sequence gaps, consent lineage và artifact đang active. Mặc định thử retrain khi chưa có candidate và đủ offline readiness, hoặc có >=50 labeled samples mới kể từ lần fit trước; đây là trigger cấu hình thử nghiệm v1, không tiêu chuẩn khoa học và không bỏ qua class/time coverage gates. Không có dữ liệu mới hữu ích thì SKIPPED_NO_NEW_DATA, không fit cho đủ số lần.
- Training dùng dữ liệu/label đã sẵn có trước cutoff, không đọc season tương lai. Tháng 6 bắt đầu bằng finalist đã khóa; các season sau chỉ refit theo recipe đã đăng ký. Nếu refit calibration, dùng season quá khứ đã đóng gần nhất làm calibration riêng và các season cũ hơn làm fit, không fit cả model và calibrator trên cùng rows. Thiếu tập đủ điều kiện giữ candidate cũ/fallback. Threshold số đã chọn giữ nguyên trong test v1, không tune lại từ outcome test; recipe khác cần holdout tương lai khác.
- Training job tạo candidate/metrics/lineage, **không auto-promote**. Ops xét quality/product/operation gates cho capability cụ thể; model dùng risk insight không tự được cấp quyền score allocation candidates.
- Evaluation schedule: hàng tháng chốt data/profile quality snapshot; có training run thì đánh giá candidate; policy đánh giá theo từng period và toàn bộ paired seeds, ở cả budget-complete lẫn serving mode. Không trộn các lịch này thành một mốc 3 tháng AI tự tốt lên.
- Registry giữ active pointer theo house/Target/capability/data_source cùng approved version trước. Promotion atomic, kiểm tra feature/schema/hash/consent và smoke inference. Artifact lỗi hash/load/schema/NaN hoặc không còn đủ consent thì disable version, rollback bản approved tương thích; không có bản hợp lệ thì RULE/PROFILE hoặc manual fallback, ghi reason/audit và trạng thái dashboard.
- Rollback không sửa kết quả lịch sử hoặc xóa training/evaluation thất bại. Bản sau cần evaluation manifest mới; không quay lại chọn thuật toán bằng holdout đã xem.

## 4. Baseline và mức cải thiện đáng dùng

### 4.1. Thuật toán allocation-baseline-v1

Baseline chính là thuật toán hiện tại trong ChoreAllocationService, không dùng behavioral history/chat/ML. Baseline và adaptive nhận cùng immutable context: occurrence, active member, snapshot, constraint, preference khai báo, availability, fixed assignments.

1. Chỉ phân công NORMAL trong DRAFT/phạm vi hợp lệ; giữ fixed assignments và tính tải của chúng.
2. Sắp việc chưa giao: DueDate tăng → SnapshotKarma giảm → occurrence ID tăng.
3. Lọc active candidate không vượt MaxChoresPerWeek theo ISO year/week của ngày deadline và MaxEffortMinutesPerDay theo ngày deadline tại Việt Nam.
4. FindStart tìm khoảng liên tục trên ngày deadline: availability thiếu/false không hợp lệ; true không slots là cả ngày; có slots dùng slots. Trừ planned intervals đã chiếm, chặn cuối ở deadline, chọn khoảng sớm nhất đủ effort. Không tự tìm ngày khác source v1.
5. Candidate sort tuple tăng: `(total assigned SnapshotKarma, rotation, preference, total assigned count, userId)`.
6. Rotation=1 nếu cùng chore có assignment ở tuần lịch ngay trước tuần deadline trong tập assignment đang xét, ngược lại 0. Đây chưa phải học lịch sử các mùa.
7. Preference: PREFERRED=-1, unknown=0, DISLIKED=1. Chọn candidate đầu, planned start sớm nhất, cập nhật tải trước bước tiếp.
8. Không candidate thì unassigned + reason; không phá hard constraint.

Python baseline_allocator.py là hàm thuần, fixture đối chiếu C#. Cùng context/canonical ID ordering cho cùng output, không random. Không gọi baseline là tối ưu toàn cục. Khi thêm date exception/eligibility mới phải cập nhật cả hai, tạo baseline version mới và chạy parity; không đổi constraint một bên để làm đẹp kết quả.

**ACTIVE replan:** mốc chính là lịch đã duyệt hiện tại trên tập tương lai được phép sửa, giữ fixed/locked items. Baseline v1 là DRAFT generation, không gọi API generation lên ACTIVE. Báo cáo replan tách generation.

### 4.2. Adaptive optimizer ứng viên đầu tiên

Local search và ngân sách dưới đây là cấu hình thử nghiệm đầu tiên cho T4, chưa phải kết luận thuật toán tối ưu cuối cùng. Baseline mục 4.1 là mốc đối chiếu phải giữ; thay optimizer/budget cần experiment version và đánh giá lại, không đổi consent/hard constraints để đạt điểm cao hơn.

Bắt đầu từ copy baseline, local search bằng chèn việc chưa xếp, chuyển người hoặc swap hai việc trong phạm vi; mỗi move tính lại start/tải/eligibility. Sau một move giải phóng capacity, thử chèn lại các việc chưa xếp theo thứ tự baseline. Duyệt occurrence/member canonical ID, nhận move cải thiện tốt nhất, lặp tới không cải thiện hoặc 10.000 evaluated moves. HTTP budget 5 giây; chưa xong trả baseline, không dùng nghiệm phụ thuộc tốc độ máy cho benchmark. Benchmark phải hoàn thành move budget và ghi trạng thái.

Objective theo thứ tự: coverage → công bằng snapshot Karma → giảm DISLIKED khai báo → tăng PREFERRED khai báo → giảm lặp loại việc → kinh nghiệm đủ bằng chứng → giảm churn. **Chưa dùng T1 dự đoán candidate chưa được giao trong optimizer v1.** Risk-only hoặc rotation-only chưa có improvement gate nên không đủ promote một lịch mới. Kinh nghiệm chỉ phá hòa phương án hợp lệ/công bằng; rank/bounty count không tăng quota. Tải tự nguyện hiện tại có thể giảm khả năng nhận thêm hiện tại, không tăng nghĩa vụ mùa sau.

**Giới hạn được chấp nhận cho demo v1:** history chủ yếu tác động qua kinh nghiệm để phá hòa; khi fairness/preference/coverage đã quyết định phương án hoặc candidate chỉ cải thiện rotation/kinh nghiệm, gate có thể giữ nguyên lịch. Profile thay đổi rõ nhưng lịch đổi ít hoặc không đổi là kết quả hợp lệ, không phải lý do sửa dữ liệu cho đẹp. Không tuyên bố local search thắng baseline tức AI học hành vi đã giúp lịch tốt hơn. Capability cho history tác động mạnh hơn phải đặc tả metric/gate/guardrail và khóa trước test mới, chưa nằm trong quyền của optimizer v1.

Hai chế độ đánh giá lưu riêng: `BUDGET_COMPLETE` hoàn thành tối đa 10.000 move để nghiên cứu; `SERVING_DEADLINE` chạy trong 5 giây, timeout trả baseline thật. Báo chất lượng output người dùng thực sự nhận, timeout/fallback count/rate và latency p50/p95; không dùng nghiệm chạy lâu làm bằng chứng serving tốt. Cùng machine/resource profile và context khi đối chiếu. Decision record ghi gate đạt ở chế độ nào.

### 4.3. Công thức so sánh

| Metric | Định nghĩa |
|---|---|
| coverage_count | Số occurrence được xếp hợp lệ trong scope; fixed items giống nhau |
| karma_gap | Max-min tổng SnapshotKarma phân công, tính cả active member tải 0 |
| karma_range_pct | `100*(max(K)-min(K))/mean(K)`; toàn bộ K=0 trả 0 |
| preferred_rate | Preferred assignments / số occurrence được xếp trong giao hai phương án |
| disliked_count | Disliked assignments trên cùng giao hai phương án |
| churn | Số occurrence đổi assignee hoặc planned start so lịch duyệt |

K là planned SnapshotKarma, không balance. Trường cũ KarmaVariancePercentage giữ wire compatibility; UI gọi độ chênh Karma tương đối, không gọi phương sai thống kê. Preferred/disliked chỉ dùng khai báo hiện tại cho gate; unknown không phải dislike. Mẫu số rỗng unavailable. Việc xếp mới ngoài giao báo riêng, không thay mẫu số để tạo cải thiện giả.

Theo dõi riêng effort/count gap, tải/capacity và distribution loại việc. Mặc định source 20 việc/tuần và 120 effort phút/ngày nếu không có setting riêng. Warning effort gap >60 hoặc chore gap >5 vẫn là warning, không tự thành hard constraint mới.

### 4.4. Gate cho từng đề xuất

**Tất cả điều kiện an toàn phải đạt:** zero hard violations; coverage không giảm; karma_gap không tăng; disliked_count trên tập chung không tăng; giữ scope/fixed locks; không tăng quota theo lịch sử bounty/giúp đỡ; replan giữ đủ consent.

Sau đó phải đạt ít nhất một mức cải thiện:

| Mục tiêu | Ngưỡng |
|---|---|
| Coverage | Thêm >=1 occurrence được xếp hợp lệ |
| Công bằng | Karma gap giảm >=10% tương đối và >=1 Karma, baseline gap >0 |
| Preference | Preferred rate tăng >=10 điểm phần trăm và thêm >=1 preferred occurrence trên tập chung |

Đây là ngưỡng sản phẩm ban đầu, không phải kết quả đã đo. Lưu version trong evals/policy_thresholds.yaml và khóa trước test. Không dùng risk/preference suy luận của chính adaptive làm ground truth tự chấm.

**Quyết định v1:** giữ ba improvement gates trên, chưa thêm gate riêng cho risk/rotation. Candidate chỉ giảm predicted risk hoặc repeat rate mà không đạt coverage/Karma/preference thì NO_MATERIAL_IMPROVEMENT, dù metric nghiên cứu có thể tốt. Muốn hỗ trợ capability đó sau này phải có metric/gate/Target specification version mới trước holdout mới, không lách gate bằng lời giải thích AI.

Không đạt: baseline + NO_MATERIAL_IMPROVEMENT. Timeout: baseline + OPTIMIZER_BUDGET_EXCEEDED. Infeasible: unassigned/reasons, không sửa ngoài quyền. Vượt gate mới cho preview/đề nghị đồng thuận, không tự apply.

### 4.5. Gate kết luận thích nghi có ích

Không bắt mọi Target/capability chứng minh bằng giảm trễ. P0 lịch coverage/fairness/preference nghiệm thu theo mục 4.4/10; claim chỉ giới hạn đúng mục tiêu đạt. **Late rate là primary riêng cho claim giảm trễ**, không là cổng bắt buộc cho mọi profile/adapter. Adjustment rate là metric phụ v1, chưa có acceptance claim giảm request; nếu muốn claim đó cần specification riêng trước test.

Late rate tính occurrence đủ điều kiện theo deadline/cutoff, không bounty acceptance. Deadline đã qua còn mở hoặc completion sau deadline là late. Cancel/unknown thiếu căn cứ bị loại và báo count. Các arm cùng task universe; báo completion/exclusion/coverage cạnh late để tránh giảm trễ bằng bỏ việc.

Chỉ tuyên bố giảm trễ trong simulator khi:

- Late rate giảm >=10% tương đối so baseline.
- Paired 95% CI của chênh lệch không chứa 0; paired bootstrap theo seed 10.000 lần với evaluation seed cố định.
- Coverage không giảm, zero hard violations và công bằng không xấu hơn.

Baseline late=0 hoặc thiếu mẫu: chưa đủ điều kiện kết luận, không đổi primary metric sau xem test. Báo raw counts, absolute percentage-point change, relative change và exclusions. Không coi từng event cùng gia đình là mẫu độc lập. Chỉ preference tốt hơn thì chỉ kết luận phù hợp sở thích hơn, chưa giảm trễ. Synthetic không thay đánh giá người thật.

### 4.6. Metric dictionary cho Evaluation Dashboard

Runner dùng chung metric definitions với gate mục 4.3–4.5; dashboard không thay công thức và không cộng các phần trăm khác nghĩa. Mỗi metric có numerator/denominator, cohort, observation window, version, exclusions và đơn vị. Chốt công thức/config trước đánh giá, giá trị chưa đủ điều kiện là null kèm lý do.

| Metric | Định nghĩa báo cáo ban đầu | Ý nghĩa/giới hạn |
|---|---|---|
| Hard Constraint Violations | Số assignment vi phạm ít nhất một hard constraint; breakdown số lỗi theo rule riêng | Một assignment vi phạm nhiều rule vẫn chỉ là một assignment lỗi trong total; breakdown có thể lớn hơn total |
| Task Coverage | Occurrence xếp hợp lệ / toàn bộ occurrence cần xếp trong task universe đã khóa | Không bỏ việc khó khỏi mẫu số; fixed/in-scope counts tách rõ |
| Adjustment Request Rate | Assignment ban đầu trong lịch có ít nhất một yêu cầu điều chỉnh hợp lệ / assignment ban đầu đủ observation window | Tối đa một hit/assignment; loại bot/retry, tách requested/approved/applied. Tính từ lúc giao tới completion hoặc deadline; cutoff chưa đủ thì pending, transfer đóng sớm không mặc định âm |
| Declared Preference Alignment | Preferred assignments / assignments có explicit PREFERRED hoặc DISLIKED cho cặp người–việc | Báo preference-data coverage và unknown count; nếu hai arm khác cohort thì chỉ mô tả, không dùng riêng tỷ lệ này để tuyên bố thắng. Gate preferred_rate vẫn theo cùng tập mục 4.3 |
| Assigned Karma Dispersion | Báo karma_gap và karma_range_pct đúng mục 4.3 | Không đặt tên variance cho range; giữ cả active member tải 0, không dùng balance |
| Workload Concentration | Với total effort >0: `sum((assigned_snapshot_minutes_i/total_assigned_snapshot_minutes)^2)`; total=0 thì N/A | Báo kèm từng người: effort, declared capacity, utilization và số người có thể nhận việc; không coi mọi tải phải bằng nhau |
| Rotation / Repeat Rate | Assignment lặp cùng chore ở tuần liền trước cho cùng người / assignment có đủ lịch sử tuần trước theo rule baseline | Category repeat là metric khác, chỉ có khi taxonomy/version đáng tin; thiếu lịch sử thì unknown, không coi không lặp |
| On-Time Completion Rate | Occurrence hoàn thành đúng hạn / occurrence có outcome đủ xác định | Quá deadline còn mở tính không đúng hạn; chưa đến deadline/chưa completed là pending. Đây là occurrence outcome, khác episode model label |

Capacity để giải thích concentration lấy availability đã xác nhận và giới hạn cá nhân theo cùng eligibility/config của run. Nếu quy đổi capacity phút/ngày, dùng min(phút rảnh hợp lệ, effort limit ngày), không biến giới hạn số việc/tuần thành phút giả. Thiếu capacity không gán 0; không dùng concentration như hard rule ép người capacity khác nhau nhận bằng nhau. Chính sách fairness hiện có và hard constraints vẫn quyết định, không tự đổi vì muốn biểu đồ đẹp.

Preference suy luận từ lịch sử báo riêng `inferred_preference_fit`, có profile version và bất định, không làm đáp án đúng tự chấm AI. Metric mức tiếp nhận bounty không là primary outcome của dashboard.

On-time/late dùng cùng task universe, exclusions và observation definition để giải thích bổ sung cho nhau; không tráo episode denominator với occurrence denominator. Adjustment metric ghi request types đã tính trong config (swap/replan/chuyển trách nhiệm do người dùng yêu cầu), không gộp claim bounty thành yêu cầu sửa lịch nếu không có request tương ứng.

**Ghép so sánh:** chỉ compare run cùng house, period, data source, task/context universe, scenario/exogenous seed, observation rules và metric-definition version. Policy/model/feature history có thể khác vì đó là biến thí nghiệm, nhưng shared inputs/exogenous conditions phải cùng manifest. Snapshot lịch hoặc dataset không tương thích thì API trả INCOMPARABLE và lý do, không vẽ delta giả.

Với REAL, chỉ lịch thực sự được dùng mới có outcome thực tế; không sao chép outcome adaptive sang baseline chưa được thực hiện. Shadow baseline có thể so constraint/coverage/preference trên cùng context, còn on-time/adjustment counterfactual là unavailable nếu không có thiết kế đánh giá thích hợp. Không trình bày so sánh quan sát như bằng chứng nhân quả.

**Delta:** adaptive-baseline theo đơn vị gốc; rate báo điểm phần trăm trước, relative change riêng, baseline=0 trả relative N/A. Chiều tốt/xấu theo metric dictionary; không tô xanh mọi số tăng. Nhiều seed báo paired aggregate/95% CI theo mục 4.5, n seeds thực tế, missing/failed counts và spread. Không bỏ seed lỗi rồi chỉ hiển thị lần đẹp. Aggregate chính chỉ finalize khi đủ cohort đã khóa; bản partial có nhãn rõ và không tuyên bố qua gate.

### 4.7. Tách lợi ích thuật toán tìm kiếm và lợi ích lịch sử

Thiết kế tối thiểu ba arm, khóa config trước test:

| Arm | Thuật toán và input | Vai trò đối chiếu |
|---|---|---|
| B0 — GREEDY_BASELINE | Greedy C# parity mục 4.1; current declarations/constraints, không learned history | Mốc source hiện tại |
| S0 — SEARCH_NO_HISTORY | Cùng local search/objective/gates/budget với H1, nhưng history-based experience trung tính và không truy profile/learned features | B0 → S0 đo phần cải thiện do search |
| H1 — SEARCH_WITH_HISTORY | Chính local search của S0; bật historical experience có evidence/cutoff đúng, không đổi hard constraints/declared inputs | S0 → H1 đo phần đóng góp bổ sung của history trong recipe v1 |

Current declared preference/availability và rule luân phiên hiện có là dữ liệu chung, không tắt ở S0 để tạo lợi thế giả cho H1. Các input khác, initial baseline, code version, budget, candidate enumeration, gate references và resource profile phải như nhau; chỉ history toggle khác. Guardrail/improvement gate serving vẫn so B0 theo mục 4.4, nhưng **attribution history phải so H1 với S0**, không chỉ H1 với B0.

Chạy fixed-context replay cho cả ba trên cùng immutable snapshot để cô lập logic search/history; policy closed-loop dùng cùng exogenous scenario/seed nhưng ghi nhận trajectory có thể khác do quyết định trước. Không giả closed-loop state luôn giống nhau. Báo riêng kết quả fixed-context và closed-loop; REAL offline không tạo outcome phản thực cho việc chưa được thực hiện.

Mỗi metric báo raw values B0/S0/H1, delta search=S0−B0, delta history=H1−S0, delta tổng=H1−B0 theo đơn vị gốc/direction. Relative % dùng mẫu số tương ứng, không cộng các % khác mẫu số. Lưu raw candidate và output sau gate/fallback riêng; **claim cho người dùng dựa trên served output** ở SERVING_DEADLINE, không candidate bị gate chặn.

History delta bằng 0/xấu/không đủ bằng chứng phải hiển thị nguyên trạng. Ví dụ B0 preferred rate 40%, S0 50%, H1 50% thì +10 điểm phần trăm là do search, history thêm 0; dù profile đang tích lũy dữ liệu cũng chưa chứng minh history làm lịch tốt hơn. Claim lợi ích bổ sung history cần metric/scope đã đăng ký và paired estimate/CI phù hợp; không tune lại test để tìm metric có lợi. Với capability chưa có gate như rotation-only, chỉ báo exploratory, không promote hoặc quảng bá production benefit.

Chat/model arms chỉ thêm sau ba arm trên khi đúng capability đã đặc tả. T1 v1 chỉ observed-episode risk insight, không tự thêm model-allocation arm vì model đã qua predictive gate.

## 5. Luồng chức năng

### 5.1. Hồ sơ/giải thích

Business service → transaction/outbox → Kafka → normalizer/episode/contribution builder → metrics/evidence/profile version → C# quyền → Flutter. Giải thích bằng số liệu/template trước; Gemini diễn đạt nếu dùng phải kiểm tra không thêm kết luận ngoài evidence. Không auto sửa điểm/tạo moral label.

### 5.2. NLU, availability, chat

NLU trả intent/entities/temporal scope/missing fields/candidate. Báo bận chưa xác nhận không sửa lịch. Date exception key `(seasonId,userId,localDate)`, row slots rỗng nghĩa bận cả ngày, không row mới dùng weekly. Qua nửa đêm tách ngày; mơ hồ lặp/ngày phải hỏi lại.

EffectiveAvailabilityService chung cho snapshot/allocation/swap/replacement/replan. Giữ DRAFT guard; REVIEWING reject về draft trước sửa; ACTIVE exception ảnh hưởng lịch áp đồng thời replan sau consent, không gỡ guard setter.

Chat auto cần setting nhà và sender consent; kiểm tra lúc enqueue/trước external call. Thu hồi giữa call thì bỏ kết quả; không thể thu hồi bytes đã gửi provider. Raw context TTL 24 giờ, không vào tabular dataset/fine-tuning. Nội dung chat là dữ liệu, không phải chỉ dẫn có quyền vượt policy. System/AI origin không loop. Inference chưa xác nhận không public thành sự thật.

Thu hồi consent áp dụng cả dữ liệu suy ra, không chỉ job đang chờ: xử lý theo bảng lifecycle mục 6.5. Việc người dùng đã xác nhận thành giao dịch nghiệp vụ độc lập giữ audit nghiệp vụ; không vì thế tiếp tục dùng raw/extracted chat cho suy luận mới.

### 5.3. Schedule workflows

- DRAFT owner xin proposal → baseline/adaptive/gate → preview → accept batch revision +1 → review như cũ.
- Swap tối đa 3 candidate hợp lệ → actor chọn → CHORE_SWAP hiện có, không ghi assignee trực tiếp.
- Replan chỉ tương lai NORMAL/ASSIGNED hợp lệ, không sửa completed/expired/penalty/forced/bounty/payment locks. C# tính owner + union old/new assignees, không tin target model. Creator chỉ được tính consent khi thuộc tập required. Reject/stale không partial, không sửa deadline/snapshot.
- Evolution source COMPLETED + target DRAFT đã có, giữ SourceTemplate mapping; không tạo season thứ hai khi accept/sửa ledger mùa đóng.
- Risk rule/profile fallback khi thiếu model; chỉ model validated mới có xác suất. Insight dedup/cooldown theo episode/policy version, không tự penalty/reassignment.

### 5.4. Bounty suggestions riêng

Giữ notification chung. Filter category/time/amount, giải thích preference khai báo/availability/kinh nghiệm; không ưu tiên chỉ vì nhận nhiều, không targeted push theo nhận nhiều, không suy động cơ tiền. Thiếu dữ liệu hiển thị thông thường. Không learned acceptance ranker hoặc thay manual accept constraints.

### 5.5. Voice/vision/Blitz

STT/flutter_tts qua thiết bị, transcript sửa được; quyền/cancel/offline/unavailable rõ, không giả engine luôn offline. Tách voice note M4A, reuse audio/session lifecycle.

Evidence entity/private storage riêng. Chỉ assignee có quyền hoàn thành upload/attach. Complete thêm EvidenceId optional, gửi cả EvidenceId và ProofImageUrl trả 400, giữ legacy read. Verify chỉ nhận EvidenceId hợp lệ, bytes qua core, không fetch URL tùy ý. Hash/version ảnh gắn nhận xét. Vision trả observations/relevance/limitations/UNCERTAIN, không complete hoặc quality label. Chưa attach chỉ uploader đọc; attach rồi active member cùng nhà đọc. Cleanup không xóa completion evidence theo TTL inference.

Blitz Gemini tách task/estimated duration/dependencies; optimizer kiểm tra resource/cycle/parallelism/participants/deadline, nói rõ phần không xếp được. Duration là ước tính chưa học từ timer. Reuse URGENT_EVENT approval và deadline/cutoff, không tạo chiến dịch song song.

### 5.6. AI Evaluation Dashboard — Đánh giá và tiến bộ của AI

Màn báo cáo riêng, không nhập chung với màn hồ sơ thành viên. Luồng: Evaluation Runner → Evaluation Store trong AI PostgreSQL → Python read API → C# kiểm tra quyền/house → Flutter. Luồng học từ event và luồng đánh giá có lịch sử độc lập; run mới không được ghi đè profile hoặc assignment.

Ba khu vực:

1. **Learning Timeline:** từng tháng/season có valid events, evidence, eligible labels, pending/excluded và lý do; thời điểm update profile, train, validation, đổi model. Đánh dấu rõ statistical update khác training, model=null nghĩa không dùng model.
2. **Baseline vs Adaptive:** chọn comparison group/period/data source/arm, hiển thị cùng metric hai bên, số mẫu/mẫu số, absolute delta, relative delta hợp lệ, khoảng dao động/CI, số seed và gate result. Chọn single seed phải ghi single-run, không trình bày như kết quả tổng hợp.
3. **Schedule Examples:** xem before/after từ snapshot lịch sử của run, highlight assignment/time thay đổi, constraints, lý do và evidence được phép. Live schedule đã đổi không thay ví dụ lịch sử; evidence không còn đủ quyền hoặc đã xóa thì hiện unavailable, không lộ raw chat/ảnh.

Header hiển thị run ID/evaluated_at/period/data source, policy/model/profile/dataset/metric versions, input/outcome cutoff và scenario/seed. DEMO_SYNTHETIC là nhãn luôn thấy trong demo cho thầy; không có fake progress score hoặc dấu trained khi chỉ dùng profile/rules.

Baseline vs Adaptive mở rộng so B0/S0/H1 theo mục 4.7, ba cột hoặc chọn cặp. Hiển thị riêng Search Gain, History Increment và Total Change với raw values/counts/CI/gate/fallback; không gộp một nhãn AI improvement. Profile adaptation và schedule impact là hai phần độc lập; history không tăng giá trị lịch phải hiện rõ, kể cả biểu đồ profile thay đổi.

Timeline thêm mốc thay đổi scenario, phân biệt DECLARED_CHANGE (baseline cũng nhận) và HISTORY_ONLY_SHIFT (adaptive quan sát dần); hiển thị adaptation lag theo mục 8.2. Không gán mọi cải thiện sau đổi availability cho ML. Có outcome/quality giảm hoặc không thích nghi thì báo nguyên trạng, không chỉnh generator để ép biểu đồ đi lên.

Mặc định dashboard Evaluation chỉ **owner ACTIVE** của đúng nhà được đọc; không thêm role Teacher/global admin. Owner trình bày từ tài khoản mình; profile facts cả nhà vẫn theo quyền mục 0/2. Deep link/example/evidence cũng kiểm tra quyền lại, không chỉ ẩn nút UI. Lưu kết quả không đồng nghĩa lưu raw chat vô thời hạn; snapshot ví dụ chỉ chứa dữ liệu cần thiết đã lọc, không có provider secret, ops payload, filesystem path hoặc model binary.

Empty/loading/RUNNING/FAILED/insufficient labels/no trained model/incomparable/partial seeds là trạng thái riêng. API/model offline giữ màn báo lỗi rõ, không chuyển số thiếu thành 0. Phân trang run/examples, filter theo period/source/arm; server tính metrics/delta/aggregate, Flutter chỉ format/chart và điều hướng. C# không tự tính lại công thức đánh giá mà validate/ủy quyền dữ liệu đã persist.

## 6. API, idempotency và vận hành

### 6.1. Public/internal contract

Prefix `/api/houses/{houseId}/ai`, JWT hiện có; actor từ session, kiểm tra resource cùng house.

| Route | Hành vi |
|---|---|
| GET /profiles, /profiles/{memberId} | Facts/evidence công khai trong nhà |
| GET /profiles/me/private | Inference riêng của chính người dùng |
| GET /contributions, /contributions/{memberId} | Breakdown season/window |
| GET /learning-report, /models/status | Owner đọc Learning Status/timeline và model validation references, không % hiểu biết; dùng cùng Evaluation Store |
| GET /evaluations/runs | Owner list lịch sử run, filter period/source/arm/status, phân trang |
| GET /evaluations/runs/{runId} | Metadata/cutoffs/metrics/counts/versions/gate của run thuộc đúng house |
| GET /evaluations/comparisons/{comparisonGroupId} | Paired arms/deltas/aggregates/CI, comparability và missing seed counts |
| GET /evaluations/runs/{runId}/examples | Paginated snapshots before/after, deep references đã lọc quyền |
| POST /observations | Idempotent UI observation, không tin client làm business fact |
| POST /interpret, /chat/insights | Candidate/clarification, không auto-apply |
| POST /schedules/propose, /schedules/replan, /schedules/swap | Context core, typed preview |
| POST /seasons/evolve, /urgent/plan | Reuse target season/campaign |
| POST /predictions/evaluate | Batch readonly, source/quality |
| GET /bounties/suggestions | Actor-scoped, không inferred acceptance probability |
| GET /recommendations/{id}; POST /recommendations/{id}/accept hoặc /reject | Server payload, một linked proposal |
| GET/PUT /settings, /me/consent | Owner bật nhà, member tự consent |
| GET /failed-events; POST /failed-events/{id}/replay | Owner proxy đã xác minh house |

Evidence: POST `/api/occurrences/{id}/evidence`, GET `/api/evidence/{id}`, POST `/api/occurrences/{id}/ai/verify-proof`. Không work-session endpoints.

Internal snapshot/export: `/internal/ai/houses/{houseId}/snapshot`, `/telemetry-export` dùng service auth khác JWT. Callback gắn job/request scope house/actor/purpose/cutoff, recheck membership/consent. Không liệt kê mọi house cho inference. Training/promote/simulator/unknown-house replay qua ops CLI, không mobile.

Python `/v1/` gồm profiles/contributions, schedules propose/replan/swap, seasons evolve, urgent plan, interpret/chat insights, predictions evaluate-batch, vision verify-proof, failures/replay và health. Thêm house-scoped read routes dưới `/v1/houses/{houseId}/evaluations/` cho runs/detail/comparisons/examples và `/learning-status`; core bridge cấp scope theo owner đã kiểm tra. Client không tự truyền house/job tùy ý tới Python. Export schema/fixtures dùng chung C#, kiểm tra auth/tenant ở cả hai.

Evaluation endpoints mobile chỉ đọc, không có POST chạy training/evaluation hoặc sửa metrics. Runner/ops tạo run qua luồng nội bộ; C# không mở write proxy cho người dùng. API detail/example không nhận reference sang nhà khác; run/aggregate/pair phải kiểm tra từng source house, data source và permissions. Không trả artifact location/ops config nhạy cảm.

### 6.2. Recommendation/concurrency

Lưu house/actor/kind, request ID/input hash, server payload, context fingerprint, profile/model/policy/prompt/schema/feature versions, evidence/asOf/expiry và linked proposal. Hai trường độc lập: data_source=REAL/DEMO_SYNTHETIC; inference_source=RULE/PROFILE/MODEL/FALLBACK, fallback_reason và component_sources khi phối hợp. Không có một enum trộn REAL với RULE_FALLBACK. States GENERATING/READY/ACCEPTED/APPLIED/FAILED/REJECTED/STALE/EXPIRED.

Unique `(houseId,actorId,clientRequestId)`: cùng ID/input trả cũ, khác input 409, GENERATING 202 không thêm provider call. Fingerprint SHA-256 canonical context season/revision/membership/assignment/episode/status/snapshot/deadline/preference/availability/constraint/locks; không now/chính proposal consent. Recheck quyền/consent/time độc lập hash.

Inference ngoài lock. Accept/final approval recompute dưới coordinator; stale 409, không regenerate rồi áp payload chưa xem. READY TTL 15 phút, AI swap/replan chờ consent 15 phút, Blitz 5 phút; approved campaign theo deadline nghiệp vụ. Append SCHEDULE_REPLAN enum, không đổi persisted values.

### 6.3. Kafka/recovery

Topics mới ai.telemetry.v1/ai.chat.v1/ai.insight.created.v1, giữ core wire. Envelope immutable, houseSequence tăng trong transaction/lock; telemetry partition house, không thay core dispatcher identity/dedup.

Python inbox/projection/outbox commit trước offset. Giữ history out-of-order/late, không vứt outcome vì sequence cũ. Gap đánh dấu profile/cutoff incomplete tới reconciliation. Provider qua job sau inbox commit, không giữ DB transaction/poll chờ Gemini. Retry theo policy hữu hạn, poison cách ly/audit; unknown-house chỉ ops, owner không tin payload tự khai scope.

### 6.4. Operation/security

- Env secrets tách inference/core callback/ops, không app/Git/log; AI/DB/trainer không expose public mặc định.
- Deadline prediction/optimizer 5 giây, NLU/chat 20, vision/urgent 30. Inference retry tối đa 1 cùng ID, mutation không replay mù. Benchmark optimizer theo move budget mục 4.
- Rate/concurrency/context/image-size/cost limits theo house. Cache kèm house/actor/input/context/profile/model version.
- Health không gọi provider tốn phí liên tục; capability/fallback rõ. AI lỗi vẫn dùng manual.
- Artifact registry tin cậy/hash/version, backup riêng. Flags mặc định off, không auto migrate/backfill/train/promote lúc startup.
- Raw chat TTL24h, ảnh không giữ ở Python sau inference, metadata-only logs. Dataset tối thiểu có scope, demo namespace riêng. Consent thu hồi dọn pending context, không xóa audit giao dịch đã áp dụng.
- Monitor latency/lag/gaps/errors/retry/quarantine/fallback/stale/data quality/cost/model-policy versions; owner chỉ dữ liệu nhà mình.

### 6.5. Consent revocation và vòng đời dữ liệu dẫn xuất

Lineage phải gắn message/sender/consent version với extracted evidence, projection, dataset feature và dashboard example. Consent đang bật không cho phép đưa raw chat vào training; bảng này còn áp dụng structured chat-derived feature nếu use case đã được cho phép. Không có lineage thì không đưa feature đó vào model.

| Dữ liệu khi sender thu hồi consent | Xử lý |
|---|---|
| Queued/running context, cache, provider response | Chặn call mới, cancel job nếu được; xóa context tạm/cache, bỏ response đang về; audit tối thiểu không có nội dung |
| Extracted evidence và inference chưa xác nhận | Đánh dấu revoked, xóa nội dung dẫn xuất khỏi serving store; không trả qua profile/recommendation mới |
| Profile projection có phụ thuộc chat | Invalidate/rebuild bỏ nguồn revoked, tăng version; business facts độc lập vẫn giữ. Trong lúc rebuild không serve inference cũ như còn hợp lệ |
| Dataset/feature snapshot | Loại/che phần chat-derived và ngăn dùng train mới; manifest lịch sử giữ hash/audit nhưng ghi WITHDRAWN_SOURCE, không tuyên bố còn tái lập đầy đủ. Dataset mới có version mới |
| Candidate/active artifact dùng nguồn revoked | Suspend capability/model phụ thuộc, không đợi kỳ retrain để ngừng dùng; rollback bản không phụ thuộc hoặc profile/rule/manual fallback. Chỉ bật lại sau dataset sạch và quality/product checks |
| Dashboard example/evidence | Redact nội dung/ẩn link, hiện EVIDENCE_WITHDRAWN; không mở raw bằng cache/deep link. Aggregate không có nội dung cá nhân có thể giữ audit, ghi giới hạn nguồn và không dùng như evidence đang hiệu lực |
| Giao dịch đã xác nhận: availability/swap/completion/payment | Giữ business audit/facts theo quyền hiện có; đã xác nhận là nguồn nghiệp vụ độc lập. Không xóa assignment/ledger hay consent của bên khác |

Revocation event/tombstone có version, replay/restore backup phải áp lại để không hồi sinh nguồn đã rút. Historical numeric evaluation không âm thầm đổi để đẹp; redaction/withdrawal có audit và comparability status. Owner không có quyền bỏ qua revocation của member. AI unavailable trong thời gian rebuild không chặn core manual.

## 7. Manifest file tạo/sửa khi triển khai

Đường dẫn tính từ repo root. Đây là công việc tương lai, không phải đã tạo code trong lần sửa doc này. File generated chỉ sinh khi implementation, không sửa migration lịch sử.

### 7.1. Python — tạo mới

```text
ai-service/
  pyproject.toml, dependency lock, Dockerfile, README.md
  app/main.py, config.py, dependencies.py
  app/api/health.py, security.py
  app/api/v1/{profiles,contributions,recommendations,predictions,nlu,chat,vision,failures,evaluations}.py
  app/schemas/{common,events,context,behavior,opportunities,recommendations,learning_tasks,evaluations,specifications}.py
  app/ingestion/{consumer,normalizer,episode_builder,contribution_builder,opportunity_builder,reconciliation,quarantine,consent_lineage}.py
  app/behavior/{evidence_builder,profile_builder,profile_explainer,contribution_metrics,responsibility_metrics,bounty_participation_metrics,preference_inference,temporal_patterns}.py
  app/services/{profile_service,recommendation_service,prediction_service,nlu_service,chat_service,vision_service}.py
  app/engines/{eligibility,fairness,baseline_allocator,allocation_optimizer,swap_optimizer,replan_optimizer,bounty_suggestions,evolution_engine,blitz_optimizer,policy_gate}.py
  app/ml/{task_registry,readiness,dataset_builder,feature_builder,label_builder,baselines,candidates,temporal_validation,experiment_runner,train,evaluate,model_registry,predictor}.py
  app/evaluation/{runner,store,metric_definitions,comparison,aggregator,learning_status,examples}.py
  app/clients/{gemini_client,core_context_client}.py
  app/storage/{db,models,repositories,artifact_store}.py
  app/messaging/{publisher,outbox}.py
  app/workers/{telemetry_worker,chat_worker,training_worker}.py
  scripts/{seed_demo,replay_history,train_candidate,evaluate_walk_forward,compare_policies,promote_model}.py
  simulation/{family_scenario,environment,chat_scenarios,evaluation_oracle}.py
  evals/policy_thresholds.yaml, evals/metric_dictionary.yaml, evals/acceptance_spec.yaml
  experiments/{target_specs,candidate_configs}/, decision_records/
  evals/labeled language/vision fixtures
  migrations/, contracts/, tests/{unit,contracts,integration,scenarios}/
```

Không tạo acceptance ranker, work-session hoặc duration trainer. Category dictionary version hóa từ chore/template mapping; unknown giữ rõ. profile_explainer chỉ diễn đạt facts/evidence, không tự thêm phẩm chất.

task_registry/target_specs quản lý Target và label contract; candidates/candidate_configs khai báo đúng tập thử, không hard-code RF làm winner; temporal_validation/experiment_runner chạy folds/calibration/selection có audit; decision_records lưu kết quả chọn/bác bỏ và capability được phép bật. Các YAML/JSON ở đây cũng là file dự kiến khi implementation, lần này chưa tạo code/config thực thi.

evaluation/runner điều phối đánh giá và ghi Store; metric_definitions/metric_dictionary là nguồn công thức có version; comparison/aggregator kiểm tra pairing và CI; learning_status dựng snapshot tiến trình; examples lọc/lưu snapshot lịch sử. ml/experiment_runner và scripts/evaluate_walk_forward.py, compare_policies.py gọi chung runner/store, trả run/group IDs; không có một pipeline JSON-only khác làm nguồn số trên dashboard. store dùng SQLAlchemy/repository hiện có. Alembic tạo Evaluation Store/indexes khi triển khai, không tạo EF bảng evaluation trong core.

readiness trả trạng thái/counts/reasons theo Target; consent_lineage liên kết và invalidation đúng mục 6.5. acceptance_spec tách guardrails/improvement goals/capability/threshold rationale/version/lock metadata, không chỉ một boolean AI passed. Các bộ đặc tả trước code sâu theo mục 10.6, không thêm file thực thi trong lần chỉnh tài liệu này.

### 7.2. Backend — tạo mới

Prefix Application/Domain/Infrastructure/Presentation thuộc `backend/src/`. Mỗi class/interface một file; tên nhóm DTO dưới đây tách type đúng quy tắc repo.

| Vị trí | File/nhóm dự kiến |
|---|---|
| Application/DTOs/AI | AIContextSnapshot, AIResponsibilityContextSnapshotDto, request/response/recommendation DTOs, AITelemetryEnvelope có snapshot reference/hash/source version, profile/contribution/observation/consent DTOs; AIEvaluationRunDto, AIEvaluationMetricDto, AIEvaluationComparisonDto, AIEvaluationExampleDto, AILearningStatusDto và paginated requests/responses |
| Application/Interfaces/Services | IAIHousekeeperService, IAIHousekeeperClient, IAIContextBuilder, IAIRecommendationService, IAITelemetryPublisher, IAIProfileService, IAIConsentService, IEvidenceService, IEffectiveAvailabilityService, IAIFailureClient; IAIEvaluationService, IAIEvaluationClient cho read bridge |
| Application/Interfaces/Repositories | IAIRecommendationRepository, IAIResponsibilityContextRepository, IAIConsentRepository, IAIObservationRepository, IEvidenceRepository, IMemberAvailabilityExceptionRepository |
| Application/Services/AI | AIHousekeeperService, AIContextBuilder, AIRecommendationService, AIResultValidator, AIInsightService, AIProfileService, AIConsentService, AIObservationService, AITelemetryService; AIEvaluationService kiểm tra owner/house và validate response, không tính lại metric |
| Application/Services | EvidenceService, EffectiveAvailabilityService, ScheduleChangeService |
| Domain/Entities | AIRecommendation, AIResponsibilityContextSnapshot, AIInsight, AIObservation, HouseAiSettings, MemberAiConsent, MemberAvailabilityException, ChoreEvidence, CampaignTaskPlan |
| Domain/ValueObjects | MinuteWindow |
| Infrastructure/AI | AIOptions, AIHousekeeperHttpClient, AIFailureHttpClient, AIEvaluationHttpClient |
| Infrastructure/Repositories | Repositories theo interfaces; settings/insight qua repository tương ứng, không CRUD framework mới |
| Infrastructure/Data/Configurations | Configuration các entity mới; unique request/observation/date exception/insight, FK giữ audit |
| Infrastructure/Messaging/AI | AITelemetryPublisher, AIInsightConsumer, AIInsightScopeResolver |
| Presentation/Controllers | AIHousekeeperController, AIRecommendationController, AIProfileController, AISettingsController, ChoreEvidenceController, AIFailedEventController, InternalAIContextController; AIEvaluationController chỉ đọc và scope đúng nhà |
| Infrastructure/Migrations | AddAIRecommendationsConsentAndObservations; AddAvailabilityExceptionsAndScheduleReplan; AddChoreEvidenceAndCampaignPlans, Designer/model snapshot do EF sinh |

AIResponsibilityContextSnapshot/config/repository/DbSet nằm trong batch core AI đầu, unique episode + prediction_time + snapshot version, payload/hash bất biến và FK giữ provenance. Mọi service mở episode ghi snapshot cùng episode/outbox; AIContextBuilder tái sử dụng nguồn context, không gọi HTTP/Python trong transaction. Snapshot endpoint đọc được đúng snapshot ID/house, không trả latest như bản cũ. Python normalizer/feature_builder dùng source-context cutoff, không dùng consumedAt làm eligibility cutoff.

AI Alembic: inbox/history, episode/outcome, contribution facts, opportunities/observations, profile/evidence, dataset/training/registry/prediction audit, quarantine, AI outbox và evaluation_runs/evaluation_metrics/evaluation_examples/evaluation_aggregates/learning_status_snapshots ở mục 3.10. Core không copy profile/evaluation database tạo hai nguồn sự thật.

### 7.3. Backend — sửa hiện có

| File/nhóm dưới backend/src | Thay đổi |
|---|---|
| Application/Services/ActionProposalService.cs; DTOs/Proposal/ActionProposalDTOs.cs; Domain/Entities/ActionProposal.cs; Domain/Enums/ProposalType.cs; proposal config | Additive replan/Blitz metadata, linked recommendation/consent/fingerprint |
| Domain/Entities/House.cs và config | AiTelemetrySequence trong transaction, không thay fingerprint |
| Application/Services/ChoreAllocationService.cs, AllocationEligibilityService.cs, ReplacementSelector.cs | Baseline parity/effective availability/batch apply, không đổi rule làm đẹp benchmark |
| Application/Services/SeasonService.cs, SeasonEndService.cs | Activation/snapshot/evolution/telemetry, không ghi rank mùa đóng |
| Application/Services/ChoreService.cs, ChoreClaimService.cs, ChoreResponsibilityService.cs, BountyService.cs, BountyExpirationService.cs, GamificationService.cs, OverduePenaltyService.cs | Instrument start/end/complete/transfer/payment/cutoff đúng transaction/actor |
| Application/Services/HouseService.cs, HouseAdministrationService.cs, HouseholdResolutionService.cs | Membership/owner/archive/consent context và invalidation, giữ nghĩa vụ mở |
| Application/Services/ChatService.cs | Consent-gated job và chống AI loop |
| Availability DTO/repository/config; CompleteChoreRequest.cs; ChoreOccurrenceResponse.cs; Mappings/ChoreProfile.cs | Date exception, EvidenceId/summary additive, legacy proof |
| Application/Interfaces/Repositories/IUnitOfWork.cs; Infrastructure/Repositories/UnitOfWork.cs; Infrastructure/Data/AppDbContext.cs | Repositories/DbSets/config giữ Application độc lập EF |
| Infrastructure/Messaging/OutboxEventPublisher.cs; Workers/OutboxDispatcherWorker.cs; Messaging/Kafka/KafkaTopics.cs | Topic/envelope AI, giữ stable core identity/crash boundaries |
| Infrastructure/Messaging/Recovery/EventScopeResolver.cs và adapter | House-verified failed event proxy, không lộ unknown-house |
| Infrastructure/Workers/MediaCleanupWorker.cs | Evidence orphan cleanup theo lifecycle |
| Presentation/Extensions DI; Program.cs; appsettings templates | Internal auth/options/clients/flags/health |
| Presentation/Hubs/ChatHub.cs, ActionProposalRealtimePublisher.cs và registry nếu cần | Group/leave-kick revocation, insight sau commit |

### 7.4. Flutter — tạo/sửa

Tạo `mobile/lib/features/ai/`: data/models/ai_models.dart, data/services/ai_api_service.dart và ai_speech_service.dart, data/repositories/ai_repository.dart, presentation/providers/ai_providers.dart. Screens: ai_housekeeper_screen.dart, family_insights_screen.dart, member_behavior_screen.dart. Widgets: recommendation/risk/timeline/consent/evidence/contribution breakdown.

Evaluation Dashboard tạo data/models/ai_evaluation_models.dart, data/repositories/ai_evaluation_repository.dart, presentation/providers/ai_evaluation_providers.dart, presentation/screens/ai_evaluation_dashboard_screen.dart, ai_evaluation_run_detail_screen.dart và widgets/learning_timeline.dart, baseline_adaptive_comparison.dart, evaluation_metric_card.dart, schedule_comparison_example.dart. Reuse ai_api_service/Dio/auth, không thêm network stack. Learning report là khu vực timeline của dashboard, không làm màn khác với công thức riêng. Cache keys gồm session/house/run/group/filters; đổi tài khoản/leave-kick hủy request và clear dữ liệu tương ứng.

Tạo chore evidence repository/vision feedback panel. Không timer panel/provider.

| File/nhóm dưới mobile/lib | Bổ sung |
|---|---|
| core/network/api_endpoints.dart, core/router/app_router.dart | Endpoints/routes, owner Evaluation Dashboard/detail, reuse Dio/session refresh |
| features/house/presentation/screens/review_schedule_screen.dart, availability_screen.dart, house_settings_screen.dart | Preview/date exception/settings/consent/dashboard |
| features/chore/presentation/screens/chore_detail_screen.dart | Swap/risk/evidence/vision |
| features/chat/presentation/screens/create_urgent_event_screen.dart, chat_room_screen.dart | NLU/chat insight/Blitz preview |
| features/chat/presentation/widgets/interactive_action_card.dart, urgent_event_banner.dart | Replan/consent/timeline/server countdown |
| features/chat/data/models/action_proposal_model.dart, data/services/chat_signalr_service.dart, providers/action_proposal_providers.dart, chat_providers.dart | Additive metadata, account/session-safe callbacks |
| features/bounty/presentation/screens/bounty_board_screen.dart, bounty_detail_screen.dart | Filter/gợi ý riêng, evidence, không targeted push |
| features/house/data/repositories/failed_event_repository.dart, presentation/screens/failed_events_screen.dart | CORE/AI origin, owner-only metadata/replay |

Sửa mobile/pubspec.yaml/lock và platform permission config sau compatibility check speech_to_text/flutter_tts. Không tạo auth/network stack khác. Có source không đồng nghĩa đã nghiệm thu ngoại vi.

baseline_adaptive_comparison.dart/ai_evaluation_models.dart nhận arm B0/S0/H1 và server-computed search/history/total deltas; learning_timeline.dart tách profile change với schedule impact. Các widget không tự tính causal attribution hoặc đổi nhãn search improvement thành model learning.

### 7.5. Test/hạ tầng/tài liệu tương lai

Python unit/contract/integration/scenarios, C# `backend/tests/UnitTests/AI/` và `IntegrationTests/Infrastructure/AI/`, Flutter `mobile/test/features/ai/`. Dùng fixture/schema chung.

Khi implementation sửa .env.example/.gitignore/docker-compose.yml opt-in AI profile; tạo backend/scripts/test-ai.ps1, tích hợp runtime script khi cần; không commit secret/dataset/model binary.

Khi code cập nhật API/database/system/backend/mobile architecture/deployment guide, metric/label dictionary, AI runbook/reports. Lần hiện tại chỉ plan/index/banner lịch sử, không thực hiện migration/codegen.

## 8. Thứ tự thực hiện và demo hơn một năm

### 8.1. Giai đoạn

| Giai đoạn | Đầu ra |
|---|---|
| 1. Contract/metric/label | Schema/source mapping/ví dụ/chống đếm trùng |
| 2. Python nền và Evaluation Store | API/DB/auth/inbox/outbox/retry/restart, versioned run/metrics/schema |
| 3. Telemetry/contribution | Episode/actor/outcome đối chiếu nguồn |
| 4. Profile/dashboard/evidence | Giải thích đúng, không suy phẩm chất |
| 5. Baseline/simulator/Evaluation Dashboard | C# parity, replay seed, thresholds/dictionary khóa; persist runs, owner API, timeline/compare/examples trước khi dùng trình bày |
| 6. Adaptive P0; adapter P2 theo phụ thuộc | Chốt gate allocation trước; swap/replan/evolution có checkpoints consent/stale/concurrency riêng |
| 7. NLU/chat/voice | Consent/extraction/preview/confirm |
| 8. Chọn phương pháp học | Target card, đối chiếu ứng viên/config, temporal eval, hai cửa predictive/product, decision record và registry hoặc fallback |
| 9. Bounty suggestions/Blitz/vision | Tách khỏi hồ sơ, không tự ghi nghiệp vụ |
| 10. Regression/bàn giao | Reports/runbooks, tách source/provider/device evidence |

Hồ sơ đúng là checkpoint trước train. Không cam kết dữ liệu thật đủ trong số ngày cố định hoặc dùng fake implementation đánh dấu hoàn tất.

Thực hiện P0 mục 1.1 trước, P1 chạy khi dữ liệu đủ readiness; các adapter P2 giữ trạng thái NOT_STARTED/IN_PROGRESS/SOURCE_TESTED/PROVIDER_VERIFIED/DEVICE_VERIFIED/ACCEPTED kèm evidence và dependency. SOURCE_TESTED không tự thành ACCEPTED. NLU phụ thuộc preview/semantic validation; chat phụ thuộc consent/lineage; voice phụ thuộc thiết bị; swap/replan/evolution phụ thuộc core workflow; Blitz/vision phụ thuộc provider/media. Không báo xong toàn A–K khi chỉ xong P0 hoặc mới tạo adapter stub.

### 8.2. Simulator

6 thành viên, 14 season tháng, mỗi mùa <=31 ngày. Dữ liệu gắn nhãn synthetic. Sinh qua business services/fake clock nội bộ môi trường demo, không SQL sửa điểm/rank và không production change-clock API. Oracle riêng, không vào feature.

Kịch bản: nhận bounty/tự hoàn thành; nhận/chuyển tiếp; receiver khác completer; nhiều loại việc; làm nhiều/rank trung bình; busy/preference thay đổi; người từng giúp nay không sẵn sàng; chat mơ hồ; mất cơ hội do người khác nhận; late/penalty/paid/unpaid/season close.

20 seed 42..61, ghi scenario/config hash, báo toàn bộ. Provider eval có labeled set riêng; mock chat simulator không chứng minh chất lượng Gemini.

**Ngân sách pilot:** khoảng 6–10 occurrence/ngày cho cả nhà, xấp xỉ 2.500–4.300 occurrence trong 14 tháng tùy số ngày thực tế; không phải cỡ mẫu bắt buộc hay bảo đảm 500 labeled samples. Kịch bản/capacity phải hợp lý, không tăng việc chỉ để đủ train. Báo riêng occurrence, episode, unique event, sample hợp lệ từng Target/lớp, pending/excluded và lý do; các số không thay thế nhau.

Thứ tự: (1) scenario nhỏ kiểm tra state transitions; (2) 1 seed đủ 14 tháng; (3) audit samples/outcome imbalance/time coverage/CPU-RAM-runtime; (4) sửa lỗi dữ liệu và chạy lại pilot có version; (5) khóa manifest rồi chạy 20 seed. Không tạo thẳng 500 completion/label; mọi facts qua business services. **20 seed là 20 lần mô phỏng độc lập**, không ghép thành 20 năm của một nhà hoặc pool mẫu để đạt readiness một thành viên.

| Scenario/mốc pilot | Dữ liệu thay đổi | Phân biệt và điều cần quan sát |
|---|---|---|
| Tháng 7 — chuyển ca làm | Availability xác nhận đổi, cùng thông tin cấp baseline/adaptive | DECLARED_CHANGE: lịch phải tuân constraint mới; không gán lợi ích này cho model tự học |
| Tháng 9 — xu hướng lựa chọn đổi | Người dùng dần chọn tự nguyện loại việc khác, không sửa declared preference ngay | HISTORY_ONLY_SHIFT: profile gần đây theo kịp không; không biến không chọn thành negative |
| Tháng 11 — giảm khả năng hỗ trợ | Người từng nhận giúp có capacity khai báo thấp hơn, hành vi nhận thêm giảm | Declared change và observed history báo riêng; không tăng quota vì lịch sử cũ |
| Xuyên suốt — effort/điểm lệch nhau | Nhiều completion nhưng effort, Karma, penalty/bonus/rank khác | Giải thích đúng snapshot/ledger, không thêm phẩm chất hoặc tự sửa điểm |

Các mốc trên là scenario config v1 khóa trước test, không label kỳ vọng AI phải thắng. Simulator có nhiễu/lựa chọn ngoại lệ/missing observations/outcome không hoàn hảo, không sinh mọi hành vi theo đúng công thức adaptive. Oracle chỉ chấm, không đi vào feature/prompt/candidate selection.

Adaptation lag: declared availability đo số lần quyết định từ lúc core xác nhận đến lịch đầu tiên hợp lệ; đó là responsiveness, không phải learning. Với history-only shift, mỗi seed dùng một probe cohort cố định từ holdout oracle, không cho profile/trainer thấy đáp án; mốc historical-only là profile all-time đóng băng ngay trước change point. Ghi số quyết định từ change point tới 3 checkpoint liên tiếp mà Brier của dự báo hành vi đủ label không còn cao hơn mốc đóng băng trên cùng probes. Checkpoint mỗi 20 quyết định đủ quan sát; không có probe labels hợp lệ thì N/A, không đạt tới cuối thì NOT_REACHED/right-censored. Đây là metric nghiên cứu v1, chưa là improvement gate allocation. Với T3 chưa có dự đoán hành vi đúng scope, chỉ báo profile trajectories, không bịa adaptation lag số học.

### 8.3. Temporal evaluation

| Giai đoạn mô phỏng | Vai trò |
|---|---|
| Tháng 1–3 | Profile cập nhật từ đầu, tạo mẫu/checkpoint Data Readiness; không mặc định 3 tháng đủ train |
| Tháng 4–5 | Validation/lựa chọn phương pháp, policy và ngưỡng; tách fit/calibration/selection/threshold theo mục 3.8 |
| Tháng 6–14 | Test walk-forward theo thiết kế đã khóa; không dùng test để tiếp tục chọn thuật toán |

Profile chỉ past events. Đầu season kiểm tra retrain theo mục 3.11, chỉ labels đã sẵn có trước cutoff và có dữ liệu mới hữu ích; không bắt buộc train mỗi mùa. Chưa đủ dữ liệu cho validation/calibration thì offline/shadow hoặc không chọn learned model; P0 vẫn dùng hồ sơ/baseline. Hàng tháng đánh giá dữ liệu/profile, mỗi training job có candidate evaluation, policy đánh giá period/multi-seed ở hai optimizer modes. Ghi các lịch riêng trong run metadata, không đánh đồng tích lũy với cải thiện.

Arms bắt buộc B0 greedy, S0 cùng search không history, H1 cùng search có history theo mục 4.7. Cùng task universe/exogenous conditions/paired seed, environment phản hồi theo policy; oracle không ưu ái adaptive. Fixed-context replay và closed-loop báo riêng. Chỉ thêm chat/model arms khi scope/spec riêng cho phép; T1 risk insight không trở thành model allocation. Báo search delta/history increment/total và paired CI, gồm trường hợp history không đổi lịch vì chỉ phá hòa hoặc bị gate chặn. Historical offline không chứng minh counterfactual/causal; synthetic không thay người dùng thật.

## 9. Kiểm thử và nghiệm thu

### 9.1. Test bắt buộc

- Baseline parity/canonical order/fixed items/capacity/deadline/ISO year-week/timezone/missing-empty availability/date exception.
- Gate sát ngưỡng: +1 coverage, karma -10% nhưng <1 Karma, preference +10 điểm phần trăm nhưng không thêm preferred item, empty intersection, baseline gap/late/Brier zero, preference tốt nhưng fairness xấu phải loại.
- Occurrence nhiều bounty/episode không cộng trùng; receiver/completer khác; chuyển rồi quay lại; pending chưa đến hạn không failure; overdue-open không bị loại để làm đẹp báo cáo.
- Tách paid help/swap/pass/forced, tiền/Karma/effort/rank; forced 0 Karma vẫn có completion; không sinh quality label/tính cách từ bounty.
- Không tăng quota người hay nhận; tải tự nguyện không thành nghĩa vụ mùa sau; declared/inferred/experience tách rõ.
- Dataset leakage/censored/unknown/one-class/sparse/missing/unseen; preprocessing train-only; demo-real isolation; artifact hash/rollback.
- Checkpoint tháng 3 chưa đủ readiness; T1/T2 số mẫu/lớp khác; không ghép seed đạt 500; fold/label/window qua biên tháng, local midnight/UTC và cutoff đúng equality rule; label chỉ sẵn có sau prediction không được trở thành feature.
- Context snapshot/episode/outbox commit hoặc rollback cùng nhau; Kafka tới sau StartedAt vẫn hợp lệ; source availability đổi sau snapshot không vào feature cũ; late-arrival correction source chưa biết tại snapshot không leak; legacy missing snapshot không dùng live state giả as-of.
- Profile dựng lại sau bằng source cutoff đúng phải khác latest profile nếu đã có tương lai; inference muộn ghi retrospective/execution time và không phát risk cho episode đã đóng. Replay/export giữ source/transport timestamps riêng.
- Label table: completed đúng deadline, transfer trước/sau deadline, other completer, cancel/skip, deadline đổi, late event, request rejected/applied/out-of-window; candidate chưa được chọn luôn NOT_APPLICABLE, không có nhãn phản thực giả.
- Experiment budget/config manifest đúng 14 cấu hình/Target; fold thiếu lớp không chuyển random split; fit/calibration/selection/test tách đúng; lớp dương T1/T2 nhất quán; không chọn lại model bằng test.
- Winner không bị ép RF; thống kê/logistic có thể thắng; metric model tốt nhưng policy không cải thiện phải giữ offline/shadow; chưa có false-alert budget không bật cảnh báo xác suất.
- Evaluation run retry/finalize atomic; không ghi đè lịch sử; model=null; cutoff input/outcome khác nhau; metric-definition/dataset đổi phải tạo run mới; FAILED/pending/unknown không thành 0/PASS.
- Metric dictionary nhất quán runner/gates/API; preference declared/inferred và metric cohort khác nhau không bị nhập; capacity khác không ép tải bằng nhau; request dedup và denominator/window đủ quan sát.
- Pair sai house/period/seed/source/task universe/definition trả INCOMPARABLE; relative baseline=0 là N/A; paired CI đúng nguồn runs; missing/failed seeds không bị bỏ khỏi aggregate một cách im lặng.
- Evaluation read API owner-only, IDOR run/group/example/evidence; member thường hoặc owner nhà khác không xem được; thu hồi membership/đổi account không lộ cache; không public write evaluation/training endpoint.
- Flutter dashboard timeline/compare/examples: synthetic badge, no-model/no-data/loading/failed/partial states, number/sample/CI formatting từ server, ví dụ dùng snapshot lịch sử không live schedule mới; tăng event count không hiện như cải thiện chất lượng.
- Duplicate/out-of-order/late/gap/replay/reconciliation; crash publish/commit; poison/unknown-house; profile version.
- Consent revoke queued/in-flight; prompt injection/house ID giả; raw context cleanup; private inference/chat không public.
- Consent revoke với evidence/projection/dataset/example đã dẫn xuất; business audit giữ độc lập; model phụ thuộc bị suspend/rollback; replay/backup restore không hồi sinh nguồn withdrawn. Metadata data_source/inference_source không trộn enum, kể cả fallback synthetic.
- Stale/retry/concurrent accept; leave/kick/owner transfer; replan reject không partial; manual swap/urgent regression.
- Logout/login không lộ cache/SignalR/response cũ; media lost-response/retry; notification không trùng.
- Python/provider/Kafka/artifact lỗi vẫn manual; source/fallback typed; uncertain vision không complete; Blitz infeasible không bịa lịch.
- Optimizer BUDGET_COMPLETE khác SERVING_DEADLINE, timeout trả baseline và tính vào serving aggregate; risk/rotation-only không vượt gate hiện tại; không dùng availability khai báo mới làm bằng chứng ML tự học.
- Ablation B0/S0/H1 cùng context/search/budget/declared inputs: history chỉ bật ở H1; search delta không bị gán cho learning, history delta 0 phải hiện 0; gate/fallback chặn candidate thì served metric không lấy raw candidate làm kết quả người dùng.
- Training schedule skip khi không có dữ liệu hữu ích, không auto-promote; artifact sai hash/schema không phục vụ; rollback theo capability giữ consent/source đúng; criterion đổi sau test không biến run cũ thành PASS.

### 9.2. Metrics

Allocation: coverage/violations/karma/effort/count/preference/rotation. Replan: churn/consent outcome. ML: PR-AUC/Brier/calibration/raw counts theo category. Chat: precision/recall intent/entity/time/clarification. Profile: đúng nguồn/evidence/double-count/unknown rate. Operation: latency/lag/gap/fallback/errors/cost.

Bounty acceptance không là metric chính hiểu gia đình. Hit@K/MRR/NDCG chỉ khi candidate set/relevance có ground truth hợp lệ; nonwinner không tự negative. Đo adaptation lag theo decision/season sau đổi hành vi, không phần trăm hiểu biết.

### 9.3. Bằng chứng bàn giao

Theo biên bản main, baseline từng có 70 unit/32 integration/15 Flutter PASS; đó là lịch sử non-AI, không phải đã chạy lại lần sửa doc này. Khi code chạy regression phù hợp/cập nhật số thực. Provider/emulator/Android camera-micro-loa có checkpoint riêng.

Delivery report tách P0 end-to-end, P1 ML experiment và từng adapter P2 theo mục 1.1/8.1. P0 đạt phải có đường truy người/event, chống double count, cùng context baseline/adaptive, persisted runs mở được trên dashboard, ví dụ lịch/evidence và manual fallback. P1 có task card/readiness/dataset/experiments kể cả kết luận không promote. P2 thiếu checkpoint thì ghi chưa nghiệm thu, không gọi toàn bộ A–K hoàn tất vì đã tạo file.

Bàn giao manifest, contract/migration, metric/label dictionary, dataset manifest, model card, temporal reports/gates/CI, seed demo/run instructions, runbook replay/retrain/promote/rollback. Evaluation Store có lịch sử run có thể truy, Dashboard owner đọc được timeline/baseline-adaptive/examples và đối chiếu số với run IDs/manifest; report file không thay kho kết quả. Không đạt gate ghi candidate/fallback, không che bằng AI score.

Report demo phải có bảng B0/S0/H1 và nêu rõ giới hạn history tie-break v1: local search có thể cải thiện lịch dù history thêm 0. Profile adaptation không thay bằng chứng schedule learning. Nếu chưa có effect lịch sử đủ bằng chứng thì bàn giao trung thực phần đã học/đã quan sát, không tuyên bố AI lịch thông minh hơn nhờ lịch sử chỉ từ total gain.

**Nghiệm thu:** truy được ai đóng góp gì, qua cơ chế nào, outcome/evidence ở đâu; đề xuất hợp lệ và đủ cải thiện theo gate; không biến chủ động giúp đỡ thành nghĩa vụ làm thêm. Chưa qua policy evaluation không tuyên bố giảm trễ.

## 10. Evaluation Metrics & Acceptance Criteria — đặc tả nghiệm thu

Metrics là thước đo, acceptance criteria là điều kiện đủ để bật một capability hoặc kết luận một loại cải thiện. Kết quả mô tả, model quality và product value là ba việc khác nhau. Mọi ngưỡng số ở đây là **PROPOSED_EXPERIMENT_V1**, lý do là tạo mốc pilot rõ ràng; không phải bảo đảm khoa học/pháp lý. Trước test tháng 6 phải đóng version/hash/spec và lock audit; chưa khóa thì không có kết luận acceptance chính thức.

### 10.1. Đọc Model Evaluation

Với T2 lớp dương là có self-request trong window; T1 lớp dương là late. Báo confusion matrix tại threshold đã khóa và cùng eligible cohort:

| Dự đoán | Thực tế dương | Thực tế âm |
|---|---|---|
| Cảnh báo | TP | FP |
| Không cảnh báo | FN | TN |

Precision=TP/(TP+FP); recall=TP/(TP+FN); FPR=FP/(FP+TN); accuracy=(TP+TN)/N. Zero denominator trả undefined/N/A kèm counts, không giả 0 hoặc 100%. FP gây cảnh báo phiền hoặc cân nhắc sửa việc không cần; FN bỏ sót việc phát sinh rủi ro. Không dùng cảnh báo để tự đổi/phạt nên ưu tiên hạn chế spam, nhưng vẫn phải báo recall để thấy phần bỏ sót.

Ví dụ: 100 assignment có 5 positive, luôn đoán âm cho accuracy 95%, recall 0 và precision undefined. Có 20 positive, cảnh báo 15 và đúng 12 thì TP=12/FP=3/FN=8, precision=80%, recall=60%; TN cần biết tổng negative mới tính. Accuracy không là primary gate.

Brier=`mean((p-y)^2)` đo sai số probability; PR-AUC bổ sung khả năng xếp positive trong dữ liệu lệch lớp. Precision/recall tại một threshold không chứng minh probability đã calibrated. Model output chỉ là probability được kiểm chứng khi qua calibration gate, không phải confidence về tính cách.

### 10.2. Calibration/threshold: cấu hình pilot và phạm vi

| Tiêu chí dự kiến | Mục đích/lý do và phạm vi | Nếu chưa đạt |
|---|---|---|
| Calibration fit block >=100 labels, >=20 mỗi lớp | Heuristic tránh fit sigmoid từ quá ít outcome; tách khỏi model fit/selection, áp từng Target | Không công bố probability đã kiểm chứng |
| Reliability evaluation: 5 bin cố định [0,.2), [.2,.4), [.4,.6), [.6,.8), [.8,1], mỗi bin có dữ liệu dùng kết luận cần >=20 mẫu; ECE <=0.10 | Pilot gate chặn sai lệch trung bình quá lớn; ECE=sum(n_bin/N * abs(mean_p_bin-observed_rate_bin)). Báo counts và reliability plot, không xem ECE một mình là bảo đảm | Bin thưa/thiếu outcome: INSUFFICIENT_EVIDENCE; giữ offline/shadow hoặc không phát xác suất |
| Quality: Brier giảm >=5% tương đối, PR-AUC không giảm; holdout >=20 mỗi lớp | Gate model mục 3.4, không đại diện toàn hệ thống | Không promote model do chỉ accuracy cao |
| Alert pilot: precision >=70%, recall >=50%, FPR <=10% trên cohort đủ nhãn | Cân bằng bớt spam và không bỏ sót toàn bộ; chỉ dùng thử T1 risk insight sau quality gate. T2 v1 vẫn offline/shadow | Không bật cảnh báo xác suất nếu validation không có threshold thỏa |
| Delivery cap: tối đa 1 push AI risk/member/ngày, cooldown 24 giờ/episode | Giới hạn phiền; không thay đổi notification nghiệp vụ bắt buộc | Dedupe/cap và báo suppressed count; đo metric cả raw predictions lẫn delivered alerts |

Threshold lựa chọn trên tháng 5B: từ grid cố định 0.05..0.95 bước 0.05, chọn recall cao nhất thỏa precision/FPR budget, hòa chọn threshold cao hơn. Khóa số chọn và selection rule trước test; không mặc định 0.5. Rate gates kèm TP/FP/FN/TN, CI và data readiness. Probability/calibration hoặc alert không đủ bằng chứng thì chặn riêng capability đó, P0 profile/allocation không bị buộc phải có learned model.

Các số 100/20/0.10/70%/50%/10%/push cap là default pilot v1 được đề xuất do yêu cầu minh bạch/số mẫu nhỏ/spam; có thể sửa bằng pilot/validation trước lock với rationale/audit và chạy lại đối chiếu. Sau khi xem test không hạ để promote; lần nghiên cứu khác cần holdout tương lai. Không dùng threshold hoặc cap đã tune trên test để báo PASS test đó.

### 10.3. Guardrails và improvement goals theo capability

| Capability/claim | Guardrails bắt buộc | Improvement goal/acceptance và giới hạn |
|---|---|---|
| P0 hồ sơ/evaluation/dashboard | Facts đúng nguồn, không trùng, phân quyền/consent, metadata chuẩn, unknown không zero, core fallback | Có run lưu/mở được, hand-worked examples đúng, lịch trước/sau/evidence; không bắt buộc model được promote |
| Adaptive allocation v1 | Zero constraint violations; coverage không giảm; karma_gap không tăng; disliked_count không tăng theo cohort chung; locks/quota/consent đúng | Ít nhất một gate coverage +1 hoặc Karma gap -10% và -1 hoặc preferred rate +10 điểm phần trăm và +1 preferred item theo mục 4.4; không đạt giữ baseline |
| Rotation-only/risk-only lịch | Cùng guardrails, không suy label candidate chưa chọn | V1 chưa có gate promotion cho riêng hai mục tiêu này; chỉ nghiên cứu, không lách gate lịch |
| Risk insight T1 | Đúng episode đã nhận, quality/calibration/alert budget và delivery cap, không tự sửa/phạt | Product value đo cảnh báo đúng trên delivered cohort/false-alert budget và operation; không suy đã cải thiện lịch hoặc score người chưa được giao |
| Giảm trễ | Same scenario/task universe, coverage/fairness không xấu và zero hard violation | Giảm late >=10% tương đối và paired 95% CI không chứa 0 theo mục 4.5, ở SERVING_DEADLINE; chỉ claim này mới bắt buộc late improvement |
| Giảm request T2 | Label/window/cohort rõ, không gán request người khác; fairness giữ nguyên | T2 bản đầu là experiment/shadow, chưa có production claim giảm request. Muốn bật cần acceptance spec mới trước holdout mới |
| P2 adapter | Quyền/consent/schema, domain validation và checkpoint provider/device phù hợp | Mỗi adapter có evidence/status riêng; tạo file/source test không đủ nói đã hoàn tất A–K |

Fairness v1 đo đúng chính sách hiện có: capacity là hard limit và karma_gap là guardrail so baseline; không ép mọi người nhận bằng nhau. Workload concentration/capacity utilization là diagnostics, chưa có một ngưỡng HHI production mới; không gọi karma-gap đạt là mọi khía cạnh công bằng đều tối ưu. Nếu muốn concentration thành veto riêng phải định nghĩa capacity/cohort/bound version mới trước test.

P0 chức năng có thể hoàn chỉnh trong khi adaptive không tìm được cải thiện ở một context: UI trả baseline/reason trung thực. Chỉ đánh dấu **improvement achieved** cho run đạt gate; không dựng kết quả phải thắng để nghiệm thu code.

### 10.4. Reporting rules và ví dụ tính tay

Mỗi metric definition phải có key/version, unit/direction, formula, sample/cohort/dedup, denominator, observation window/cutoff, exclusions/pending handling và ít nhất một ví dụ có đáp án. Tất cả examples sau là fixture minh họa, không phải số chạy dự án:

| Metric/ví dụ | Kết quả đúng và điều không được suy ra |
|---|---|
| Coverage: 18/20 việc xếp hợp lệ | 90%, còn 2 unassigned, không đổi mẫu số thành 18 |
| Request rate: 4/20 → 3/20 assignment đủ window | 20% →15%, -5 điểm phần trăm, -25% tương đối; chưa đủ bằng chứng riêng nếu mẫu nhỏ |
| Một so sánh 20% →14% | -6 điểm phần trăm, -30% tương đối; phải ghi cả counts/cohort |
| Karma [10,20,30] | Gap=20, mean=20, range_pct=100%; không phải statistical variance hoặc wallet balance |
| Effort [30,30] | HHI=0.5, nhưng còn phải xem capacity; người capacity 30 và 120 không có cùng utilization |
| Preference +1/-0 | Smoothed score=(1+1)/(1+0+2)=2/3; chỉ 1 phản hồi, không phải confidence 66.7% hoặc bằng chứng thích chắc chắn |
| On-time 8, late 2, pending 3 | On-time=8/10=80%, pending=3; episode chuyển trước deadline có thể censored dù occurrence cuối hoàn thành |
| Không known outcomes | N/A + reason, không zero; baseline metric=0 thì relative change N/A |

Báo period, per-class counts/time coverage, seed planned/completed/failed, paired effect/CI, outcome maturity, budget mode/latency/fallback, data_source/inference_source và scope capability. Declared change baseline cũng biết phải báo riêng history-only improvement. Tăng event/evidence/sample count chỉ là data accumulation. Không gộp nhiều seed thành lịch sử một nhà, không bỏ seed thất bại hoặc chỉ show lần đẹp.

Attribution bắt buộc theo mục 4.7: trình bày search S0−B0, history H1−S0, tổng H1−B0; ví dụ 40%/50%/50% phải kết luận search +10 điểm, history +0 điểm. Không cộng relative changes khác mẫu số; không gọi profile thay đổi là lịch cải thiện nếu served assignments/metrics chưa đổi. Giới hạn này được chấp nhận ở demo v1, mở capability khác cần spec/gate khóa trước test mới.

### 10.5. Evaluation Specification và quyết định sử dụng

Spec có `spec_id/version/status`, Target/capability, primary metric, secondary diagnostics, guardrails, metric-definition references, comparison protocol/cohorts/source/seeds, temporal split/cutoffs, readiness, proposed numeric thresholds/rationale, acceptance rule, operation/fallback requirements, reporting rules, code/config hashes và lock audit. Trạng thái DRAFT → VALIDATION_LOCKED → TEST_LOCKED trước tháng 6; không ghi phiên bản đã khóa nếu chưa có manifest thực tế.

Sau test: PASS chỉ cho capability đạt đủ gate, INSUFFICIENT_EVIDENCE khi thiếu dữ liệu, FAIL khi không đạt, NOT_SUPPORTED cho risk/rotation allocation v1. Dashboard hiển thị lý do và spec version, không dùng một AI Passed boolean chung. Nếu sửa tiêu chí sau test, lưu spec mới và giữ verdict cũ, không biến FAIL thành PASS bằng đổi số. Metadata/data bug làm run không hợp lệ phải đánh INVALIDATED và có audit/re-evaluation, không âm thầm tính lại.

### 10.6. Ba bộ đặc tả phải đóng trước code sâu/thực nghiệm cuối

1. **Data & Metric Specification:** event dictionary và actor/episode linkage, ordering/knownAt, contribution/dedup, metric definitions/cohorts/windows/exclusions, consent lineage và hand-worked fixtures; cơ sở mục 2/3.3/4.6/6.5/10.4. Khi triển khai tách thành docs/ai/data-metric-specification.vi.md và schema/metric dictionary có version.
2. **Learning Task Specification:** task cards, Prediction Time/features, label decision table, readiness/offline-vs-product, candidates/config/baselines, calibration/threshold/gates và usage limits; cơ sở mục 3/10.1–10.3. File dự kiến docs/ai/learning-task-specification.vi.md và target_specs.
3. **Demo & Evaluation Specification:** scenarios/noise/change points, pilot scale/seeds, lịch 1–3/4–5/6–14, paired arms, optimizer modes, dashboard/capability acceptance/reporting và delivery priority; cơ sở mục 1/4/5.6/8/10. File dự kiến docs/ai/demo-evaluation-specification.vi.md và acceptance_spec.

Ba file đặc tả đã được tạo trong phiên implementation 23/10/2026: [Data & Metric](../ai/data-metric-specification.vi.md), [Learning Tasks](../ai/learning-task-specification.vi.md), [Demo & Evaluation](../ai/demo-evaluation-specification.vi.md). Dictionary `ai-service/contracts/profile-metrics.v1.json` được xuất từ source và có regression đối chiếu. Evaluation spec cuối vẫn DRAFT, chưa có lock manifest chứng minh đã khóa trước holdout; không hồi tố gọi pilot đã xem kết quả là TEST_LOCKED. Đóng event/label/metric contract trước khi code sâu; khóa toàn bộ evaluation spec sau validation và trước test. Không triển khai label_builder theo suy diễn riêng hoặc chạy test rồi mới chọn criteria.

### 10.7. Đối chiếu tám nhóm góp ý đã tích hợp

| Nhóm góp ý | Nơi áp dụng |
|---|---|
| Ưu tiên và bàn giao thực tế | 1.1, 8.1, 9.3: P0/P1/P2, không giảm scope A–K |
| Checkpoint 3 tháng và lịch train/eval | 3.8, 3.11, 8.3: 1–3/4–5/6–14, readiness riêng, retrain có điều kiện |
| Quy mô/quy trình pilot | 8.2: 6–10 occurrence/ngày, pilot nhỏ → 1 seed → audit → multi-seed |
| Scenario và attribution thích nghi | 5.6, 8.2: declared vs history-only, change points, noise/oracle, lag |
| Readiness/ngưỡng không phải hằng số khoa học | 3.4, 10.2: purpose/rationale/scope/status/blocking/version/audit |
| Target/feature/label | 3.3–3.5: observed responsibility only, decision table, window/exclusions |
| Policy gate đúng claim và runtime | 4.2–4.5, 10.3: giữ gate v1, không ép late cho mọi Target, hai optimizer modes |
| Consent/metadata/lifecycle/tests/specifications | 3.11, 6.2, 6.5, 9, 10: nguồn độc lập, derived data revoke, rollback, ba spec trước code sâu |

Góp ý tiếp theo đã đồng bộ: mục 1.1 ghi còn khoảng 2 tuần và ngày nộp chính thức chờ xác nhận; mục 3.3.2 quy định source snapshot atomic không phụ thuộc Kafka arrival; mục 4.2/4.7 và dashboard/report tách search gain với history increment, chấp nhận giới hạn lịch sử chỉ phá hòa v1.
