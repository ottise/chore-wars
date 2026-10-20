# Kế hoạch thực thi kiểm thử runtime BE/Flutter, PostgreSQL, Kafka và Android

Ngày lập: 20/10/2026. Nhóm: 4 thành viên. Trạng thái: **KẾ HOẠCH — các ca bên dưới chưa được chạy trong lượt viết tài liệu này**.

## 1. Mục tiêu và phạm vi

Hoàn tất năm phần còn thiếu bằng bằng chứng runtime: 6 integration PostgreSQL; E2E 3–6 tài khoản; quyền SignalR/session/media; outbox/Kafka khi lỗi; camera/micro/loa và native share trên Android thật. Phát hiện lỗi → sửa source đúng tầng → thêm regression test → chạy lại ca liên quan và smoke flow.

Nguồn áp dụng theo thứ tự:

1. Quyết định hiện hành trong `non-ai-10-groups-implementation-plan.vi.md` và yêu cầu người dùng.
2. Báo cáo `../reports/non-ai-implementation-progress-2026-10-20.vi.md` cho baseline và giới hạn đã xác nhận.
3. Source hiện tại và contract mới trong `../api/api-specification.md`.
4. `non-ai-full-system-test-plan.vi.md` làm kho test bổ sung. Các đoạn cũ yêu cầu release APK hoặc payOS không áp dụng cho đợt này.

**Không triển khai AI, payOS, thủ quỹ, QR chuyển tiền hoặc production deployment trong kế hoạch này.** Payment confirmation chỉ là creditor xác nhận nhận tiền, không có chuyển tiền thật. Chạy ứng dụng Flutter debug trên thiết bị qua `flutter run` để kiểm thử; không cần tạo APK release hoặc cung cấp URL production.

Kết quả cuối phải gồm code test có thể chạy lại, lỗi runtime đã sửa, log/TRX/video và biên bản PASS/FAIL/BLOCKED cho từng case. Không gọi toàn bộ sản phẩm đã nghiệm thu nếu thiếu bằng chứng thiết bị thật hoặc Kafka.

## 2. Baseline và các điểm cần chuẩn bị

| Nội dung hiện có | Dùng trong đợt này | Khoảng thiếu |
| --- | --- | --- |
| `backend/scripts/test-non-ai.ps1` | PostgreSQL disposable, cổng loopback ngẫu nhiên, restore biến môi trường và dọn container | Chưa xuất TRX/kiểm tra 6 case bắt buộc không SKIP; image test 17 khác compose 16 |
| `PostgresFixture.cs`, `CoreConcurrencyTests.cs` | DB riêng từng test, 4 ca concurrent thực | Cần chạy lại và xử lý lỗi runtime nếu có |
| `HttpAuthorizationAndMediaTests.cs`, `ApiFactory.cs` | HTTP thật qua test server, auth/private media/Range | Factory gỡ hosted workers; kết quả này không chứng minh Kafka/worker hoạt động |
| `MigrationBackfillTests.cs` | Upgrade chore cũ về default deadline/custom dates | Cần chạy trên PostgreSQL thật |
| 47 unit BE, 9 Flutter test theo báo cáo gần nhất | Bộ regression cơ sở | Không thay thế E2E, thiết bị hay broker |
| Outbox dispatcher + consumer dedup | Test delivery lại và crash window | Chưa có broker fixture, process harness và điểm dừng có kiểm soát |
| `mobile/test/core/auth_refresh_test.dart` | Single-flight refresh, retry, expire một lần | Chưa chứng minh upload đang chạy, session đổi user và SignalR trên máy thật |
| Camera/chat audio/share đã có code | Kiểm thử trên Android debug, API thật | Chưa có biên bản ngoại vi và E2E Flutter |

Điểm kiểm tra đặc biệt từ source, chưa kết luận là lỗi runtime:

- `docker-compose.yml` có `container_name` và host ports cố định. Chỉ đổi Compose project name chưa đủ cách ly; phải dùng compose test riêng.
- Topic `bounty.accepted` có mapping publish nhưng chưa thấy consumer tương ứng được đăng ký. Không chờ `ProcessedMessages` của topic này nếu nghiệp vụ không có handler; phải ghi rõ coverage topic nào có consumer.
- Một số producer/consumer/cleanup còn dùng `DateTime.UtcNow`; thay clock trong một service chưa làm toàn hệ thống đi cùng thời gian.
- Bounty consumer cần kiểm tra có lọc người LEFT/BANNED khi phát notification hay không.
- Poison payload hiện giữ offset/retry. Đây là trạng thái có thể chặn partition; không được báo đã có DLQ/quarantine hoặc tự động phục hồi sau poison.

## 3. Kiến trúc bộ kiểm thử

```text
PowerShell runner
  ├─ PostgreSQL integration: DB ngẫu nhiên → migration → service/HTTP → assert DB → drop DB
  ├─ Runtime stack riêng: PostgreSQL + Redis + Kafka + private-media volume
  │    ├─ API thật ← Flutter debug trên Android/emulator
  │    └─ Worker test host ← fault probe → crash/restart → assert outbox/inbox/offset
  └─ Evidence: TRX + manifest môi trường + SQL snapshot + logs + video + kết luận
```

