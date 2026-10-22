import json
from pathlib import Path
from uuid import NAMESPACE_URL, uuid4, uuid5

import numpy as np

from app.allocation import POLICY_VERSION
from app.behavior import experience_from_profiles, profiles
from app.evaluation import comparison, persist_comparison
from app.ml import run_experiment
from app.schemas import Context, Event
from app.storage import EvaluationStore, aggregates, canonical_hash
from app.stream import stream_status


def child_path(root: Path, name: str) -> Path:
    resolved = (root / name).resolve()
    if not resolved.is_relative_to(root.resolve()):
        raise ValueError("Manifest paths must stay inside their export directory")
    return resolved


def import_demo(
    store: EvaluationStore,
    manifest_file: Path,
    artifacts: Path,
    timeout: float | None = 4,
    move_budget: int = 10000,
) -> dict:
    manifest = json.loads(manifest_file.read_text(encoding="utf-8-sig"))
    root = manifest_file.parent
    if manifest.get("data_source") != "DEMO_SYNTHETIC" or not manifest.get(
        "database", ""
    ).startswith("cw_ai_demo_"):
        raise ValueError(
            "Only explicit disposable core business-service exports are accepted"
        )
    house = manifest["house_id"]
    cutoff = None
    count = 0
    with child_path(root, manifest["events"]).open(encoding="utf-8-sig") as stream:
        for line in stream:
            event = Event.model_validate_json(line)
            if str(event.house_id) != house or event.data_source != "DEMO_SYNTHETIC":
                raise ValueError("Export crosses household or real/synthetic boundary")
            count += int(store.ingest(event))
            cutoff = max(cutoff or event.recorded_at, event.recorded_at)
    history = store.history(house)
    if not stream_status(history)["telemetry_complete"] or cutoff is None:
        raise ValueError("Source stream is incomplete; do not evaluate or train it")
    output = {
        "house_id": house,
        "seed": manifest["seed"],
        "scenario_id": manifest["scenario_id"],
        "data_source": "DEMO_SYNTHETIC",
        "mode": "SERVING_DEADLINE" if timeout is not None else "BUDGET_COMPLETE",
        "new_events": count,
        "comparisons": [],
        "actual_outcome_policy": "CORE_BASELINE_ONLY",
        "counterfactual_outcomes": "NOT_OBSERVED",
    }
    for month, name in enumerate(manifest["contexts"], 1):
        context = Context.model_validate_json(
            child_path(root, name).read_text(encoding="utf-8-sig")
        )
        if str(context.house_id) != house or context.data_source != "DEMO_SYNTHETIC":
            raise ValueError("Context does not belong to this demo export")
        observed = store.history(house, context.as_of, context.source_sequence)
        if not stream_status(observed, context.source_sequence)["telemetry_complete"]:
            raise ValueError(
                "Historical context is not fully reconstructed at source cutoff"
            )
        profile = profiles(observed, context.as_of)
        identity = canonical_hash(
            {
                "house": house,
                "month": month,
                "context": context.model_dump(mode="json"),
                "mode": output["mode"],
                "move_budget": move_budget,
                "policy_version": POLICY_VERSION,
            }
        )
        result = persist_comparison(
            store,
            context,
            experience_from_profiles(profile),
            identity,
            manifest["seed"],
            manifest["scenario_id"],
            timeout,
            move_budget,
        )
        output["comparisons"].append({"month": month, **result})
        print(
            json.dumps(
                {
                    "phase": "POLICY_EVALUATION",
                    "seed": manifest["seed"],
                    "month": month,
                    "comparison_group_id": result["comparison_group_id"],
                }
            ),
            flush=True,
        )
    output["experiments"] = {}
    for target in ("T1", "T2"):
        run_id = str(
            uuid5(
                NAMESPACE_URL,
                f"{house}/{canonical_hash(history)}/{target}/experiment-v1",
            )
        )
        report = run_experiment(store, house, target, artifacts, cutoff, run_id)
        output["experiments"][target] = {
            "run_id": report["run_id"],
            "status": report["status"],
            "family": report.get("family"),
            "model_version": report.get("model_version"),
            "quality_passed": report.get("quality_passed", False),
            "product_passed": False,
        }
    output["manifest_hash"] = canonical_hash(manifest)
    child_path(root, f"evaluation-{output['mode'].lower()}.json").write_text(
        json.dumps(output, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    return output


def aggregate_longitudinal(
    store: EvaluationStore, reports: list[dict], bootstrap_seed: int = 42
) -> dict:
    expected = set(range(42, 62))
    seen = set()
    cohort = []
    issues = []
    metadata = []
    for report in reports:
        seed = report["seed"]
        if seed in seen:
            raise ValueError("Do not pool histories or duplicate an independent seed")
        seen.add(seed)
        monthly = []
        selected = [r for r in report["comparisons"] if 6 <= r["month"] <= 14]
        if {r["month"] for r in selected} != set(range(6, 15)):
            issues.append({"seed": seed, "reason": "INCOMPLETE_FROZEN_MONTHS_6_TO_14"})
            continue
        for row in selected:
            measured = comparison(store, report["house_id"], row["comparison_group_id"])
            if measured["status"] != "COMPARABLE":
                raise ValueError("All monthly B0/S0/H1 comparisons must match")
            monthly.append(measured)
            metadata.extend(r["metadata"] for r in measured["runs"])
        seed_metrics = {}
        for metric in monthly[0]["deltas"]:
            seed_metrics[metric] = {
                component: float(
                    np.mean([m["deltas"][metric][component] for m in monthly])
                )
                for component in ("search", "history", "total")
            }
        cohort.append(
            {"seed": seed, "house_id": report["house_id"], "metrics": seed_metrics}
        )
    for key in (
        "data_source",
        "scenario_id",
        "evaluation_mode",
        "metric_definition_version",
        "policy_version",
    ):
        if len({m.get(key) for m in metadata}) > 1:
            raise ValueError(
                "Incompatible evaluation specifications cannot be aggregated"
            )
    complete = seen == expected and len(cohort) == 20 and not issues
    rng = np.random.default_rng(bootstrap_seed)
    metrics = {}
    if cohort:
        for metric in cohort[0]["metrics"]:
            metrics[metric] = {}
            for component in ("search", "history", "total"):
                values = np.array([r["metrics"][metric][component] for r in cohort])
                sample = (
                    rng.choice(values, (10000, len(cohort)), replace=True).mean(axis=1)
                    if complete
                    else None
                )
                metrics[metric][component] = {
                    "mean": float(values.mean()),
                    "min": float(values.min()),
                    "max": float(values.max()),
                    "ci95": np.quantile(sample, [0.025, 0.975]).tolist()
                    if sample is not None
                    else None,
                    "seed_count": len(values),
                }
    result = {
        "id": str(uuid4()),
        "version": "monthly-paired-seeds-v1",
        "status": "COMPLETE" if complete else "PARTIAL",
        "expected_seeds": sorted(expected),
        "present_seeds": sorted(seen),
        "missing_seeds": sorted(expected - seen),
        "issues": issues,
        "eligible_seed_count": len(cohort),
        "frozen_months": [6, 14],
        "summary_unit": "MEAN_MONTHLY_METRIC_DELTA_PER_INDEPENDENT_SEED",
        "bootstrap_seed": bootstrap_seed,
        "bootstrap_samples": 10000,
        "metrics": metrics,
        "data_source": "DEMO_SYNTHETIC",
        "outcome_improvement_acceptance": "NOT_EVALUATED_COUNTERFACTUAL_OUTCOMES_NOT_OBSERVED",
        "claim": "This report separates search and historical increments in schedules. It does not establish a reduction in late completion or adjustment requests.",
    }
    with store.engine.begin() as db:
        for house in {r["house_id"] for r in reports}:
            db.execute(
                aggregates.insert().values(
                    id=str(uuid4()), house_id=house, payload=result
                )
            )
    return result
