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
