# KẾ HOẠCH KIỂM THỬ TOÀN BỘ BACKEND VÀ FLUTTER — KHÔNG GỒM AI

> **Cập nhật 19/10/2026:** áp dụng [kế hoạch không-AI hiện hành](non-ai-10-groups-implementation-plan.vi.md). payOS, QR chuyển tiền, thủ quỹ và settlement đang HOÃN để hỏi giảng viên; các mục triển khai/kiểm thử tương ứng bên dưới chỉ giữ làm lịch sử, không thuộc đợt hiện tại. Payment tracking và creditor xác nhận nhận tiền vẫn trong phạm vi.

Ngày lập: 18/10/2026. Nhóm PRM393_FA26_SE1910 có **4 thành viên**, cần tối thiểu **12 giao diện**, mỗi người 3 giao diện.

**Cập nhật oracle thanh toán:** sử dụng [kế hoạch thủ quỹ/payOS hiện hành](house-treasurer-payos-and-10-requirements-plan.vi.md) và bổ sung TRE-01…15. Với checkout qua thủ quỹ, webhook chỉ xác nhận thu; obligation chỉ hoàn tất sau đối soát và receiver xác nhận chiều chi. Những case PAY/E2E bên dưới mô tả chuyển trực tiếp phải áp dụng theo phương thức thực tế, không đánh PAID cả nghĩa vụ chỉ vì thủ quỹ đã nhận tiền. Mô hình thủ quỹ là phần mở rộng nghiệp vụ cần ghi vào đặc tả.

## 1. Mục tiêu và ranh giới

Kiểm thử sản phẩm BE/FE đã được nhóm triển khai từ lúc cài app, đăng ký đến kết thúc mùa, nhận reward và tạo mùa tiếp theo. Mỗi ca phải nối được thao tác UI, request API, dữ liệu PostgreSQL và cập nhật trên thiết bị khác khi có realtime.

Không kiểm thử Python, Gemini, ML, AI proposal, AI replan/swap, AI chat mining, AI Blitz hoặc AI vision. **Automatic Fair Allocation thuần C# vẫn thuộc phạm vi**, vì đây là nghiệp vụ cốt lõi, không phải AI. Chat thông thường, upload ảnh, camera, microphone và loa vẫn cần kiểm tra theo yêu cầu môn học.

Kế hoạch AI riêng đã được lưu tại [ai-python-full-implementation-plan.vi.md](ai-python-full-implementation-plan.vi.md). Không cần tạo thêm bản sao kế hoạch AI.

Tài liệu này là kế hoạch chạy test, chưa phải biên bản đạt. Lần lập kế hoạch chỉ đọc source và tài liệu; chưa chạy app, build APK, test tự động hay truy cập DB/server. Trạng thái khởi đầu của toàn bộ test là **NOT RUN**. Những chỗ source chưa có capability dùng trạng thái **BLOCKED — chưa có chức năng** sau khi xác nhận, không đánh dấu PASS bằng mock.

## 2. Nguồn yêu cầu và thứ tự áp dụng

1. Yêu cầu môn: dịch vụ thanh toán, đăng nhập, 3 giao diện/người, sản phẩm hoàn chỉnh, ít nhất 3 ngoại vi điện thoại.
2. SRS, Business Rules và Full System Flow người dùng đính kèm ngày 18/10/2026.
3. Contract/API và policy đã được nhóm chốt để giải quyết các điểm tài liệu chưa thống nhất.
4. Source hiện tại là đối tượng kiểm thử, không tự trở thành đáp án đúng khi khác yêu cầu.

Đặc biệt: SRS/BR ghi MVP chỉ tracking nghĩa vụ thanh toán, trong khi môn yêu cầu **dịch vụ thanh toán**. Nghiệm thu môn cần một tích hợp dịch vụ thực sự hoặc xác nhận rõ của giảng viên về hình thức được chấp nhận; nút “đã thanh toán” chưa chứng minh có dịch vụ. Sandbox có thể dùng để chứng minh tích hợp nếu được chấp nhận; phải ghi đúng môi trường, không báo đã chuyển tiền thật.

## 3. Quyết định cần ghi vào test oracle trước khi chạy

Không sửa kết quả mong đợi để phù hợp lỗi source. Các điểm còn mở được ghi DECISION REQUIRED và chốt với người phụ trách nghiệp vụ trước khi kết luận PASS/FAIL cho ca phụ thuộc.

