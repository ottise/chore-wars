import os
import re
from pathlib import Path

from alembic.script import ScriptDirectory
from sqlalchemy import inspect, text

from app.storage import metadata


def build_version() -> str:
    value = os.getenv("RENDER_GIT_COMMIT") or os.getenv("BUILD_COMMIT", "")
    return value.lower() if re.fullmatch(r"[a-fA-F0-9]{40}", value) else "unknown"


def schema_status(engine) -> dict:
    try:
        scripts = ScriptDirectory(str(Path(__file__).resolve().parents[1] / "migrations"))
        expected = set(scripts.get_heads())
        with engine.connect() as db:
            if db.dialect.name == "postgresql":
                db.execute(text("SET LOCAL statement_timeout = '2000ms'"))
            tables = set(inspect(db).get_table_names())
            missing = sorted(set(metadata.tables) - tables)
            revisions = set(db.execute(text("SELECT version_num FROM alembic_version")).scalars()) if "alembic_version" in tables else set()
        ready = not missing and revisions == expected
        return {"ready": ready, "reason": "schema_ready" if ready else "schema_incomplete"}
    except Exception:
        return {"ready": False, "reason": "database_unavailable"}
