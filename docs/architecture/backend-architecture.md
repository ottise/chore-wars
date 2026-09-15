# Backend Architecture

The Chore Wars backend is built using **.NET 10**, strictly adhering to **Clean Architecture** and **Domain-Driven Design (DDD)**.

## 1. Dependency Flow

Clean Architecture mandates that dependencies point strictly inwards. Inner layers must have absolute zero knowledge of outer layers.

- **Presentation → Application → Domain**
- **Infrastructure → Application → Domain**

The core rule is:
- **Domain** depends on NOTHING.
- **Application** depends ONLY on Domain.
- **Infrastructure** depends on Application and Domain to implement the abstractions.
- **Presentation** depends on Application (to trigger use cases) and Infrastructure (strictly for Dependency Injection setup).

---

## 2. Layer Breakdown & Detailed Folder Structure

### 🟢 1. Domain (`src/Domain`)
At the core of the application. It represents the business model and rules. It has zero external dependencies (No EF Core, no Kafka, no HTTP).

- **`Common/Constants/`**: Contains static string values to prevent magic strings (e.g., `PenaltyConstants`, `AuthConstants`, `RoleConstants`).
- **`Entities/`**: Core business models that map to database tables (`Chore`, `User`, `House`, `ChoreBounty`, `ChoreSeason`, etc.).
- **`Enums/`**: Strongly typed domain enumerations (e.g., `ChoreType`, `AllocationMethod`, `ChoreOccurrenceStatus`).
- **`ValueObjects/`**: Immutable objects that describe characteristics but have no identity.
- **`Exceptions/`**: Custom domain exceptions thrown when business rules are violated (e.g., `DomainException`, `NotFoundException`, `UnauthorizedDomainException`).

### 🟡 2. Application (`src/Application`)
Contains the application's use cases and business logic. It orchestrates the domain models but doesn't know *how* data is saved or messages are sent.

- **`DTOs/`**: Data Transfer Objects. Purely used for passing data in and out of the Application layer (e.g., `CreateChoreRequest`, `ChoreResponse`).
- **`Interfaces/Repositories/`**: Contracts for data access. (e.g., `IChoreRepository`, `IHouseRepository`).
- **`Interfaces/Services/`**: Contracts for application services and supporting abstractions (e.g., `IUserContextService`).
- **`Interfaces/Auth/`**: Contracts for authentication-related logic (e.g., `IJwtTokenGenerator`).
- **`IUnitOfWork.cs`**: Contract for the Unit of Work pattern to ensure transactional integrity across repositories.
- **`IEventPublisher.cs`**: Contract for publishing domain events. The Application layer uses this without knowing it goes to Kafka.
- **`Services/`**: The core business logic implementations (`ChoreService`, `BountyService`). This is where the actual use cases live.
- **`Events/`**: Strongly typed C# classes representing things that happened in the system (e.g., `ChoreCompletedEvent`, `BountyCreatedEvent`).
- **`Validations/`**: FluentValidation classes used to validate incoming DTOs (e.g., `CreateChoreValidator`).
- **`Mappings/`**: AutoMapper profiles to convert between Entities and DTOs.

### 🟠 3. Infrastructure (`src/Infrastructure`)
Implements the interfaces defined in the Application layer. It handles all I/O, Database, External APIs, and messaging.

- **`Data/`**: Contains the EF Core `AppDbContext`, EF Migrations, and Fluent API Entity Configurations.
- **`Repositories/`**: Concrete implementations of data access using EF Core (`ChoreRepository`, `UserRepository`).
- **`UnitOfWork/`**: Concrete implementation of `IUnitOfWork` that calls `SaveChangesAsync()` and manages DB transactions.
- **`Auth/`**: Implementations for JWT generation and password hashing.
- **`Cache/Redis/`**: Concrete implementation of caching services using StackExchange.Redis.
- **`Messaging/Kafka/`**: 
  - Kafka Producers (implementing `IEventPublisher`).
  - **`Consumers/`**: Background services that listen to Kafka topics (e.g., `ChoreCompletedConsumer`) and trigger Application layer services.
- **`Workers/`**: `.NET BackgroundService` classes (e.g., `OverdueChoreWorker`). They act as schedulers to wake up, resolve an Application Service, and execute it.

### 🔵 4. Presentation (`src/Presentation`)
The entry point of the application. It receives HTTP requests/SignalR connections and routes them to the Application layer.

- **`Controllers/`**: ASP.NET Core API Controllers (`ChoresController`, `AuthController`). They remain extremely thin.
- **`Authorization/`**: Policies and handlers for ASP.NET Core authorization mechanisms.
- **`Hubs/`**: SignalR Hubs for real-time WebSocket communication (`NotificationHub`).
- **`Middleware/`**: Global exception handling (`GlobalExceptionMiddleware`) to catch DomainExceptions and translate them to proper HTTP 400/404/500 responses.
- **`Extensions/`**: Dependency Injection (DI) extensions (`ServiceCollectionExtensions.cs`) to keep `Program.cs` clean.
- **`Program.cs`**: The main bootstrap file.
- **`appsettings.json` / `appsettings.Development.json`**: Configuration files for connection strings, JWT secrets, and Kafka brokers.

### 🟣 5. Tests (`tests/`)
- **`UnitTests/`**: Tests isolated components (mostly Application Services and Domain Entities) using mocking frameworks.
- **`IntegrationTests/`**: Tests the request pipeline and infrastructure integrations such as Database and Kafka behavior. Testcontainers will be used for isolated integration environments.

---

## 3. Feature Implementation Flow

When implementing a new feature, follow this strict top-down flow:

1. **Domain**: Create/Update Entities, Enums, and custom Exceptions.
   ↓
2. **Application Interface**: Define what the Repository or Service interface looks like.
   ↓
3. **DTO + Validation**: Create Request/Response DTOs and write FluentValidation rules.
   ↓
4. **Application Service**: Implement the business logic (fetch data, apply rules, map to DTO, save).
   ↓
5. **Infrastructure**: Implement the Repository and EF Core configurations (if it requires database changes, run Migrations).
   ↓
6. **Controller**: Create the API endpoint, inject the Application Service, and map HTTP requests.
   ↓
7. **Test**: Write Unit and Integration tests for the new flow.

---

## 4. Repository vs Service Pattern

It is crucial to understand the distinction between a Repository and a Service in this architecture:

- **Repository = Data Access Only**
  - **Do:** Perform database CRUD operations (`GetByIdAsync`, `Add`, `Update`, `Delete`).
  - **Do:** Encapsulate complex EF Core LINQ queries.
  - **Do Not:** Put ANY business rules, logic, validation, or throw domain exceptions inside a Repository.

- **Service = Business Logic / Use Case**
  - **Do:** Validate business rules (e.g., "Cannot complete a chore if it's already complete").
  - **Do:** Call Repositories to fetch and save data.
  - **Do:** Publish events via `IEventPublisher`.
  - **Do:** Orchestrate operations inside an `IUnitOfWork` transaction boundary.
  - **Do Not:** Write raw SQL or interact with `AppDbContext` directly.