Giữ test rule nhanh trong UnitTests. Test transaction/unique index dùng PostgreSQL thật. Test broker/crash dùng Kafka thật và tiến trình worker riêng. Widget/provider test kiểm tra state FE; Android thật xác nhận plugin, permissions và âm thanh. Không dùng EF InMemory hoặc mock Kafka để kết luận đạt các ca runtime.

Test host riêng chỉ phục vụ integration: đăng ký cùng worker/service thực của backend, bổ sung clock/probe bằng DI. Probe dừng ở một điểm đã biết và báo cho harness trước khi harness kill đúng PID do nó tạo. Không thêm endpoint công khai để đổi thời gian, crash server hoặc bỏ qua auth.

## 4. Môi trường, tài khoản và fixture

### 4.1. Hạ tầng

- Docker Desktop engine truy cập được bằng `docker info`; thiếu engine: BLOCKED-ENV, không phải PASS/SKIP hợp lệ cho gate PostgreSQL/Kafka.
- Compose test **độc lập**, không kế thừa service có container_name/volume thật. Không dùng `docker compose down -v` cho stack dự án.
- PostgreSQL 16 là lượt tương thích chính với compose hiện tại; PostgreSQL 17 là lượt bổ sung nếu nhóm muốn tiếp tục hỗ trợ image của script cũ. Ghi image/tag thực vào manifest.
- Redis và Kafka dùng image cùng cấu hình tương đương source hiện tại; topic/group riêng theo run ID. Single broker chỉ kiểm thử crash/retry ở cấp ứng dụng, không chứng minh broker HA hoặc durability khi mất cả volume.
- Kafka advertised listener phải truy cập được từ worker test host: host process và container dùng địa chỉ phù hợp, không sao chép `localhost` giữa hai network khác nhau.
- Backend test dùng DB/Redis/Kafka/media storage riêng, secret giả, không lấy credential người dùng. Chạy migration có chủ đích trước API; không giả định app tự migrate khi startup.
- Health live/ready trả OK và smoke register/login thành công trước E2E. Ready hiện chỉ chứng minh DB; phải kiểm tra Redis/Kafka riêng.

### 4.2. Thiết bị và mạng

Tối thiểu 1 Android vật lý để nghiệm thu ngoại vi, kết hợp 2 emulator/thiết bị khác cho ba phiên đồng thời. Ưu tiên 2 điện thoại vật lý cho realtime và thu/phát voice note giữa hai máy. Kiểm tra sáu tài khoản không bắt buộc sáu máy; chuyển user theo session có kiểm soát, nhưng các ca race/revocation cần phiên mở đồng thời.

Cách chạy debug dự kiến sau khi xác định serial và địa chỉ backend test:

```powershell
flutter devices
Set-Location mobile
flutter run -d <device-id> --dart-define=UI_PREVIEW=false --dart-define=API_BASE_URL=<test-api-base>/api --dart-define=SIGNALR_BASE_URL=<test-api-base>/hubs
```

`<...>` là giá trị cần điền, không phải lệnh chạy nguyên văn. Emulator có thể dùng 10.0.2.2. Android USB có thể dùng `adb reverse` với đúng port backend, hoặc dùng LAN/Wi-Fi chung; phải xác minh kết nối HTTP và SignalR từ thiết bị. Nếu dùng HTTP local, kiểm tra network security/debug cleartext configuration, không mở cleartext toàn cục cho release. Không cần production HTTPS trong giai đoạn này.

### 4.3. Dữ liệu

| Fixture | Vai trò |
| --- | --- |
| A | Owner H1, người giao việc/post bounty ở các nhánh riêng |
| B, C | Active members, tối thiểu 3 người để review/activate |
| D, E, F | Nâng H1 lên 4 rồi 6 người, tham gia xác nhận khi đang active membership |
| G | Tài khoản thứ 7, phải bị chặn join H1 đã đủ 6 |
| X | Owner/member H2, không có quyền H1; dùng đổi tài khoản trên cùng máy |
| L | Thành viên H1 riêng cho leave/kick, không còn work/debt để thao tác rời nhà hợp lệ |
| S_AUTO | Season draft cho phân công tự động |
| S_MANUAL | Season riêng cho manual/reject/approve |
| S_END | Season/clock fixture dành riêng cutoff/ranking/pass |

Routine gồm EASY 15 phút, MEDIUM 30 phút, HARD 45 phút, Karma khác nhau để phân biệt fairness Karma với phút. Có người thiếu availability, bận cả ngày, rảnh 18:00–20:00, capacity thấp và người inactive.

Mỗi nhánh completion/bonus/bounty/pass dùng occurrence riêng. Seed lịch sử và thời gian bằng fixture có version chỉ trong DB test. Ưu tiên tạo dữ liệu E2E qua UI/API; nếu seed case khó như qua 36h phải ghi nhãn SEEDED TIME, không coi đó là thao tác người dùng đã thực hiện.

### 4.4. Thời gian

