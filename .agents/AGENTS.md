# Chore Wars Backend — Implementation Discipline

## Absolute Rules

1. **No unnecessary comments.** Do not use comments to explain obvious code. Comments are allowed when explaining complex business rules, algorithms, transaction boundaries, or non-obvious technical decisions.
2. **No magic strings / magic numbers.** Use Constants, Enums, Options, Configuration.
3. **No dead code.** No commented-out code, unused usings, unused variables, TODO without reason.
4. **No fake implementations.** No `return new List<>()`, no `throw new NotImplementedException()` marked as complete.
5. **No over-engineering.** No Factory/Strategy/Mediator/Handler/Decorator/GenericRepository/BaseService/BaseController/Helper/Manager unless required.
6. **Clean Architecture enforced.** Domain → no dependencies. Application → only Domain. Infrastructure → Application + Domain. Presentation → Application + Infrastructure (DI only).
7. **Application CANNOT reference:** EF Core, PostgreSQL, Redis, Kafka, SignalR, ASP.NET Core HTTP.
8. **Domain CANNOT reference:** anything external.
9. **Using/import at top of file only.** Never inside methods or between classes.
10. **One class per file.**
11. **Naming:** IChoreService/ChoreService, IChoreRepository/ChoreRepository. No Svc/Impl/Manager/Helper/Util suffixes.
12. **DI only.** No `new` for dependencies in Application Services.
13. **Repository = data access only.** No business logic.
14. **Controller = thin.** Receive request → get user → call service → return response.
15. **CancellationToken** must flow from Controller → Service → Repository → EF Core.
16. **Null safety.** Always check entity existence before operating.
17. **Async everything** for database operations.
18. **UnitOfWork pattern:** BeginTransaction → operations → SaveChanges → Commit. Rollback on error. No save per step.
19. **Kafka = side effects only.** Core transaction (chore status + karma) must be in DB transaction. Kafka for Achievement, Notification, Cache invalidation.
20. **Redis = cache only.** PostgreSQL is source of truth. App must work without Redis.
21. **Entity ↔ DTO mapping** in Application layer. Never expose Entity from Controller.
22. **Validation** via FluentValidation for input DTOs. Business authorization separate.
23. **Error handling:** No swallowing exceptions. Rollback + throw. Global handling in Middleware.

## Business Rules (Immutable)

- **HouseRole:** OWNER, MEMBER (not Admin)
- **AllocationMethod:** MANUAL, AUTOMATIC (no RANDOM/ROUND_ROBIN/WEIGHTED as user-facing)
- **ChoreType:** NORMAL, BONUS (not Personal/Shared)
- **FrequencyType:** DAILY, EVERY_X_DAYS, WEEKLY, X_TIMES_PER_WEEK, SPECIFIC_DAYS, MONTHLY, EVERY_X_MONTHS, YEARLY, CUSTOM
- **ChoreOccurrenceStatus:** ASSIGNED → OVERDUE → CRITICAL_OVERDUE (not Pending)
- **Penalty:** -5 karma per 12h, max -15 karma
- **Bounty:** Real money only, no karma bounty
- **Bounty expired:** Forced reassignment at 120%
- **No CompleteBounty()** — CompleteChore() detects bounty and creates PaymentObligation
- **Reward:** Season ranking reward, Rank #1 gets Chore Pass (skip + reassignment), no karma shop
- **JWT:** Use ASP.NET Core built-in AddAuthentication().AddJwtBearer(), no custom JwtMiddleware

## Implementation Order

1. Domain (Entities, Enums, ValueObjects, Exceptions, Constants)
2. Application (Interfaces, DTOs, Validations, Mappings, Services)
3. Infrastructure (Data/DbContext, Configurations, Repositories, UnitOfWork, Migrations, Cache, Kafka, Workers)
4. Presentation (Controllers, Authorization, Hubs, Middleware, Extensions, Program.cs)
5. Tests

## Before Coding Any Feature

Identify: Feature, Use case, Entities affected, Repositories needed, Service needed, Transaction required, Authorization required, Events required, Cache affected, Worker affected, Tests required.

## Change Discipline

If requirement conflicts with architecture: STOP → Identify conflict → Explain impact → Propose solution → Wait for approval.
