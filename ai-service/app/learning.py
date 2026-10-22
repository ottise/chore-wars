from datetime import datetime
from uuid import NAMESPACE_URL, uuid5

from sqlalchemy import select, text

from app.behavior import profiles
from app.dataset import build_dataset
from app.labels import readiness
from app.storage import EvaluationStore, canonical_hash, learning
from app.stream import stream_status


def snapshot_learning(
    store: EvaluationStore,
    house: str,
    cutoff: datetime,
    source_sequence: int | None = None,
) -> dict:
    history = store.history(house, cutoff, source_sequence)
    profile = profiles(history, cutoff)
    data = build_dataset(history, cutoff)
    result = {
        "house_id": house,
        "as_of": cutoff.isoformat(),
        "source_sequence": source_sequence,
        "valid_event_count": len(history),
        "observed_interaction_count": sum(
            e["event_type"] == "interaction.upsert" for e in history
        ),
        "profile_evidence_count": profile["evidence_count"],
        "profile_version": profile["profile_version"],
        "dataset_manifest": data["manifest"],
        "targets": [readiness(data["rows"], "T1"), readiness(data["rows"], "T2")],
        **stream_status(history, source_sequence),
    }
    identity = str(uuid5(NAMESPACE_URL, f"{house}/{canonical_hash(result)}"))
    result["id"] = identity
    with store.engine.begin() as db:
        if db.dialect.name == "postgresql":
            db.execute(
                text("select pg_advisory_xact_lock(hashtextextended(:key,0))"),
                {"key": identity},
            )
        if (
            db.execute(select(learning.c.id).where(learning.c.id == identity)).first()
            is None
        ):
            db.execute(
                learning.insert().values(
                    id=identity, house_id=house, as_of=cutoff, payload=result
                )
            )
    return result
