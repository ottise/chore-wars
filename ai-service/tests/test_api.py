from uuid import uuid4

from app.config import Settings
from app.main import create_app
from app.storage import metadata
from fastapi.testclient import TestClient


def test_service_auth_and_tenant_scope(tmp_path, context):
    app = create_app(
        Settings(
            environment="test",
            service_key="x" * 32,
            database_url=f"sqlite:///{(tmp_path / 'api.db').as_posix()}",
        )
    )
    metadata.create_all(app.state.store.engine)
    with TestClient(app) as client:
        path = f"/v1/houses/{context.house_id}/profiles"
        assert client.get(path).status_code == 401
        headers = {
            "X-AI-Key": "x" * 32,
            "X-House-Id": str(context.house_id),
            "X-Actor-Id": str(uuid4()),
        }
        assert client.get(path, headers=headers).status_code == 200
        assert (
            client.get(f"/v1/houses/{uuid4()}/profiles", headers=headers).status_code
            == 403
        )
        result = client.post(
            "/v1/schedules/propose",
            headers=headers,
            json={"context": context.model_dump(mode="json")},
        )
        assert result.status_code == 200
        assert result.json()["metrics"]["hard_violations"] == 0
        headers["X-House-Id"] = str(uuid4())
        assert (
            client.post(
                "/v1/schedules/propose",
                headers=headers,
                json={"context": context.model_dump(mode="json")},
            ).status_code
            == 403
        )


def test_failure_metadata_never_exposes_unknown_or_other_house_payload(store, context):
    house = str(context.house_id)
    known = store.quarantine({"raw_hex": "private-value"}, "KNOWN", house)
    store.quarantine({"raw_hex": "unknown-private-value"}, "UNKNOWN", None)
    store.quarantine({"raw_hex": "other-private-value"}, "OTHER", str(uuid4()))
    app = create_app(
        Settings(
            environment="test", service_key="x" * 32, database_url=str(store.engine.url)
        )
    )
    headers = {"X-AI-Key": "x" * 32, "X-House-Id": house, "X-Actor-Id": str(uuid4())}
    with TestClient(app) as client:
        path = f"/v1/houses/{house}/failures"
        result = client.get(path, headers=headers)
        assert result.status_code == 200
        assert result.json()["items"] == [
            {"id": known, "status": "FAILED", "error_code": "KNOWN", "replay_count": 0}
        ]
        assert "private-value" not in result.text
        assert client.get(path + "?page=2", headers=headers).json()["items"] == []
        assert client.get(path + "?page=0", headers=headers).status_code == 422
