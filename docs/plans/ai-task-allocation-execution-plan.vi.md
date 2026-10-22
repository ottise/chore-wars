# Kế hoạch code AI giao việc cho Chore Wars

> **Tài liệu lịch sử/MVP cũ.** Dùng [plan Python đầy đủ, cập nhật 20/10/2026 theo main 0e55613](ai-python-full-implementation-plan.vi.md) khi triển khai. Phạm vi hiện hành gồm toàn bộ A–K, trọng tâm hồ sơ đóng góp có bằng chứng và baseline/ngưỡng cải thiện rõ ràng; không tăng quota theo lịch sử nhận bounty. Chưa triển khai timer/model thời lượng hoặc dự đoán người nhận bounty. Source non-AI và các điểm nối đã thay đổi sau bản này.

Ngày lập: 18/10/2026. Cơ sở: source hiện tại, tài liệu trong `docs/`, hai tài liệu đính kèm của người dùng.

## 1. Mục tiêu và phạm vi

Triển khai một luồng hoàn chỉnh: thành viên khai báo ngày rảnh bằng tiếng Việt → xem và xác nhận thay đổi → chủ nhà yêu cầu AI đề xuất phân công cho mùa nháp → xem lịch, tổng Karma và lý do → xác nhận áp dụng → thành viên duyệt mùa theo quy tắc đã chốt.

Đây là kế hoạch thực hiện, chưa triển khai tính năng. Đã khảo sát cấu trúc backend, mobile, database/migrations, infrastructure, tài liệu và các điểm nối chính của phân công, mùa giải, chat, sự kiện và kiểm thử. Chưa chạy backend, Flutter, migration hoặc test; các nhận xét dưới đây là kết quả đọc code, không phải chứng nhận hệ thống chạy đúng. Không cần đọc từng asset, file sinh tự động hoặc secret để lập kế hoạch.

Hai tài liệu đầu vào có phạm vi khác nhau: kế hoạch 8 ngày chọn một intent availability; báo cáo AI Housekeeper mô tả cả ML, telemetry, chat, swap, blitz và vision. Bản này chọn AI giao việc làm đích; chia MVP và mở rộng để không biến mọi năng lực trong báo cáo thành điều kiện cho bản đầu.

### MVP phải có

- Nhập text tiếng Việt để sửa availability của chính mình theo ngày trong tuần, trong một season cụ thể.
- Đề xuất phân công occurrence của season `DRAFT`, dựa trên Karma, availability, constraint và preference.
- Preview trước khi ghi assignment; giải thích dựa trên số liệu thật.
- Confirm/reject proposal; kiểm tra lại quyền và dữ liệu tại thời điểm confirm.
- Cân bằng Karma dự kiến được giao; phút là giới hạn sức tải và thông tin phụ.
- AI service lỗi vẫn còn thao tác thủ công và thuật toán C# hợp lệ.
- Test API, DB và Flutter xuyên suốt.

### Sau MVP

Voice, lịch theo giờ, ngoại lệ ngày cụ thể, tái sử dụng mùa thông minh, rủi ro hoàn thành, Kafka telemetry, ML, đổi việc có nhiều bên xác nhận, chat action card, blitz và vision. Không tự đổi assignment của mùa `ACTIVE` trong MVP.

## 2. Hiện trạng và khoảng cách cần xử lý

Các đường dẫn trong tài liệu tính từ gốc repository.

