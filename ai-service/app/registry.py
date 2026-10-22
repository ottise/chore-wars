import hashlib
from pathlib import Path

import joblib
import numpy as np
from sqlalchemy import select

from app.storage import EvaluationStore, models


def trusted_artifact(root: Path, name: str, digest: str):
    root = root.resolve()
    path = (root / name).resolve()
    if (
        not path.is_relative_to(root)
        or path.suffix != ".joblib"
        or hashlib.sha256(path.read_bytes()).hexdigest() != digest
    ):
        raise ValueError("ARTIFACT_HASH_OR_PATH_INVALID")
    return joblib.load(path)


def promote(
    store: EvaluationStore, house: str, model_id: str, product_run: str, root: Path
):
    with store.engine.begin() as db:
        row = (
            db.execute(
                select(models).where(
                    models.c.house_id == house, models.c.id == model_id
                )
            )
            .mappings()
            .first()
        )
        if row is None:
            raise LookupError("Model not found")
        report = row["payload"]
        evaluation = store.get_run(house, product_run)
        if (
            not report.get("quality_passed")
            or report.get("threshold") is None
            or row["target"] != "T1"
            or not evaluation
            or evaluation["status"] != "SUCCEEDED"
        ):
            raise ValueError("QUALITY_OR_PRODUCT_GATE_MISSING")
        meta = evaluation["metadata"]
        if (
            meta.get("model_version") != model_id
            or meta.get("capability") != "RISK_INSIGHT"
            or meta.get("data_source") != report["data_source"]
        ):
            raise ValueError("PRODUCT_EVIDENCE_SCOPE_MISMATCH")
        m = evaluation["metrics"]
        for key, minimum in (("precision", 0.7), ("recall", 0.5)):
            if m.get(key, {}).get("value") is None or m[key]["value"] < minimum:
                raise ValueError("DELIVERED_ALERT_GATE_FAILED")
        if (
            m.get("fpr", {}).get("value") is None
            or m["fpr"]["value"] > 0.1
            or meta.get("operational_gate_passed") is not True
        ):
            raise ValueError("FALSE_ALERT_OR_OPERATIONAL_GATE_FAILED")
        trusted_artifact(root, report["artifact_file"], report["artifact_hash"])
        for old in db.execute(
            select(models).where(
                models.c.house_id == house,
                models.c.target == row["target"],
                models.c.status == "APPROVED",
            )
        ).mappings():
            if old["payload"].get("data_source") == report["data_source"]:
                db.execute(
                    models.update()
                    .where(models.c.id == old["id"])
                    .values(status="PREVIOUS_APPROVED")
                )
        db.execute(
            models.update()
            .where(models.c.id == model_id)
            .values(
                status="APPROVED",
                payload={**report, "product_evaluation_run": product_run},
            )
        )


def predict_observed(
    store: EvaluationStore, house: str, features: dict, data_source: str, root: Path
) -> dict:
    with store.engine.connect() as db:
        rows = list(
            db.execute(
                select(models).where(
                    models.c.house_id == house,
                    models.c.target == "T1",
                    models.c.status.in_(["APPROVED", "PREVIOUS_APPROVED"]),
                )
            ).mappings()
        )
    rows.sort(key=lambda row: row["status"] != "APPROVED")
    errors = []
    for row in rows:
        report = row["payload"]
        if report["data_source"] != data_source:
            continue
        try:
            artifact = trusted_artifact(
                root, report["artifact_file"], report["artifact_hash"]
            )
            if artifact["feature_version"] != "episode-at-start-v1":
                raise ValueError("FEATURE_VERSION_MISMATCH")
            p = artifact["estimator"].predict_proba([features])[:, 1]
            if artifact["calibrator"] is not None:
                clipped = np.clip(p, 1e-6, 1 - 1e-6)
                p = artifact["calibrator"].predict_proba(
                    np.log(clipped / (1 - clipped)).reshape(-1, 1)
                )[:, 1]
            if not np.isfinite(p).all() or not 0 <= p[0] <= 1:
                raise ValueError("INVALID_PREDICTION")
            return {
                "status": "PREDICTED",
                "p_late": float(p[0]),
                "model_version": row["id"],
                "threshold": report["threshold"],
                "inference_source": "MODEL",
                "data_source": data_source,
                "rollback_used": row["status"] != "APPROVED",
            }
        except (ValueError, OSError, KeyError, TypeError) as error:
            errors.append(type(error).__name__)
            with store.engine.begin() as db:
                db.execute(
                    models.update()
                    .where(models.c.id == row["id"])
                    .values(status="SUSPENDED")
                )
    return {
        "status": "NO_APPROVED_MODEL",
        "p_late": None,
        "inference_source": "FALLBACK",
        "data_source": data_source,
        "fallback_reason": "NO_COMPATIBLE_VALID_ARTIFACT",
        "errors": errors,
    }
