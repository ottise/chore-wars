import time
from uuid import uuid4

from app.allocation import METRIC_VERSION, POLICY_VERSION, baseline, measure, optimize
from app.learning import snapshot_learning
from app.schemas import Context
from app.storage import EvaluationStore, canonical_hash
from app.stream import stream_status


def persist_comparison(
    store: EvaluationStore,
    context: Context,
    experience: dict,
    job: str,
    seed: int | None,
    scenario: str,
    timeout: float | None = 4,
    move_budget: int = 10000,
) -> dict:
    group = str(uuid4())
    data = context.model_dump(mode="json")
    telemetry = stream_status(
        store.history(str(context.house_id), context.as_of, context.source_sequence),
        context.source_sequence,
    )
    snapshot = snapshot_learning(
        store, str(context.house_id), context.as_of, context.source_sequence
    )
    job = canonical_hash(
        {
            "request_job": job,
            "policy_version": POLICY_VERSION,
            "metric_version": METRIC_VERSION,
            "profile_version": snapshot["profile_version"],
            "move_budget": move_budget,
            "timeout": timeout,
        }
    )
    if not telemetry["telemetry_complete"]:
        experience = {}
    started = time.monotonic()
    initial = baseline(context)
    baseline_duration = (time.monotonic() - started) * 1000
    arms = {
        "B0": {
            "tasks": [t.model_dump(mode="json") for t in initial],
            "metrics": measure(context, initial),
            "reason": "BASELINE",
            "moves": 0,
            "duration_ms": round(baseline_duration, 2),
        },
        "S0": optimize(context, {}, move_budget, timeout),
        "H1": optimize(context, experience, move_budget, timeout),
    }
    ids = {}
    for arm, result in arms.items():
        meta = {
            "data_source": context.data_source,
            "inference_source": "PROFILE" if arm == "H1" else "RULE",
            "policy_version": POLICY_VERSION,
            "model_version": None,
            "data_cutoff": context.as_of.isoformat(),
            "outcome_cutoff": None,
            "evaluation_period": context.season_id.hex,
            "dataset_version": canonical_hash(data),
            "context_hash": canonical_hash(data),
            "profile_version": snapshot["profile_version"] if arm == "H1" else None,
            "experience_hash": canonical_hash(experience) if arm == "H1" else None,
            "learning_snapshot_id": snapshot["id"],
            "history_enabled": arm == "H1",
            "scenario_id": scenario,
            "seed": seed,
            "metric_definition_version": METRIC_VERSION,
            "source_sequence": context.source_sequence,
            "telemetry": telemetry,
            "run_kind": "POLICY",
            "evaluation_mode": "SERVING_DEADLINE"
            if timeout is not None
            else "BUDGET_COMPLETE",
            "move_budget": move_budget,
            "reason": result["reason"],
            "moves": result["moves"],
            "duration_ms": result["duration_ms"],
            "outcome_metrics_status": "NOT_OBSERVED",
            "constraint_scope": result.get(
                "constraint_scope",
                "ENTIRE_DRAFT"
                if context.status == "DRAFT"
                else "EDITABLE_FUTURE_WITH_FIXED_HISTORY_AND_BOOKINGS",
            ),
            "duration_scope": "OPTIMIZER_ONLY; EXCLUDES_CORE_HTTP_AND_PROFILE_RECONSTRUCTION",
            "fairness_cohort": "ACTIVE_MEMBERS_IN_FROZEN_CONTEXT; FIXED_HISTORICAL_ASSIGNMENTS_RETAINED",
        }
        measured = result["metrics"]
        rates = {
            "coverage": (measured["coverage_count"], len(context.tasks)),
            "declared_preference_alignment": (
                measured["preferred_count"],
                measured["preference_eligible_count"],
            ),
            "rotation_repeat_rate": (
                measured["rotation_repeat_count"],
                measured["rotation_eligible_count"],
            ),
        }
        values = {
            k: {
                "value": v,
                "definition_version": METRIC_VERSION,
                "numerator": rates.get(k, (v, None))[0],
                "denominator": rates.get(k, (None, None))[1],
                "cohort": "FROZEN_CONTEXT",
                "observation_window": context.season_id.hex,
                "exclusions": 0,
                "status": "VALID" if v is not None else "NOT_APPLICABLE",
            }
            for k, v in result["metrics"].items()
        }
        meta["acceptance"] = {
            "status": "BASELINE_REFERENCE"
            if arm == "B0"
            else (
                "MATERIAL_SCHEDULE_IMPROVEMENT"
                if result.get("accepted")
                else "BASELINE_RETAINED"
            ),
            "reason": result["reason"],
            "outcome_gate": "NOT_EVALUATED",
            "learning_gain_gate": "REQUIRES_H1_VS_S0_PAIRED_EVIDENCE",
        }
        sample = [
            {
                "before": data["tasks"],
                "after": result["tasks"],
                "reason": result["reason"],
                "context_hash": meta["context_hash"],
            }
        ]
        ids[arm] = store.save_run(
            str(context.house_id), group, job, arm, meta, values, sample
        )
    # Idempotent reruns retrieve the original group instead of returning an unused UUID.
    group = store.get_run(str(context.house_id), ids["B0"])["group_id"]
    return {"comparison_group_id": group, "runs": ids}


def comparison(store: EvaluationStore, house: str, group: str) -> dict:
    rows = store.group_runs(house, group)
    if not rows:
        raise LookupError("Comparison not found")
    required = (
        "data_source",
        "context_hash",
        "scenario_id",
        "seed",
        "metric_definition_version",
        "evaluation_mode",
    )
    if any(
        any(row["metadata"].get(k) != rows[0]["metadata"].get(k) for k in required)
        for row in rows
    ):
        return {
            "status": "INCOMPARABLE",
            "reason": "CONTEXT_OR_METRIC_MISMATCH",
            "runs": rows,
        }
    arms = {r["arm"]: r for r in rows}
    if not all(k in arms for k in ("B0", "S0", "H1")):
        return {"status": "PARTIAL", "runs": rows}
    deltas = {}
    for key in arms["B0"]["metrics"]:
        b, s, h = [
            arms[a]["metrics"].get(key, {}).get("value") for a in ("B0", "S0", "H1")
        ]
        if all(isinstance(v, (int, float)) for v in (b, s, h)):
            deltas[key] = {
                "search": s - b,
                "history": h - s,
                "total": h - b,
                "relative_total": (h - b) / b if b else None,
            }
    return {
        "status": "COMPARABLE",
        "comparison_group_id": group,
        "runs": rows,
        "deltas": deltas,
        "confidence_interval": None,
        "confidence_interval_status": "SINGLE_SEED_NO_AGGREGATE",
        "claim": "Search gain does not establish historical learning gain; no completion outcomes are fabricated.",
    }