Không đổi đồng hồ Windows/điện thoại hoặc server dùng chung. Với service test: TimeProvider cố định, điều chỉnh tuần tự trong test. Với runtime test: clock/fixture chỉ có trong test host; nếu dùng seed due/expiry trong quá khứ thì ghi lại before/after và worker interval. Các mốc: due−1 giây, due, +1 giây, +12h, +24h, +36h; bounty expiry−1 giây/đúng/+1 giây; season cutoff tương tự. Tách race completion/finalization thành test có kiểm soát.

## 5. Đợt A — Chạy đủ 6 integration PostgreSQL

### Thực hiện

1. Ghi commit, working tree diff hash hoặc bản patch, dotnet SDK, PostgreSQL image, run ID. Commit SHA một mình không đủ xác định source khi chưa commit thay đổi.
2. Cập nhật runner để xuất TRX và log riêng từng test project, nhận tham số PostgreSQL image, kiểm tra kết quả từng test bắt buộc. Không chỉ dựa vào exit code vì dotnet test có thể thành công dù 6 ca bị SKIP.
3. Chạy từ repo root:

```powershell
./backend/scripts/test-non-ai.ps1
```

4. Nếu lỗi kết nối/migration: xác nhận đúng container/cổng ngẫu nhiên và health trước; giữ log trước cleanup. Không chữa bằng cách tắt test hoặc xóa constraint nghiệp vụ.
5. Nếu lỗi DI/HTTP/serialization/transaction/SQL: tái hiện một test, sửa code tầng gây lỗi, thêm regression khi cần. Sau sửa chạy lại sáu test và bộ unit BE.

### Các ca bắt buộc hiện có

| ID | Test | Oracle PASS |
| --- | --- | --- |
| PG-01 | `CoreConcurrencyTests.CompetingCompletionsCreditKarmaAndOutboxOnce` | Hai retry hợp lệ, chỉ một credit/completion ledger và một outbox; balance tăng đúng một lần |
| PG-02 | `CoreConcurrencyTests.SimultaneousConfirmationsActivateOnlyAfterAllThreePersist` | Cả ba confirmation lưu cùng revision, cuối cùng ACTIVE; không mất ghi khi đồng thời |
| PG-03 | `CoreConcurrencyTests.ConcurrentRewardRedemptionsCannotOverspend` | Hai lần tiêu vượt balance không cùng thành công; một redemption và debit hợp lệ |
| PG-04 | `CoreConcurrencyTests.PaymentReceiptRetryDoesNotChangeAuditTime` | PAID bởi creditor, retry không tạo nghĩa vụ/đổi actor hoặc PaidAt |
| PG-05 | `HttpAuthorizationAndMediaTests.RealHttpPipelineProtectsHouseAndPrivateMedia` | Auth thật, outsider 403, send retry cùng ID, Range 206, thành viên LEFT không đọc được file |
| PG-06 | `MigrationBackfillTests.LegacyRoutineKeepsEndOfDayAndGetsAnEmptyCustomCalendar` | Upgrade giữ Karma, deadline 1439, custom dates rỗng, không tạo source template giả |

Chỉ kết luận theo assertion thực có. Nếu PG-04 mới kiểm tra status/actor/non-null PaidAt mà chưa so thời điểm trước/sau retry, phải bổ sung assertion; tên test không thay bằng chứng. PG-02 cần mở rộng quan sát sau 1/2 confirmation vẫn REVIEWING; ba request đồng thời và trạng thái cuối chưa đủ chứng minh mọi trạng thái trung gian.

**Gate A:** 6/6 ca bắt buộc PASS, 0 SKIP, unit BE PASS; có TRX và log migration. Nếu container không chạy, gate không đạt.

## 6. Đợt B — E2E 3–6 tài khoản