| Khu vực | Bằng chứng trong code | Tác động đến kế hoạch |
|---|---|---|
| Backend | `backend/src/{Domain,Application,Infrastructure,Presentation}` | Giữ Clean Architecture; orchestration ở Application, HTTP/EF ở Infrastructure |
| Phân công | `Application/Services/ChoreAllocationService.cs` | Đã có greedy allocation, availability, constraint, preference; tái sử dụng nền, không viết lại toàn bộ |
| Fairness | `assignedWorkload` tăng bằng `EstimatedMinutes`; preference cộng/trừ 30 | Chưa cân bằng Karma theo hướng tài liệu; cần sửa trước khi dùng làm bộ kiểm tra AI |
| Vi phạm constraint | Allocator fallback bỏ constraint, cuối cùng chọn cả người bận | Phải trả việc chưa xếp và lý do; không âm thầm phá hard constraint |
| Tải đang có | Bộ đếm tải, việc/tuần, phút/ngày khởi tạo bằng 0 | Khi phân bổ bổ sung phải tính các assignment hiện có |
| Tuần | Bộ đếm dùng số tuần, chưa kèm năm ISO | Dùng cặp ISO year/week, kiểm thử mùa qua năm mới |
| Availability | `Domain/Entities/MemberAvailability.cs`: season, user, thứ, bool | Không thể thực hiện đúng câu “18–21 giờ”; MVP nhận cả ngày, câu theo giờ trả unsupported/clarification |
| Chore/occurrence | Có `KarmaPoints`, `EstimatedMinutes`, `Difficulty`, occurrence có `SnapshotKarma`, `SeasonId` | Fairness theo snapshot Karma; chưa có dữ liệu phiên làm thực tế để học duration |
| Sinh occurrence | `ChoreGenerationService` lấy chore theo house | Có nguy cơ kéo template của nhiều season vào mùa hiện tại; cần chốt template dùng chung rồi lọc tường minh |
| Xóa occurrence | `ChoreOccurrenceRepository.DeleteBySeasonIdAsync` lọc `o.Chore.SeasonId` | Không nhất quán với truy vấn theo `o.SeasonId`; sửa trước reject/regenerate |
| Generate schedule | `SeasonService.GenerateScheduleAsync` gọi sinh, giao, rồi đổi trạng thái qua các transaction riêng | Lỗi giữa các bước có thể để dữ liệu dở dang, lần thử sau bị chặn duplicate |
| Confirmation | `ConfirmSeasonAsync` kích hoạt sau một confirmation; `StartSeasonAsync` cho `DRAFT → ACTIVE` | Cần thống nhất chính sách duyệt; tránh đường tắt bỏ qua review |
| Clone season | `CloneSeasonAsync` chưa copy `Difficulty`, `EstimatedMinutes` | Lịch tái sử dụng có thể sai đặc tính đầu vào |
| Authorization | Endpoint summary/warnings gọi service không có userId; nhiều action không dùng houseId trên route | Kiểm tra user active, house của season và quyền từng action tại service |
| Manual assignment | Kiểm tra season qua `Chore.SeasonId`, chưa chặn trạng thái mùa/occurrence tại đây | Dùng `occurrence.SeasonId`; cùng policy với phân công tự động |
| Worker | `ChoreAllocationWorker` gọi phân bổ mùa active mỗi 24 giờ | Cần policy rõ cho việc chưa giao; không để worker lách proposal hoặc luật hard constraint |
| AI | Chưa có thư mục `ai-service/`, proposal entity, AI controller/client trong cấu trúc khảo sát | Phải xây mới các phần này; tài liệu master plan không phải tính năng đã có |
| Kafka/chat | Kafka có publisher, consumer và topic nghiệp vụ; chưa có `chat.message_sent` trong topic map | Tái sử dụng hạ tầng sau MVP; không coi chat mining đã sẵn sàng |
| Mobile | Có availability, member settings, review schedule, chat; Dio/Riverpod/GoRouter | Tích hợp vào luồng sẵn có; thêm feature AI nhỏ |
| Voice | `mobile/pubspec.yaml` chưa khai báo STT/TTS | Là hạng mục mới, xếp sau text end-to-end |
| Test | Có unit test generation và các file test mẫu | Chưa có bằng chứng coverage cho phân công/proposal/concurrency; test generation đang mock query theo season khác query theo house trong service |

Những điểm này là việc phải kiểm chứng và xử lý theo ưu tiên; không suy rộng thành kết luận rằng mọi module khác đều lỗi.

## 3. Quyết định nghiệp vụ mặc định để bắt đầu code

