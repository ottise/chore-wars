import hashlib
import json
from datetime import datetime, timezone
from typing import Any
from uuid import NAMESPACE_URL, uuid4, uuid5

from sqlalchemy import (
    JSON,
    Column,
    DateTime,
    ForeignKey,
    Integer,
    MetaData,
    String,
    Table,
    UniqueConstraint,
    create_engine,
    select,
    text,
)

from app.schemas import Event

metadata = MetaData()
events = Table(
    "event_inbox",
    metadata,
    Column("id", String(36), primary_key=True),
    Column("house_id", String(36), nullable=False, index=True),
    Column("sequence", Integer, nullable=False),
    Column("recorded_at", DateTime(timezone=True), nullable=False),
    Column("payload", JSON, nullable=False),
    Column("hash", String(64), nullable=False),
    UniqueConstraint("house_id", "sequence", name="uq_inbox_house_sequence"),
)
facts = Table(
    "behavior_facts",
    metadata,
    Column("house_id", String(36), primary_key=True),
    Column("kind", String(80), primary_key=True),
    Column("entity_id", String(36), primary_key=True),
    Column("sequence", Integer, nullable=False),
    Column("payload", JSON, nullable=False),
)
runs = Table(
    "evaluation_runs",
    metadata,
    Column("id", String(36), primary_key=True),
    Column("house_id", String(36), nullable=False, index=True),
    Column("group_id", String(36), nullable=False, index=True),
    Column("job_key", String(128), nullable=False),
    Column("arm", String(40), nullable=False),
    Column("status", String(40), nullable=False),
    Column("evaluated_at", DateTime(timezone=True), nullable=False),
    Column("metadata", JSON, nullable=False),
    UniqueConstraint("house_id", "job_key", "arm", name="uq_evaluation_job_arm"),
)
metrics = Table(
    "evaluation_metrics",
    metadata,
    Column(
        "run_id",
        String(36),
        ForeignKey("evaluation_runs.id", ondelete="RESTRICT"),
        primary_key=True,
    ),
    Column("key", String(80), primary_key=True),
    Column("payload", JSON, nullable=False),
)
examples = Table(
    "evaluation_examples",
    metadata,
    Column("id", String(36), primary_key=True),
    Column(
        "run_id",
        String(36),
        ForeignKey("evaluation_runs.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    ),
    Column("payload", JSON, nullable=False),
)
aggregates = Table(
    "evaluation_aggregates",
    metadata,
    Column("id", String(36), primary_key=True),
    Column("house_id", String(36), nullable=False, index=True),
    Column("payload", JSON, nullable=False),
)
learning = Table(
    "learning_status_snapshots",
    metadata,
    Column("id", String(36), primary_key=True),
    Column("house_id", String(36), nullable=False, index=True),
    Column("as_of", DateTime(timezone=True), nullable=False),
    Column("payload", JSON, nullable=False),
)
failures = Table(
    "failed_events",
    metadata,
    Column("id", String(36), primary_key=True),
    Column("house_id", String(36), nullable=True, index=True),
    Column("status", String(32), nullable=False),
    Column("error_code", String(80), nullable=False),
    Column("payload", JSON, nullable=False),
    Column("replay_count", Integer, nullable=False, default=0),
)
training = Table(
    "training_runs",
    metadata,
    Column("id", String(36), primary_key=True),
    Column("house_id", String(36), nullable=False, index=True),
    Column("target", String(20), nullable=False),
    Column("status", String(40), nullable=False),
    Column("payload", JSON, nullable=False),
)
models = Table(
    "model_versions",
    metadata,
    Column("id", String(36), primary_key=True),
    Column("house_id", String(36), nullable=False, index=True),
    Column("target", String(20), nullable=False),
    Column("capability", String(40), nullable=False),
    Column("status", String(32), nullable=False),
    Column("payload", JSON, nullable=False),
)
training_jobs = Table(
    "training_jobs",
    metadata,
    Column("id", String(36), primary_key=True),
    Column("house_id", String(36), nullable=False, index=True),
    Column(
        "source_event_id",
        String(36),
        ForeignKey("event_inbox.id", ondelete="RESTRICT"),
        nullable=False,
    ),
    Column("target", String(20), nullable=False),
    Column("status", String(32), nullable=False),
    Column("cutoff", DateTime(timezone=True), nullable=False),
    Column("lease_until", DateTime(timezone=True), nullable=True),
    Column("attempts", Integer, nullable=False, default=0),
    Column("error_code", String(80), nullable=True),
    UniqueConstraint("source_event_id", "target", name="uq_training_source_target"),
)
predictions = Table(
    "observed_predictions",
    metadata,
    Column("id", String(36), primary_key=True),
    Column("house_id", String(36), nullable=False, index=True),
    Column("episode_id", String(36), nullable=False),
    Column("target_version", String(40), nullable=False),
    Column("payload", JSON, nullable=False),
    UniqueConstraint(
        "house_id", "episode_id", "target_version", name="uq_prediction_episode_target"
    ),
)


def canonical_hash(value: Any) -> str:
    return hashlib.sha256(
        json.dumps(value, sort_keys=True, separators=(",", ":"), default=str).encode()
    ).hexdigest()


class EvaluationStore:
    def __init__(self, url: str):
        self.engine = create_engine(url, pool_pre_ping=True)

    def ingest(self, event: Event) -> bool:
        data = event.model_dump(mode="json")
        digest = canonical_hash(data)
        with self.engine.begin() as db:
            # Serializes all events of a household, including out-of-order delivery.
            if db.dialect.name == "postgresql":
                db.execute(
                    text("select pg_advisory_xact_lock(hashtextextended(:house, 0))"),
                    {"house": str(event.house_id)},
                )
            previous = (
                db.execute(select(events).where(events.c.id == str(event.event_id)))
                .mappings()
                .first()
            )
            if previous:
                if previous["hash"] != digest:
                    raise ValueError("EVENT_ID_CONTENT_CONFLICT")
                return False
            if db.execute(
                select(events.c.id).where(
                    events.c.house_id == str(event.house_id),
                    events.c.sequence == event.house_sequence,
                )
            ).first():
                raise ValueError("HOUSE_SEQUENCE_IDENTITY_CONFLICT")
            db.execute(
                events.insert().values(
                    id=str(event.event_id),
                    house_id=str(event.house_id),
                    sequence=event.house_sequence,
                    recorded_at=event.recorded_at,
                    payload=data,
                    hash=digest,
                )
            )
            kind = event.event_type.removesuffix(".upsert")
            key = (
                (facts.c.house_id == str(event.house_id))
                & (facts.c.kind == kind)
                & (facts.c.entity_id == str(event.entity_id))
            )
            old = db.execute(select(facts.c.sequence).where(key)).scalar_one_or_none()
            if old is None:
                db.execute(
                    facts.insert().values(
                        house_id=str(event.house_id),
                        kind=kind,
                        entity_id=str(event.entity_id),
                        sequence=event.house_sequence,
                        payload=event.payload,
                    )
                )
            elif old < event.house_sequence:
                db.execute(
                    facts.update()
                    .where(key)
                    .values(sequence=event.house_sequence, payload=event.payload)
                )
            if kind == "season" and event.payload.get("status") == "COMPLETED":
                for target in ("T1", "T2"):
                    db.execute(
                        training_jobs.insert().values(
                            id=str(uuid4()),
                            house_id=str(event.house_id),
                            source_event_id=str(event.event_id),
                            target=target,
                            status="WAITING",
                            cutoff=event.recorded_at,
                            attempts=0,
                        )
                    )
        return True

    def history(
        self,
        house: str,
        cutoff: datetime | None = None,
        source_sequence: int | None = None,
    ) -> list[dict]:
        with self.engine.connect() as db:
            query = (
                select(events.c.payload)
                .where(events.c.house_id == house)
                .order_by(events.c.sequence)
            )
            if cutoff is not None:
                query = query.where(events.c.recorded_at <= cutoff)
            if source_sequence is not None:
                query = query.where(events.c.sequence <= source_sequence)
            return list(db.execute(query).scalars())

    def house_facts(self, house: str, kind: str | None = None) -> list[dict]:
        with self.engine.connect() as db:
            query = select(facts).where(facts.c.house_id == house)
            if kind:
                query = query.where(facts.c.kind == kind)
            return [dict(x) for x in db.execute(query).mappings()]

    def save_run(
        self,
        house: str,
        group: str,
        job: str,
        arm: str,
        meta: dict,
        values: dict,
        sample_examples: list[dict],
    ) -> str:
        with self.engine.begin() as db:
            if db.dialect.name == "postgresql":
                db.execute(
                    text("select pg_advisory_xact_lock(hashtextextended(:key, 0))"),
                    {"key": f"{house}:{job}:{arm}"},
                )
            old = (
                db.execute(
                    select(runs).where(
                        runs.c.house_id == house,
                        runs.c.job_key == job,
                        runs.c.arm == arm,
                    )
                )
                .mappings()
                .first()
            )
            if old:
                semantic_keys = (
                    "context_hash",
                    "profile_version",
                    "policy_version",
                    "metric_definition_version",
                    "data_source",
                    "scenario_id",
                    "seed",
                    "evaluation_mode",
                    "move_budget",
                )
                if any(old["metadata"].get(k) != meta.get(k) for k in semantic_keys):
                    raise ValueError("EVALUATION_IDEMPOTENCY_CONFLICT")
                return old["id"]
            run_id = str(uuid4())
            db.execute(
                runs.insert().values(
                    id=run_id,
                    house_id=house,
                    group_id=group,
                    job_key=job,
                    arm=arm,
                    status="SUCCEEDED",
                    evaluated_at=datetime.now(timezone.utc),
                    metadata=meta,
                )
            )
            for key, value in values.items():
                db.execute(
                    metrics.insert().values(run_id=run_id, key=key, payload=value)
                )
            for example in sample_examples:
                db.execute(
                    examples.insert().values(
                        id=str(uuid4()), run_id=run_id, payload=example
                    )
                )
            return run_id

    def list_runs(self, house: str, page: int = 1, source: str | None = None) -> dict:
        with self.engine.connect() as db:
            query = (
                select(runs)
                .where(runs.c.house_id == house)
                .order_by(runs.c.evaluated_at.desc(), runs.c.id)
            )
            rows = [dict(r) for r in db.execute(query).mappings()]
        if source:
            rows = [r for r in rows if r["metadata"].get("data_source") == source]
        return {
            "items": rows[(page - 1) * 20 : page * 20],
            "total": len(rows),
            "page": page,
            "page_size": 20,
        }

    def get_run(self, house: str, run_id: str) -> dict | None:
        with self.engine.connect() as db:
            row = (
                db.execute(
                    select(runs).where(runs.c.house_id == house, runs.c.id == run_id)
                )
                .mappings()
                .first()
            )
            if row is None:
                return None
            return {
                **dict(row),
                "metrics": {
                    m["key"]: m["payload"]
                    for m in db.execute(
                        select(metrics).where(metrics.c.run_id == run_id)
                    ).mappings()
                },
            }

    def run_examples(self, house: str, run_id: str, page: int) -> dict | None:
        if self.get_run(house, run_id) is None:
            return None
        with self.engine.connect() as db:
            rows = list(
                db.execute(
                    select(examples)
                    .where(examples.c.run_id == run_id)
                    .order_by(examples.c.id)
                ).mappings()
            )
        return {
            "items": [dict(r) for r in rows[(page - 1) * 20 : page * 20]],
            "total": len(rows),
            "page": page,
        }

    def group_runs(self, house: str, group: str) -> list[dict]:
        with self.engine.connect() as db:
            ids = list(
                db.execute(
                    select(runs.c.id).where(
                        runs.c.house_id == house, runs.c.group_id == group
                    )
                ).scalars()
            )
        return [self.get_run(house, i) for i in ids]

    def quarantine(self, payload: dict, code: str, house: str | None = None) -> str:
        identity = {
            key: payload[key]
            for key in ("topic", "partition", "offset")
            if key in payload
        }
        failure_id = (
            str(uuid5(NAMESPACE_URL, canonical_hash(identity)))
            if len(identity) == 3
            else str(uuid4())
        )
        with self.engine.begin() as db:
            if db.dialect.name == "postgresql":
                db.execute(
                    text("select pg_advisory_xact_lock(hashtextextended(:key,0))"),
                    {"key": failure_id},
                )
            if db.execute(
                select(failures.c.id).where(failures.c.id == failure_id)
            ).first():
                return failure_id
            db.execute(
                failures.insert().values(
                    id=failure_id,
                    house_id=house,
                    status="FAILED",
                    error_code=code,
                    payload=payload,
                    replay_count=0,
                )
            )
        return failure_id

    def replay_failure(self, failure_id: str, house: str) -> dict:
        with self.engine.connect() as db:
            row = (
                db.execute(
                    select(failures).where(
                        failures.c.id == failure_id, failures.c.house_id == house
                    )
                )
                .mappings()
                .first()
            )
        if row is None:
            raise LookupError(
                "Verified household failure not found; unidentified payload requires source repair by operations"
            )
        event = Event.model_validate_json(bytes.fromhex(row["payload"]["raw_hex"]))
        if str(event.house_id) != house:
            raise ValueError("FAILURE_SCOPE_MISMATCH")
        inserted = self.ingest(event)
        with self.engine.begin() as db:
            db.execute(
                failures.update()
                .where(failures.c.id == failure_id)
                .values(status="REPLAYED", replay_count=failures.c.replay_count + 1)
            )
        return {"id": failure_id, "status": "REPLAYED", "new_event": inserted}

    def remember_prediction(self, house: str, episode: str, value: dict) -> dict:
        with self.engine.begin() as db:
            if db.dialect.name == "postgresql":
                db.execute(
                    text("select pg_advisory_xact_lock(hashtextextended(:key,0))"),
                    {"key": f"prediction/{house}/{episode}"},
                )
            previous = db.execute(
                select(predictions.c.payload).where(
                    predictions.c.house_id == house,
                    predictions.c.episode_id == episode,
                    predictions.c.target_version == "T1-v1",
                )
            ).scalar_one_or_none()
            if previous is not None:
                return previous
            if value.get("status") == "PREDICTED":
                value = {"prediction_id": str(uuid4()), **value}
                db.execute(
                    predictions.insert().values(
                        id=value["prediction_id"],
                        house_id=house,
                        episode_id=episode,
                        target_version="T1-v1",
                        payload=value,
                    )
                )
            return value