| ID | Bước chạy | Kỳ vọng và bằng chứng |
| --- | --- | --- |
| FLOW-01 | A tạo H1; B/C join; X ở H2 | Membership/role đúng; X không truy cập H1. Video ba phiên và API/DB IDs |
| FLOW-02 | A/B/C khai báo khung giờ, capacity và sở thích | Lưu/đọc lại đúng; thiếu ngày không được suy ra cả ngày rảnh |
| FLOW-03 | Tạo routine và import vào S_AUTO | Copy độc lập; import retry không tạo bản sao ngoài policy; thay routine không sửa lịch sử |
| FLOW-04 | Generate automatic | Normal giao theo Karma/capacity/khung giờ, không chồng việc; không có người phù hợp giữ unassigned và chặn submit |
| FLOW-05 | Tạo S_MANUAL riêng; generate và giao occurrence | Chỉ DRAFT; không sinh việc ngoài recurrence; vượt availability có cảnh báo, không chặn chỉ vì bận |
| FLOW-06 | Submit; B reject kèm lý do; sửa/regenerate | REVIEWING khóa sửa; reject về DRAFT, tăng revision; confirmations/occurrences cũ vô hiệu |
| FLOW-07 | Submit lại; gửi revision cũ; A/B rồi C confirm | Revision cũ 409; sau A/B vẫn REVIEWING; chỉ C cuối cùng mới ACTIVE |
| FLOW-08 | Test nhà 4 rồi 6 người; G join khi đủ | Required set theo active membership của revision; người thứ 7 bị chặn, không vượt 6 khi join đồng thời |
| FLOW-09 | Thực hiện normal; claim bonus cạnh tranh; retry completion | Chỉ assignee/bonus claimant hợp lệ; ledger/balance chỉ một lần; chưa season start không complete được |
| FLOW-10 | A post bounty; B accept và complete | Trách nhiệm chuyển đúng; normal completion Karma theo policy; một nghĩa vụ đúng amount/creditor |
| FLOW-11 | Bounty khác expiry 24h; worker chạy | Có người hợp lệ: forced 24h mới và một compensation 120%; không có người: giữ trách nhiệm để resolution |
| FLOW-12 | Tăng clock qua các mốc phạt và cho replacement thất bại | Mỗi episode tối đa 3 ×5; counter không truyền sang người mới; không sinh compensation lần hai |
| FLOW-13 | Creditor xác nhận tiền sau khi đủ điều kiện | Debtor/outsider 403; forced chưa hoàn thành không settle; retry PAID giữ audit |
| FLOW-14 | Create/edit/disable/redeem custom reward | Cost >0, disabled không đổi được; debit đúng một lần; không tiêu quá balance và không sửa Chore Pass qua API custom |
| FLOW-15 | Claim và use Chore Pass có/không có replacement | Có người hợp lệ: chuyển trách nhiệm, người thay nhận normal Karma; không có người: giữ pass và assignment |
| FLOW-16 | Finalize S_END, retry worker, complete việc muộn | Phạt đến cutoff trước rank; một rank/user, một pass hạng nhất; balance giữ qua mùa; completion muộn không đổi ledger/rank snapshot |

S_AUTO và S_MANUAL dùng house hoặc chu kỳ season khác nhau nếu hệ thống chỉ cho một current season/house. Không cố tạo hai mùa hiện hành trái constraint để tiện test.

Với FLOW-16: lưu ledger, balance, ranking và số reward trước/sau finalization; tạo tie có cùng Karma nhưng khác mandatory count, bonus Karma, joined time, user ID để kiểm tra tie-break. Không kiểm tra mỗi thứ tự đang hiển thị trên UI.

**Gate B:** Luồng tối thiểu 3 tài khoản chạy trọn vẹn qua UI/API thật; biến thể 4/6 và reject/revision/negative permissions có evidence. Không đánh PASS cả chuỗi chỉ vì seed DB tới trạng thái cuối.

## 7. Đợt C — SignalR, session và retry media

| ID | Cách tạo tình huống | Oracle PASS |
| --- | --- | --- |
| RT-01 | L mở chat bằng hai kết nối; owner kick L; A gửi marker mới | Cả hai kết nối bị thu hồi; L không nhận marker, rejoin room/API/private media bị từ chối; A/B vẫn nhận |
| RT-02 | L không có work/debt tự leave khi đang mở chat | Không nhận sự kiện mới sau commit leave; reconnect bị từ chối; lịch sử đúng chính sách |
| RT-03 | Thành viên còn nghĩa vụ thử leave/kick | Thao tác bị chặn; không thu hồi nhầm kết nối khi transaction thất bại |
| AUTH-01 | Upload chậm qua proxy; access token hết hạn và refresh bị từ chối | Một thông báo hết phiên, token/cache/chat/audio cũ được dọn; về login, không loop refresh, không tự replay multipart đã tiêu thụ |
| AUTH-02 | Upload bị 401 nhưng refresh thành công | Không tự replay stream cũ; người dùng retry bằng FormData mới; upload/send cuối hợp lệ, không mất draft vô cớ |
| MEDIA-01 | Cho `/media/send` commit rồi proxy bỏ response | Client chưa biết đã gửi; retry giữ attachment ID và clientMessageId; DB chỉ một message, UI dedup dù có broadcast lại |
| MEDIA-02 | Upload commit nhưng bỏ response trước khi client nhận attachment ID | Client có thể upload lại vì chưa biết ID; chỉ một message được attach; file bỏ dở được cleanup sau TTL. Không đòi exactly-once upload khi chưa có upload idempotency |
| MEDIA-03 | Dùng lại UUID với attachment khác | Conflict; không đổi nội dung message đã tồn tại |
| SESSION-01 | A đang tải media/phát audio, logout rồi login X trên cùng máy | Không hiện/tải tiếp dữ liệu H1 bằng token A; audio dừng, SignalR A đóng, provider X tải H2; request media H1 với X bị từ chối |
| SESSION-02 | Bật/tắt mạng và background/foreground khi mở chat | Không nhân đôi connection/message/listener; pagination không trùng; reconnect tải lại phần thiếu |

Dùng proxy/fault adapter riêng để phân biệt request chưa tới server, đã commit nhưng response mất và token thất bại. Không dùng một thao tác bật airplane mode rồi suy đoán nó rơi đúng crash window. Kiểm tra server log/correlation ID và DB trước khi kết luận.

