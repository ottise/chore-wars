import calendar
import hashlib
import time
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from uuid import uuid4
from zoneinfo import ZoneInfo

import joblib
import numpy as np
from sklearn.ensemble import HistGradientBoostingClassifier, RandomForestClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import average_precision_score, brier_score_loss, confusion_matrix
from sklearn.pipeline import Pipeline
from sqlalchemy import select

from app.behavior import parse_time
from app.dataset import build_dataset
from app.features import DictFeatureEncoder
from app.labels import readiness
from app.learning import snapshot_learning
from app.storage import EvaluationStore, canonical_hash, models, training


def candidates() -> list[tuple[str, dict]]:
    return (
        [("B0", {})]
        + [("B1", {"alpha": a}) for a in (5, 20)]
        + [("L", {"C": c}) for c in (0.1, 1, 10)]
        + [
            ("R", {"max_depth": d, "min_samples_leaf": l})
            for d in (4, 8)
            for l in (5, 10)
        ]
        + [
            ("G", {"learning_rate": r, "max_leaf_nodes": l})
            for r in (0.05, 0.1)
            for l in (7, 15)
        ]
    )


class RateEstimator:
    def __init__(self, alpha: float | None):
        self.alpha = alpha

    def fit(self, x, y):
        self.rate = float(np.mean(y))
        self.groups = {}
        if self.alpha is not None:
            for row, label in zip(x, y):
                key = row.get("template_id", row.get("difficulty", "unknown"))
                count, total = self.groups.get(key, (0, 0))
                self.groups[key] = (count + 1, total + int(label))
        return self

    def predict_proba(self, x):
        result = []
        for row in x:
            n, s = self.groups.get(
                row.get("template_id", row.get("difficulty", "unknown")), (0, 0)
            )
            p = (
                (s + self.alpha * self.rate) / (n + self.alpha)
                if self.alpha is not None
                else self.rate
            )
            result.append([1 - p, p])
        return np.array(result)


def make_estimator(family: str, config: dict):
    if family in ("B0", "B1"):
        return RateEstimator(config.get("alpha"))
    if family == "L":
        classifier = LogisticRegression(C=config["C"], max_iter=1000, solver="lbfgs")
    elif family == "R":
        classifier = RandomForestClassifier(
            n_estimators=200,
            max_depth=config["max_depth"],
            min_samples_leaf=config["min_samples_leaf"],
            random_state=42,
            n_jobs=1,
            max_features="sqrt",
        )
    else:
        classifier = HistGradientBoostingClassifier(
            learning_rate=config["learning_rate"],
            max_leaf_nodes=config["max_leaf_nodes"],
            max_iter=100,
            min_samples_leaf=20,
            l2_regularization=1,
            early_stopping=False,
            random_state=42,
        )
    steps = [
        (
            "features",
            DictFeatureEncoder(
                encoding="ordinal" if family == "G" else "onehot", scale=family == "L"
            ),
        )
    ]
    steps.append(("classifier", classifier))
    return Pipeline(steps)


def classification_metrics(y, p, threshold: float | None = None) -> dict:
    y, p = np.asarray(y, dtype=int), np.asarray(p, dtype=float)
    if len(y) == 0 or not np.isfinite(p).all():
        return {"status": "INSUFFICIENT_EVIDENCE", "sample_count": len(y)}
    result = {
        "status": "VALID",
        "sample_count": len(y),
        "positive_count": int(sum(y)),
        "negative_count": int(len(y) - sum(y)),
        "brier": float(brier_score_loss(y, p)),
        "pr_auc": float(average_precision_score(y, p)) if sum(y) > 0 else None,
    }
    ece = 0.0
    bins = []
    sparse = False
    for i in range(5):
        mask = (p >= i / 5) & ((p < (i + 1) / 5) if i < 4 else (p <= 1))
        n = int(mask.sum())
        if n:
            average = float(p[mask].mean())
            observed = float(y[mask].mean())
            ece += n / len(y) * abs(average - observed)
            sparse |= n < 20
            bins.append(
                {
                    "lower": i / 5,
                    "upper": (i + 1) / 5,
                    "n": n,
                    "mean_probability": average,
                    "observed_rate": observed,
                }
            )
    result.update(
        ece=ece,
        reliability_bins=bins,
        calibration_status="INSUFFICIENT_EVIDENCE"
        if sparse
        else ("PASS" if ece <= 0.1 else "FAIL"),
    )
    if threshold is not None:
        tn, fp, fn, tp = confusion_matrix(y, p >= threshold, labels=[0, 1]).ravel()
        result.update(
            tp=int(tp),
            fp=int(fp),
            fn=int(fn),
            tn=int(tn),
            precision=float(tp / (tp + fp)) if tp + fp else None,
            recall=float(tp / (tp + fn)) if tp + fn else None,
            fpr=float(fp / (fp + tn)) if fp + tn else None,
            threshold=threshold,
        )
    return result


