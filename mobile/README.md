# chore_wars

## Run frontend normally

From the `mobile` directory, run:

```powershell
flutter run
```

Flutter selects its device and port normally. The project PowerShell shortcut
has been removed. In VS Code, select **Chore Wars Web** and press F5; Chrome
uses Flutter's automatically selected port.

## Backend connection

The app connects to the deployed backend by default:

- API: `https://chore-wars-o3rm.onrender.com/api`
- SignalR: `https://chore-wars-o3rm.onrender.com/hubs`

Stop and restart Flutter after changing these compile-time settings. A browser
refresh of an already-running development build does not recompile the app.

To use a local backend explicitly:

```powershell
flutter run -d chrome --dart-define-from-file=config/google.json --dart-define=API_BASE_URL=http://localhost:5297/api --dart-define=SIGNALR_BASE_URL=http://localhost:5297/hubs
```

For an Android emulator, replace `localhost` with `10.0.2.2`. Web deployments
using `USE_SAME_ORIGIN=true` still route through their own `/api` and `/hubs` proxy.

## Optional launch helper

`./scripts/run-web.ps1` runs the original Flutter SDK and loads
`config/google.json`. It leaves port/device selection to Flutter by default.
Use `-NoBrowser` for the web-server device and open the printed URL yourself.
An explicit `-Port` is optional, never the default.

Google OAuth requires the actual browser origin, including its current port,
to be registered under Authorized JavaScript origins. Update that origin when
testing Google after a port change. The Web Client ID remains configured.

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
