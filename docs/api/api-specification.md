# API Specification

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