1. Chủ nhà active được tạo/apply đề xuất giao lịch cho mùa nháp. Thành viên active chỉ sửa availability của chính mình và duyệt mùa khi đủ điều kiện.
2. Luồng mùa chuẩn: `DRAFT → REVIEWING → ACTIVE → COMPLETED`. Mặc định yêu cầu toàn bộ thành viên active trong danh sách duyệt xác nhận; nếu nghiệp vụ cuối cùng chọn owner-only thì triển khai một policy tập trung và đổi test tương ứng.
3. Áp dụng proposal giao việc chuyển mùa từ `DRAFT` sang `REVIEWING`, không đồng nghĩa kích hoạt mùa.
4. Reject mùa quay về `DRAFT`, xóa đúng occurrence/confirmation thuộc mùa; vô hiệu proposal liên quan.
5. Mùa `REVIEWING` khóa dữ liệu đầu vào của lịch. Muốn sửa availability/template phải quay về draft và duyệt lại. Mùa `ACTIVE` giữ nguyên lịch trong MVP.
6. Thiếu availability không tự hiểu là đã đồng ý mọi ngày. Thành viên cần hoàn tất khai báo trước khi sinh lịch; hiển thị người còn thiếu.
7. Hard constraint gồm membership active, đúng house/season, ngày rảnh, số việc/tuần, phút/ngày và occurrence được phép sửa. Không đủ người hợp lệ thì trả `unassigned` kèm lý do.
8. BONUS giữ nguyên cơ chế tự nhận hiện tại, không tự giao; loại khỏi tập tối ưu bắt buộc.
9. Karma phân công là tổng `SnapshotKarma` của việc được giao, không phải số dư Karma đã kiếm được hay đang bị phạt. Không cộng/trừ Karma khi áp dụng lịch.
10. MVP không hứa hỗ trợ khung giờ. Thêm giờ sau này cần schema, API, UI và thuật toán kiểm tra khả thi đồng bộ.

## 4. Kiến trúc và trách nhiệm

```text
Flutter → ASP.NET Core → Python FastAPI → Gemini (hiểu câu/diễn đạt)
                    ↓           ↓
          Validation + DB    Đề xuất có cấu trúc
                    ↓
            Proposal → Preview → Confirm → Transaction
```

- Flutter gửi text, hiển thị preview và gọi confirm bằng proposal ID; không gửi lại assignment để backend tin tưởng.
- C# lấy user từ JWT, tải dữ liệu đúng house/season, tạo snapshot, kiểm tra hard constraint và lưu DB.
- Python nhận snapshot tối thiểu từ C#, thực hiện NLU và thuật toán đề xuất; không nhận connection string DB nghiệp vụ.
- Gemini hiểu tiếng Việt và có thể diễn đạt lý do; quyết định eligibility và tính tổng Karma do code xác định.
- Có thể triển khai solver đầu tiên ở C# và Python nhận trách nhiệm NLU/giải thích trước. Nếu dùng solver Python cho đề xuất, bộ kiểm tra C# vẫn là nguồn quyết định cuối cùng; dùng chung bộ fixture để tránh hai bên lệch luật.
- Giai đoạn đầu không phụ thuộc Kafka để tạo lịch. Chỉ thêm consumer AI khi đã có contract sự kiện và dữ liệu lịch sử phù hợp.

## 5. Thiết kế thuật toán giao việc

### 5.1 Snapshot đầu vào

Gồm houseId, seasonId, trạng thái/version, timezone, thành viên active, availability đã khai báo, constraint, preference theo chore, occurrence chưa giao, assignment hiện có và lịch sử giao gần đây nếu có. Mỗi occurrence có ID, due date, snapshot Karma, estimated minutes, difficulty và loại.

C# tạo snapshot từ dữ liệu server. Không tin userId, danh sách thành viên hay điểm do mobile/model tự cung cấp. Chốt timezone nghiệp vụ trước khi tính thứ và ngày; UTC dành cho instant, ngày lịch phải được quy đổi đúng. MVP mặc định múi giờ Việt Nam và ghi rõ trong contract.

### 5.2 Trình tự đề xuất

1. Tính tải hiện tại từ toàn bộ assignment liên quan, không tính riêng vòng phân công mới.
2. Sắp occurrence theo số ứng viên hợp lệ tăng dần, sau đó snapshot Karma giảm dần và deadline; thêm ID làm tie-break ổn định.
3. Lọc người hợp lệ theo hard constraint.
4. Chọn ứng viên theo thứ tự ưu tiên: mức mất cân bằng Karma sau khi gán, sở thích, xoay vòng và tổng phút. Dùng so sánh tuần tự để preference không lấn át mục tiêu Karma một cách ngẫu nhiên.
5. Cập nhật tải, counter tuần/ngày sau từng assignment.
6. Không có ứng viên: giữ unassigned, giải thích giới hạn nào chặn.
7. Tùy ngân sách, thử hoán đổi cục bộ hữu hạn để giảm chênh lệch Karma, luôn kiểm tra lại constraint cả hai người.
8. Trả assignments, unassigned, summary, warnings và reason code; không ghi DB.

