# Test case backend và frontend từ đầu đến cuối

Ngày: 28/10/2026 (Asia/Saigon). Phạm vi: source hiện tại, gồm Google, AI, Order email, My Debts và lịch Overview mới. Tài liệu này là bộ ca kiểm thử để thực thi, **không phải báo cáo tất cả chức năng đã PASS**. Trạng thái ban đầu của từng ID bên dưới là **NOT RUN**.

## 1. Chuẩn bị và quy tắc ghi kết quả

- A: owner H1; B: member H1, hai tài khoản và hai browser profile/thiết bị độc lập. Dùng cả hai mạng khác nhau nhưng cùng API/SignalR/database cloud để nghiệm thu đồng bộ. Hai Docker DB riêng không tự đồng bộ.
- X: thuộc H2, không thuộc H1; L: đã rời H1. Có thể dùng phiên thứ ba/fixture để test quyền; không dùng A giả làm X bằng cách chỉ đổi tên trên UI.
- H1 có draft/reviewing/active/completed season tách biệt theo từng ca, không tái dùng occurrence đã hoàn thành cho case overdue/bounty. Mùa cho ca cơ bản 7 ngày, mọi dữ liệu gắn nhãn QA và có ID thật.
- Các giới hạn cần trên 2 người dùng fixture riêng 3–6 thành viên; không coi hai tài khoản đủ để chứng minh thuật toán phân công cho 6 người. Thời gian test lưu UTC, đối chiếu lịch Việt Nam UTC+7.
- Backend, AI, FE cùng bản build; ghi SHA, URL, thời điểm, migrations. `UI_PREVIEW=false`; không dùng repo mock cho E2E. PostgreSQL/Redis/Kafka test riêng cho race/crash/reset. Không chạy xóa DB hoặc tua đồng hồ trên production.
- Local Google: origin/port khớp URL Flutter thực tế đã đăng ký trong Google Cloud, Client ID đã cấu hình; Google test users gồm A/B. Backend bật Google và migration Google đã áp dụng. Frontend mới cần restart/rebuild, hot reload không thay dart-define cũ.
- Mail: SMTP đã cấu hình, supplier contact/catalog thật hoặc fixture QA được ghi rõ; dùng mailbox test do nhóm kiểm soát. Case Send có gửi email thật nên chỉ chạy với recipient test. Cuộc gọi, thanh toán thật phải do tester chủ động thực hiện; không phát sinh chỉ vì mở trang.
- AI cần health ready, key kết nối core ↔ AI khớp, schema hai dịch vụ sẵn sàng. payOS legacy chỉ chạy khi có kênh sandbox/test và đúng cấu hình. Camera/mic/loa cần trình duyệt HTTPS hoặc localhost và thiết bị có phần cứng.

Mỗi lần chạy ghi: `Run ID | Case ID | SHA FE/BE/AI | môi trường/thiết bị | actor/house/entity ID | thời gian VN | expected | actual | PASS/FAIL/BLOCKED/SKIP/NOT RUN | evidence | defect ID`. Không ghi password, bearer/refresh token, API key hoặc số tài khoản cá nhân vào bằng chứng công khai. BLOCKED phải có nguyên nhân (thiếu OAuth/SMTP/thiết bị/chức năng), SKIP phải có lý do phạm vi. Mock pass không được thay cho nghiệm thu Google/mail/voice/AI/payment thật.

P0: AUTH-01/04/07, HOU-01/04/07, CHO-01/03, MED-01, CHA-01/03, NOT-01, ORD-01/03/06, DEB-01, CAL-01, AI-03, OPS-01/02/03. Các ca khác P1; legacy/future được đánh phạm vi riêng. Mỗi ca cần xác minh cả FE và BE theo bảng, không chỉ nhìn toast thành công.

## 2. Đăng ký, đăng nhập và Google

| ID | Tiền điều kiện và bước thực hiện | Kết quả FE | Kết quả BE/dữ liệu |
|---|---|---|---|
| AUTH-01 | Email A chưa có. Đăng ký hợp lệ → đăng nhập → reload. | Vào My Houses đúng tên; reload không mất phiên. | Một user; password hash, không plaintext; cấp JWT/refresh đúng user; không tự thêm nhà. |
| AUTH-02 | Thử email sai định dạng, thiếu trường, email đã có; sửa request bỏ qua form. | Validation rõ; giữ input hợp lý, không tạo tài khoản thành công giả. | Từ chối dữ liệu sai/trùng; không có user/refresh token mồ côi. |
| AUTH-03 | Sai password/email; gửi nhiều lần; API timeout/500/offline. | Loading kết thúc, nút dùng lại được; thông báo ngắn, không raw C#/SQL/stack. | Không cấp phiên; lỗi server có trace ID/log nội bộ; input sai không biến thành truy vấn thành công. |
| AUTH-04 | Google email mới; bấm Google, chọn tài khoản test, reload. | Nút Google hiện trên Web thường và script; vào My Houses; tài khoản mới chưa có nhà. | Google signature/issuer/audience/expiry/email verified được xác minh; user theo sub; token trả về là phiên Chore Wars. |
| AUTH-05 | Đóng popup Google; chặn popup/mạng SDK; gửi ID token trống, giả, hết hạn/sai audience. | Cancel không báo thành công; lỗi có thể thử lại; password login vẫn hoạt động. | Không tạo user/link/refresh mới; không log token; config disabled/thiếu allowlist từ chối an toàn. |
| AUTH-06 | A đã có email/password, chưa link. Google cùng email → đăng nhập password → My Account → Link Google → logout → Google. | Lần đầu hướng dẫn link; sau link Google dùng được, không mất tên/avatar/nhà. | Không auto-link bằng email; explicit link cần JWT, email khớp; không thay subject thuộc user khác. |
| AUTH-07 | Hai request Google đồng thời cùng subject mới; thử link Google email B vào phiên A. | Không tạo hai tài khoản; không đổi phiên A khi link bị từ chối. | Unique subject; transaction/lock đúng; email mismatch bị từ chối; hai session hợp lệ cùng user, không hai user. |
| AUTH-08 | Access token hết hạn, nhiều API đồng thời; sau đó refresh hết hạn/logout, đăng nhập B cùng browser. | Refresh một lần hợp lý; hết phiên về login; B không nhìn cache/avatar/ảnh/nhà của A. | Refresh rotation/revocation; không loop refresh; Google login không bị retry như request nghiệp vụ; quyền theo phiên mới. |