def select_threshold(y, p):
    if len(set(y)) < 2:
        return None
    choices = []
    for threshold in np.arange(0.05, 1, 0.05):
        m = classification_metrics(y, p, float(threshold))
        if (
            m.get("precision") is not None
            and m["precision"] >= 0.7
            and m["recall"] >= 0.5
            and m["fpr"] <= 0.1
        ):
            choices.append((m["recall"], float(threshold)))
    return max(choices)[1] if choices else None


def candidate_complexity(family: str, params: dict) -> tuple:
    rank = {"B0": 0, "B1": 1, "L": 2, "R": 3, "G": 4}[family]
    return (
        rank,
        params.get("max_depth", params.get("max_leaf_nodes", 0)),
        -params.get("min_samples_leaf", 0),
        params.get("C", params.get("learning_rate", 0)),
        -params.get("alpha", 0),
    )


def choose_brier_candidate(values: list[dict], score_key: str) -> dict:
    best = min(row[score_key] for row in values)
    tied = (
        [row for row in values if row[score_key] <= best * 1.01]
        if best > 0
        else [row for row in values if row[score_key] == 0]
    )
    return min(tied, key=lambda row: candidate_complexity(row["family"], row["config"]))


def temporal_shortlist(
    rows: list[dict], target: str, month, fold_blocks: dict | None = None
) -> tuple[list[tuple[str, dict]], list[dict]]:
    """Tune configurations only in forward folds inside months 1–3, before calibration/selection."""
    reports = []
    for family, params in candidates():
        folds = []
        for boundary in (1, 2):
            fits, validation = (
                fold_blocks[boundary]
                if fold_blocks is not None
                else (
                    [r for r in rows if month(r) <= boundary],
                    [r for r in rows if month(r) == boundary + 1],
                )
            )
            if (
                len({r[target] for r in fits}) < 2
                or len({r[target] for r in validation}) < 2
            ):
                continue
            estimator = make_estimator(family, params).fit(
                [r["features"] for r in fits], [r[target] for r in fits]
            )
            metrics = classification_metrics(
                [r[target] for r in validation],
                estimator.predict_proba([r["features"] for r in validation])[:, 1],
            )
            folds.append(
                {
                    "fit_through_month": boundary,
                    "validation_month": boundary + 1,
                    **metrics,
                }
            )
        reports.append(
            {
                "family": family,
                "config": params,
                "forward_folds": folds,
                "mean_brier": float(np.mean([f["brier"] for f in folds]))
                if len(folds) == 2
                else None,
            }
        )
    shortlisted = []
    for family in ("B0", "B1", "L", "R", "G"):
        baseline = reports[0]["forward_folds"]
        choices = [
            r
            for r in reports
            if r["family"] == family
            and r["mean_brier"] is not None
            and len(baseline) == 2
            and all(
                f["pr_auc"] >= b["pr_auc"] for f, b in zip(r["forward_folds"], baseline)
            )
        ]
        if choices:
            winner = choose_brier_candidate(choices, "mean_brier")
            shortlisted.append((family, winner["config"]))
    return shortlisted, reports


