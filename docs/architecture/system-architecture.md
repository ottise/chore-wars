# System Architecture

Chore Wars uses a modern, decoupled microservices-inspired architecture designed to run efficiently via Docker Compose for development and scale smoothly in production.

## Component Overview

1.  **Mobile Client (Flutter)**
    *   **Role**: Primary user interface.
    *   **Responsibilities**: Authentication, managing house members, viewing and completing chores, managing seasons, receiving push notifications, and posting/claiming bounties.
    *   **Communication**: Communicates with the Backend API via REST (HTTP/JSON) and SignalR (WebSockets) for real-time updates.

2.  **Backend API (.NET 10)**
    *   **Role**: Core business logic and data orchestration.
    *   **Responsibilities**: Authorization, chore allocation algorithms, season management, karma calculations, and handling Domain side-effects.
    *   **Architecture**: Built using Domain-Driven Design (DDD) principles and Clean Architecture (Domain, Application, Infrastructure, Presentation).

3.  **PostgreSQL (Database)**
    *   **Role**: Primary persistent data store.
    *   **Schema**: Relational schema handling Users, Houses, Seasons, Chores, Bounties, and Notifications.

4.  **Redis (Cache)**
    *   **Role**: High-speed, in-memory data store.
    *   **Responsibilities**: Storing active seasons for quick retrieval, managing refresh tokens, and rate-limiting (future).

5.  **Apache Kafka (Message Broker)**
    *   **Role**: Asynchronous event bus.
    *   **Responsibilities**: Decoupling domain side-effects. For example, when a chore is completed, the API publishes a `ChoreCompletedEvent`. A background worker consumes this event to check for achievements and issue notifications, keeping the main HTTP request fast and decoupled.

## High-Level Architecture Diagram

```mermaid
graph TD
    Client[Mobile App (Flutter)] -->|REST API & SignalR| API[Backend API (.NET 10)]
    
    API -->|Read/Write| DB[(PostgreSQL)]
    API -->|Cache| Redis[(Redis)]
    API -->|Publish Events| Kafka[Apache Kafka]
    
    Kafka -->|Consume Events| Workers[Background Workers (.NET)]
    Workers -->|Read/Write| DB
```

## Triển khai không-AI hiện tại — 20/10/2026

HTTP/controller và worker gọi Application service. Mutation nghiệp vụ theo household đi qua `IHouseMutationCoordinator` → implementation PostgreSQL mở transaction, lấy advisory transaction lock theo house, bỏ các entity đọc trước lock, đọc lại trạng thái, thực hiện nghiệp vụ, Save/Commit. Nested call cùng nhà dùng lại transaction; không mở mutation sang nhà khác. Unique indexes bảo vệ các invariant ở DB.

`IEventPublisher` hiện là `OutboxEventPublisher`: payload và thay đổi nghiệp vụ commit cùng DB. `OutboxDispatcherWorker` lấy bản ghi bằng `FOR UPDATE SKIP LOCKED`, publish Kafka với key là outbox ID rồi đánh dấu published. Có thể publish lại khi process dừng giữa Kafka và DB commit; consumer dedup bằng `(Consumer, Id)` trong cùng transaction với tác dụng nghiệp vụ. Offset chỉ commit sau dữ liệu. Payload lỗi được retry/seek, chưa có cơ chế cách ly poison event tự động.

Realtime gửi sau commit qua after-commit queue tại các luồng dùng notification service; media controller broadcast sau service commit. Realtime không phải nguồn dữ liệu chính: client tải lại từ API và dedup message ID khi reconnect/retry.

Lịch là season draft có revision; chỉ all-confirm của cùng revision mới khóa ACTIVE. Recurrence/effort/timezone, allocation eligibility, replacement selector và responsibility episode nằm tại Application; Application không phụ thuộc EF. Chốt mùa snapshot ledger/rank; work/payment còn lại vẫn có thể được giải quyết theo chính sách, không ghi lại ledger mùa đã đóng.

Private media dùng storage adapter ngoài wwwroot, metadata có room/owner và kiểm tra active membership khi đọc/gửi. Flutter dùng provider theo session, private download có auth, một audio player và foreground recording. Các module AI và payOS chưa được tích hợp trong thay đổi này.

Báo cáo kiểm thử và giới hạn runtime: `../reports/non-ai-implementation-progress-2026-10-20.vi.md`.

## Source runtime đã bổ sung

Quarantine/replay đã có UI owner trong house settings, API kiểm tra quyền và house scope theo tài nguyên DB. Consumer lưu FailedEvents trước khi chuyển offset sau retry; replay ghi audit, giữ message key và cập nhật RESOLVED cùng transaction business/dedup. IRuntimeProbe mặc định no-op; worker executable điều khiển fault chỉ nằm trong tests, không có endpoint làm crash app.

Bounty accepted có consumer kiểm tra thành tích; completion consumer kiểm tra completion/Karma/streak. House tạo thành tích mặc định trong transaction. Số dư tiêu được là house member balance, khác với ledger dùng xếp hạng một season. Các thay đổi này được đối chiếu trong source journey và test consumer Kafka.