API: `POST /api/auth/register`, `/login`, `/google`, authorized `/google/link`, `/refresh-token`, `/logout`; `GET/PUT /api/user/profile`, `POST /api/user/avatar`. Kiểm tra Google trên Web bằng tài khoản thật là bước riêng với test verifier mock.

## 3. Nhà, QR và hồ sơ

| ID | Tiền điều kiện và bước thực hiện | Kết quả FE | Kết quả BE/dữ liệu |
|---|---|---|---|
| HOU-01 | A tạo H1; B join bằng invitation code. | Cả hai thấy cùng nhà; A Owner/B Member; reload đúng. | Một membership active/người; cùng house ID; B không được owner quyền. |
| HOU-02 | B scan QR bằng camera từ màn A; thử tải ảnh QR rõ nét; nhập code thủ công. | Ba cách đến cùng preview/join; camera xin quyền; QR ảnh chạy được trên PC. | Chỉ nhận invite đúng format; không tự mở URL QR tùy ý; validation invitation phía server. |
| HOU-03 | QR mờ, ảnh không QR, code sai/hết hiệu lực/đã rotate; camera denied/busy. | Giải thích và cho chọn ảnh/nhập code; không treo scanner hoặc join nhầm. | Code không hợp lệ không tạo membership; rotate vô hiệu code cũ. |
| HOU-04 | A có H1/H2; chuyển nhà liên tục, mở deep link/chat/noti/order/calendar từng nhà. | Header và dữ liệu cùng nhà, không lóe ảnh/số dư nhà trước; không duplicate navigator. | Mỗi API kiểm tra active membership; không tin house ID từ client là quyền truy cập. |
| HOU-05 | X/L gọi API H1, đổi entity ID/house ID; B gọi owner endpoint bằng HTTP trực tiếp. | Không lộ dữ liệu; thông báo thiếu quyền hợp lý. | 401 khi chưa xác thực, 403/404 theo policy khi không có quyền; response không chứa dữ liệu H1, không mutate. |
| HOU-06 | A chuyển ownership cho B active; thử target ngoài nhà, tự rời khi còn ràng buộc. | Owner badge/quyền cập nhật; thao tác không hợp lệ có hướng dẫn. | Chuyển atomic, đúng một owner; rời/archive theo policy; quyền cũ bị thu hồi cả realtime. |
| HOU-07 | Mở profile từ My Houses rồi trong H1; đổi tên/avatar và Save, reload cả hai phiên. | Ngoài nhà chỉ thông tin cá nhân; trong nhà đúng tab Profile/Chore Settings/My Debts. Avatar đã lưu vẫn còn. | Profile không tự query dữ liệu H1 từ lựa chọn cũ; upload bền vững, không lưu blob URL tạm. |
| HOU-08 | Fixture 6 active, người thứ 7 join; hai người cùng tranh chỗ cuối. | Chỉ báo joined cho người thực sự được thêm. | Không vượt sức chứa; duplicate join không tạo hai membership; transaction chống race. |

## 4. Mùa, availability, routine và phân công

