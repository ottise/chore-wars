# Báo cáo kiểm chứng source non-AI — 20/10/2026

> Đây là snapshot trước khi hợp nhất code nhóm từ `origin/main`. Đọc [biên bản đồng bộ main](main-sync-2026-10-20.vi.md) để xem các thay đổi tiếp theo, phạm vi proposal thủ công và kết quả hồi quy sau merge.

## Phạm vi đã chốt

Người dùng yêu cầu hoàn thiện non-AI trong ngày, chọn quản trị message lỗi dành cho chủ nhà, sau đó xác nhận **chỉ test source**, chưa cắm điện thoại. Đợt này chạy unit/widget, HTTP/SignalR test server, PostgreSQL thật và Kafka thật; không đóng APK release, không deploy và không tích hợp AI/payOS.

Màn hình quản trị: House settings → Xử lý hệ thống. Owner ACTIVE chỉ xem/replay lỗi đã xác minh thuộc nhà mình; không có màn admin global. JSON không xác định được house được cách ly ở backend và không lộ cho owner khác.

## Kết quả đã xác nhận

| Kiểm tra | Kết quả |
| --- | --- |
| Backend unit | 55/55 PASS |
| Flutter tests | 12/12 PASS |
| `dart analyze lib test` | No issues found |
| Integration/PostgreSQL/Kafka lượt hồi quy cuối | **27/27 PASS, 0 FAIL, 0 SKIP** |
| Runtime lượt trước | 26/26 PASS, 0 SKIP; chưa bao gồm phần bổ sung metric thành tích ở lượt cuối |
| Android thật, camera/micro/loa/share thực tế | CHƯA CHẠY theo scope người dùng |

Lượt cuối sử dụng PostgreSQL 16 disposable và Kafka apache/kafka:3.7.0 riêng. Artifacts: `artifacts/runtime/b1421f5b649946c99f6387eb274e26a2/kafka/`. Các test bắt buộc không được tính đạt khi thiếu biến môi trường hoặc bị SKIP.

## Code và lỗi đã xử lý

- Sửa cấu hình JWT bị chụp sớm, gây token đăng nhập hợp lệ nhưng HTTP test nhận 401; không bỏ auth khỏi test.
- Thêm FailedEvents, replay audit và message key gốc trong outbox. Chỉ commit offset sau business commit hoặc sau khi lưu quarantine thành công; lỗi lưu quarantine thì seek/retry.
- Owner list/replay được kiểm tra role, active membership, resource scope, archived state và group xử lý. Payload gốc được đối chiếu với occurrence/bounty/season thật; API không trả payload/stack cho UI.
- Replay đồng thời/retry không enqueue hai lần; giữ message key để consumer dedup. Trạng thái RESOLVED cùng transaction với dữ liệu nghiệp vụ/processed marker.
- UI chủ nhà có filter, phân trang, pull-to-refresh, xác nhận trước replay, trạng thái đang chờ và mô tả lỗi. Có widget test hủy/xác nhận/không gửi lại yêu cầu đã queued.
- Notification mới không tạo cho thành viên không ACTIVE. Thu hồi chat SignalR kiểm tra cả hai kết nối cùng user và reconnect sau leave/kick.
- Thêm test upload multipart: refresh thành công không tự replay stream đã tiêu thụ; refresh bị từ chối xóa session và báo hết phiên đúng một lần.
- HTTP test kiểm tra logout làm refresh token cũ bị từ chối và đổi Authorization sang tài khoản khác trên cùng client không đọc được media/house cũ.
- Bounty expiry giữ deadline gốc của episode trước khi chuyển trách nhiệm. Thông báo expiry không khẳng định đã forced-reassign khi không có người hợp lệ.
- Claim Chore Pass yêu cầu thành viên ACTIVE; LEFT/BANNED bị chặn. Live ranking dùng cùng tie-break joined time/user ID như snapshot cuối mùa.
- Forced completion 0 Karma vẫn ghi completion ledger amount 0 để tính việc hoàn thành và audit, không tăng balance.
- Số dư Karma trả về đúng balance household và giữ qua mùa; breakdown vẫn thuộc season đang active. UI ghi rõ Spendable Karma.
- Hoàn thiện metric thành tích theo house: completion, Karma earned, longest streak theo lịch Vietnam và bounty acceptance theo episode lịch sử; bỏ các placeholder trả 0.
- Nhà mới có bốn mốc thành tích mặc định; migration dữ liệu thêm mốc thiếu cho nhà cũ. Thêm consumer bounty.accepted và kiểm tra đúng người nhận từ episode; completion consumer kiểm tra cả streak.
- Cho phép HTTP local riêng ở Android debug manifest; không nới cleartext của release. XML đã được parse kiểm tra, chưa build/chạy Android.

## Bộ integration và bằng chứng

