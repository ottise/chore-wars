# API Specification

> Cập nhật đồng bộ main 20/10/2026: các proposal `URGENT_EVENT` và `CHORE_SWAP` thủ công đã có thể tạo/xác nhận qua `/api/houses/{houseId}/proposals`, `/api/proposals/{proposalId}/respond` (alias `/api/v1` được giữ). Proposal `SEASON_APPROVAL` vẫn không thay đổi lifecycle mùa; dùng season review đúng revision. Các đoạn cũ ghi toàn bộ proposal mutation đang deferred được thay thế bởi phạm vi này. Xem [biên bản hợp nhất](../reports/main-sync-2026-10-20.vi.md).

> Urgent event chỉ tạo việc sau đồng thuận của mọi target và kiểm tra lại active membership, active season/cutoff; trả approved campaign trong active proposals cho tới deadline. Swap chỉ nhận hai việc thường chưa hết hạn trong cùng mùa ACTIVE, không có bounty/payment; kiểm tra lại availability/capacity và chuyển responsibility episode trong giao dịch. Request dựa trên context đã thay đổi trả conflict, không tự áp dụng lịch cũ. Đây là thao tác thủ công, chưa có AI.

The Chore Wars API is a RESTful service. All endpoints expect and return JSON payloads.

## Authentication
All protected endpoints require a Bearer token in the Authorization header.
`Authorization: Bearer <JWT_TOKEN>`

## Endpoints Overview

### Auth (`/api/auth`)
- `POST /register`: Register a new user. Returns User data + JWT.
- `POST /login`: Authenticate existing user. Returns User data + JWT.
- `POST /refresh`: Refresh an expired JWT using a valid Refresh Token.

### Houses (`/api/houses`)
- `POST /`: Create a new house (creates UserHouse role OWNER).
- `GET /{id}`: Get house details and active members.
- `POST /{id}/join`: Join an existing house via JoinCode (creates UserHouse role MEMBER).
- `POST /{id}/leave`: Leave the house.

### Seasons (`/api/houses/{houseId}/seasons`)
- `POST /`: Create a new season. Defines start/end dates and the global `AllocationMethod` (Manual or Automatic) for chores in this season.
- `GET /current`: Get the currently active season and leaderboard.
- `GET /`: List historical seasons.

### Chores (`/api/houses/{houseId}/chores`)
- `POST /`: Create a new chore within the active season.
- `GET /`: List chores (supports filtering by assignee, status).
- `GET /{id}`: Get specific chore details.
- `POST /{id}/complete`: Mark a chore as completed. Increases user karma. Triggers event for checking Bounties and Achievements.

### Bounties (`/api/houses/{houseId}/chores/{choreId}/bounty`)
- `POST /`: Create a bounty on an assigned chore, offering a real money reward to whoever completes it.
- `POST /claim`: Claim a bounty. Reassigns the chore to the claimer.

## SignalR Hub (`/hubs/notifications`)
A real-time WebSocket connection for pushing updates to the mobile client.
- **Connection**: Requires valid JWT token.
- **Events Emitted**:
  - `ReceiveNotification`: Generic notification push.
  - `ChoreAssigned`: Pushed to the specific user assigned.
  - `BountyCreated`: Pushed to all house members.
  - `AchievementUnlocked`: Pushed to the user who unlocked it.

## Bổ sung contract không-AI — 20/10/2026

Phần này cập nhật các endpoint thay đổi trong đợt triển khai `non-ai-10-groups-implementation-plan.vi.md`. Tất cả yêu cầu Bearer token và membership ACTIVE, tài nguyên phải thuộc house trên route. House archive chỉ đọc. Xem trạng thái kiểm thử thực tế tại `../reports/non-ai-implementation-progress-2026-10-20.vi.md`.

### Lịch và xác nhận

Base: `/api/houses/{houseId}/seasons/{seasonId}`.