| ID | Tiền điều kiện và bước thực hiện | Kết quả FE | Kết quả BE/dữ liệu |
|---|---|---|---|
| SEA-01 | Owner tạo mùa hợp lệ; thử thiếu tên, end trước start, hơn 31 ngày; member gọi create/start. | Form chỉ báo thành công khi lưu; ngày lỗi rõ. | Validation server, tối đa 31 ngày và quyền owner; không có mùa lỗi. |
| SEA-02 | Mùa draft; A/B đặt availability, thêm hai interval, xóa interval, overnight, overlap; reload. | Giờ VN đúng; empty day là unavailable; tổng giờ không cộng đôi. | Persist đúng intervals; overnight theo contract hai ngày; dữ liệu xấu bị từ chối/canonicalize nhất quán. |
| SEA-03 | Chore Settings sửa preferences/capacity; thử sửa user khác bằng request. | Có tên mục dễ hiểu; không còn tên season “test tháng”/Season Schedule ở Account. | Chỉ sửa dữ liệu actor được phép; season/house scope đúng; không mutate người khác. |
| SEA-04 | Tạo routine DAILY/WEEKLY/EVERY_X_DAYS; duplicate submit; sửa/xóa khi policy cho phép. | Routine thật hiển thị, không Popular Templates viết cứng; tab/back không mất trạng thái. | Occurrence đúng anchor/frequency, không trùng khi generate/start nhiều lần; history không bị xóa sai. |
| SEA-05 | Fixture ngày 29/30/31, tháng 2/năm nhuận; timezone khác trên máy tester. | Ngày/giờ hạn thống nhất với lịch VN. | Generation MONTHLY/YEARLY/custom đúng recurrence contract; biên được unit test bằng clock, không đổi giờ server. |
| SEA-06 | Manual assign vào B và giờ B bận; automatic với availability/capacity khác nhau. | Manual hiển thị cảnh báo theo policy; automatic giải thích nếu không có người phù hợp. | Manual/automatic là hai mode thật; auto tôn trọng hard constraints, không bịa availability. |
| SEA-07 | Gửi review; A confirm, B chưa confirm; sửa lịch sau confirm rồi thử start. | Trạng thái xác nhận rõ; không hiện active sớm. | Required confirmations đủ/đúng revision mới start; thay đổi liên quan vô hiệu xác nhận theo policy; không bypass owner. |
| SEA-08 | Không ai rảnh/thiếu lịch; chạy phân công lặp và đồng thời. | Empty/infeasible có hướng dẫn; không báo phân công thành công giả. | Không assign người không hợp lệ; atomic, không duplicate occurrence/responsibility; phút và Karma không dùng lẫn. |
| SEA-09 | Kết thúc mùa rồi tạo mùa sau/clone; retry end. | Summary/ranking/reward đọc được, mùa mới độc lập. | Snapshot ổn định; end idempotent; không cấp reward hoặc carry-over hai lần. |

## 5. Chore, bằng chứng và lịch Overview

| ID | Tiền điều kiện và bước thực hiện | Kết quả FE | Kết quả BE/dữ liệu |
|---|---|---|---|
| CHO-01 | Mùa active, việc normal giao A. A complete, B reload Team/detail. | Cả hai thấy Completed, đúng người/giờ; CTA không còn cho complete lại. | Status + Karma + trách nhiệm lưu cùng transaction; một completion, đúng một lần cộng điểm. |
| CHO-02 | B cố complete việc A; gửi hai complete đồng thời; retry sau mất response. | Không complete nhầm; lỗi không làm UI tự cộng điểm. | Kiểm tra quyền/status; không double Karma/event/payment. |
| CHO-03 | Bonus nằm tab Chore. A/B claim cùng một bonus rồi người thắng complete. | Một người nhận; người còn lại thấy trạng thái mới, không hai assignee. | Atomic claim; complete theo cùng core flow, đúng bonus Karma. |
| CHO-04 | Dùng fixture due−1s/due/due+1s và +12h/+24h/+36h/+48h. | Overdue/critical rõ, điểm/history khớp. | Phạt −5 mỗi 12h tối đa −15 cho trách nhiệm theo rule; job lặp không phạt trùng. |
| CHO-05 | Forced reassignment rồi người mới overdue/complete; worker chạy đồng thời. | Assignee/history không tự quay lại người cũ. | Counter/phạt gắn đúng responsibility; không dùng lại counter người trước; một lần kết thúc trách nhiệm. |
| MED-01 | Take Photo → chụp → Complete with This Photo → mở lại detail, reload và B xem lịch. | Camera thật mở; ảnh giữ sau lưu/reload; không chỉ preview blob. | Media bền vững và evidence attach đúng occurrence; chỉ ảnh đã attach/completed vào lịch. |
| MED-02 | Chọn ảnh thay camera; draft chưa complete; cancel; camera denied hoặc đã bị app khác giữ. | Có chọn ảnh/fallback; cancel không hoàn thành việc; lỗi camera không treo UI. | Draft không bị công khai trên lịch; cleanup theo retention; không complete chỉ do upload. |
| MED-03 | File không phải ảnh, sai MIME/extension, rỗng/quá giới hạn; đổi evidence ID/actor; AI vision lỗi. | Thông báo gọn; có thể chọn lại; AI lỗi không mất ảnh. | Kiểm tra content/kích thước/quyền ở server; AI feedback không tự sửa trạng thái nghiệp vụ. |
| CAL-01 | Chọn ngày có A/B làm việc; 0/1/2/3/5 ảnh hợp lệ; bấm +N/gallery/detail. | Đúng người/việc/ngày; tối đa hai preview, số còn lại +1/+3; ảnh mở xem được. | Dữ liệu thật, không mock; ảnh private đọc có auth; không ảnh nháp/nhà khác. |
| CAL-02 | Hạn hôm qua, complete hôm nay gần 00:00 VN; đổi timezone máy. | Task đến hạn ở ngày due; ảnh completion ở ngày hoàn thành VN. | UTC→VN grouping chính xác, không dựa timezone client; không duplicate evidence. |
| CAL-03 | X/L lấy ảnh đầy đủ/thumbnail sau A đã làm nóng cache; query >42 ngày. | Không lộ ảnh cũ, lỗi range rõ. | Auth được kiểm tra cả cache hit, private/no-store; range giới hạn, không tải cả lịch sử vô hạn. |
| CAL-04 | Xem tháng trước/sau/Today; narrow phone + text lớn; ảnh lỗi/mạng chậm. | Không overflow; fallback ảnh/loading/retry, ngày chọn không nhảy bất ngờ. | Query đúng range/house/session; lỗi ảnh không phá response danh sách chores. |

## 6. Bounty, nghĩa vụ tiền và reward

