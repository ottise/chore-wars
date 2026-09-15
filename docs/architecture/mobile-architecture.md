# Mobile Architecture

The Chore Wars mobile application is built using Flutter with a feature-based architecture designed to maintain high cohesion and low coupling.

State management is handled by Riverpod, while GoRouter is used for application routing.

## Folder Structure

```text
mobile/
└── lib/
    ├── core/                  # App-wide shared resources
    │   ├── constants/         # App constants and API-related constants
    │   ├── network/           # Dio configuration, interceptors, API endpoints
    │   ├── router/            # GoRouter configuration and route guards
    │   ├── storage/           # Secure storage for tokens and local settings
    │   ├── theme/             # Application theme definitions
    │   ├── utils/             # Formatters, extensions, and utility functions
    │   └── widgets/           # Reusable generic UI components
    │
    └── features/              # Feature modules
        ├── auth/
        ├── house/
        ├── season/
        ├── chore/
        ├── bounty/
        ├── gamification/
        └── notification/
```

## Feature Anatomy

Each feature follows a Clean Architecture-inspired structure adapted for Flutter.

```text
feature/
├── data/
│   ├── datasources/
│   ├── models/
│   └── repositories/
│
├── domain/
│   ├── entities/
│   ├── repositories/
│   └── usecases/
│
└── presentation/
    ├── providers/
    ├── screens/
    └── widgets/
```

### 1. data/
Responsible for external data access and data transformation.
- **datasources/**: Handles communication with external data sources, primarily HTTP APIs through Dio.
- **models/**: Data models used for API serialization and deserialization.
- **repositories/**: Concrete implementations of repository interfaces defined by the Domain layer.

### 2. domain/
Contains the feature's core business-facing abstractions and models.
- **entities/**: Pure Dart domain entities independent of API and infrastructure details.
- **repositories/**: Abstract repository contracts used by the Domain and Presentation layers.
- **usecases/**: Optional use-case classes for complex feature operations. Simple CRUD operations may be handled directly through repository abstractions.

### 3. presentation/
Responsible for UI and presentation state.
- **providers/**: Riverpod providers/notifiers responsible for managing UI state and coordinating with domain repositories.
- **screens/**: Full-page Flutter screens.
- **widgets/**: Feature-specific UI components such as `ChoreCard`.

## Dependency Flow

Dependencies follow a one-way flow between the presentation, domain, and data layers.

```text
Presentation
      ↓
   Domain
      ↑
     Data
```

A typical feature request follows this flow:

```text
Screen
  ↓
Provider
  ↓
IChoreRepository
  ↑
ChoreRepository
  ↓
ChoreRemoteDataSource
  ↓
Dio
  ↓
Backend API
```

The Presentation layer depends on Domain abstractions rather than concrete Data implementations.

## Key Libraries
- **Riverpod**: State management and dependency injection.
- **GoRouter**: Application routing and route guards.
- **Dio**: HTTP client used for communication with the backend API.
- **Freezed & JSON Serializable**: Used for immutable models and JSON serialization/deserialization.
- **Flutter Secure Storage**: Used for securely storing authentication tokens.
- **SignalR Client**: Planned for real-time communication with the backend, including notifications and live chore/bounty events.
