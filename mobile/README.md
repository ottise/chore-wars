# chore_wars

## Run in Chrome when automatic debugging times out

From this `mobile` directory, run:

```powershell
.\scripts\run-web.ps1
```

The script opens Chrome at `http://localhost:8080` once compilation finishes.
Use `-Port 8081` if 8080 is occupied, or `-NoBrowser` to open the URL yourself.
Keep this terminal running; press `q` or `Ctrl+C` to stop it.

In VS Code, select **Chore Wars Web (avoid Chrome debugger timeout)**.
This launch configuration serves the app; open the URL printed in the terminal.

This uses Flutter's `web-server` target, avoiding the automatic Chrome/DWDS
debugger handshake that can time out in `WebkitDebugger.enable`. It does not
repair the SDK debugger; Dart breakpoint debugging is limited in this mode.
See [Flutter web setup](https://docs.flutter.dev/platform-integration/web/setup).
The normal `flutter run -d chrome` command remains available.

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