| ID | Tiền điều kiện và bước thực hiện | Kết quả FE | Kết quả BE/dữ liệu |
|---|---|---|---|
| BOU-01 | A mở Post Bounty, chọn việc của mình hợp lệ; thử việc B bằng ID trực tiếp. | Picker chỉ có việc A đủ điều kiện; một CTA tạo chính, không trùng nút empty-state/FAB. | Không cho post hộ việc B; kiểm tra eligibility/status và amount server-side. |
| BOU-02 | Amount 0/âm/quá lớn/ký tự/lẻ theo đơn vị tiền; double submit. | VND dễ hiểu, validation rõ; không hai bounty. | Tiền thật, không Karma bounty; idempotency/concurrency bảo toàn một bounty hợp lệ. |
| BOU-03 | B accept bounty A; A tự accept, X accept, hai người accept đồng thời. | Chỉ người đủ quyền thắng; state đồng bộ hai phiên. | Không self/outsider accept; không hai responsibility; không chuyển tiền khi chỉ accept. |
| BOU-04 | B hoàn thành occurrence có bounty rồi refresh/retry. | Chore completed; A/B thấy obligation đúng vai trò. | Core CompleteChore nhận diện bounty, tạo đúng một PaymentObligation; không endpoint complete bounty giả. |
| BOU-05 | Bounty hết hạn bằng clock fixture; worker chạy lặp/race accept tại biên. | Trạng thái expired/reassigned nhất quán. | Forced reassignment và mức 120% theo snapshot/policy; không tạo hai compensation hoặc âm tiền. |
| PAY-01 | Debtor report chuyển một phần; creditor kiểm tra rồi confirm/reject. | Phân biệt reported/pending/confirmed; debtor không thấy nút tự confirm của creditor. | Chỉ creditor được confirm; report chưa giảm nợ; reject giữ nguyên; confirm/retry không giảm hai lần. |
| PAY-02 | Sửa actor/amount/source ID; report hơn outstanding; history xem pending/settled. | Không hiện settled cho pending; lỗi không tự đổi số dư. | Chặn unauthorized/overpayment, đúng audit actor và nguồn; không gộp khoản tiền không liên quan. |
| REW-01 | Complete/penalty làm thay đổi Karma, mở History filter/Leaderboard/Achievements ở A/B. | Tổng và từng dòng khớp; earned/penalties/spent lọc đúng; không hard-code số đẹp. | Sum ledger đúng; event lặp không thêm achievement/điểm; snapshot/ranking theo mùa hiện hành. |
| REW-02 | End season, claim reward hợp lệ; retry claim/claim người khác/hết hạn. | Quyền và trạng thái claim đúng; không thông báo nhận thành công khi lỗi. | Eligibility, expiry và unique redemption bảo đảm; không xem reward là Karma shop mới. |
| REW-03 | Dùng Chore Pass còn hiệu lực cho việc hợp lệ; rời nhà rồi thử dùng; retry. | Pass giảm một lần, việc được chuyển theo policy; lỗi có giải thích. | Membership/expiry/ownership kiểm tra lại; không skip tự do hoặc tiêu pass hai lần. |

## 7. Chat, notification, ảnh và voice

| ID | Tiền điều kiện và bước thực hiện | Kết quả FE | Kết quả BE/dữ liệu |
|---|---|---|---|
| CHA-01 | A/B mở H1, A gửi text, B nhận rồi reload, phân trang lịch sử. | Một tin, đúng sender/time/order; lịch sử không mất/lặp khi reconnect. | Persist trước side effect; room access đúng; SignalR và HTTP cùng dữ liệu. |
| CHA-02 | A mention B/@Everyone; thử tên trùng, ký tự dài, chỉ whitespace, HTML/script. | Mention rõ; nội dung không thực thi HTML/script; không gửi whitespace rỗng. | Validate body/mention membership; không gửi noti cho ID ngoài room. |
| CHA-03 | A chụp/choose ảnh rồi gửi; B xem, A mở Photo history và reload. | Ảnh gửi thật, retry/remove hoạt động; history có ảnh đã gửi, không ảnh failed/draft. | Multipart bytes/MIME đúng; persisted media URL/ID hợp lệ; không submit blob URL cho server. |
| CHA-04 | Ngắt mạng giữa upload/send rồi retry; X/L đoán media/room ID. | Trạng thái lỗi rõ, input không mất; không nhân đôi ảnh/tin do retry. | Upload và message gắn đúng room; auth private media; không orphan vô hạn, không vượt size. |
| CHA-05 | A record voice 7 giây → send; B play/pause/replay đến hết, reload rồi phát lại. | Bubble có nút/tiến độ/thời lượng; nghe được âm thanh thật, không chỉ text Voice note. | File audio thật được lưu/đọc có quyền; MIME/codec hỗ trợ; không cần bearer header mà audio element không gửi được. |
| CHA-06 | Mic denied/no device/format unsupported; ngắt mạng khi play; đổi nhà/logout khi đang phát. | Không ghi âm giả; lỗi ngắn, dừng tài nguyên; không tiếp tục phát âm riêng phiên cũ. | Room/house quyền được kiểm tra; media cũ không đọc tiếp bằng phiên không có quyền. |
| NOT-01 | B bật chuông chat H1; A gửi khi B đang trang khác. B mở header bell → View Details. | Badge/noti đúng H1; Details vào đúng tin/việc/bounty, không sang My Houses lỗi GlobalKey. | Preferences persist; đúng receiver/house/entity; mark read chỉ actor, chỉ phạm vi chọn. |
| NOT-02 | B mute H1, giữ H2 bật; A gửi H1/H2 rồi B reload/relogin. | Chuông phản ánh setting; H1 không báo chat, H2 vẫn báo; không trộn inbox. | Setting per-user/per-house; không mute toàn nhóm; sự kiện lặp không spam noti. |
| NOT-03 | Mark one/all read, filter Chore/Chat/Bounty, đổi nhà; cùng tin qua HTTP/realtime. | Count/filter nhất quán; không duplicate; toast không đè thanh nhập mãi. | Không mark read của người/nhà khác; dedup event; pagination không mất unread. |
| NOT-04 | B tắt hẳn tab/app; test quyền OS notification denied/granted riêng. | Ghi đúng mức hỗ trợ thực tế: in-app hay OS push; chưa có push thì BLOCKED, không gọi in-app là push. | Xác minh transport/subscription thực, không suy từ SignalR rằng app đóng vẫn nhận. |

