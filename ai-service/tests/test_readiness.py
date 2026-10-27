from app.readiness import schema_status, build_version
from app.storage import EvaluationStore
from sqlalchemy import inspect, text
from app.config import Settings
from app.main import create_app
from fastapi.testclient import TestClient


def test_empty_database_not_ready_and_no_tables_created(tmp_path):
    store = EvaluationStore(f"sqlite:///{tmp_path / 'empty.db'}")
    assert not schema_status(store.engine)["ready"]
    assert inspect(store.engine).get_table_names() == []
    store.engine.dispose()


def test_full_migration_ready_but_missing_table_not_ready(postgres_store):
    assert schema_status(postgres_store.engine)["ready"]
    with postgres_store.engine.begin() as db:
        db.execute(text("DROP TABLE observed_predictions"))
    assert not schema_status(postgres_store.engine)["ready"]


def test_version_validates_commit(monkeypatch):
    monkeypatch.setenv("RENDER_GIT_COMMIT", "not-a-sha")
    assert build_version() == "unknown"
    monkeypatch.setenv("RENDER_GIT_COMMIT", "a" * 40)
    assert build_version() == "a" * 40


def test_public_readiness_and_private_auth_fail_closed_without_schema(tmp_path):
    app = create_app(Settings(environment="test", service_key="x" * 32,
                              database_url=f"sqlite:///{tmp_path / 'missing.db'}"))
    with TestClient(app) as client:
        assert client.get("/health/live").status_code == 200
        assert client.get("/health/ready").status_code == 503
        assert client.get("/health/service-auth").status_code == 401
        response = client.get("/health/service-auth", headers={"X-AI-Key": "x" * 32})
        assert response.status_code == 503 and response.json()["schema_ready"] is False
        assert response.json()["worker"] == "unverified"
    assert inspect(app.state.store.engine).get_table_names() == []
    app.state.store.engine.dispose()