| Mã | Điểm cần thống nhất | Oracle đề xuất/nguồn |
|---|---|---|
| D01 | Thời điểm sinh occurrence | Tạo để review ở draft/reviewing; chỉ được thực thi khi active; không sinh trùng khi active |
| D02 | Ai xác nhận mùa? | BR-CONFIRM: mọi required member xác nhận; owner không có quyền bỏ qua |
| D03 | Quyền manual và availability | BR-AVAIL-03: availability không chặn manual, chỉ cảnh báo; auto vẫn là hard constraint |
| D04 | Khi nào được post bounty? | Flow/SRS đặt sau critical overdue, BR-BOUNTY-01 cho phép sau assigned; cần chọn một policy |
| D05 | Bounty hết hạn lúc nào? | Phải có thời hạn hợp lý sau thời điểm mở; nếu chỉ mở khi overdue thì không dùng due date đã qua làm expiry |
| D06 | Snapshot compensation | SRS nói lúc tạo bounty, BR nói lúc forced reassignment; chốt mốc và cấm giảm amount sau snapshot |
| D07 | Payment manual ai được xác nhận? | Flow ghi receiver xác nhận, source cho debtor hoặc creditor; chọn policy tường minh |
| D08 | Người bị reassigned tiếp tục thất bại | Penalty theo trách nhiệm mới; không lấy counter người trước để coi người sau đã bị phạt đủ. Giới hạn chain cụ thể bao nhiêu lần? |
| D09 | Household 3–6 | Tạo nhà ban đầu 1 người là hợp lệ để mời; giới hạn tối đa 6; chốt tối thiểu để bắt đầu mùa |
| D10 | Thay đổi membership/lịch khi reviewing hoặc active | Ai được sửa, vô hiệu confirmation nào, xử lý assignment/payment/reward còn tồn |
| D11 | Múi giờ và mốc biên | Ngày giờ household Việt Nam, lưu instant UTC; test đúng dấu bằng deadline/expiry, không theo timezone máy tùy ý |
| D12 | Tie ranking, reward cost | Chốt cùng rank hay tie-break cố định; bonus Karma là tổng điểm bonus theo BR, không chỉ số lần complete |
| D13 | Month/year/custom frequency | Ngày 29/30/31, năm nhuận, anchor và custom rule cần mô tả để biết ngày dự kiến |
| D14 | Notification khi app đóng | SignalR trong app hay có push hệ điều hành? Không coi realtime khi mở app là bằng chứng nhận khi app đóng |
| D15 | Service payment gắn nghiệp vụ nào? | Bounty hoặc compensation; chốt lúc tạo nghĩa vụ và lúc cho phép thanh toán; không thanh toán hai lần khi có manual settle |

## 4. Môi trường và dữ liệu kiểm thử

### 4.1. Môi trường

- Test local với PostgreSQL/Redis/Kafka riêng, backend test config và dữ liệu seed có thể reset. Không chạy test phá dữ liệu trên DB đang dùng để demo hoặc production.
- Staging dùng API HTTPS và SignalR thật; lưu commit/backend version, migration version, APK version, thiết bị/OS và URL môi trường.
- Tối thiểu 2 điện thoại Android để kiểm tra realtime, QR, camera/mic/loa; có thể dùng emulator cho tài khoản thứ ba/bốn. Vẫn cần test luồng cả 4 tài khoản, không bắt buộc 4 máy vật lý cùng lúc.
- Test **APK release**, không chỉ debug hoặc web preview; `UI_PREVIEW=false`, không dùng mock repository/preview ID. API và SignalR dùng cùng môi trường.
- Kiểm tra manifest đã merge của release: INTERNET, CAMERA, RECORD_AUDIO theo tính năng; kiểm tra iOS usage description nếu nhóm nộp iOS.
- Cấu hình provider thanh toán sandbox bằng credential server; không đưa secret vào APK/log.

### 4.2. Tài khoản và fixture

| Fixture | Mục đích |
|---|---|
| A | Owner nhà H1, assignee một số việc |
| B, C, D | 3 member active của H1 |
| X | Người thuộc H2, kiểm tra không truy cập H1 |
| L | Người từng rời H1, kiểm tra lịch sử, quyền và rejoin |
| E, F, G | Bổ sung để kiểm tra 6 người, người thứ 7 và join đồng thời |
| S1 | Draft 7 ngày dùng để đối chiếu generation dễ tính |
| S2 | Reviewing, 4 required members |
| S3 | Active, occurrence normal/bonus/overdue/bounty được seed riêng |
| S4 | Completed có snapshot ranking/reward |

Tạo chore có Karma 10/20/30/40, phút 15/30/60, difficulty khác nhau để phát hiện thuật toán dùng nhầm phút và Karma. Có người bận cả ngày, người chỉ rảnh một khoảng giờ, giới hạn tải thấp, thiếu availability và người inactive.

Tách occurrence cho mỗi nhánh: complete thường, bonus claim, bounty accepted, bounty expired/forced, Chore Pass. Không tái sử dụng cùng bản ghi cho các ca khiến trạng thái trước phụ thuộc thứ tự test ngoài ý muốn.

### 4.3. Kiểm thử thời gian không phải chờ thật

Dùng `TimeProvider`/clock abstraction nếu đã có, hoặc fixture thời điểm cố định và service/job được kích hoạt trong môi trường test. Với code đang dùng UTC trực tiếp, seed các due/expiry khác nhau trong database test theo script có version. Không chỉnh đồng hồ server chung.

Test `due−1s`, `due`, `due+1s`, `+11h59m59s`, `+12h`, `+24h`, `+36h`, `+48h`; reward trước/đúng/sau 7 ngày claim và 10 ngày sau claim. Ghi rõ scheduler interval để phân biệt business time với độ trễ job.

## 5. Phân tầng test và cấu trúc bộ kiểm thử dự kiến

