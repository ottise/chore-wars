from datetime import datetime, timezone

from app.labels import label_episode, readiness

NOW = datetime(2026, 1, 3, tzinfo=timezone.utc)


def episode():
    return {
        "snapshot_id": "snapshot",
        "member_id": "A",
        "reason": "INITIAL",
        "started_at": "2026-01-01T00:00:00Z",
        "deadline": "2026-01-02T00:00:00Z",
        "ended_at": None,
    }


def test_transfer_before_deadline_is_censored():
    e = episode()
    e["ended_at"] = "2026-01-01T12:00:00Z"
    o = {
        "due_at": e["deadline"],
        "completed_by": "B",
        "completed_at": "2026-01-01T13:00:00Z",
    }
    assert label_episode(e, o, [], NOW, True)["T1"] is None


def test_overdue_open_and_rejected_request_are_positive():
    e = episode()
    o = {"due_at": e["deadline"]}
    result = label_episode(
        e,
        o,
        [
            {
                "actor_id": "A",
                "requested_at": "2026-01-01T01:00:00Z",
                "status": "REJECTED",
            }
        ],
        NOW,
        True,
    )
    assert result["T1"] == 1 and result["T2"] == 1


def test_late_transport_does_not_mean_missing_source_snapshot():
    e = episode()
    e["completed_by"] = "A"
    e["ended_at"] = e["deadline"]
    result = label_episode(
        e,
        {"due_at": e["deadline"], "completed_by": "A", "completed_at": e["deadline"]},
        [],
        NOW,
        True,
    )
    assert result["T1"] == 0
    assert (
        label_episode(e, {"due_at": e["deadline"]}, [], NOW, False)["status"]
        == "INCOMPLETE_TELEMETRY"
    )


def test_readiness_does_not_pool_unknown_as_negative():
    result = readiness([{"T1": 0}, {"T1": 1}, {"T1": None, "status": "PENDING"}], "T1")
    assert result["offline_eligible"] and not result["product_data_eligible"]
    assert result["class_counts"] == {"0": 1, "1": 1}