**Gate C:** Quyền bị thu hồi ở server và UI/session sạch; có log hai phía. Không lấy việc ẩn màn hình làm bằng chứng server đã chặn.

## 8. Đợt D — Outbox/Kafka thật và fault injection

### 8.1. Cách điều khiển

Tạo process harness khởi động worker host do test sở hữu; probe chặn tại các điểm transaction/publish/commit. Harness nhận ACK đã tới điểm dừng rồi kill đúng PID, sau đó restart cùng DB/topic/group. Dùng run ID, outbox ID, message key, topic/partition/offset làm correlation; log không chứa token/password/media riêng tư.

Probe mặc định no-op trong app; test host đăng ký implementation riêng qua DI. Không bật chức năng kill/đổi clock theo query string hoặc endpoint trên app thật. Nếu test cần tách API/dispatcher/consumer, cấu hình chỉ ở test host, không tắt worker production để làm ca PASS.

### 8.2. Ma trận lỗi

| ID | Điểm fault | Oracle sau restart |
| --- | --- | --- |
| KAF-01 | Mutation đã Save nhưng trước outer DB commit | Rollback cả nghiệp vụ/outbox; không ledger/balance/message mồ côi; advisory lock được giải phóng |
| KAF-02 | DB commit thành công, dispatcher chưa publish | Outbox còn pending; sau restart publish và handler tạo side effect |
| KAF-03 | Broker ACK publish, chưa commit PublishedAt | Event có thể được publish lại với cùng key; consumer chỉ ghi side effect một lần nhờ dedup |
| KAF-04 | Consumer đang xử lý, chưa commit nghiệp vụ/dedup | Rollback; restart cùng group đọc lại và thực hiện đúng một lần |
| KAF-05 | Consumer đã commit nghiệp vụ/dedup nhưng chưa commit offset | Delivery lại; ProcessedMessages chặn side effect lặp; offset tiến tiếp sau xử lý |
| KAF-06 | Broker tạm dừng khi tạo/chốt nghiệp vụ | Mutation/outbox vẫn nhất quán; pending chưa bị đánh published sai; khôi phục broker thì drain backlog trong timeout hợp lý |
| KAF-07 | Hai dispatcher hoặc hai consumer cùng group hoạt động | Không overspend/duplicate ledger/achievement/notification; duplicate delivery vẫn được dedup |
| KAF-08 | Broker chứa JSON hỏng hoặc payload null ở một partition | Có lỗi quan sát được, offset không commit vượt poison trên partition đó; message sau nó ở cùng partition chưa được tính là xử lý thành công |
| KAF-09 | JSON đúng cú pháp nhưng thiếu/không hợp lệ business IDs | Không tạo side effect sai hoặc marker thành công giả; lỗi domain phải có log/cách xử lý rõ, kiểm tra riêng vì deserialize có thể nhận giá trị mặc định |
| KAF-10 | Consumer phát notification lúc LEFT/BANNED hoặc transaction rollback | Chỉ người đủ quyền nhận dữ liệu; không broadcast tác dụng của transaction đã rollback |

Với KAF-08: quan sát partition khác còn chạy hay bị consumer loop chặn; ghi đúng phạm vi ảnh hưởng hiện tại. Không mặc định toàn hệ thống vẫn thông suốt.

### 8.3. Poison message và phục hồi

Đợt này trước hết nghiệm thu behavior hiện tại là **không mất message do commit vượt offset**, đồng thời ghi backlog/partition bị chặn. Chưa có yêu cầu triển khai giao diện quản trị quarantine trong năm mục này.

Để tiếp tục suite, dùng topic/group khác của ca kế tiếp; giữ topic poison cho evidence. Nếu cần thử recovery trong chính partition đó, phải ghi quyết định cách ly message và offset cụ thể, lưu raw payload/key/hash vào evidence rồi dùng công cụ quản trị Kafka trong cluster test để reposition group khi consumer đã dừng. Không làm trong production, không tự sửa `ProcessedMessages` để giả đã xử lý và không gọi thao tác skip thủ công là retry thành công.

Nếu yêu cầu nghiệm thu bổ sung là “không bị kẹt sau poison và có cách phục hồi tự phục vụ”, phải mở work package riêng: quarantine record/DLQ, retry limit, quyền thao tác và audit/replay. Không âm thầm đánh PASS khả năng chưa có.

### 8.4. Bằng chứng và giới hạn

- DB snapshot trước/sau: occurrence, balance, ledger, obligations, outbox, ProcessedMessages, notifications/achievements liên quan.
- Kafka snapshot: key, partition/offset, committed group offset trước/sau; giữ log restart và ACK probe.
- Chỉ assert side effect của topic có handler hiện hữu. Với `bounty.accepted`, kiểm tra publish/delivery nếu không có consumer, ghi N/A phần consumer và quyết định cần handler hay không theo yêu cầu nghiệp vụ.
- Không gọi toàn bộ pipeline exactly-once. Kỳ vọng là delivery ít nhất một lần và tác dụng DB được dedup trong phạm vi đã kiểm thử; realtime có thể phát lặp hoặc bị lỡ và client phải đồng bộ qua API.
- Timeout có giới hạn và điều kiện quan sát: chờ row/offset, không dùng sleep cố định để kết luận. Budget mặc định 60 giây/case sau broker sẵn sàng, tăng có lý do theo retry hiện tại; timeout là FAIL/BLOCKED cần điều tra.

