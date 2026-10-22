import logging
import signal
import time
from datetime import datetime, timedelta, timezone

from sqlalchemy import and_, or_, select

from app.config import Settings
from app.ml import run_experiment
from app.storage import EvaluationStore, events, training_jobs
from app.stream import stream_status

logger = logging.getLogger("chorewars.ai.trainer")


def process_one(store: EvaluationStore, config: Settings) -> bool:
    now = datetime.now(timezone.utc)
    with store.engine.begin() as db:
        query = (
            select(training_jobs)
            .where(
                training_jobs.c.attempts < 3,
                or_(
                    training_jobs.c.status == "WAITING",
                    and_(
                        training_jobs.c.status == "RUNNING",
                        training_jobs.c.lease_until < now,
                    ),
                ),
            )
            .order_by(training_jobs.c.cutoff)
        )
        job = None
        for candidate in db.execute(
            query.with_for_update(skip_locked=True).limit(32)
        ).mappings():
            source = db.execute(
                select(events.c.payload).where(
                    events.c.id == candidate["source_event_id"]
                )
            ).scalar_one()
            history = store.history(candidate["house_id"], candidate["cutoff"])
            if stream_status(
                history, source.get("batch_last_sequence") or source["house_sequence"]
            )["telemetry_complete"]:
                job = dict(candidate)
                break
        if job is None:
            return False
        db.execute(
            training_jobs.update()
            .where(training_jobs.c.id == job["id"])
            .values(
                status="RUNNING",
                attempts=job["attempts"] + 1,
                lease_until=now + timedelta(minutes=15),
            )
        )
    try:
        cutoff = (
            job["cutoff"].replace(tzinfo=timezone.utc)
            if job["cutoff"].tzinfo is None
            else job["cutoff"]
        )
        report = run_experiment(
            store, job["house_id"], job["target"], config.artifacts, cutoff, job["id"]
        )
        with store.engine.begin() as db:
            db.execute(
                training_jobs.update()
                .where(training_jobs.c.id == job["id"])
                .values(status="COMPLETED", lease_until=None, error_code=None)
            )
        logger.info(
            "Training job %s completed: %s, no automatic promotion",
            job["id"],
            report["status"],
        )
    except Exception as error:
        with store.engine.begin() as db:
            db.execute(
                training_jobs.update()
                .where(training_jobs.c.id == job["id"])
                .values(
                    status="FAILED" if job["attempts"] + 1 >= 3 else "WAITING",
                    lease_until=None,
                    error_code=type(error).__name__,
                )
            )
        logger.warning("Training job %s failed (%s)", job["id"], type(error).__name__)
    return True


def run_trainer():
    config = Settings()
    store = EvaluationStore(config.database_url)
    stopped = False

    def stop(*_):
        nonlocal stopped
        stopped = True

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    try:
        while not stopped:
            if not process_one(store, config):
                time.sleep(5)
    finally:
        store.engine.dispose()


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    run_trainer()
