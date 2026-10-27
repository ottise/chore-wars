#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
expected=d3b14c876900e553bc736ca19295fc09e3853e8e
sdk_root="$(cd "$(dirname "$(command -v flutter)")/.." && pwd)"
test "$(git -C "$sdk_root" rev-parse HEAD)" = "$expected"
export API_BASE_URL="${API_BASE_URL:-https://chore-wars-o3rm.onrender.com/api}"
export SIGNALR_BASE_URL="${SIGNALR_BASE_URL:-https://chore-wars-o3rm.onrender.com/hubs}"
export USE_SAME_ORIGIN="${USE_SAME_ORIGIN:-false}"
[[ "$API_BASE_URL" =~ ^https://[^/]+/api$ ]]
[[ "$SIGNALR_BASE_URL" =~ ^https://[^/]+/hubs$ ]]
for url in "$API_BASE_URL" "$SIGNALR_BASE_URL"; do
  [[ ! "$url" =~ ^https://(localhost|127\.0\.0\.1|\[::1\])([:/]|$) ]]
  [[ "$url" != *"@"* ]]
done
[[ "$USE_SAME_ORIGIN" == true || "$USE_SAME_ORIGIN" == false ]]
sha="${RENDER_GIT_COMMIT:-${BUILD_COMMIT:-${GITHUB_SHA:-$(git rev-parse HEAD)}}}"
[[ "$sha" =~ ^[a-f0-9]{40}$ ]]
flutter pub get --enforce-lockfile
flutter build web --release --dart-define=UI_PREVIEW=false \
  --dart-define="USE_SAME_ORIGIN=$USE_SAME_ORIGIN" \
  --dart-define="API_BASE_URL=$API_BASE_URL" \
  --dart-define="SIGNALR_BASE_URL=$SIGNALR_BASE_URL"
printf '{"sha":"%s","api":"%s","hubs":"%s","sameOrigin":%s}\n' \
  "$sha" "$API_BASE_URL" "$SIGNALR_BASE_URL" "$USE_SAME_ORIGIN" > build/web/deploy-version.json