**Gate D:** KAF-01…10 có kết quả và evidence; không có duplicate/lost business write; poison có giới hạn vận hành được ghi rõ. Nếu KAF-09 hoặc quyền notification phát hiện lỗi thì sửa và chạy lại trước nghiệm thu.

## 9. Đợt E — Android thật: camera, micro, loa, native share

| ID | Thao tác thiết bị | Tiêu chí PASS |
| --- | --- | --- |
| DEV-01 | Camera: cho quyền → chụp → xem lại → gửi chat/luồng ảnh đang hỗ trợ | File từ camera thật tới API và xuất hiện trên máy B; không nhầm ảnh gallery là bằng chứng camera |
| DEV-02 | Camera: từ chối/cancel/quay lại app | Không crash, không tạo tin giả; thông báo/đường phục hồi phù hợp permission plugin thực tế |
| DEV-03 | Micro: cấp quyền → ghi 5–10s → nghe preview → gửi B | Có tiếng thu thực; AAC/M4A được server chấp nhận; B tải có auth và nghe được |
| DEV-04 | Micro: từ chối quyền, stop, xóa, chuyển nền, mốc 59–60s | Không ghi nền ngoài ý muốn; xóa không gửi; giới hạn server <=60s/5MB vẫn áp dụng; không rò file tạm sau logout/dispose theo policy |
| DEV-05 | Loa: B phát voice note, đổi message nhanh, chuyển nền | Âm thanh ra loa vật lý, chỉ một player; dừng khi background/logout; không phát lại tự động khi vào màn |
| DEV-06 | Media offline/retry/response mất | Thể hiện lỗi và cho retry; không nhân đôi message; không phát file của user trước sau đổi tài khoản |
| DEV-07 | Share thành tích đã unlock → native share sheet → chọn nơi nhận | PNG đúng dữ liệu server, chữ/ảnh không bị cắt; file thực mở được ở ứng dụng nhận |
| DEV-08 | Share cancel/locked achievement | Cancel không crash; thành tích chưa unlock không được chia sẻ như đã đạt |

Loa phải nghe thực tế, screen recording không thu tiếng không đủ chứng minh. Lưu video ngoài hoặc biên bản người kiểm thử nghe và xác nhận thiết bị không bật mute/tai nghe/Bluetooth. Share không cần tự động đăng lên mạng xã hội; dùng ứng dụng nhận/file cục bộ do nhóm chọn.

Ghi model thiết bị, Android version, app debug version/source fingerprint, permission ban đầu, trạng thái mạng và kết quả. Nếu chỉ có emulator thì DEV camera/micro/loa/native sheet không đủ điều kiện nghiệm thu Android thật.

**Gate E:** Có bằng chứng ba ngoại vi riêng biệt Camera + Micro + Loa, share thực qua OS, cả đường thành công và từ chối/cancel cơ bản. Không thay bằng screenshot UI.

## 10. File dự kiến tạo/sửa khi thực thi

Các file dưới đây là **manifest công việc dự kiến**, chưa được tạo hoặc sửa code trong lượt lập kế hoạch này. Nếu lỗi dẫn tới sửa thêm file phải cập nhật manifest thực tế trong báo cáo.