## 8. AI trong hai bên chat, urgent và voice

| ID | Tiền điều kiện và bước thực hiện | Kết quả FE | Kết quả BE/dữ liệu |
|---|---|---|---|
| AI-01 | Mở Assistant qua nút nhỏ, private chat và gọi AI trong group; prompt hỏi việc nhà. | Trả lời dành cho người dùng, không JSON/debug/reasoning thô; không AI Settings/evaluation ngầm trong UI thường. | Request đúng house/actor/context; quyền admin/evaluation không mở cho member thường. |
| AI-02 | AI chưa cấu hình/down/timeout/429; chỉ mở app, rồi retry prompt. | Nói chưa có/chưa sẵn sàng, có retry; Chore/Chat/Order vẫn dùng được. | Không 403 nền lặp vô hạn; không business write khi provider lỗi; không bịa câu trả lời thành công. |
| AI-03 | A prompt “22 giờ tối nay tiệc 10 người, tôi và Trinh chuẩn bị”; B là Trinh. | Plan task chuẩn bị trước 22:00, preview người/hạn; Trinh nhận AI message/noti để accept. | Resolve B theo active membership; giờ 22:00 là giờ tiệc, không giờ bắt đầu mọi task; request/proposal lưu đúng participants. |
| AI-04 | B accept/decline/không phản hồi proposal; A đổi plan sau khi B đã xem. | A/B thấy cùng revision/status; decline/expired không hiện active. | Chỉ required participant respond; không tự approve hộ B; stale/duplicate response không kích hoạt hai lần. |
| AI-05 | “Trinh” không có hoặc có hai người trùng tên; giờ đã qua; thiếu ngày/quy mô. | Hỏi rõ người/ngày/giờ còn thiếu; không chọn bừa, không tạo campaign sai. | Ground member/catalog/season IDs; reject hallucinated IDs và deadline không hợp lệ. |
| AI-06 | Prompt destructive/đổi assignee người khác/đặt đơn/trả tiền bằng lời; xác nhận hoặc cancel. | Có review/confirmation theo hành động; cancel không thực thi; không nói đã thanh toán khi chưa có evidence. | Authorization phía core độc lập AI; provider không gọi thẳng DB tiền/phân công bỏ qua quyền và transaction. |
| AI-07 | A voice prompt, sửa transcript rồi Send; Read câu trả lời, Stop; mic/English voice không có. | Transcript chỉnh được; Read phát thật hoặc nói chưa hỗ trợ; Stop dừng âm thanh/recording. | Speech/voice capability lỗi không biến thành gửi prompt trùng; không ghi nhận thành công khi không có audio. |
| AI-08 | Vision feedback cho ảnh; low confidence/503; thử xem observation/risk của người/nhà khác. | Feedback tham khảo, người dùng quyết định hoàn thành; không lộ đánh giá nội bộ. | Không tự cộng/phạt Karma hoặc hoàn thành vì AI; privacy và scope đúng cho evidence/profiles. |
| AI-09 | Gợi ý bounty không đủ điều kiện; prompt order hàng không có; Gemini trả ID bịa/JSON sai. | Hiện chưa có/không đủ dữ liệu; không tạo item/chore giả để lấp UI. | Validate schema/grounding, fail closed; không tạo business rows từ payload không hợp lệ. |
| AI-10 | Core request timeout nhưng AI trả muộn; retry cùng intent/client ID, restart AI. | Không hai proposal/đơn; không mất lịch sử chat hợp lệ. | Idempotency tại core, consistency với AI DB/outbox; cùng actor/house; không lưu secret vào prompt log. |

## 9. Order mới: số lượng → email → ghi nhận đã trả tiền

Không dùng runbook supplier login/approve shares/payOS làm happy path cho `SIMPLE_CONTACT`. Luồng mới không tự tạo nợ của B. Catalog/contact hiện chưa có thì phải hiện empty state thật; không thêm supplier/item mock để qua test.