| Method/path | Request | Hành vi |
| --- | --- | --- |
| POST `/generate-schedule` | Không body | Chỉ DRAFT; sinh occurrence, automatic phân công theo capacity và availability |
| POST `/submit-review` | Không body | Ít nhất 3 thành viên active; mandatory đã được giao hết; tạo confirmations đúng revision |
| POST `/confirm` | `{ "scheduleRevision": 7 }` | 409 nếu revision cũ; chỉ ACTIVE sau người xác nhận cuối cùng |
| POST `/reject` | `{ "reason": "Cần đổi lịch thứ hai" }` | Lý do bắt buộc, tối đa 1000; về draft, tăng revision, bỏ occurrence/confirmation để tạo lại |
| PUT `/occurrences/{occurrenceId}/assign` | `{ "assigneeId": "uuid" }` | Giao mandatory occurrence có sẵn, chỉ DRAFT |
| POST `/routines/{templateId}` | Không body | Import routine cùng nhà, copy cấu hình; không sửa template gốc |

Endpoint `/start` cũ không được phép bỏ qua all-confirm. API assign chore cũ cần thêm `occurrenceId` bên cạnh `userId`; không tạo occurrence ngoài lịch generate.

Availability dùng `availabilities` là map day-of-week 0=Sunday đến 6=Saturday, và `slots` là map cùng khóa chứa `{startMinute,endMinute}`; khoảng nửa mở, `0 <= start < end <= 1440`, không trùng nhau. Ngày không khai báo không được xem là rảnh. Legacy `true` không có slots tương ứng cả ngày.

Chore create/update bổ sung `difficulty`, `deadlineMinutes` (0..1439, mặc định 1439), `recurrenceAnchor` dạng yyyy-MM-dd, `customDates`; create có `asRoutine`. Effort theo difficulty EASY=15, MEDIUM=30, HARD=45 phút; client không dùng estimatedMinutes để vượt chính sách. Ngày lịch theo Vietnam, instant truyền UTC.

### House và trách nhiệm

| Method/path | Request/hành vi |
| --- | --- |
| GET `/api/invitations/{code}/preview` | Tên nhà, số active, giới hạn 6; yêu cầu đăng nhập |
| POST `/api/houses/{houseId}/rotate-invite` | Owner; trả inviteCode mới |
| POST `/api/houses/{houseId}/transfer-ownership` | Owner; `{targetUserId}` active cùng nhà |
| POST `/api/houses/{houseId}/archive` | Owner; không còn season hiện hành, trách nhiệm/nợ chưa xử lý |
| GET `/api/houses/{houseId}/unresolved-chores` | Việc critical/expired bounty chưa hoàn thành |
| POST `/api/occurrences/{occurrenceId}/take-responsibility` | Active member tự nhận việc unresolved, hạn 24h mới, không tạo khoản bồi thường mới |
| POST `/api/occurrences/{occurrenceId}/claim` | Claim bonus chưa có người, trong season ACTIVE đã bắt đầu và chưa hết hạn |

Payment settle là người có `CreditorUserId` xác nhận nhận tiền; con nợ không tự đánh dấu PAID. Forced compensation chỉ xác nhận sau khi người hưởng khoản đó hoàn thành đúng occurrence. Request retry sau PAID không thay đổi audit time.

### Custom rewards

Base `/api/houses/{houseId}/rewards`:

- GET: danh sách có `id`, `name`, `description`, `cost`, `enabled`.
- POST: `{name,description,cost}`; active member tạo; name tối đa 100, description tối đa 1000, cost >0.
- PUT `/{rewardId}`: `{name,description,cost,enabled}`; chỉ CUSTOM cùng nhà, không thay đổi Chore Pass hoặc redemption đã phát sinh.
- POST `/{rewardId}/redeem`: `{clientRequestId: uuid}`; reuse UUID khi retry cùng giao dịch. Lưu cost snapshot, debit và redemption trong một transaction; disabled/thiếu Karma trả conflict.

### Private media