| Tầng | Chứng minh gì? | Vị trí |
|---|---|---|
| Unit BE | Rule, frequency, workload, penalty boundary, calculation | `backend/tests/UnitTests/Services/` |
| Integration BE | PostgreSQL transaction/constraint, auth, API, Kafka/worker, concurrency | `backend/tests/IntegrationTests/` |
| Unit/widget FE | Mapping DTO, error state, form, provider/router | `mobile/test/` |
| E2E mobile | Thao tác thật → API → DB → UI/realtime | `mobile/integration_test/` — cần bổ sung bộ test |
| Manual device | Camera/mic/loa, permission, release, mạng, payment redirect | Checklist + video trên máy thật |

Các file test nên tách theo Auth, House, SeasonLifecycle, ChoreGeneration, ManualAllocation, AutomaticAllocation, CompletionKarma, BonusClaim, BountyAcceptance, BountyExpiration, Payment, Rewards, Authorization, ChatRealtime. Unit test dùng mock hợp lý; race condition/transaction phải test với PostgreSQL thật và request đồng thời. Không xem file `Test1()` trống là coverage.

Lệnh dự kiến, chạy sau khi cấu hình test database và dependency đầy đủ:

```powershell
dotnet test backend/ChoreWars.slnx
flutter analyze
flutter test
flutter test integration_test
flutter build apk --release --dart-define=UI_PREVIEW=false --dart-define=API_BASE_URL=<https-api>/api --dart-define=SIGNALR_BASE_URL=<https-api>/hubs
```

Các lệnh Flutter chạy trong `mobile/`; integration test chỉ chạy khi đã có suite/thiết bị. Kiểm tra lại path solution trước khi thực thi. Đây chưa phải các lệnh đã chạy thành công.

## 6. Cách ghi một test case

Mỗi case có: ID, rule/SRS liên quan, priority, tài khoản/house, dữ liệu trước, bước UI/API, expected HTTP/response, expected UI, expected DB, actual, PASS/FAIL/BLOCKED/NOT RUN, evidence, bug ID, tester và build.

DB checks dùng khóa thực tế do fixture tạo; ghi đủ occurrence, assignee, status, SnapshotKarma, completed time, transaction count/sum, obligation payer/receiver/amount/reason/status. Không cần xuất toàn bộ DB hoặc token vào báo cáo.

Mỗi ca quyền phải thử cả **REST** và **SignalR** nếu module có hub. Không dừng ở việc UI đã ẩn nút.

## 7. Danh mục test từ đầu đến cuối

Ưu tiên P0: quyền, tiền/Karma, ghi trùng, hỏng dữ liệu, khóa mùa. P1: chức năng chính, ngoại vi và yêu cầu môn. P2: trải nghiệm/hiển thị phụ. Những ca dưới đây đều cần ghi actual/evidence khi chạy.

### 7.1. Cài đặt, auth và profile — BR-AUTH

| ID | Thao tác/biến thể | Kết quả cần kiểm tra |
|---|---|---|
| BOOT-01 | Cài mới APK release, mở app, không có token | Không crash; vào login; gọi đúng backend thật |
| AUTH-01 | Register email mới, password hợp lệ | 1 user, password hash, UI đến luồng đúng |
| AUTH-02 | Email trùng khác hoa/thường, email sai, password thiếu | Validation nhất quán FE/BE; không tạo user trùng |
| AUTH-03 | Login đúng/sai, account không có | Đúng có token; sai không cấp session, thông báo phù hợp |
| AUTH-04 | Đóng/mở app, access token hết hạn nhưng refresh còn hạn | Tự duy trì session, dữ liệu tải lại, không yêu cầu login thừa |
| AUTH-05 | Refresh hết hạn/revoked, logout rồi dùng refresh cũ | Không refresh được; local token xóa, về login |
| AUTH-06 | Nhiều request đồng thời nhận 401 | Refresh có điều phối, không mất session/ghi lặp action |
| AUTH-07 | Logout/relogin A→B | Cache/provider/hub của A không lộ sang B |
| AUTH-08 | Profile sửa tên/avatar; upload sai MIME/quá cỡ, mất mạng | UI và DB đồng nhất; lỗi không lưu nửa chừng |
| AUTH-09 | API thiếu JWT, JWT sai/hết hạn, userId giả trong body | 401/403 phù hợp; không impersonate |

### 7.2. Household, invite và membership — BR-HOUSE