Reason code ví dụ: `LOWEST_PROJECTED_KARMA`, `PREFERRED_CHORE`, `ROTATION`, `UNAVAILABLE`, `DAILY_LIMIT`, `WEEKLY_LIMIT`.

### 5.3 Đo chất lượng

- Tổng Karma mỗi người, max–min, độ lệch so với trung bình; nếu trung bình bằng 0 thì độ lệch phần trăm là 0.
- Số việc không giao được và số hard constraint bị vi phạm: số vi phạm phải bằng 0.
- So sánh với thuật toán baseline trên cùng fixture; không hứa mọi dữ liệu đều đạt lệch ≤20% vì Karma rời rạc và availability có thể làm điều đó bất khả thi.
- Không tối ưu bằng cách bỏ thêm việc để làm đẹp fairness: ưu tiên phủ việc khả thi rồi mới cải thiện cân bằng.
- Giải thích nêu số liệu cụ thể, ví dụ “sau phân công A: 40, B: 45 Karma”; không khẳng định AI đã học thói quen khi chưa có dữ liệu.

## 6. API và proposal

Các endpoint mới dưới đây là đề xuất, không phải API đã có.

| Method/path, dưới `/api/houses/{houseId}` | Mục đích |
|---|---|
| `POST /seasons/{seasonId}/ai/interpret` | Text → proposal sửa availability hoặc yêu cầu hỏi lại |
| `POST /seasons/{seasonId}/ai/allocation-proposals` | Tạo đề xuất giao việc cho mùa nháp |
| `GET /ai/proposals/{proposalId}` | Lấy preview từ server |
| `POST /ai/proposals/{proposalId}/confirm` | Kiểm tra lại và áp dụng |
| `POST /ai/proposals/{proposalId}/reject` | Từ chối proposal |

Python nội bộ: `GET /health`, `POST /v1/interpret`, `POST /v1/allocation/propose`. Dùng service credential, timeout và request ID; model/provider cấu hình qua môi trường, kiểm chứng SDK/model khi bắt đầu tích hợp.

NLU trả `SUCCESS`, `NEEDS_CLARIFICATION`, `UNSUPPORTED`. Lỗi provider là lỗi dịch vụ riêng. Ví dụ “Mùa này tôi bận thứ Hai và thứ Tư” tạo patch cho hai ngày; giữ nguyên các ngày khác. “Tuần này tôi bận” hoặc câu theo giờ không được tự ép thành lịch cả mùa.

### Proposal lưu ở C#

`Id`, `HouseId`, `SeasonId`, `RequestedBy`, `Type`, `SchemaVersion`, `PayloadJson`, `InputVersion`, `Status`, `CreatedAt`, `ExpiresAt`, `AppliedAt`, `IdempotencyKey`, `Version`.

- Type: `UPDATE_OWN_AVAILABILITY`, `ALLOCATE_DRAFT_SEASON`.
- Status: `PENDING → APPLIED / REJECTED / EXPIRED / INVALIDATED`.
- Payload server lưu gồm assignment/patch được kiểm tra; không thực thi lời văn hay code do model trả về.
- Ràng buộc unique idempotency key theo user và loại thao tác; thời hạn gợi ý 15 phút, cấu hình được.
- Đầu vào thay đổi khi tạo/sửa/xóa chore, availability, constraint, preference, membership hoặc occurrence thì tăng revision lịch. Mọi đường ghi liên quan phải tham gia cơ chế này.

### Confirm an toàn

1. Nạp proposal; kiểm tra chủ thể, house/season và quyền hiện tại.
2. Kiểm tra pending, hạn dùng và revision dữ liệu.
3. Trong transaction ngắn, khóa/version-check proposal và revision season; bảo đảm cập nhật đầu vào khác không chen giữa kiểm tra và ghi.
4. Kiểm tra lại toàn bộ assignment từ payload: ID thuộc mùa, không trùng occurrence, user active, hợp lệ và đủ coverage theo policy.
5. Ghi availability hoặc assignment; nếu giao lịch thì tạo confirmation và đổi `REVIEWING` cùng transaction.
6. Chuyển `APPLIED`, commit. Confirm lại trả kết quả đã áp dụng, không ghi thêm.
7. Reject/expire/stale không thay đổi dữ liệu nghiệp vụ. Stale trả `409` để tạo lại đề xuất; sai quyền trả `403`, sai payload `400`, AI unavailable `503` có thông báo dùng thao tác thủ công.