| File/nhóm file | Việc thực hiện |
| --- | --- |
| `backend/scripts/test-non-ai.ps1` | Tham số image/output, xuất TRX, giữ log lỗi trước cleanup, fail nếu 6 ca thiếu hoặc skip |
| `backend/tests/IntegrationTests/Infrastructure/PostgresFixture.cs` | Timeout/diagnostic cleanup và thông tin DB test an toàn nếu lỗi môi trường |
| `backend/tests/IntegrationTests/Infrastructure/CoreConcurrencyTests.cs` | Bổ sung assertion intermediate confirmation/PaidAt đúng mức cần chứng minh |
| `backend/tests/IntegrationTests/Infrastructure/HttpAuthorizationAndMediaTests.cs`, `ApiFactory.cs`, `MigrationBackfillTests.cs` | Sửa fixture/runtime nếu lỗi thật phát hiện; không gỡ auth/constraint để PASS |
| `backend/tests/RuntimeTests/RuntimeTests.csproj` | Bộ test real HTTP, SignalR, broker và process restart riêng |
| `backend/tests/RuntimeTests/Fixtures/RuntimeStackFixture.cs` | Quản lý stack, topics/group, private media và teardown đúng run ID |
| `backend/tests/RuntimeTests/Fixtures/ScenarioData.cs`, `TestClock.cs` | Tài khoản/house/season/clock cho các nhánh độc lập |
| `backend/tests/RuntimeTests/Fixtures/WorkerProcessHarness.cs` | Start/probe ACK/kill/restart đúng tiến trình test, log và timeout |
| `backend/tests/RuntimeTests/SeasonJourneyTests.cs` | HTTP journey 3/6 tài khoản, reject/revision/role/cutoff; hỗ trợ đối chiếu E2E UI |
| `backend/tests/RuntimeTests/SignalRRevocationTests.cs` | Nhiều connection, leave/kick/rollback, reconnect và quyền read/send |
| `backend/tests/RuntimeTests/MediaRetryTests.cs` | Commit rồi response mất, UUID khác nội dung, upload orphan |
| `backend/tests/RuntimeTests/OutboxFailureTests.cs`, `PoisonMessageTests.cs` | KAF-01…10 với broker thật; quan sát inbox/offset/side effects |
| `backend/tests/WorkerTestHost/WorkerTestHost.csproj`, `Program.cs`, `FaultInjectionProbe.cs` | Host worker thực, registration clock/probe chỉ cho test |
| `backend/src/Infrastructure/Testing/IRuntimeTestProbe.cs` | Interface + no-op cho các fault point, nếu cần để dừng chính xác; implementation điều khiển nằm ở test project |
| `backend/src/Infrastructure/Concurrency/PostgresHouseMutationCoordinator.cs`, `Workers/OutboxDispatcherWorker.cs`, `Messaging/Kafka/Consumers/KafkaConsumerBase.cs` | Gắn probe vào đúng crash window; sửa lỗi transaction/retry/validation được test chứng minh |
| `backend/src/Presentation/Extensions/InfrastructureServiceExtensions.cs` | Cho phép test host dùng registration worker có chọn lọc mà không đổi mặc định app |
| `backend/tests/RuntimeTests/Infrastructure/docker-compose.runtime-test.yml` | Compose độc lập, không container_name/volume thật; bind loopback và network riêng |
| `backend/scripts/test-runtime.ps1` | Runner runtime, kiểm tra broker readiness, TRX/log/evidence, teardown có phạm vi |
| `backend/ChoreWars.slnx` | Thêm project test/host mới khi triển khai |
| `mobile/pubspec.yaml`, `mobile/pubspec.lock` | Thêm Flutter SDK integration_test dev dependency nếu chưa có |
| `mobile/integration_test/support/test_accounts.dart`, `test_app.dart`, `journey_driver.dart` | Nhận tài khoản test từ cấu hình không commit mật khẩu; login flow và tìm widget ổn định |
| `mobile/integration_test/household_journey_test.dart`, `session_isolation_test.dart`, `chat_media_retry_test.dart` | Luồng UI thật, đổi tài khoản, retry và đồng bộ; không dùng preview repo |
| `mobile/test/core/auth_refresh_test.dart` và test providers chat bổ sung | Regression refresh/multipart/session, connection disposal và message dedup |
| Widget liên quan trong `mobile/lib/features/house`, `chore`, `chat`, `gamification` | Thêm Key/semantics ổn định cho test, sửa lỗi UI thực tế; không đưa nút fault/seed vào sản phẩm |
| `mobile/lib/core/network/interceptors/auth_interceptor.dart`, `core/router/app_router.dart`, `core/storage/session_provider.dart` | Chỉ sửa theo lỗi session/upload thực tế phát hiện |
| `mobile/android/app/src/debug/AndroidManifest.xml` hoặc debug network config | Chỉ khi local-device HTTP bị chặn; không nới policy release |
| `docs/testing/runtime-execution-runbook.vi.md` | Lệnh chạy đã kiểm chứng, giá trị cấu hình và thứ tự setup/cleanup |
| `docs/testing/android-device-checklist.vi.md` | Checklist DEV-01…08 và RT/AUTH trên thiết bị |
| `docs/testing/runtime-test-result-template.vi.md` | Mẫu kết quả/evidence/defect |
| `docs/reports/runtime-verification-<run-id>.vi.md` | Kết quả thực tế từng case và các file code đã sửa |

Tên file dự kiến có thể điều chỉnh theo convention khi code; phải giữ được mapping ID → test → evidence. Không tạo project runtime rồi để test rỗng hoặc mặc định skip được tính là PASS.

## 11. Kết quả, lỗi và bằng chứng

Thư mục artifacts cục bộ dự kiến: `artifacts/runtime/<run-id>/`, có ignore phù hợp nếu chứa log/video; commit báo cáo text đã làm sạch, không commit token/password/media cá nhân. Lưu `manifest.json`, TRX theo project, logs API/worker/broker, các SQL snapshot cần thiết và tên/link video.

Mỗi ca có: ID, source fingerprint, môi trường, fixture IDs, bước chạy, expected, actual, PASS/FAIL/BLOCKED/NOT RUN, evidence, defect ID và người chạy. Test automatic và test device là hai kết quả riêng, không lấy cái này thay cái kia.

Quy trình sửa lỗi:

1. Lưu log/snapshot và tái hiện tối thiểu trước khi thay dữ liệu.
2. Phân loại môi trường, fixture hay implementation; không gộp mọi lỗi vào Docker.
3. Sửa đúng lớp, giữ auth/transaction/invariant; thêm regression test có ý nghĩa.
4. Chạy lại ca lỗi và nhóm phụ thuộc. Lỗi outbox/transaction/clock phải chạy lại PG và Kafka liên quan; lỗi session chạy lại auth/chat/logout; lỗi plugin chạy lại trên máy thật.
5. Đóng defect khi có evidence chạy lại. DB test mới và run ID mới cho lượt xác nhận, không chỉ replay fixture đã bị biến đổi không rõ.