| ID | Thao tác/biến thể | Kết quả cần kiểm tra |
|---|---|---|
| HOUSE-01 | A tạo H1 tên hợp lệ/rỗng | Owner record + house + room nhất quán; tên rỗng bị chặn |
| HOUSE-02 | B nhập invite code đúng/sai, gửi join lặp | Join đúng một lần; code sai không ghi membership |
| HOUSE-03 | C quét QR thật | Thấy thông tin nhà, xác nhận rồi mới join theo flow; scan trùng không join lặp |
| HOUSE-04 | Nhà 6 người, G join; hai người tranh slot cuối | Không vượt 6; kiểm tra giới hạn ở BE/DB, không chỉ UI |
| HOUSE-05 | Member thường tạo/sửa chore/routine theo BR-HOUSE-05 | Được phép đúng policy; không bị ép thành owner-only |
| HOUSE-06 | Owner chuyển quyền; owner rời hoặc bị kick | Có đúng owner theo policy, lịch sử không mất |
| HOUSE-07 | L leave khi không việc; leave khi có mandatory assignment | Trường hợp có việc bị chặn/được xử lý trước; không bỏ việc vô chủ |
| HOUSE-08 | L rejoin bằng invite còn hiệu lực | Kích hoạt lại hợp lệ, không duplicate member/history |
| HOUSE-09 | Kick/leave khi còn bounty/payment/reward | Nghĩa vụ/historical records giữ nguyên, policy rõ |
| HOUSE-10 | Quản lý invite/disband theo SRS; user không quyền thử API | Đúng quyền và giữ audit; capability chưa có ghi BLOCKED |
| HOUSE-11 | X đổi houseId/memberId trên URL | Không đọc/sửa H1; route house và entity thực phải khớp |

### 7.3. Chore template, deadline và generation — BR-CHORE/BR-OCC

| ID | Thao tác/biến thể | Kết quả cần kiểm tra |
|---|---|---|
| CHORE-01 | Create/edit NORMAL và BONUS | DTO/UI/DB khớp tên, Karma, loại, frequency, difficulty, minutes |
| CHORE-02 | Karma ≤0, phút âm, frequency X≤0, enum sai | Không ghi dữ liệu không hợp lệ |
| CHORE-03 | Đặt deadline 20:00 rồi generate | Occurrence đúng 20:00 theo timezone, không tự đổi 23:59 |
| GEN-01 | DAILY trong 7 ngày | Đúng 7 occurrence trong khoảng, không ngoài season |
| GEN-02 | Every 3 days từ anchor đã chốt | Ngày 1/4/7…, số lượng và deadline khớp |
| GEN-03 | Weekly và specific Mon/Wed trong 2 tuần | Đúng thứ và count, kiểm tra Sunday=0 |
| GEN-04 | X_TIMES_PER_WEEK=2 | Mỗi tuần theo policy có đúng số ngày, không fallback thành daily |
| GEN-05 | Monthly, every 2 months, yearly | Đúng anchor, ngày 29/30/31, tháng ngắn, năm nhuận |
| GEN-06 | CUSTOM | Chu kỳ mô tả được, input/output kiểm chứng được; chưa định nghĩa ghi DECISION REQUIRED |
| GEN-07 | H1 có chore của nhiều season và template chung | Chỉ sinh tập template được chọn, không lẫn lịch mùa khác |
| GEN-08 | Generate lặp/đồng thời, lỗi giữa generation và allocation | Không occurrence trùng, không dữ liệu dở; retry có kết quả rõ |
| GEN-09 | Edit/delete template ở draft/reviewing/active/completed | Theo policy D10; snapshot/historical Karma và completion không bị sửa/xóa sai |

### 7.4. Availability, manual và auto thuần C# — BR-AVAIL/MANUAL/AUTO

| ID | Thao tác/biến thể | Kết quả cần kiểm tra |
|---|---|---|
| ALLOC-01 | Mỗi người lưu availability, đọc lại trên app | Của đúng user/season; ngày/giờ được lưu theo yêu cầu |
| ALLOC-02 | Manual: A 2×20 Karma, B 4×10 Karma | Workload đều 40, không hiểu nhầm A nhẹ hơn chỉ vì ít việc |
| ALLOC-03 | Manual assign lúc bận | BR-AVAIL-03 cho giữ assignment, cảnh báo feasibility nếu có; không tự đổi |
| ALLOC-04 | Manual method rồi generate | Không tự chạy auto giao lịch thay người dùng |
| ALLOC-05 | Auto: người bận/inactive, thiếu deadline feasibility, max workload | Không giao người vi phạm hard constraint |
| ALLOC-06 | Auto: tất cả bận hoặc vượt tải | Trả không khả thi/unassigned + lý do, không phá constraint để đủ assignment |
| ALLOC-07 | Tải cũ đã có, Karma khác phút | Tính cả tải cũ, cân bằng Karma đúng BR, không chỉ cộng phút vòng chạy mới |
| ALLOC-08 | Ít occurrence hơn thành viên | Không tạo việc giả, có thể có người 0 việc, cảnh báo phù hợp |
| ALLOC-09 | Rotation qua các kỳ và owner tham gia | Owner không được ưu tiên nhẹ; rotation có bằng chứng lịch sử |
| ALLOC-10 | BONUS trong season | Không tự giao/không góp fairness mandatory; bonus vẫn cộng leaderboard khi làm |
| ALLOC-11 | Warning manual mất cân bằng | Cảnh báo có số liệu; người dùng giữ lịch được; DB không tự sửa |
| ALLOC-12 | Tuần qua năm mới/season boundary | Counter ngày/tuần và timezone đúng, không gộp nhầm tuần khác năm |

### 7.5. Review và season lifecycle — BR-SEASON/CONFIRM

