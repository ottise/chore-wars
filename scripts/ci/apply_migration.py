"""Only called by the protected manual migration job after SQL/backup review."""
import argparse
import json
import os
from pathlib import Path

import psycopg
from scripts.ci.schema_gate import verify


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--target", choices=["core", "ai"], required=True)
    parser.add_argument("--sql", required=True)
    args = parser.parse_args()
    if os.getenv("PRODUCTION_DB_APPROVED") != "true" or not os.getenv("BACKUP_REFERENCE"):
        raise SystemExit("Protected migration approval and backup reference required")
    manifest = json.loads(Path("artifacts/migrations/manifest.json").read_text())
    if manifest["sha"] != os.getenv("RELEASE_SHA"):
        raise SystemExit("Reviewed manifest SHA mismatch")
    expected = [r["id"] for r in manifest["core"]] if args.target == "core" else manifest["ai_heads"]
    try:
        with psycopg.connect(os.environ["MIGRATION_DATABASE_URL"], connect_timeout=10, autocommit=True) as db:
            expected_database = "chorewars" if args.target == "core" else "chorewars_ai"
            if db.execute("SELECT current_database()").fetchone()[0] != expected_database:
                raise ValueError("wrong_database")
            tables = {row[0] for row in db.execute("SELECT table_name FROM information_schema.tables WHERE table_schema='public'")}
            if args.target == "core":
                applied = {row[0] for row in db.execute('SELECT "MigrationId" FROM "__EFMigrationsHistory"')} if "__EFMigrationsHistory" in tables else set()
                if not applied <= set(expected):
                    raise ValueError("unknown_existing_migration")
            else:
                applied = {row[0] for row in db.execute("SELECT version_num FROM alembic_version")} if "alembic_version" in tables else set()
                start = os.getenv("MIGRATION_FROM_REVISION", "base")
                if applied != (set() if start == "base" else {start}):
                    raise ValueError("reviewed_start_revision_mismatch")
            db.execute(Path(args.sql).read_text(encoding="utf-8-sig"), prepare=False)
            result = verify(db, expected, args.target)
    except Exception:
        raise SystemExit("Migration failed. Inspect private database logs and history before retry; no rollback was attempted.")
    if result["state"] != "pass":
        raise SystemExit("Migration executed but schema verification failed")
    print("Reviewed migration applied and schema verified")


if __name__ == "__main__":
    main()
