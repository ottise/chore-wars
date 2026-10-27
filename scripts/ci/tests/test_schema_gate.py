import os

import psycopg
import pytest
from psycopg import sql
from scripts.ci.schema_gate import verify


def test_schema_gate_is_read_only_and_rejects_wrong_or_incomplete_database():
    source = os.getenv("AI_TEST_POSTGRES_ADMIN")
    if not source:
        pytest.skip("Disposable PostgreSQL fixture is required")
    info = psycopg.conninfo.conninfo_to_dict(source)
    assert info["host"] in {"127.0.0.1", "localhost"}
    with psycopg.connect(source, autocommit=True) as admin:
        with psycopg.connect(source) as wrong:
            assert verify(wrong, [], "core")["reason"] == "wrong_database"
        admin.execute('CREATE DATABASE chorewars')
        try:
            with psycopg.connect(**{**info, "dbname": "chorewars"}) as db:
                assert verify(db, ["migration-1"], "core")["reason"] == "missing_migration_history"
                assert list(db.execute("SELECT table_name FROM information_schema.tables WHERE table_schema='public'")) == []
                db.execute('CREATE TABLE "__EFMigrationsHistory" ("MigrationId" text)')
                db.execute('INSERT INTO "__EFMigrationsHistory" VALUES (%s)', ("migration-1",))
                for table in ("Users", "Houses", "AIChatInsights"):
                    db.execute(sql.SQL("CREATE TABLE {} (id int)").format(sql.Identifier(table)))
                db.commit()
                assert verify(db, ["migration-1"], "core")["state"] == "pass"
                assert verify(db, ["migration-1", "migration-2"], "core")["state"] == "fail"
        finally:
            admin.execute('DROP DATABASE chorewars WITH (FORCE)')