| ID | Thao tác/biến thể | Kết quả cần kiểm tra |
|---|---|---|
| SEASON-01 | Create start/end sai, quá thời lượng, có active khác | Validation; tối đa 1 active/house kể cả request đồng thời |
| SEASON-02 | Generate lịch | DRAFT→REVIEWING; UI đủ lịch, summary Karma, required confirmations |
| SEASON-03 | A confirm, còn B/C/D pending | Vẫn REVIEWING, chưa hoạt động/chưa khóa như active |
| SEASON-04 | Đủ A/B/C/D confirm, confirm lặp/đồng thời | ACTIVE đúng một lần; required list/status chính xác |
| SEASON-05 | B reject với reason | Reason được lưu/hiển thị, chỉnh/review lại; confirm cũ không dùng lại |
| SEASON-06 | Gọi start trực tiếp từ draft/chưa đủ confirm | Không bỏ qua quy tắc tất cả xác nhận |
| SEASON-07 | Member mới/rời nhà lúc reviewing | Áp dụng D10; không activate bằng danh sách thiếu/sai người |
| SEASON-08 | Complete/penalty/worker trước active | Không chạy nghiệp vụ như mùa active trên draft/reviewing |
| SEASON-09 | Reuse/edit/new season | Copy đủ field/frequency, ID mới, lịch sử mùa cũ giữ nguyên |
| SEASON-10 | Reject/regenerate S1 khi H1 còn S2/S4 | Không xóa occurrence/confirmation mùa khác |
| SEASON-11 | Member/X truy cập summary/warnings/manual API | Membership active, đúng house/season ở cả GET và mutation |

### 7.6. Completion, Karma và bonus — BR-OCC/KARMA/BONUS

| ID | Thao tác/biến thể | Kết quả cần kiểm tra |
|---|---|---|
| DONE-01 | Assignee complete normal | Status COMPLETED, completed time/actor truy vết, đúng snapshot Karma và 1 transaction |
| DONE-02 | User khác complete, user cũ sau reassignment complete | Bị từ chối, DB không thay đổi |
| DONE-03 | Double tap, retry sau mất mạng, 2 request complete đồng thời | Chỉ 1 lần completion/Karma/payment phát sinh |
| DONE-04 | Template Karma thay đổi sau lock | Complete dùng snapshot, historical workload/reward không đổi ngầm |
| DONE-05 | Complete sau penalty | Được complete theo policy; penalty đã phát sinh không hoàn lại |
| DONE-06 | Optional proof image đúng/sai MIME/quá cỡ/link ngoài | Quyền upload/xem và giới hạn đúng; lỗi không làm sai completion |
| BONUS-01 | Claim bonus available, hai người claim cùng lúc | Một người nhận; không đưa vào mandatory allocation |
| BONUS-02 | Complete bonus | Đúng bonus Karma, leaderboard tăng, không double credit |
| KARMA-01 | Tổng balance và history | Tổng ledger khớp user/house/season, không sửa trực tiếp bỏ audit |
| KARMA-02 | Karma âm và dữ liệu H2 | Âm được hiển thị đúng; không lẫn ledger giữa nhà |

### 7.7. Reminder, overdue và penalty — BR-PENALTY/NOTI

| ID | Thao tác/biến thể | Kết quả cần kiểm tra |
|---|---|---|
| PEN-01 | Trước deadline, đúng deadline, sau deadline 1s | Chuyển overdue theo oracle; chưa đến 12h thì chưa phạt |
| PEN-02 | +12h/+24h/+36h | Lần lượt tổng −5/−10/−15, đúng người, từng ledger record rõ |
| PEN-03 | +48h/+72h; job chạy lặp/2 worker đồng thời | Không vượt −15 cho responsibility episode theo policy; không phạt trùng |
| PEN-04 | Worker dừng rồi chạy lại sau 30h | Catch-up đúng mốc đã qua, không phạt mốc chưa đến |
| PEN-05 | Complete cùng lúc penalty job | Kết quả serialize hợp lệ; không phạt sau complete trái rule, không balance lệch |
| PEN-06 | Reminder gần deadline, app mở/đóng/mất mạng | In-app/push theo D14; nhắc đúng người và amount khi có penalty |
| PEN-07 | Người nhận forced reassignment cũng không làm | Failure/penalty của người mới độc lập; không bị counter cũ miễn phạt hoặc phạt chồng sai |

### 7.8. Bounty accepted/expired và compensation — BR-BOUNTY/REASSIGN/DATA

| ID | Thao tác/biến thể | Kết quả cần kiểm tra |
|---|---|---|
| BOU-01 | Assignee post với amount >0, user khác, amount≤0 | Đúng quyền, house/occurrence đúng, validation BE |
| BOU-02 | Post theo D04, kiểm tra expiresAt theo D05 | Bounty có thời gian nhận thực tế, không vừa tạo đã hết hạn ngoài policy |
| BOU-03 | 2 open bounty cùng occurrence | Chỉ tối đa 1 active, kể cả request đồng thời |
| BOU-04 | Tự accept, X accept, member inactive accept, accept sau expiry | Từ chối, không chuyển assignment |
| BOU-05 | B và C accept cùng lúc | Chính xác một người thành công, một assignee, không duplicate obligation |
| BOU-06 | Accepted member complete | Normal snapshot Karma cho người làm, người gốc không nhận completion; nghĩa vụ amount gốc đúng |
| BOU-07 | Người gốc đã bị −15 trước accept | Penalty giữ nguyên, không hoàn tiền/Karma trái rule |
| BOU-08 | Bounty hết hạn không ai nhận | Expired, reassignment phù hợp availability/workload/rotation; người gốc còn penalty |
| BOU-09 | Amount 30.000, forced reassignment | Compensation 36.000 snapshot; người nhận hoàn thành +0 Karma |
| BOU-10 | Audit forced obligation | Có house/season/occurrence, payer/receiver/amount/reason/time; UI truy ra đúng việc |
| BOU-11 | Complete/accept/expire cùng lúc | Một kết quả hợp lệ, không tạo compensation cho chore đã completed |
| BOU-12 | Worker retry/restart; không còn người hợp lệ | Không tạo obligation trùng hoặc chọn sai người; có trạng thái không khả thi |
| BOU-13 | Người forced tiếp tục fail/post bounty | Policy chain D08 được giữ; không nhân compensation vô hạn |