| ID | Tiền điều kiện và bước thực hiện | Kết quả FE | Kết quả BE/dữ liệu |
|---|---|---|---|
| ORD-01 | A mở Order, chọn hàng/số lượng → Send; nhận mail ở mailbox supplier QA. | Không bước chọn payer/participants/approve; có queued/sending/sent thật, detail đọc lại được. | Order + dispatch snapshot + audit commit cùng nhau; đúng email/món/quantity/price/total/người đặt; một đơn, chưa PAID. |
| ORD-02 | Catalog rỗng, supplier inactive/email sai, quantity 0/âm/quá tồn, product khác supplier; sửa HTTP trực tiếp. | Empty/validation rõ; không giả Send thành công hoặc thay hàng khác. | Server validation; không queue mail/order lỗi; không seed mock tự động. |
| ORD-03 | SMTP thiếu/sai password/timeout; worker chết sau claim; app restart rồi explicit retry. | Không hiện Sent giả; Unknown giải thích cần kiểm tra trước resend; giỏ/đơn không mất. | Lease/claim atomic; expired lease Unknown; không tự resend kết quả bất định; secret không vào log. |
| ORD-04 | Double Send; mất response rồi retry cùng client ID; cùng ID nhưng đổi quantity. | Không hai đơn; thông báo conflict khi request khác. | Idempotency fingerprint; không hai dispatch/business transaction; không tạo debt/share/proposal cho order mới. |
| ORD-05 | A/B cùng mở đơn; Call supplier; thử khi phone/email trống; Back/refresh. | Call mở trình gọi đúng tel:, không tự gọi khi mở trang; thiếu contact nói chưa có. | Snapshot contact/lines không bị thay lặng lẽ theo catalog mới; B chỉ có quyền đọc/chỉnh theo policy. |
| ORD-06 | Mail Sent. A chuyển ngoài app rồi Mark as paid; reload Orders/detail. | Hiện số tiền/người ghi/thời gian/reference và lịch sử; không yêu cầu B approve. | PAID log có source USER_REPORTED, không nói ngân hàng verified; không tự tạo B nợ A. |
| ORD-07 | Mark paid trước Sent, B cố mark đơn A, số tiền sai; cùng payment request retry và đổi request. | Nút/quyền/validation rõ; không tự đổi state khi API fail. | Chỉ creator, trạng thái hợp lệ; record idempotent; không log tiền hai lần hoặc đi vào checkout legacy. |
| ORD-08 | A nhờ AI chọn quantity ở private/group rồi review → Send. | Dùng cùng form/order flow; AI không nói đã gửi khi chỉ draft. | Ground supplier/products thật; cùng Send API; prompt chưa xác nhận không tự gửi mail hay đánh PAID. |
| ORD-09 | Reminder đến ngày theo fixture rồi chạy worker lặp. | Nhắc đúng nhóm/nhà, mở đúng Order; không tự gửi đơn/thanh toán. | Reminder dedup, timezone đúng, quyền bật lịch theo policy; SMS chưa triển khai ghi future/BLOCKED. |
| ORD-10 | Đổi H1/H2, mở order ID H1 dưới route H2; X/L gọi detail/email retry/payment. | Không lộ người đặt/contact/đơn nhà khác. | House + membership + creator checks ở core; legacy/new discriminator không bypass quyền. |

## 10. My Debts — khoản nợ cá nhân thật

Fixture nợ được tạo từ nguồn hợp lệ hoặc seed test có provenance; không suy rằng đơn email mới tự sinh nợ. Không offset/chuyển A→B→C thành A→C.

| ID | Tiền điều kiện và bước thực hiện | Kết quả FE | Kết quả BE/dữ liệu |
|---|---|---|---|
| DEB-01 | Khoản B nợ A 100.000; A/B mở My Account → My Debts. | A thấy Owed to me, B thấy I owe; cùng số dư, đúng người; type Debt rõ. | Một debt trực tiếp, đúng source/actor; không đưa tổng đơn hàng vào số tiền cá nhân. |
| DEB-02 | B report 40.000, A chưa nhận; B tự confirm, X xem bank, A reject rồi report/confirm đúng. | Pending không giảm; chỉ A nhận tiền được confirm; còn 60.000 sau xác nhận hợp lệ. | Creditor-only, outstanding atomic; reject/retry không double count; bank details chỉ người có quyền. |
| DEB-03 | A cũng nợ B; thêm B nợ C; hoàn một phần rồi reload/history. | Mỗi hướng độc lập, không tự cấn hoặc đổi creditor; lịch sử có type Debt. | Không debt netting/transitive rewrite; tổng còn lại bằng gốc trừ confirmed, đối chiếu được từng giao dịch. |
| DEB-04 | Trả quá số dư, hai confirm đồng thời, đổi người nhận/source ID. | Lỗi rõ, không số âm; UI không tự đánh Settled trước response. | Validation/transaction/idempotency; không âm balance, không sửa debt của actor khác. |

## 11. UI, lỗi và vận hành

