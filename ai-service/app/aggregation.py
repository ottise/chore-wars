from uuid import uuid4

import numpy as np

from app.evaluation import comparison
from app.storage import EvaluationStore, aggregates, canonical_hash


def aggregate_comparisons(
    store: EvaluationStore,
    house_groups: list[tuple[str, str]],
    bootstrap_seed: int = 42,
) -> dict:
    comparisons = [comparison(store, house, group) for house, group in house_groups]
    if not comparisons or any(c["status"] != "COMPARABLE" for c in comparisons):
        raise ValueError("Only complete paired B0/S0/H1 comparisons can be aggregated")
    contexts = [c["runs"][0]["metadata"] for c in comparisons]
    if len({h for h, _ in house_groups}) > 1 and any(
        m.get("data_source") != "DEMO_SYNTHETIC" for m in contexts
    ):
        raise ValueError(
            "Cross-house aggregation is restricted to operator-created synthetic experiments"
        )
    seeds = [m.get("seed") for m in contexts]
    if None in seeds or len(set(seeds)) != len(seeds):
        raise ValueError(
            "One paired comparison per independent seed is required; aggregate months within seed first"
        )
    for key in (
        "data_source",
        "scenario_id",
        "metric_definition_version",
        "evaluation_mode",
        "policy_version",
    ):
        if len({m.get(key) for m in contexts}) != 1:
            raise ValueError("Incompatible evaluation specification")
    rng = np.random.default_rng(bootstrap_seed)
    count = len(comparisons)
    result = {}
    for metric in comparisons[0]["deltas"]:
        result[metric] = {}
        for component in ("search", "history", "total"):
            values = np.array(
                [c["deltas"][metric][component] for c in comparisons], dtype=float
            )
            samples = (
                rng.choice(values, (10000, count), replace=True).mean(axis=1)
                if count >= 20
                else None
            )
            result[metric][component] = {
                "mean": float(values.mean()),
                "min": float(values.min()),
                "max": float(values.max()),
                "seed_count": count,
                "ci95": np.quantile(samples, [0.025, 0.975]).tolist()
                if samples is not None
                else None,
                "status": "PAIRED_SEED_BOOTSTRAP"
                if samples is not None
                else "INSUFFICIENT_INDEPENDENT_SEEDS",
            }
    report = {
        "id": str(uuid4()),
        "data_source": contexts[0]["data_source"],
        "scenario_id": contexts[0]["scenario_id"],
        "comparisons": [{"house_id": h, "group_id": g} for h, g in house_groups],
        "seeds": seeds,
        "seed_count": count,
        "bootstrap_seed": bootstrap_seed,
        "bootstrap_samples": 10000,
        "metrics": result,
        "outcome_status": "NOT_OBSERVED",
        "aggregate_version": "paired-seeds-v1",
        "manifest_hash": canonical_hash(house_groups),
    }
    # Each household can only retrieve its own aggregate reference through the core bridge.
    with store.engine.begin() as db:
        for house, _ in house_groups:
            private_report = {
                **report,
                "comparisons": [
                    r for r in report["comparisons"] if r["house_id"] == house
                ],
            }
            db.execute(
                aggregates.insert().values(
                    id=str(uuid4()), house_id=house, payload=private_report
                )
            )
    return report