Sáu case PostgreSQL gốc: concurrent completion/outbox, all-confirm concurrent, redeem không overspend, retry receipt giữ PaidAt, HTTP auth/private media/Range, upgrade dữ liệu cũ. Chúng nằm trong tổng integration, không cộng đúp thành một bộ riêng.

Các case bổ sung:

- 2 case quyền owner/replay idempotency và lỗi scope không hợp lệ không lộ qua UI.
- 2 case leave/kick: hai kết nối bị đóng, owner còn gửi được, reconnect của người bị thu hồi không join được room.
- 2 journey service với PostgreSQL thật: 3 actor automatic và 6 actor manual. Tạo/join nhà, availability, routine import, generate, reject, revision cũ, all-confirm, normal/bonus/bounty/forced compensation, creditor receipt, custom reward, cutoff/rank/pass, giữ pass nếu không có replacement, transfer hợp lệ và completion bình thường sau pass. Tài khoản thứ 7 bị chặn ở biến thể 6 người.
- 2 case kill process mutation ngay trước/sau outer commit: rollback toàn bộ hoặc giữ commit, retry không cộng Karma/outbox hai lần.
- 10 case Kafka thật: poison không chặn message sau sau khi đã quarantine; restart/delivery trùng; broker ACK trước outbox commit; consumer commit trước offset; hard kill dispatcher sau publish; hard kill consumer trước/sau DB commit; owner replay đến RESOLVED; broker pause/unpause với pending outbox; consumer completion/acceptance cấp thành tích và từ chối actor giả.

Các hard crash dùng WorkerTestHost riêng, probe ACK đúng boundary và kill PID do harness tạo. Đây là kill tiến trình thực, khác với các case ném exception có kiểm soát cũng được giữ để regression. Worker host không mở HTTP endpoint.

Các ca source journey seed actor trong DB rồi gọi Application service qua DI thực; không gọi đó là E2E đăng nhập/thao tác UI trên điện thoại. HTTP/SignalR test riêng sử dụng pipeline thật qua test server và PostgreSQL.

TRX chứa tên/kết quả từng case. `postgres.log`, `kafka.log` và các thư mục `artifacts/runtime/process-*/` chứa log/ACK của crash test. Tất cả artifacts dùng dữ liệu giả và được gitignore. Không truy cập hoặc reset DB của các stack Docker người dùng đang chạy; runner tự dọn container do mình tạo.

## Migration mới và vận hành

Ngoài hai migration non-AI core trước đó:

- `20261020054624_AddFailedEventRecovery`: FailedEvents, FailedEventReplays, OutboxMessages.MessageKey.
- `20261020061539_SeedDefaultHouseAchievements`: thêm definitions mặc định còn thiếu; Down giữ definitions để không phá lịch sử award. Không suy diễn bounty acceptance lịch sử chưa được ghi bằng episode.

Migration chỉ được áp dụng vào DB test dùng một lần trong đợt này. Trước khi nâng DB dự án: backup và chạy preflight/read-only trên bản sao, xử lý duplicate rõ ràng. Không tự rewrite dữ liệu Karma/balance lịch sử vì có thể thiếu audit của phiên bản cũ.

Lệnh chạy lại: xem [runbook](../testing/runtime-execution-runbook.vi.md). Code còn trong working tree, chưa commit/push.

## Giới hạn còn lại

- Chưa chứng minh camera/micro/loa/native share trên Android thật hoặc E2E Flutter trên thiết bị; đây là phần hoãn theo yêu cầu source-only.
- Broker test là single-node; không chứng minh Kafka HA, mất toàn bộ disk/volume hoặc nhiều node production. Các test fault chủ yếu dùng pipeline bounty.created; có thêm completion/acceptance, chưa tuyên bố mọi consumer khác có coverage tương đương.
- Redis thật và consumer season-ended/cache invalidation không phải đối tượng xác nhận trong các case broker này. Service finalization/ledger/ranking đã có journey riêng.
- AutoMapper 12.0.1 của dự án vẫn bị NuGet báo NU1903; cần một đợt nâng dependency phù hợp license/API và regression trước nghiệm thu bảo mật.
- Kết quả source PASS không thay thế yêu cầu dịch vụ thanh toán của môn; payOS vẫn hoãn. APK release/HTTPS/deploy làm sau.

## Bằng chứng lượt source cuối

`source-manifest.json` lưu SHA-256 các file C#/Dart, project/dependency và runner; `source-fingerprint.json` lưu commit và hash manifest trong thư mục artifacts của run cuối. Source còn thay đổi chưa commit nên không dùng commit SHA một mình làm fingerprint. Đã đọc lại TRX: UnitTests total/passed=55, IntegrationTests total/passed=27, failed=0, notExecuted=0.

Đã kiểm tra runner dọn hết container prefix `cw-runtime-kafka-`/`cw-non-ai-test-` và không còn dotnet WorkerTestHost do suite tạo. `git diff --check` không có lỗi whitespace. Không dọn các container dự án người dùng.
