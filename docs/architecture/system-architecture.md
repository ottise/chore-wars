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
