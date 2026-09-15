# 🧹 Chore Wars — Gamified Household Chore Management

Chore Wars is a gamified household chore management platform designed for roommates and shared living spaces.
The system turns routine household chores into a transparent game system through fair workload allocation, Karma, penalties, bounties, achievements, leaderboards, and seasonal rewards.

**🚧 Status: In Development**

## 📑 Table of Contents

- [Quick Start](#-quick-start)
- [Features](#-features)
- [Core Concepts](#-core-concepts)
- [Tech Stack](#-tech-stack)
- [System Architecture](#-system-architecture)
- [Project Structure](#-project-structure)
- [Development Guidelines](#-development-guidelines)
- [Testing](#-testing)
- [Troubleshooting](#-troubleshooting)
- [Documentation](#-documentation)
- [Implementation Roadmap](#-implementation-roadmap)
- [Contributing](#-contributing)
- [License](#-license)

## 🚀 Quick Start

### Prerequisites
- Docker / Docker Compose
- .NET 10 SDK
- Flutter SDK
- Git

### Clone Repository
```bash
git clone <repository-url>
cd chore-wars
```

### Run Locally (For Active Development)

1. **Setup Infrastructure via Docker (Recommended)**
   To quickly spin up the required PostgreSQL database, Redis cache, and Kafka broker, run:
   ```bash
   docker compose up -d postgres redis kafka
   ```

2. **Database Setup**
   *(Database migrations and initial schema setup are Planned)*

3. **Run Backend**
   ```bash
   cd backend
   dotnet run --project src/Presentation/Presentation.csproj
   ```
   *(API runs at `http://localhost:5297`)*


## ✨ Features

*Note: The project is currently under development. The features below describe the defined project scope; some features have not been implemented yet.*

### 🏠 Household Management
- 👥 Create and manage a household.
- 🔑 Generate an invitation code for joining a household.
- 📱 Join a household using an invitation QR code.
- 👑 Household creator acts as the House Owner.
- 🔄 Transfer household ownership.
- 🚪 Manage household membership.

### 🧹 Chore Management
- 📝 Create and manage recurring chores.
- 📅 Support multiple chore frequencies: Daily, Every X days, Weekly, X times per week, Specific days, Monthly, Every X months, Yearly, Custom.
- ⏰ Define chore deadlines and time windows.
- 🔁 Separate recurring Chore Templates from concrete Chore Occurrences.
- 🎁 Support normal chores and bonus chores.

### ⚖️ Fair Chore Distribution
- 🤖 Automatic chore allocation based on fairness rules.
- 👤 Manual chore assignment.
- 📊 Workload-based fairness instead of simply counting chores.
- 🗓️ Consider member availability and deadline feasibility.
- ⚖️ Consider current workload, Karma, and previous assignments.
- 🔄 Support rotation between members.
- ⚠️ Warn when manual assignments create a significantly imbalanced workload.

### 🎮 Gamification
- ⭐ Earn Karma from completed chores.
- 📉 Lose Karma through overdue penalties.
- 🏆 Seasonal leaderboard and rankings.
- 🥇 Season-based rewards.
- 🏅 Achievements such as: House MVP, Chore Streak, Cleaning Warrior, Bounty Hunter.
- 🎟️ Chore Pass reward for the #1 seasonal ranking.

### 💰 Bounty System
- 💵 An assigned member can create a bounty for a chore.
- 🤝 Another household member can accept the bounty.
- 🔄 The chore is reassigned to the member who accepts it.
- 📋 Track the resulting payment obligation.
- ⏳ Expired bounties trigger fairness-based reassignment.
- 💸 Forced reassignment creates compensation equal to 120% of the original bounty.
- 🛡️ Forced reassignment does not create an infinite compensation chain.

### 🔔 Notifications
The system is designed to notify users about: Upcoming chores, Chore deadlines, Overdue chores, Karma penalties, Bounty events, Forced reassignment, Season ending, Available rewards.
Real-time notification delivery is planned to be implemented through SignalR.

## 🧠 Core Concepts

Chore Wars is built around several core business concepts.

**Chore Season**
A Chore Season is a period in which a household follows a defined chore routine.
A season contains: Chore schedule, Frequency, Deadlines, Karma values, Allocation method, Member availability.
The default season duration is one month. At the end of a season, the household can reuse, edit, or create a new season.

**Chore Template**
Defines the recurring chore itself. (e.g., Take out the trash | Frequency: Every 3 days | Deadline: 20:00 | Karma: +5)

**Chore Occurrence**
A concrete instance generated from a Chore Template.

**Karma**
Karma represents a member's contribution to household chores.
Karma values are fixed for the season once the season starts.

**Fair Allocation**
Automatic allocation does not attempt to give every member the same number of chores. Instead, it prioritizes:
`Availability` ↓ `Deadline Feasibility` ↓ `Current Workload` ↓ `Season Karma` ↓ `Previous Assignment / Rotation`
The goal is to distribute the overall workload as fairly as possible while respecting hard constraints.

**Bounty & Forced Reassignment**
A bounty provides a way for an assigned member to negotiate the responsibility of a chore with another household member.
If a bounty expires without being accepted, fairness-based reassignment assigns a new member, giving 0 Karma for forced assignment but generating a 120% compensation obligation.

## 🛠️ Tech Stack

### Mobile
- **Framework**: Flutter + Dart
- **State Management**: Riverpod
- **Routing**: GoRouter
- **HTTP Client**: Dio
- **Realtime**: SignalR

### Backend
- **Framework**: ASP.NET Core 10 Web API
- **Language**: C#
- **Architecture**: Clean Architecture
- **ORM**: Entity Framework Core
- **Database**: PostgreSQL 16
- **Cache**: Redis 7
- **Message Broker**: Apache Kafka 3.7 (KRaft)
- **Monitoring**: Prometheus + Grafana 11 (Planned)
- **CI/CD**: GitHub Actions (Planned)

## 🏗️ System Architecture

The backend follows Clean Architecture:
`Presentation` → `Application` ← `Domain`
`Infrastructure` → `Application` & `Domain`

The dependency direction keeps business logic independent from external technologies.
Infrastructure-specific technologies such as PostgreSQL, Redis, Kafka, and external authentication implementations remain inside the Infrastructure layer. *(Note: Redis and Kafka integration are currently Planned)*

## 📁 Project Structure

```text
chore-wars/
├── backend/                  # .NET 10 Backend API (Clean Architecture)
│   ├── src/
│   │   ├── Domain/
│   │   ├── Application/
│   │   ├── Infrastructure/
│   │   └── Presentation/
│   └── tests/
```

## 🧩 Development Guidelines

The project follows a fixed Clean Architecture structure.

### Layer Responsibilities
- **Domain**: Entities, Enums, Value Objects, Domain rules, Domain exceptions. Must not depend on Infrastructure.
- **Application**: Use cases, Business logic, DTOs, Validation, Repository/service abstractions, Event abstractions. Must not directly depend on EF Core, DBs, or Kafka.
- **Infrastructure**: Implementations of EF Core, PostgreSQL, Redis, Kafka, JWT, Password hashing, Background workers.
- **Presentation**: Controllers, Authorization, Middleware, SignalR hubs, Dependency injection, HTTP responses.

### Background Workers & Events
- **Workers** act only as schedulers/orchestrators and must not contain core business logic.
- **Event-Driven Architecture**: Application services publish typed events through `IEventPublisher`. The Infrastructure layer maps these to Kafka. The Application layer does not know Kafka topic names.

## 🧪 Testing
Unit Tests and Integration Tests (covering Critical flows like Auth, House, Chore completion, Bounty, Penalty) are planned.

## 🔧 Troubleshooting
- **Backend does not build**: Check `.NET SDK` version.
- **Database connection errors**: Ensure PostgreSQL is running and EF Core migrations are applied.
- **Solution file not found**: The project uses `ChoreWars.slnx` instead of `.sln`.

## 📚 Documentation
The implementation rules are documented in `IMPLEMENTATION_DISCIPLINE.md`.

## 🗺️ Implementation Roadmap
- **Phase 1-6**: Backend Foundation, Core Features, Infrastructure, Workers, Events, Tests.
- **Phase 7-9**: Mobile Setup, Auth, House, Season, Chore, Bounty, Gamification.
- **Phase 10-12**: Monitoring, CI/CD, Documentation.

## 🤝 Contributing
Contributions should follow the project's architecture and implementation rules.
Architecture changes should not be introduced without updating the project design and implementation rules.

## 📄 License
License information will be added when the project license is finalized.
