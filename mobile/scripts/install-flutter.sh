#!/usr/bin/env bash
set -euo pipefail
revision=d3b14c876900e553bc736ca19295fc09e3853e8e
directory="${FLUTTER_ROOT:-${RUNNER_TEMP:-/tmp}/chorewars-flutter}"
if ! command -v flutter >/dev/null 2>&1; then
  git init "$directory"
  git -C "$directory" remote add origin https://github.com/flutter/flutter.git
  git -C "$directory" fetch --depth 1 origin refs/tags/3.47.2:refs/tags/3.47.2
  git -C "$directory" checkout --detach refs/tags/3.47.2
  export PATH="$directory/bin:$PATH"
fi
actual_root="$(cd "$(dirname "$(command -v flutter)")/.." && pwd)"
test "$(git -C "$actual_root" rev-parse HEAD)" = "$revision"
flutter config --enable-web --no-analytics
if [[ -n "${GITHUB_PATH:-}" ]]; then
  echo "$actual_root/bin" >> "$GITHUB_PATH"
fi