| ID | Tiền điều kiện và bước thực hiện | Kết quả FE | Kết quả BE/dữ liệu |
|---|---|---|---|
| UI-01 | Duyệt toàn bộ màn ở 354×645, tablet/desktop, text scale lớn, bàn phím mở. | Không overflow/nút bị che; bottom bar Overview/Chore/Chat/Order/Bounty, Bonus trong Chore; AI nhỏ tránh CTA/keyboard. | Mỗi màn gọi đúng API/house, không nhân provider/request vô hạn khi resize. |
| UI-02 | Back/deep link từ noti, order cũ, bonus, profile ngoài nhà; reload URL. | Đúng màn/selected tab; không GlobalKey/HeroControllerScope đỏ; không hai shell. | Alias giữ entity ID/house; router không thay authorization. |
| UI-03 | Quan sát nút send/complete trên nền tím, focus bàn phím, tooltip/icon, tiếng Anh. | Icon/text đủ tương phản (send trắng), nhãn đọc được, trạng thái disabled/loading phân biệt; không tiếng Việt hệ thống lẫn UI Anh. | Không toast raw exception; validation lỗi trường không làm mất form/ảnh. |
| UI-04 | Empty/loading/403/404/409/429/500/offline ở mỗi màn, bấm retry/back/logout. | Empty nói chưa có, error nói không tải được; không dùng mock để thay lỗi, không màn đỏ/stack. | HTTP status có nghĩa; conflict không partial write; trace phục vụ debug, không password/token/SQL trong response. |
| OPS-01 | Khởi động backend/AI trên DB đã migrate; FE dùng URL Render; kiểm tra live/ready/version. | Đăng nhập được khi API ready; không localhost:5297 trong bản deploy. | SHA/version đúng, schema đủ (gồm AIChatInsights và migration Order/Google); readiness fail khi DB/schema lỗi, liveness độc lập phù hợp. |
| OPS-02 | CI test fail hoặc schema gate fail; thử trigger deploy cùng SHA/lần chạy cũ. | Không công bố bản hỏng như đã lên thành công. | CI required chặn deploy; migration protected/manual; health smoke kiểm tra version + dependencies; không startup migrate production để né gate. |
| OPS-03 | Backend Redis down rồi phục hồi; Kafka mất broker/sai TLS rồi phục hồi. | Core action có kết quả đúng hoặc lỗi rõ; không giả thông báo đã gửi; app không lộ log broker. | PostgreSQL là nguồn thật; outbox không mất, worker retry/dedup; Kafka Aiven không dùng localhost:9094 khi deploy. |
| OPS-04 | Consumer crash trước/sau side effect, replay failed event hai lần; member thử replay. | Owner thấy recovery đúng; member không có thao tác quản trị. | Không lặp Karma/noti/payment; poison event lưu lỗi; replay có quyền/audit; shutdown không mất transaction. |
| OPS-05 | Restart/redeploy container với media volume/storage cấu hình thật; tắt Docker máy A khi dùng cloud. | Ảnh/avatar/voice lịch sử vẫn đọc; A/B dùng cloud tiếp tục hoạt động. | DB/media không nằm ở filesystem ephemeral ngoài ý muốn; app cloud không phụ thuộc Postgres/Redis/Kafka local. |
| OPS-06 | Release/CI scan source, Docker image/env, network và log sự cố. | Không đưa secret/debug UI ra app; OAuth Client ID công khai được phép. | SMTP/Gemini/DB/payOS secrets không vào Git/FE/image localsettings; migration gate không reset/restore DB ngẫu nhiên. |

## 12. Legacy và phần chưa triển khai

| ID | Phạm vi và bước | Kỳ vọng |
|---|---|---|
| LEG-01 | Đọc order LEGACY_SHARED/lịch sử cũ sau migrate; thử revise/checkout legacy trên SIMPLE_CONTACT. | History cũ không mất; đơn mới bị chặn khỏi luồng legacy không phù hợp, không tự sinh share approval/debt. |
| LEG-02 | Nếu nghiệm thu payOS: checkout với kênh test, signed webhook thật; bad signature/duplicate/out-of-order/return URL. | Chỉ provider evidence hợp lệ xác minh; redirect không chứng minh trả tiền; một khoản tiền không ghi nhận hai lần. Thiếu kênh thì BLOCKED. |
| LEG-03 | Nếu còn hỗ trợ refund/dispute/legacy supplier API, chạy trên fixture legacy riêng. | Quyền operator/actor, version, refund acceptance/audit đúng; không yêu cầu supplier login trong happy path Order mới. |
| FUT-01 | SMS supplier, bank integration chuyển tiền giữa A/B/C, native Google chưa có signing config, OS push chưa có transport. | Ghi chưa có/BLOCKED hoặc ngoài phạm vi; không tạo test PASS từ nút gọi điện, log thủ công hoặc mock provider. |

## 13. Kịch bản chạy liền mạch cho hai người

**E2E-01 — từ tài khoản mới đến kết thúc mùa:** A/B mở hai browser profile → AUTH-01 → HOU-01 → HOU-02 → SEA-01/02/03/04 → review/confirm/start theo SEA-07 → CHO-01/MED-01/CAL-01 → CHA-01/03/05 và NOT-01/02 → BOU-01/03/04 → PAY-01 → SEA-09 và REW-01/02. Lưu ID từng bước, kiểm tra reload ở cả hai phía. Nếu rule tối thiểu người start mùa yêu cầu hơn hai người thì bổ sung fixture active thật và ghi rõ, không bypass điều kiện chỉ để demo.

**E2E-02 — Google với tài khoản cũ:** A đã có password/H1 → AUTH-06 → logout → Google chọn cùng email → đúng H1/tên/avatar → logout A/login B cùng browser → AUTH-08/HOU-04; kiểm tra không lộ cache của A. Đồng thời B thử chọn Google email sai khi link, phải bị từ chối. Ghi origin/Client ID và provider thật, không chụp token.

**E2E-03 — urgent bằng text và voice:** A mở AI private: “Tối nay 22 giờ tiệc 10 người, tôi và Trinh chuẩn bị” → AI-03/04/05. B nhận tin với AI/noti, xem và accept → A/B xem cùng task/đúng hạn trước tiệc → hoàn thành có ảnh. Lặp phiên khác trong group bằng voice; không tái dùng proposal đã active. Decline/cancel/AI unavailable là nhánh riêng không tạo nhiệm vụ thật.