## 12. Phân công 4 thành viên và thứ tự thực hiện

| Người phụ trách đề xuất | Công việc chính | Người đối chiếu |
| --- | --- | --- |
| Thành viên 1 | Gate A, runner/DB/migration, API journey | Thành viên 2 |
| Thành viên 2 | E2E season/bounty/payment/reward, UI assertions | Thành viên 1 |
| Thành viên 3 | SignalR/session/media, Android camera/micro/loa | Thành viên 4 |
| Thành viên 4 | Kafka/outbox/fault harness, evidence/runbook | Thành viên 3 |

Đây là phân vai đề xuất cho nhóm 4 người, không giả định đã biết tên từng thành viên hoặc đã phân công thực tế. Một người có thể thực thi tuần tự; phần review chéo giữ lại khi nhóm chạy.

Thứ tự và ước lượng để lập lịch, không phải cam kết hoàn thành theo giờ:

1. **Chuẩn bị + Gate A: 0,5–1 ngày công.** Docker/SDK/device inventory, TRX runner, chạy 6 integration, sửa lỗi căn bản.
2. **Test harness/runtime fixtures: 1–2 ngày công.** Stack riêng, clock, worker process/probe và broker evidence. Đây là công việc code mới, không coi như chỉ chạy lệnh có sẵn.
3. **Gate B + C: 1–2 ngày công.** Luồng 3/6 tài khoản và fault session/SignalR/media; có thể chia hai người sau khi hạ tầng ổn định.
4. **Gate D: 1–2 ngày công.** Crash windows và poison, sửa/regression; không chạy fault trên môi trường đang dùng cho video E2E.
5. **Gate E + nghiệm thu lại: 0,5–1 ngày công.** Android thật, quay bằng chứng, re-run lỗi chéo và chốt báo cáo.

Tổng khoảng **4–8 ngày công**, phụ thuộc lỗi runtime và thiết bị; nhiều thành viên có thể giảm lịch thực tế nhưng Kafka harness là dependency đáng kể. Nếu chưa có Android vật lý, tiếp tục Gate A–D và ghi Gate E BLOCKED-DEVICE, không dừng toàn bộ phần độc lập.

## 13. Điều kiện kết thúc đợt này

- Gate A: sáu PostgreSQL integration bắt buộc PASS, không bị skip; unit regression PASS.
- Gate B/C: journey và quyền/session/media chạy thật, không có lỗi làm sai tiền/Karma/trách nhiệm, rò quyền hoặc dữ liệu user trước.
- Gate D: các crash window có evidence, delivery lại không nhân side effect, broker outage hồi phục; poison behavior và giới hạn vận hành được báo đúng.
- Gate E: Camera + Micro + Loa + native share trên Android thật có evidence; denial/cancel/background không crash hoặc vi phạm policy.
- Danh sách FAIL/BLOCKED và rủi ro dependency còn lại hiện rõ; tài liệu API/kiến trúc được cập nhật nếu sửa contract. Chưa nâng dependency không được tự biến thành đã hết cảnh báo.
- APK release/deploy và tích hợp thanh toán tiếp tục hoãn. Hoàn tất năm nhóm test này không tự động đáp ứng mục dịch vụ thanh toán của môn học.

## Quyết định khi bắt đầu thực thi — 20/10/2026

Người dùng xác nhận chỉ test source/API và hạ tầng, chưa dùng điện thoại. Có 1 Android thật + emulator nhưng chưa đưa vào đợt chạy này. Kafka chọn bổ sung màn quản trị dành riêng owner ACTIVE, chỉ lỗi xác minh được nhà mình; không có admin global.

Oracle poison cập nhật: sau bốn lần xử lý thất bại, phải lưu quarantine bền vững rồi mới được commit offset để không chặn partition; nếu lưu không thành công phải giữ/seek offset. Owner replay dùng key gốc, audit actor/time và transaction outbox. Message không xác định được house không được lộ trong UI chủ nhà. Các KAF-08/09 dùng oracle cập nhật này thay quy tắc giữ offset vô hạn ban đầu.

Chạy theo `../testing/runtime-execution-runbook.vi.md`. Không tính service journey/PostgreSQL là bằng chứng đã thao tác E2E trên Android. Gate E ngoại vi vẫn chưa nghiệm thu, theo scope source-only mới nhất.

## Kết quả thực thi source

Xem [biên bản kiểm chứng 20/10/2026](../reports/non-ai-runtime-verification-2026-10-20.vi.md): 55/55 unit BE, 27/27 integration, 12/12 Flutter tests PASS; analyzer sạch. Bộ integration có đủ 6 PostgreSQL bắt buộc, 10 case Kafka thật, hard process crash và journey 3/6 actor; không có SKIP trong lượt chạy cuối. Thiết bị thật chưa chạy theo yêu cầu source-only.