### 7.9. Payment tracking và dịch vụ thanh toán môn học

| ID | Thao tác/biến thể | Kết quả cần kiểm tra |
|---|---|---|
| PAY-01 | List/detail obligation A/B/X | Đúng nhà/người/quyền và amount; X không đọc được |
| PAY-02 | Manual Received/settle theo D07 | Người có quyền xác nhận, PAID/PaidAt và audit đúng, bấm lặp không ghi thêm |
| PAY-03 | Backend tạo checkout cho obligation | Order gắn nghiệp vụ và amount/currency từ server, không tin amount app sửa |
| PAY-04 | Mở link/provider, thanh toán sandbox thành công | Backend xác minh provider result; PAID đúng 1 lần, app query lại khớp DB |
| PAY-05 | Cancel/fail/pending/quay lại app sớm | Không tự PAID chỉ vì return URL/hiển thị success |
| PAY-06 | Webhook giả/chữ ký sai/amount sai/order sai | Bị từ chối, trạng thái nghiệp vụ không đổi |
| PAY-07 | Webhook duplicate/out-of-order và timeout sau commit | Idempotency, không thanh toán/settle hai lần; đối soát query được |
| PAY-08 | Hai checkout cùng obligation; manual settle đụng webhook | Không tạo hai nghĩa vụ/kết quả tiền mâu thuẫn; đúng policy D15 |
| PAY-09 | Thiết bị Wi-Fi/4G, app bị đóng khi đang trả tiền | Mở lại nhận trạng thái từ BE; deep link/return hợp lệ |

Nếu chưa có gateway/provider, PAY-03…09 là **BLOCKED — thiếu dịch vụ thanh toán**, không thay thế bằng gọi settle rồi đánh dấu đạt yêu cầu môn.

### 7.10. Leaderboard, reward, Chore Pass và achievements

| ID | Thao tác/biến thể | Kết quả cần kiểm tra |
|---|---|---|
| RANK-01 | Normal+bonus−penalty giữa A/B/C/D | Ranking theo ledger season, không theo workload dự kiến |
| RANK-02 | Bằng Karma, khác mandatory count/bonus Karma | Tie-break đúng D12; không dùng nhầm số bonus chores thay tổng bonus points |
| RANK-03 | Job/manual end đồng thời, restart job | COMPLETED và final ranking/reward đúng một lần |
| RANK-04 | Dữ liệu thay đổi sau end | Snapshot ranking không đổi, không tiếp tục sinh occurrence sai |
| REWARD-01 | Member tạo reward tùy chỉnh theo BR-HOUSE-05/REWARD | Có luồng BE+FE đúng quyền, cost và reward được lưu |
| REWARD-02 | Redeem đủ/thiếu Karma, hai redeem đồng thời | Không tiêu vượt số dư, có ledger deduction, đúng quantity/policy |
| PASS-01 | Rank #1 claim trước/đúng/sau 7 ngày | Trạng thái và boundary đúng, user khác không claim hộ |
| PASS-02 | Use trước/đúng/sau 10 ngày sau claim | Một pass dùng một lần, hết hạn không dùng được |
| PASS-03 | Use trên chore mình/người khác/đã completed/nhà khác | Chỉ áp dụng đúng rule; không xóa occurrence hoặc cộng completion cho người dùng pass |
| PASS-04 | Việc cần người thay, không có người hợp lệ | Xử lý khả thi, không chọn inactive/bận, không dùng mất pass mà việc vô chủ |
| ACH-01 | Đạt điều kiện achievement, consumer replay | Trao đúng một lần theo house/season/condition |
| ACH-02 | Share achievement card ra ứng dụng ngoài | Card đúng số liệu, share/cancel không crash; chưa có capability ghi BLOCKED |

### 7.11. Chat và notification thường — BR-CHAT-01/NOTI

