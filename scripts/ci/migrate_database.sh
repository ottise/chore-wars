#!/usr/bin/env bash
set -euo pipefail
mode="${1:?review or apply}"
target="${2:?core or ai}"
sha="${RELEASE_SHA:?}"
[[ "$sha" =~ ^[a-f0-9]{40}$ ]]
[[ "$(git rev-parse HEAD)" == "$sha" ]]
mkdir -p artifacts/migrations
sql="artifacts/migrations/$target.sql"
if [[ "$mode" == review ]]; then
  if [[ "$target" == core ]]; then
    dotnet tool restore
    dotnet ef migrations script --idempotent --project backend/src/Infrastructure --startup-project backend/src/Presentation --output "$sql"
  elif [[ "$target" == ai ]]; then
    base="${MIGRATION_FROM_REVISION:-base}"
    [[ "$base" =~ ^[a-zA-Z0-9_]+$ ]]
    (cd ai-service && AI_DATABASE_URL=postgresql+psycopg://review:review@localhost/review python -m alembic upgrade "$base:head" --sql) > "$sql"
  else
    exit 2
  fi
  sha256sum "$sql" > artifacts/migrations/sha256.txt
elif [[ "$mode" == apply ]]; then
  [[ "${PRODUCTION_DB_APPROVED:-}" == true ]]
  [[ -n "${BACKUP_REFERENCE:-}" ]]
  [[ "${EXPECTED_SQL_SHA256:-}" =~ ^[a-f0-9]{64}$ ]]
  [[ "$(sha256sum "$sql" | cut -d' ' -f1)" == "$EXPECTED_SQL_SHA256" ]]
  python -m scripts.ci.apply_migration --target "$target" --sql "$sql"
else
  exit 2
fi
