# Database Design

The Chore Wars database is built on **PostgreSQL**. It uses Entity Framework Core as the ORM, utilizing Code-First migrations.

## Core Entities

### User (`Users`)
- `Id` (UUID, PK)
- `Email`, `Username`, `PasswordHash`
- `Karma` (Global integer tracking points across all time)

### House (`Houses`)
- `Id` (UUID, PK)
- `Name`, `JoinCode` (Unique string for invites)
- `OwnerId` (FK to User)

### UserHouse (`UserHouses`)
- *Junction Table for User <-> House Many-to-Many.*
- `UserId`, `HouseId` (Composite PK)
- `Role` (Enum: `OWNER`, `MEMBER`)

### ChoreSeason (`ChoreSeasons`)
- `Id` (UUID, PK)
- `HouseId` (FK)
- `Name`, `StartDate`, `EndDate`
- `AllocationMethod` (Enum: `MANUAL`, `AUTOMATIC`)

### Chore (`Chores`)
- `Id` (UUID, PK)
- `HouseId`, `SeasonId`, `AssignedToUserId` (FKs)
- `Title`, `Description`
- `ChoreType` (Enum: `NORMAL`, `BONUS`)
- `FrequencyType` (Enum: `DAILY`, `WEEKLY`, `CUSTOM`, etc.)
- `BaseKarma`, `Status` (Enum: `ASSIGNED`, `OVERDUE`, `CRITICAL_OVERDUE`)
- `DueDate`, `CompletedAt`

### ChoreBounty (`ChoreBounties`)
- `Id` (UUID, PK)
- `ChoreId` (FK, Unique)
- `CreatedByUserId`, `ClaimedByUserId` (FKs)
- `Amount` (Decimal for real money)
- `Status` (Enum: `ACTIVE`, `CLAIMED`, `EXPIRED`)
- `ExpiresAt`

### Notification (`Notifications`)
- `Id` (UUID, PK)
- `UserId` (FK)
- `HouseId` (FK)
- `Title`, `Message`
- `Type` (Enum), `IsRead`

## Transaction Boundaries

The system strictly enforces Domain boundaries using the **Unit of Work** pattern.
Core operations like "Complete a Chore" must happen within a single ACID transaction. If calculating Karma succeeds but saving the completion timestamp fails, the entire operation rolls back.

External side-effects (like pushing a real-time notification) occur *after* the database transaction successfully commits, utilizing Kafka events.

## Bổ sung dữ liệu không-AI — 20/10/2026

Các migration mới: `20261018175315_CompleteNonAiCore`, `20261018180128_AddNonAiIntegrityGuards`. Đây là hai migration gom theo dependency, không phải tên từng work package trong plan.

- Season: ScheduleRevision, FinalizedAt, rejection reason/actor; confirmations gắn revision.
- Chore: source routine, deadline, anchor, custom dates. Occurrence: snapshot effort/difficulty, planned start, completed actor.
- MemberAvailabilitySlot: start/end minute có check constraint; kế thừa availability theo weekday.
- ChoreResponsibility: episode người phụ trách với deadline, penalties, reason, ended/completed; filtered unique index bảo đảm một episode mở/occurrence.
- PaymentObligation: actor xác nhận, unique forced compensation/occurrence kể cả khoản đã hủy; FKs lịch sử Restrict.
- Custom Reward: cost/enabled, season nullable; redemption lưu ClientRequestId/CostSnapshot. KarmaTransaction season nullable cho redeem ngoài mùa, penalty step giúp chống ghi trùng phạt.
- ChatMessage: typed message, attachment/client ID; MediaAttachment metadata và private storage key. Unique room/sender/client ID khi có UUID.
- OutboxMessages và ProcessedMessages hỗ trợ eventual delivery/dedup. Completion, active bounty, achievement và season rank có unique guard nghiệp vụ.

Không tự xóa hoặc hợp nhất ledger trùng để chạy migration. Chạy `backend/scripts/non-ai-migration-preflight.sql` trên bản sao trước và xử lý dữ liệu cũ có chủ đích. Chưa áp dụng lên DB thật trong đợt code. Chi tiết test upgrade/giới hạn legacy tại `../reports/non-ai-implementation-progress-2026-10-20.vi.md`.

## Phục hồi message và thành tích — 20/10/2026

Migration `20261020054624_AddFailedEventRecovery` thêm FailedEvents/FailedEventReplays và OutboxMessages.MessageKey. Identity SHA-256 của group/topic/key chống nhân record quarantine. HouseId nullable: lỗi không thể xác minh scope chỉ được giữ ở backend. Replay audit giữ actor, thời điểm và outbox ID; không sửa payload gốc. Không xóa lịch sử để đánh dấu đã xử lý.

Migration dữ liệu `20261020061539_SeedDefaultHouseAchievements` bổ sung bốn định nghĩa mặc định còn thiếu trên nhà cũ. Down cố ý giữ định nghĩa vì awards có thể tham chiếu tới chúng; không dùng downgrade để xóa thành tích người dùng. Model schema không thay đổi trong migration dữ liệu này.

Nhà mới tạo defaults trong cùng transaction tạo house/member/chat room. Bounty claim metric truy vấn các episode BOUNTY đã có, không suy diễn một lịch sử chưa được ghi từ assignee hiện tại. Ledger forced completion amount 0 giữ bằng chứng hoàn thành và cho tie-break rank, nhưng balance không tăng.