| ID | Thao tác/biến thể | Kết quả cần kiểm tra |
|---|---|---|
| CHAT-01 | A/B join room, gửi text | DB persist trước broadcast, sender và receiver nhận bản server, không duplicate |
| CHAT-02 | X biết roomId H1 rồi gọi JoinRoom/GET history/SendMessage | Không join group/đọc/nghe/gửi trái quyền |
| CHAT-03 | Leave/kick khi vẫn giữ kết nối hub | Mất quyền nhận/gửi đúng policy, không nghe tiếp room cũ |
| CHAT-04 | Reconnect, background/foreground, pagination | Lịch sử đúng thứ tự, không mất/trùng tin, scroll/load-more hoạt động |
| CHAT-05 | Upload ảnh sai MIME/quá cỡ, X mở file nhà khác | Access/file policy đúng; không chỉ giấu URL trong UI |
| NOTI-01 | Reminder/penalty/bounty/reassign/reward/season end | Đúng recipient, payload, amount và deep link tới đúng entity |
| NOTI-02 | Read/unread, nhận cùng event nhiều lần | Counter/status bền vững, không spam; user khác không mark hộ |
| NOTI-03 | Expired JWT, chuyển nhà/logout | Reconnect xác thực đúng, không nhận notification user/house cũ |

### 7.12. Ba ngoại vi — độc lập AI

| ID | Ngoại vi | Kịch bản nghiệm thu |
|---|---|---|
| HW-01 | Camera | Hai máy: một máy hiện invite QR, máy kia quét → preview → confirm join; camera cũng có thể dùng proof photo |
| HW-02 | Camera permissions | Deny, deny permanently, quay lại settings, app resume; nhập invite thủ công vẫn được |
| HW-03 | Microphone | Có thể chọn ghi voice note trong chat, hoặc voice nhập form; ghi/stop/cancel, dữ liệu thật được thu, không cần Python/Gemini |
| HW-04 | Microphone permissions | Deny, không có mic/đang bị app khác sử dụng, app background; thông báo và fallback phù hợp |
| HW-05 | Loa | Phát voice note hoặc đọc reminder bằng TTS thường; có âm thanh thật, stop/replay/volume hoạt động |
| HW-06 | Audio lifecycle | Cuộc gọi chen vào, khóa màn hình, chuyển app, tai nghe/Bluetooth, mute; không tự phát sai thời điểm |

Camera quét QR và camera chụp ảnh vẫn là **một loại ngoại vi**. Nút notification im lặng/icon loa chưa chứng minh dùng loa. Nếu voice nằm trong AI chưa triển khai, phạm vi không-AI chưa thể ghi đủ 3; cần một luồng audio không phụ thuộc AI hoặc ghi rõ chỉ nghiệm thu sau khi chức năng đó chạy thật.

## 8. Kịch bản nghiệm thu xuyên suốt

### E2E-01 — Người mới đến mùa tiếp theo

1. Cài APK release; đăng ký A/B/C/D, login, mở lại app giữ session.
2. A tạo H1; B join code, C join QR có xác nhận, D join.
3. Mỗi người cập nhật profile và availability; tạo routine có Karma/frequency/deadline.
4. Tạo season manual; phân công có chênh Karma; xem warning, giữ hoặc chỉnh lịch.
5. Review: A confirm chưa active; B reject có reason → sửa → mọi người confirm lại → active.
6. A complete normal có ảnh nếu chọn; B/C/D thấy cập nhật; retry không cộng trùng.
7. C claim/complete bonus; balance/history/leaderboard đúng.
8. End season theo clock/fixture; final ranking, reward và achievement đúng.
9. Winner claim pass; tạo season tiếp theo bằng reuse/edit/new; dùng pass trong phạm vi được phép, việc vẫn có người xử lý.
10. Logout/relogin và restart app/server; dữ liệu vẫn đúng, không dùng cache giả để chứng minh.

### E2E-02 — Auto, overdue, bounty accepted, thanh toán

Season riêng automatic → kiểm tra eligibility và Karma → tất cả confirm → seed thời gian overdue tới −15 → post bounty theo policy → B accept → B complete nhận normal Karma → nghĩa vụ A trả B đúng amount → checkout provider sandbox → backend xác minh → PAID → A vẫn giữ penalty.

### E2E-03 — Bounty expired và forced reassignment

Occurrence riêng → bounty 30.000 hết hạn → chọn người hợp lệ → obligation 36.000 có audit → forced assignee complete +0 Karma → thanh toán/Received theo luồng được chọn. Chạy lại worker không thêm compensation. Nhánh riêng kiểm tra người forced cũng fail theo policy D08.

### E2E-04 — Quyền và cạnh tranh

X dùng UUID thật của H1 để gọi REST/hub → không truy cập; B/C accept cùng bounty → một người thắng; complete/penalty/expire cùng thời điểm → chỉ một kết quả nghiệp vụ nhất quán; token hết hạn/mất mạng sau commit không gây double action.

### E2E-05 — Yêu cầu môn trên điện thoại

Login thật → camera quét QR → mic ghi voice note → loa phát lại → tạo và hoàn tất giao dịch provider sandbox → mở ít nhất 12 màn được phân cho 4 người → đối chiếu backend/DB. Không dùng AI trong kịch bản này.

## 9. 12 giao diện tối thiểu cho 4 thành viên

Source hiện có 38 file `*screen.dart` trong features. Đây là số file, không phải 38 giao diện đã đạt: có màn tương tự/trùng module, route trùng và màn có thể chưa truy cập được.