def run_experiment(
    store: EvaluationStore,
    house: str,
    target: str,
    artifacts: Path,
    cutoff: datetime,
    run_id: str | None = None,
) -> dict:
    if target not in ("T1", "T2"):
        raise ValueError("Only observed-episode targets may be trained")
    run_id = run_id or str(uuid4())
    with store.engine.connect() as db:
        previous = db.execute(
            select(training.c.payload).where(
                training.c.id == run_id, training.c.house_id == house
            )
        ).scalar_one_or_none()
    if previous is not None:
        return previous
    history = store.history(house, cutoff)
    data = build_dataset(history, cutoff)
    snapshot = snapshot_learning(store, house, cutoff)
    ready = readiness(data["rows"], target)
    report = {
        "run_id": run_id,
        "target": target,
        "evaluated_at": datetime.now(timezone.utc).isoformat(),
        "readiness": ready,
        "dataset_manifest": data["manifest"],
        "learning_snapshot_id": snapshot["id"],
        "candidates": [],
        "protocol": "source-cutoff-forward-folds/calibrate-4/select-5A/threshold-5B/frozen-walk-forward-6-14-v1",
        "data_source": data["manifest"]["data_sources"][0]
        if len(data["manifest"]["data_sources"]) == 1
        else "MIXED_REJECTED",
        "capability": "RISK_INSIGHT" if target == "T1" else "SHADOW_ONLY",
        "status": "INSUFFICIENT_DATA",
        "quality_passed": False,
        "product_passed": False,
        "product_reason": "SEPARATE_DELIVERED_COHORT_AND_OPERATIONAL_GATES_REQUIRED",
    }
    candidate_record = None
    eligible = [r for r in data["rows"] if r.get(target) in (0, 1) and r["features"]]
    if (
        eligible
        and ready["offline_eligible"]
        and report["data_source"] != "MIXED_REJECTED"
        and snapshot["telemetry_complete"]
    ):
        zone = ZoneInfo("Asia/Ho_Chi_Minh")
        anchor = min(
            parse_time(r["prediction_time"]).astimezone(zone)
            for r in data["rows"]
            if r["features"]
        )
        report["temporal_anchor"] = anchor.strftime("%Y-%m")

        def month(row):
            stamp = parse_time(row["prediction_time"]).astimezone(zone)
            return (stamp.year - anchor.year) * 12 + stamp.month - anchor.month + 1

        def end_of(number, day=None):
            year, index = divmod(anchor.year * 12 + anchor.month - 1 + number - 1, 12)
            actual = day or calendar.monthrange(year, index + 1)[1]
            return datetime(
                year, index + 1, actual, 23, 59, 59, 999999, zone
            ).astimezone(timezone.utc)

        blocks = {}

        def block(first, last, known_at, predicate=None):
            known_at = min(known_at, cutoff)
            key = known_at.isoformat()
            if key not in blocks:
                blocks[key] = build_dataset(store.history(house, known_at), known_at)
            return [
                r
                for r in blocks[key]["rows"]
                if first <= month(r) <= last
                and r.get(target) in (0, 1)
                and r["features"]
                and (predicate is None or predicate(r))
            ]

        x = lambda rows: [r["features"] for r in rows]
        y = lambda rows: [r[target] for r in rows]
        valid = lambda rows: len({r[target] for r in rows}) == 2

        def probabilities(estimator, calibrator, rows):
            if not rows:
                return np.empty(0)
            probability = estimator.predict_proba(x(rows))[:, 1]
            if calibrator is not None:
                clipped = np.clip(probability, 1e-6, 1 - 1e-6)
                probability = calibrator.predict_proba(
                    np.log(clipped / (1 - clipped)).reshape(-1, 1)
                )[:, 1]
            return probability

        def fitted(family, params, fits, calibration):
            estimator = make_estimator(family, params).fit(x(fits), y(fits))
            calibrator = None
            counts = Counter(y(calibration))
            if (
                family != "B0"
                and len(calibration) >= 100
                and min(counts[0], counts[1]) >= 20
            ):
                raw = np.clip(
                    estimator.predict_proba(x(calibration))[:, 1], 1e-6, 1 - 1e-6
                )
                calibrator = LogisticRegression().fit(
                    np.log(raw / (1 - raw)).reshape(-1, 1), y(calibration)
                )
            return estimator, calibrator

        fits = block(1, 3, end_of(3))
        calibration = block(4, 4, end_of(4))
        choose = block(
            5,
            5,
            end_of(5, 15),
            lambda r: parse_time(r["prediction_time"]).astimezone(zone).day <= 15,
        )
        threshold_rows = block(
            5,
            5,
            end_of(5),
            lambda r: parse_time(r["prediction_time"]).astimezone(zone).day > 15,
        )
        folds = {
            boundary: (
                block(1, boundary, end_of(boundary)),
                block(boundary + 1, boundary + 1, end_of(boundary + 1)),
            )
            for boundary in (1, 2)
        }
        shortlist, inner = temporal_shortlist(fits, target, month, folds)
        report["inner_validation"] = inner
        if cutoff >= end_of(5) and valid(fits) and valid(choose) and shortlist:
            scored = []
            for family, params in shortlist:
                started = time.perf_counter()
                estimator, calibrator = fitted(family, params, fits, calibration)
                fit_ms = (time.perf_counter() - started) * 1000
                started = time.perf_counter()
                probability = probabilities(estimator, calibrator, choose)
                predict_ms = (time.perf_counter() - started) * 1000
                measured = classification_metrics(y(choose), probability)
                entry = {
                    "family": family,
                    "config": params,
                    "validation": measured,
                    "selection_brier": measured["brier"],
                    "fit_ms": fit_ms,
                    "predict_ms": predict_ms,
                }
                report["candidates"].append(entry)
                scored.append(
                    {**entry, "estimator": estimator, "calibrator": calibrator}
                )
            baseline_pr = next(
                row["validation"]["pr_auc"] for row in scored if row["family"] == "B0"
            )
            admissible = [
                row for row in scored if row["validation"]["pr_auc"] >= baseline_pr
            ]
            winner = choose_brier_candidate(admissible, "selection_brier")
            family, params = winner["family"], winner["config"]
            estimator, calibrator = winner["estimator"], winner["calibrator"]
            threshold = select_threshold(
                y(threshold_rows), probabilities(estimator, calibrator, threshold_rows)
            )
            report.update(
                family=family,
                config=params,
                threshold=threshold,
                selection_data_cutoff=end_of(5).isoformat(),
                decision_rule="BRIER_WITHIN_1_PERCENT_THEN_SIMPLICITY_PR_AUC_NONINFERIOR",
                status="SELECTED_PENDING_HOLDOUT",
            )
            reference_rate = float(np.mean(y(fits)))
            previous_seen = len(block(1, 5, end_of(5)))
            model_cutoff = end_of(4)
            forecast = []
            test_y = []
            test_probability = []
            test_reference = []
            closed = 0
            while end_of(closed + 1) <= cutoff:
                closed += 1
            for number in range(6, min(closed, 14) + 1):
                outcome_cutoff = min(cutoff, end_of(number))
                decision_cutoff = end_of(number - 1)
                status = "FROZEN_FINALIST" if number == 6 else "SKIPPED_NO_NEW_DATA"
                if number > 6:
                    available = block(1, number - 1, decision_cutoff)
                    refit = block(1, number - 2, decision_cutoff)
                    recalibration = block(number - 1, number - 1, decision_cutoff)
                    cal_counts = Counter(y(recalibration))
                    if len(available) - previous_seen >= 50 and valid(refit):
                        if (
                            family == "B0"
                            or len(recalibration) >= 100
                            and min(cal_counts[0], cal_counts[1]) >= 20
                        ):
                            estimator, calibrator = fitted(
                                family, params, refit, recalibration
                            )
                            fits = refit
                            reference_rate = float(np.mean(y(refit)))
                            previous_seen = len(available)
                            model_cutoff = decision_cutoff
                            status = "REFIT_FROZEN_RECIPE"
                        else:
                            status = "RETAINED_PREVIOUS_INSUFFICIENT_CALIBRATION"
                held = block(number, number, outcome_cutoff)
                p = probabilities(estimator, calibrator, held)
                test_y.extend(y(held))
                test_probability.extend(p.tolist())
                test_reference.extend([reference_rate] * len(held))
                forecast.append(
                    {
                        "month": number,
                        "fit_id": canonical_hash(
                            {
                                "family": family,
                                "config": params,
                                "cutoff": model_cutoff.isoformat(),
                                "sample_hash": canonical_hash(fits),
                            }
                        ),
                        "training_data_cutoff": model_cutoff.isoformat(),
                        "decision_cutoff": decision_cutoff.isoformat(),
                        "outcome_cutoff": outcome_cutoff.isoformat(),
                        "status": status,
                        "training_count": len(fits),
                        "metrics": classification_metrics(y(held), p, threshold),
                    }
                )
            measured = classification_metrics(test_y, test_probability, threshold)
            base = classification_metrics(test_y, test_reference)
            report.update(
                walk_forward=forecast,
                holdout=measured,
                baseline=base,
                quality_passed=bool(
                    len(fits) >= 500
                    and min(Counter(y(fits))[0], Counter(y(fits))[1]) >= 50
                    and min(Counter(test_y)[0], Counter(test_y)[1]) >= 20
                    and calibrator is not None
                    and measured.get("calibration_status") == "PASS"
                    and base.get("brier", 0) > 0
                    and measured["brier"] <= base["brier"] * 0.95
                    and measured["pr_auc"] >= base["pr_auc"]
                ),
            )
            report["quality_scope"] = (
                "FROZEN_RECIPE_WALK_FORWARD; LATEST_ARTIFACT_REQUIRES_ITS_OWN_PROSPECTIVE_PRODUCT_GATE"
            )
            if forecast:
                report["status"] = "EXPERIMENTED"
            # The serving candidate may refit after the last observed season, while every backtest prediction above keeps its own prior cutoff.
            serving_cutoff = model_cutoff
            if closed >= 6:
                decision_cutoff = end_of(closed)
                available = block(1, closed, decision_cutoff)
                refit = block(1, closed - 1, decision_cutoff)
                recalibration = block(closed, closed, decision_cutoff)
                counts = Counter(y(recalibration))
                if (
                    len(available) - previous_seen >= 50
                    and valid(refit)
                    and (
                        family == "B0"
                        or len(recalibration) >= 100
                        and min(counts[0], counts[1]) >= 20
                    )
                ):
                    estimator, calibrator = fitted(family, params, refit, recalibration)
                    serving_cutoff = decision_cutoff
            model_id = str(uuid4())
            artifacts.mkdir(parents=True, exist_ok=True)
            artifact = artifacts / f"{model_id}.joblib"
            temporary = artifact.with_suffix(".pending")
            joblib.dump(
                {
                    "estimator": estimator,
                    "calibrator": calibrator,
                    "target": target,
                    "feature_version": "episode-at-start-v1",
                    "threshold": threshold,
                },
                temporary,
            )
            temporary.replace(artifact)
            report.update(
                model_version=model_id,
                artifact_file=artifact.name,
                artifact_hash=hashlib.sha256(artifact.read_bytes()).hexdigest(),
                serving_data_cutoff=serving_cutoff.isoformat(),
                feature_encoding=estimator.named_steps["features"].manifest()
                if isinstance(estimator, Pipeline)
                else {"method": "EMPIRICAL_RATE"},
            )
            candidate_record = dict(
                id=model_id,
                house_id=house,
                target=target,
                capability=report["capability"],
                status="CANDIDATE",
                payload=report,
            )
        else:
            report["reason"] = "TEMPORAL_BLOCKS_INCOMPLETE_OR_MISSING_CLASS"
        report["temporal_block_manifests"] = {
            key: value["manifest"] for key, value in blocks.items()
        }
    with store.engine.begin() as db:
        if candidate_record is not None:
            db.execute(models.insert().values(**candidate_record))
        db.execute(
            training.insert().values(
                id=run_id,
                house_id=house,
                target=target,
                status=report["status"],
                payload=report,
            )
        )
    return report
