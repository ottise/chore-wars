"""Read-only production schema gate. Never applies migrations."""
import argparse
import json
import os
from pathlib import Path


def verify(connection, expected: list[str], framework: str) -> dict:
    with connection.transaction():
        connection.execute("SET TRANSACTION READ ONLY")
        connection.execute("SET LOCAL statement_timeout = '3000ms'")
        expected_database = "chorewars" if framework == "core" else "chorewars_ai"
        if connection.execute("SELECT current_database()").fetchone()[0] != expected_database:
            return {"state": "fail", "reason": "wrong_database"}
        tables = {r[0] for r in connection.execute("SELECT table_name FROM information_schema.tables WHERE table_schema='public'")}
        history = "__EFMigrationsHistory" if framework == "core" else "alembic_version"
        if history not in tables:
            return {"state": "fail", "reason": "missing_migration_history"}
        query = 'SELECT "MigrationId" FROM "__EFMigrationsHistory"' if framework == "core" else "SELECT version_num FROM alembic_version"
        actual = {r[0] for r in connection.execute(query)}
        required = {"Users", "Houses", "AIChatInsights"} if framework == "core" else {"event_inbox", "training_jobs", "model_versions"}
        ready = actual == set(expected) and required <= tables
        return {"state": "pass" if ready else "fail", "reason": "schema_ready" if ready else "schema_mismatch"}


def main():
    import psycopg
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    manifest = json.loads(Path(args.manifest).read_text())
    result = {"sha": manifest["sha"], "components": {}}
    for framework, env, name in (("core", "CORE_READONLY_DATABASE_URL", "database"), ("ai", "AI_READONLY_DATABASE_URL", "ai-database")):
        try:
            url = os.environ[env]
            with psycopg.connect(url, connect_timeout=5) as db:
                expected = [r["id"] for r in manifest["core"]] if framework == "core" else manifest["ai_heads"]
                result["components"][name] = verify(db, expected, framework)
        except Exception:
            result["components"][name] = {"state": "fail", "reason": "missing_credentials_or_connection_failed"}
    Path(args.output).write_text(json.dumps(result, indent=2), encoding="utf-8")
    raise SystemExit(0 if all(r["state"] == "pass" for r in result["components"].values()) else 1)


if __name__ == "__main__":
    main()
