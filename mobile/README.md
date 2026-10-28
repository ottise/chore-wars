# chore_wars

## Fixed frontend origin

The frontend origin is **http://localhost:7357**. In a new PowerShell terminal,
run `flutter run` from this repository or `mobile`; the installed project shortcut
starts the fixed-port launcher. The shortcut is scoped to bare `flutter run` in
this checkout. Other Flutter commands and other projects use the original SDK.

On another Windows machine, run `./mobile/scripts/install-flutter-shortcut.ps1`
once from the repository root, then open a new PowerShell terminal. To load it
in an existing terminal after stopping Flutter: `. $PROFILE.CurrentUserAllHosts`.
Alternatively run `./scripts/run-web.ps1` from mobile or use the VS Code launch
configuration **Chore Wars Web (localhost:7357)**.

If 7357 is occupied, stop the previous frontend. The launcher reports the occupied
port and does not silently switch to a random one. It waits for JavaScript before
opening Chrome. Use `-NoBrowser` to open the URL yourself.

## Backend connection

The app connects to the deployed backend by default:

- API: `https://chore-wars-o3rm.onrender.com/api`
- SignalR: `https://chore-wars-o3rm.onrender.com/hubs`

Stop and restart Flutter after changing these compile-time settings. A browser
refresh of an already-running development build does not recompile the app.

To use a local backend explicitly:

```powershell
flutter run -d chrome --web-hostname localhost --web-port 7357 --dart-define-from-file=config/google.json --dart-define=API_BASE_URL=http://localhost:5297/api --dart-define=SIGNALR_BASE_URL=http://localhost:5297/hubs
```

For an Android emulator, replace `localhost` with `10.0.2.2`. Web deployments
using `USE_SAME_ORIGIN=true` still route through their own `/api` and `/hubs` proxy.

## Google OAuth origin

Register `http://localhost` and `http://localhost:7357` as Authorized JavaScript
origins for the configured Google Client ID. Frontend deployments must also have
their actual HTTPS origin registered. Changing backend environment variables
does not register a frontend origin with Google.

Messages about newer package versions are informational. An AI offline screen
is a separate backend/service configuration status, not a browser launch failure.

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
# Build cloud qua CI

Dùng `scripts/install-flutter.sh` và `scripts/build-render-web.sh` để cài đúng revision Flutter, build release với API/hub Render và sinh `deploy-version.json`. Build cloud mặc định `USE_SAME_ORIGIN=false`; không đưa secret vào dart-define. Docker local vẫn dùng nginx proxy `backend:8080` và `USE_SAME_ORIGIN=true`; không dùng image local đó trực tiếp cho Render. FE cloud dùng static hosting với artifact `build/web`, thiết lập SPA rewrite `/*` → `/index.html` và tắt cache cho `deploy-version.json`.

Các biến và hướng dẫn kích hoạt nằm ở [CI/CD runbook](../scripts/ci/README.md).