Bảng dưới là **phân công mẫu**, chưa phải xác nhận đóng góp. Nhóm điền tên thật, route, commit/PR và ảnh/video của mỗi người; không ghi người làm nếu chưa xác minh.

| Thành viên | Màn 1 | Màn 2 | Màn 3 | Bằng chứng |
|---|---|---|---|---|
| Bạn | Login | Register | Edit profile | Route, commit, video — cần điền |
| Thành viên 2 | House list/dashboard | Create house | QR join | Cần điền |
| Thành viên 3 | Chore list | Create/edit chore | Chore detail/complete | Cần điền |
| Thành viên 4 | Bounty board | Bounty detail/accept | Payment obligations/checkout | Cần điền |

Các màn review schedule, availability, leaderboard, rewards, chat, notifications là bổ sung để demo sản phẩm hoàn chỉnh. Không tính create/edit của cùng một form thành hai giao diện nếu giảng viên không chấp nhận. Mỗi màn được tính phải truy cập được trong release, có chức năng riêng, loading/error/empty state và dữ liệu thật phù hợp.

## 10. Nonfunctional, release và dữ liệu

- Kiểm tra loading/empty/error, back navigation/deep link thiếu `state.extra`, keyboard, màn nhỏ, chữ lớn, tiếng Việt và số tiền không mất chữ/overflow.
- Kiểm tra route trùng `/bounties`, `/karma-history` và hai module `chore/chores`, `profile/auth`, `leaderboard/gamification`; xác định màn đang chạy thật, không chỉ file tồn tại.
- Mất Wi-Fi, đổi 4G, timeout, retry, double tap; sau commit nhưng trước response phải đọc lại server, không đoán thất bại.
- Không log password/token/secret; upload kiểm tra MIME/size/quyền, object ID trên route không được tin mặc định.
- Kiểm tra concurrency với DB thật, không gọi tuần tự rồi kết luận race condition đã được xử lý.
- Restart backend/Kafka/Redis trong môi trường thử nghiệm; không mất DB, không phát lại event gây double Karma/compensation/reward.
- Migration từ schema trước với dữ liệu seed, backup/restore thử, version ứng dụng khớp schema. Rollback code không tự phục hồi DB.
- APK không chứa endpoint emulator mặc định khi dùng máy thật; API/SignalR HTTPS và storage ảnh bền vững trên server.
- Đo response time/error rate trên bộ dữ liệu đại diện; ghi số đo thật thay vì tự tuyên bố đạt SLA chưa định nghĩa.

## 11. Lịch thực hiện và phân công test

| Ngày | Công việc | Đầu ra |
|---|---|---|
| 1 | Chốt D01–D15, setup môi trường/fixture, smoke release | Environment manifest, decision log, test data |
| 2 | Auth/house/chore/frequency; unit/widget test liên quan | Evidence và bug list có bước tái hiện |
| 3 | Availability/manual/auto/review/confirmation | Lifecycle và fairness được kiểm chứng |
| 4 | Completion/Karma/penalty/bounty/race tests | Ledger/obligation before-after, concurrency results |
| 5 | Payment service, rewards/chat/notification, 3 ngoại vi | Provider evidence, video thiết bị, bảng 12 màn |
| 6 | E2E-01…05, regression sau sửa, release/restart/deploy | Test report, APK/build ID, danh sách lỗi còn lại |

Lịch trên là ngân sách **kiểm thử**, chưa bao gồm thời gian triển khai capability còn thiếu hoặc sửa bug lớn. Nếu provider/mic/loa chưa có, chạy phần không bị chặn trước và ghi BLOCKED cho phần thiếu, không thay bằng kết quả giả.

Phân công theo 4 người: người 1 phụ trách auth/house; người 2 chore/allocation/season; người 3 Karma/penalty/bounty/payment; người 4 Flutter device/realtime/reward/release. Mỗi bug được người khác xác minh lại; mọi người đều chạy ít nhất một E2E hoàn chỉnh, không chỉ module mình code.

## 12. Mẫu bug và điều kiện kết thúc

Bug gồm: ID, priority, rule, build, account/house/fixture, steps, expected/actual, HTTP/request ID, DB count/sum cần thiết, ảnh/video và owner. Không đưa token hay credential vào artifact.

Nghiệm thu khi:

- P0/P1 trong phạm vi đã chạy và đạt, không còn lỗi sai quyền, sai tiền/Karma, ghi trùng hoặc hỏng dữ liệu.
- 5 yêu cầu môn có bằng chứng: login, provider payment, 12 màn/4 người, product end-to-end, 3 loại ngoại vi thật.
- Tất cả test không đạt/bị chặn được liệt kê; không tính tỷ lệ PASS trên số ca đã chạy rồi giấu ca blocked.
- Regression sau fix đạt; APK release và backend commit/migration/version được ghi lại.
- Có tài khoản demo giả lập, dữ liệu seed, runbook, test report, video dự phòng và kế hoạch rollback.

Biên bản kết quả cuối nên ghi: tổng test, PASS, FAIL, BLOCKED, NOT RUN; quyết định còn mở; danh sách bug; build đã nghiệm thu. **Kế hoạch này chưa xác nhận BE/FE đã PASS**, cũng không thay đổi code nghiệp vụ.
