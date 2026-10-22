import os
from pathlib import Path
from uuid import UUID, uuid4

import psycopg
import pytest
from alembic import command
from alembic.config import Config
from app.schemas import Context
from app.storage import EvaluationStore, metadata
from psycopg import sql


@pytest.fixture
def context():
    return Context.model_validate(
        {
            "house_id": str(UUID(int=100)),
            "season_id": str(UUID(int=101)),
            "revision": 1,
            "status": "DRAFT",
            "as_of": "2026-01-01T00:00:00Z",
            "members": [
                {
                    "id": str(UUID(int=i)),
                    "availability": [
                        {
                            "day": d,
                            "available": True,
                            "slots": [{"start": 480, "end": 1200}],
                        }
                        for d in range(7)
                    ],
                }
                for i in (1, 2, 3)
            ],
            "tasks": [
                {
                    "id": str(UUID(int=200 + i)),
                    "template_id": str(UUID(int=300 + i % 2)),
                    "due_at": "2026-01-02T14:00:00Z",
                    "minutes": 15,
                    "karma": 10,
                }
                for i in range(6)
            ],
        }
    )


@pytest.fixture
def store(tmp_path):
    result = EvaluationStore(f"sqlite:///{(tmp_path / 'test.db').as_posix()}")
    metadata.create_all(result.engine)
    yield result
    result.engine.dispose()


@pytest.fixture
def postgres_store(monkeypatch):
    admin = os.getenv("AI_TEST_POSTGRES_ADMIN")
    if not admin:
        pytest.skip(
            "AI_TEST_POSTGRES_ADMIN must point to a disposable local PostgreSQL server"
        )
    info = psycopg.conninfo.conninfo_to_dict(admin)
    if info.get("host") not in ("localhost", "127.0.0.1"):
        raise ValueError("Tests may only create databases on a local disposable server")
    database = "cw_ai_test_" + uuid4().hex
    with psycopg.connect(admin, autocommit=True) as connection:
        connection.execute(
            sql.SQL("CREATE DATABASE {}").format(sql.Identifier(database))
        )
    url = f"postgresql+psycopg://{info['user']}:{info['password']}@{info['host']}:{info.get('port', '5432')}/{database}"
    monkeypatch.setenv("AI_DATABASE_URL", url)
    store = EvaluationStore(url)
    try:
        config = Config(str(Path(__file__).resolve().parents[1] / "alembic.ini"))
        command.upgrade(config, "head")
        command.check(config)
        yield store
    finally:
        store.engine.dispose()
        with psycopg.connect(admin, autocommit=True) as connection:
            connection.execute(
                sql.SQL("DROP DATABASE {} WITH (FORCE)").format(
                    sql.Identifier(database)
                )
            )