**E2E-04 — Order tự đặt và AI:** A chọn quantity → ORD-01/03/04; B đọc cùng đơn → A Call (không cần bấm gọi thật) → người đặt ghi nhận đã trả → ORD-06/07; refresh/relogin kiểm tra log. Lặp order khác bằng AI draft → review → Send. My Debts vẫn không tự tăng do đơn mới; kiểm tra DEB-01/02 trên fixture nợ nguồn độc lập. Không dùng phiếu email làm chứng cứ ngân hàng đã nhận.

**E2E-05 — cách ly và sự cố:** Đang xem H1 thì switch H2 → nhận noti H1 → Details → HOU-04/05, NOT-01/03, UI-02. Thử X/L đọc ảnh và voice đã làm nóng cache → CAL-03/CHA-06. Mất mạng/reconnect/restart worker ở môi trường riêng → UI-04/OPS-03/04/05. Không thao tác phá hệ thống cloud đang demo của nhóm khác.

## 14. Liên kết tự động hóa hiện có và phần cần chạy thật

Các file dưới đây là điểm bắt đầu coverage, không có nghĩa mỗi case ở trên đã được tự động hóa đầy đủ. Phải đọc tên test/assertion trước khi đánh covered.

| Nhóm | Backend hiện có | Flutter hiện có | Nghiệm thu thật còn cần |
|---|---|---|---|
| Google/session | GoogleAuthTests, GoogleIdentityVerifierTests | google_auth_test, auth_refresh_test | Google popup/account/test user/origin, revoke/expired session. |
| House/QR/profile | HouseNavigationTests, HouseCapacityTests, HttpAuthorizationAndMediaTests | qr_join_flow_test, qr_image_decoder_test, profile_and_chat_inbox_test, avatar_upload_test | Camera scan thật, avatar restart/deploy. |
| Season/chore | SeasonLifecycleTests, CurrentSeasonWorkflowTests, RecurrenceCalculatorTests, CoreConcurrencyTests, HouseholdJourneyTests | schedule_settings_test, routine_creation_test, chore_team_view_test | Chuỗi approve/start/end/reward trên hai phiên/thiết bị. |
| Proof/calendar | SimpleOrderCalendarTests, EvidenceThumbnailTests | household_calendar_test | Camera thật, VN midnight, gallery private trên hai user. |
| Bounty/payment | BountyCompensationTests, PaymentConfirmationTests, ResponsibilityPenaltyTests | bounty_own_chores_test, bounty_amount_test, rewards_and_settings_layout_test | Transfer/receiver confirmation; provider test nếu bật legacy. |
| Chat/noti/media | MediaHttpUploadTests, ChatNotificationsKafkaTests, ChatNotificationPreferenceTests, SignalRRevocationTests | chat_camera_test, chat_media_upload_test, chat_photo_history_test, audio_message_bubble_test, notification_navigation_test | Audio nghe thật, mic, app background/closed, hai mạng. |
| AI | AIHousekeeperTests, AIServiceContractTests, UrgentProposalTests | assistant_task_flow_test, assistant_chat_test, ai_voice_controls_test | Gemini thật, TTS/STT thiết bị và private/group participant acceptance. |
| Order/debt | SimpleOrderCalendarTests, OrderEmailTransportTests, SupplyPurchaseTests, SupplyHttpTests | supplies_flow_test | SMTP mailbox recipient thật; không coi loopback SMTP là gửi supplier thật. |
| Recovery/deploy | DeploymentSchemaTests, DeploymentHealthControllerTests, RealKafkaTests, MutationCrashTests | shared_web_configuration_test, app_error_fallback_test, failed_event_recovery_test | Render env/migrations, Linux media persistence, protected deploy/run SHA. |

Chạy unit/widget theo runbook CI hiện có; integration PG/Kafka phải dùng server tạm và các biến `CHOREWARS_TEST_*` trong [runtime execution runbook](runtime-execution-runbook.vi.md). Không đặt connection string production vào biến test. Test SKIP do thiếu dependency không được tính là PASS full backend. Với AI contract, cần AI test service đúng cấu hình; bộ test Gemini thật là nhánh riêng có quota/cost.

## 15. Điều kiện chốt đợt test

- P0 PASS cả API/dữ liệu/UI; không còn bug lộ dữ liệu hai nhà, mất media, double money/Karma, login 500 hoặc GlobalKey đỏ.
- Toàn bộ ID có kết quả và evidence; BLOCKED/SKIP có chủ sở hữu và lý do. Google thật, mail thật, camera/mic/loa và Android chưa chạy phải ghi rõ, không suy từ widget pass.
- So khớp số dư: Karma ledger, confirmed debt và payment source; USER_REPORTED không được đổi thành PROVIDER_VERIFIED bằng việc test bấm nút.
- CI xanh đúng SHA, schema/health/version đúng môi trường; chưa áp dụng cloud migration/config thì không ghi “đã deploy xong”. Chạy smoke sau deploy và kế hoạch rollback trước thay đổi production.

Template lỗi: `BUG-ID — Case ID — môi trường/SHA — actor/house/ID — preconditions — steps tối thiểu — expected/actual — request/HTTP/traceId đã che secret — ảnh/video — mức độ — trạng thái — retest Run ID`.