Không giữ DB transaction trong lúc chờ Gemini/Python. Hai proposal cùng snapshot chỉ được tối đa một proposal áp dụng khi revision thay đổi. Generate thủ công, worker và apply AI phải dùng cùng cơ chế khóa/revision.

## 7. Danh sách công việc theo tầng

### Backend nền — sửa trước AI

- `ChoreGenerationService.cs`: thống nhất nguồn template; sinh đúng season, truyền cancellation token; tách hàm build occurrence thuần khỏi hàm persist.
- `ChoreOccurrenceRepository.cs`: thống nhất filter bằng occurrence.SeasonId; test reject không xóa mùa khác.
- `ChoreAllocationService.cs`: tách `BuildPlan`/`ValidatePlan` khỏi ghi DB; bỏ fallback vi phạm hard constraint, tính existing load và Karma summary.
- `SeasonService.cs`: một orchestration transaction cho persist lịch + trạng thái + confirmation; không lồng transaction của service con. Xử lý retry khi generate lỗi giữa chừng.
- Khóa luồng start/confirm/reject theo policy; concurrency test để tránh nhiều confirm đồng thời gây sai trạng thái.
- Clone copy đủ difficulty/estimated minutes; kiểm tra lại các field cần giữ.
- `SeasonController.cs`: truyền context user/house cho các action cần quyền, gồm summary/warnings/manual assign.
- `ChoreAllocationWorker.cs`: loại đường tự ghi trái policy của mùa active; cơ chế legacy cần được ghi rõ nếu tiếp tục giữ.

### Backend AI — tạo mới

- Domain: `AIProposal`, `AIProposalType`, `AIProposalStatus`; season có revision/version.
- Application: DTO interpret/allocation/proposal; `IAIHousekeeperClient`, `IAIProposalRepository`, `IAIHousekeeperService`; `AIHousekeeperService`, `AllocationPlanValidator`.
- Infrastructure: `AIHousekeeperHttpClient`, options cấu hình, repository/configuration proposal, migration, concurrency implementation.
- Cập nhật `AppDbContext`, `IUnitOfWork`, `UnitOfWork` và DI trong `Presentation/Extensions/` theo cấu trúc sẵn có.
- Presentation: `AIHousekeeperController`; error mapping và request limit. Summary bổ sung `TotalAssignedKarma`, min/max/imbalance, unassigned count, giữ field phút để mobile cũ tiếp tục đọc.

### Python — tạo `ai-service/`

```text
ai-service/
  app/main.py
  app/config.py
  app/schemas/{nlu,allocation}.py
  app/api/{health,interpret,allocation}.py
  app/clients/gemini_client.py
  app/services/{nlu_service,allocation_planner,explanation_service}.py
  tests/
  fixtures/
  pyproject.toml
  Dockerfile
  .env.example
```

Schema chặt, giới hạn text/kích thước snapshot, xử lý output sai và timeout. Không có training lúc startup; không kết nối DB nghiệp vụ. Giải thích có thể sinh từ template để proposal vẫn có lý do khi phần diễn đạt Gemini lỗi.

### Flutter

- Thêm `mobile/lib/features/ai/` với models, remote datasource/repository, Riverpod provider, màn nhập yêu cầu và widget proposal.
- Nối vào `availability_screen.dart`: nhập câu, xem ngày đổi, confirm/reject; chỉ refresh sau API success.
- Nối vào `review_schedule_screen.dart` và luồng draft: “Đề xuất giao việc”, hiển thị trước/sau, tổng Karma, việc chưa giao, warning và lý do.
- Cập nhật `core/network/api_endpoints.dart`, `core/router/app_router.dart`, model summary liên quan.
- Phân biệt confirm proposal với confirm mùa; tránh người dùng hiểu preview là đã kích hoạt.
- Loading, mất mạng, proposal stale/hết hạn, thử lại và mở lại app. Disable nút khi gửi request chỉ hỗ trợ UX; backend vẫn chống lặp.
- Voice là bổ sung sau text; kiểm tra transcript trước khi gửi, xử lý từ chối quyền và chỉ đọc thành công sau backend commit.

## 8. Lộ trình 8 ngày dành riêng cho AI giao việc

Ước lượng một người full-stack làm 7–9 giờ/ngày, quen C#/Flutter và cơ sở dự án chạy được. Không cộng thêm thanh toán và hoàn thiện toàn bộ yêu cầu môn học vào cùng ngân sách. Nếu vẫn giữ kế hoạch 8 ngày tổng thể trong tài liệu đầu tiên, nên chỉ làm intent availability; bản giao việc đầy đủ cần thêm thời gian hoặc cắt các phần khác.