1. POST `/api/media`: multipart `roomId`, `file`; tối đa 5 MB. Ảnh JPEG/PNG hoặc AAC/M4A tối đa 60 giây được xác định phía server; trả `{id,type,durationSeconds,size}`.
2. POST `/api/media/send`: `{roomId,attachmentId,clientMessageId}`; client UUID cố định qua retry. Gửi cùng UUID với nội dung khác trả conflict. Lưu message rồi broadcast `MessageReceived`.
3. GET `/api/media/{id}`: quyền active member của room; file chưa attach chỉ owner đọc; hỗ trợ Range/206, `Cache-Control: private, no-store`.

Message thêm `messageType` TEXT/IMAGE/AUDIO, `attachmentId`, `clientMessageId`. TEXT cũ mặc định vẫn đọc được. Không còn upload chat công khai vào wwwroot; ảnh cũ dạng text được giữ tương thích hiển thị.

GET `/health/live` kiểm tra process; GET `/health/ready` kiểm tra kết nối DB. Chúng không chứng minh Kafka/Redis/thiết bị đã được nghiệm thu.

## Bổ sung phục hồi Kafka theo quyền chủ nhà — 20/10/2026

GET `/api/houses/{houseId}/failed-events?status=FAILED&page=1` và POST `/api/houses/{houseId}/failed-events/{failedEventId}/replay` yêu cầu owner ACTIVE của đúng nhà. List hỗ trợ FAILED/REPLAY_REQUESTED/RESOLVED, page >=1, 20 dòng/trang; response `{items,total,page,pageSize}`. Replay trả 202; request lặp khi queued không enqueue lần hai, resolved trả conflict. House archive không replay.

Owner chỉ nhận metadata các lỗi có HouseId đã được kiểm chứng qua tài nguyên DB. Payload thô và stack không đưa về client. Message không xác minh được nhà không xuất hiện trong UI owner. Replay giữ key gốc, ghi audit và chờ consumer xử lý; 202 không phải bằng chứng đã khôi phục.

Consumer hiện retry tối đa bốn lần cho một delivery, sau đó ghi quarantine bền vững trước khi commit offset. Nếu ghi quarantine thất bại thì không tiến offset. Quy tắc này thay mô tả trước đây “poison luôn giữ offset”, theo lựa chọn bổ sung màn quản trị của người dùng. Xem `../testing/runtime-execution-runbook.vi.md`.

## Bổ sung số dư và thành tích mặc định — 20/10/2026

`GetKarmaBalance`/summary.current là Karma có thể dùng của household, lấy từ balance thành viên và giữ qua các mùa, kể cả lúc không có season ACTIVE. Các field normal/bonus/penalties trong summary là breakdown của season ACTIVE; chúng không được dùng thay số dư tích lũy.

Nhà mới có bốn mốc thành tích: First chore (1 completion), Karma collector (100 Karma kiếm được), Three-day streak (3 ngày lịch Vietnam liên tiếp), Helping hand (1 lần nhận bounty). Migration dữ liệu bổ sung các mốc mặc định còn thiếu cho nhà cũ, không xóa custom definitions hoặc awards.

Metric chỉ tính trong đúng household: Karma earned cộng transaction dương từ CHORE_COMPLETED/BONUS/BOUNTY_REWARD; không lấy debit/refund loại khác. Streak là chuỗi ngày hoàn thành dài nhất đã đạt, bỏ ngày trùng và dùng ngày Vietnam. Bounty claimed tính episode trách nhiệm BOUNTY để giữ lịch sử khi việc được chuyển tiếp.

`bounty.accepted` hiện có consumer để kiểm tra Helping hand; house được tra từ bounty thật vì contract cũ chỉ có bountyId/acceptedByUserId. Actor phải có episode BOUNTY tương ứng. Completion consumer kiểm tra cả completion/Karma/streak. Completion forced 0 Karma vẫn có ledger amount 0 để tính số việc hoàn thành và audit; không làm tăng balance.