| Ngày | Công việc | Đầu ra/điều kiện qua mốc |
|---|---|---|
| 1 | Chạy baseline, chốt policy/contract; sửa season scoping, quyền, clone và confirmation | Fixture 3 người/7 ngày, bug nền có test tái hiện; luồng mùa nhất quán |
| 2 | Tách planner/validator; fairness Karma, existing load, unassigned, transaction generation | Thuật toán C# deterministic, không vi phạm constraint; lỗi giữa chừng không để lịch dở |
| 3 | Dựng FastAPI, Gemini NLU, schema, HTTP client C# và fallback | C# gọi Python được; bộ câu Việt phân biệt rõ ngày/giờ/ngoài phạm vi |
| 4 | Proposal entity/migration, revision, confirm/reject và idempotency | API availability proposal chạy đủ; test confirm đồng thời, stale, sai quyền |
| 5 | Allocation proposal, snapshot/summary/explanation, apply lịch + confirmation | Preview không ghi assignment; apply đúng một lần và chuyển reviewing |
| 6 | Flutter text, preview, confirm/reject, tổng Karma và error states | Điện thoại chạy xuyên suốt; cuối ngày đóng tính năng |
| 7 | Deploy môi trường thử nghiệm, regression, concurrency, AI timeout và retry | API/DB/APK đạt checklist; sửa lỗi chặn |
| 8 | Nghiệm thu, tài liệu, dữ liệu demo, APK và diễn tập | Bản chạy có commit xác định, bằng chứng test và giới hạn rõ |

Thứ tự phụ thuộc: sửa nền → planner/validator → proposal/locking → AI client → UI → nghiệm thu. Có thể dựng Python song song về mặt công việc sau khi chốt contract; không chia người vào cùng service đang refactor.

Nếu hết ngày 2 nền chưa ổn: bỏ mở rộng và ưu tiên planner. Nếu hết ngày 4 chưa confirm an toàn: dành ngày 5–6 cho availability, lùi allocation AI. Không cắt quyền/transaction/concurrency để đủ lịch.

## 9. Kiểm thử và tiêu chí nghiệm thu

| Nhóm | Ca bắt buộc |
|---|---|
| Generation | Chỉ sinh đúng template/mùa; rollback khi allocation lỗi; reject xóa đúng mùa; retry không duplicate |
| Allocation | Không giao người bận/inactive; không vượt phút/ngày, việc/tuần; tính tải cũ; BONUS không tự giao |
| Fairness | Fixture đối xứng cân bằng Karma; dữ liệu bất khả thi có cảnh báo; tie-break ổn định; không bỏ việc để đẹp số |
| Time | Chủ nhật mapping 0; timezone qua ngày; tuần qua năm mới; deadline/season boundary |
| NLU | 30–40 câu Việt: nhiều cách nói, thiếu ngày, theo giờ, tuần cụ thể, sửa người khác, ngoài phạm vi, prompt injection |
| Proposal | Preview không ghi nghiệp vụ; reject/expire không đổi lịch; confirm lặp không đổi thêm; hai confirm đồng thời |
| Concurrency | Hai proposal chung revision; đổi availability/member/template khi confirm; reject mùa đụng confirm; worker đụng apply |
| Authorization | Người ngoài house, member inactive, houseId trên route khác season, proposal người khác, summary/warnings rò dữ liệu |
| Resilience | Gemini/Python timeout, JSON sai, ID lạ, response quá lớn, mất mạng sau commit, backend restart |
| Flutter | Loading, preview, stale, hết hạn, refresh dữ liệu, mở lại app; thao tác thủ công vẫn dùng được |
| Regression | Complete chore/Karma, bounty, penalty và season lifecycle không đổi sai sau khi áp dụng lịch |

Test domain/planner dùng fixture; test transaction, unique constraint và concurrency phải chạy với PostgreSQL thử nghiệm. Mock/in-memory không đủ chứng minh chống ghi lặp. Test live Gemini tách khỏi suite deterministic, ghi tỷ lệ hiểu đúng thực tế và không coi JSON hợp lệ là hiểu đúng.

Điều kiện hoàn thành MVP:

- Câu “Mùa này tôi bận thứ Hai và thứ Tư” chỉ sửa hai ngày của chính người dùng sau confirm.
- Chủ nhà tạo đề xuất lịch, nhìn được số Karma từng người và lý do; chưa confirm thì assignment chưa đổi.
- Apply không vi phạm hard constraint; trường hợp thiếu người báo việc chưa giao và chặn chuyển reviewing nếu còn việc bắt buộc chưa giao.
- Mùa chỉ active khi đạt policy duyệt, không có đường API start bỏ qua.
- Proposal stale/sai quyền/hết hạn và confirm đồng thời xử lý đúng theo DB.
- AI unavailable không làm mất luồng form và phân công thủ công hợp lệ.
- Có kết quả test, API contract, migration, cấu hình chạy và kịch bản demo.

## 10. Deploy và vận hành

- Thêm ai-service vào Docker Compose; backend gọi bằng tên service nội bộ. Endpoint health phân biệt service đang sống với provider đang khả dụng.
- Cấu hình: `AI__Enabled`, `AI__BaseUrl`, `AI__ServiceKey`, `AI__TimeoutSeconds`, `AI__ProposalTtlMinutes`; Python có provider key/model qua biến môi trường.
- Không đưa Gemini key vào APK; không log token, credential hoặc toàn bộ nội dung cá nhân mặc định.
- Migration bổ sung tương thích; backup DB trước triển khai. Tắt feature flag là fallback nhanh; rollback code không tự đảo migration/dữ liệu.
- Theo dõi thời gian gọi AI, lỗi schema, số proposal pending/applied/rejected/stale, unassigned và constraint rejection. Request ID nối C#–Python.
- Retry có giới hạn cho request suy luận; mutation retry phải có idempotency. Sau mất mạng, client đọc lại trạng thái proposal để biết commit đã thành công hay chưa.

## 11. Lộ trình AI Housekeeper sau bản giao việc

1. **Giờ rảnh và ngày ngoại lệ:** thêm time interval/date override, timezone, UI và feasibility validation. Đây là điều kiện trước khi nhận câu “thứ Sáu này từ 18 giờ”.
2. **Smart reuse:** sửa clone đủ field, map chore cũ sang chore mới và preference, tạo draft mới rồi đề xuất. Không copy ID occurrence/assignment cũ một cách trực tiếp.
3. **Telemetry:** bổ sung event ID, schema version, timestamp, assignee tại thời điểm sự kiện, due/completed time và snapshot cần thiết; outbox/inbox, dedup và consumer group riêng. Topic hiện tại chưa đủ để suy ra thời lượng làm thật.
4. **Habit/risk:** tổng hợp thống kê có số mẫu, smoothing và fallback người mới. Việc hay overdue là tín hiệu rủi ro, không tự kết luận người đó ghét việc hay được miễn việc.
5. **ML:** thu thập nhãn thật trước; `CompletedAt - DueDate` không phải duration. Dữ liệu synthetic chỉ kiểm thử pipeline/demo, không chứng minh model dự đoán người dùng tốt. Chia train/test theo thời gian, so baseline, version model và feature.
6. **Swap/replan:** định nghĩa consent người bị ảnh hưởng, bảo toàn nghiệp vụ bounty/payment/penalty, khóa occurrence và xác nhận nhiều bên trước khi đổi mùa active.
7. **Chat/blitz/vision:** xây action card và opt-in/context policy riêng; ảnh đánh giá là tín hiệu hỗ trợ, không tự động phạt hoặc kết luận gian lận.

Không ước lượng cố định toàn bộ các bước mở rộng trước khi có dữ liệu và nghiệm thu MVP. Mỗi bước cần contract, test và điều kiện hoàn thành riêng.

## 12. Thứ tự commit đề xuất

1. `fix: enforce season scope and approval policy`
2. `refactor: separate allocation planning validation and persistence`
3. `feat: balance projected karma with strict allocation constraints`
4. `feat: add ai proposal storage revisions and atomic confirmation`
5. `feat: add python interpretation and allocation proposal service`
6. `feat: integrate ai client and authorized proposal endpoints`
7. `feat: add mobile ai availability and allocation preview`
8. `test: cover proposal concurrency and end-to-end allocation`
9. `docs: document ai deployment acceptance and demo`

Mỗi commit có kiểm tra liên quan và không chứa secret. Giữ tài liệu master plan hiện có làm định hướng dài hạn; dùng bản này làm backlog triển khai MVP từ source hiện tại.
