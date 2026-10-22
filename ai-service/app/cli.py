import argparse
import json
from datetime import datetime, timezone
from pathlib import Path
from uuid import uuid4

from alembic import command
from alembic.config import Config
from sqlalchemy import select

from app.behavior import experience_from_profiles, profiles
from app.config import Settings
from app.demo import aggregate_longitudinal, import_demo
from app.evaluation import persist_comparison
from app.main import create_app
from app.ml import run_experiment
from app.profile_metrics import METRIC_DEFINITIONS, METRIC_VERSION
from app.schemas import Context, Event
from app.storage import EvaluationStore, models


def main():
    parser = argparse.ArgumentParser(
        description="Internal AI operations; never exposed as mobile write routes"
    )
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("migrate")
    commands.add_parser("export-contracts")
    replay = commands.add_parser("replay-failure")
    replay.add_argument("--id", required=True)
    replay.add_argument("--house", required=True)
    ingest = commands.add_parser("import-events")
    ingest.add_argument("--file", type=Path, required=True)
    ingest.add_argument("--house", required=True)
    evaluate = commands.add_parser("evaluate")
    evaluate.add_argument("--context", type=Path, required=True)
    evaluate.add_argument("--job", default=None)
    evaluate.add_argument("--seed", type=int)
    evaluate.add_argument("--scenario", default="manual-context")
    evaluate.add_argument("--mode", choices=["serving", "budget"], default="serving")
    train = commands.add_parser("train")
    train.add_argument("--house", required=True)
    train.add_argument("--target", choices=["T1", "T2"], default="T1")
    status = commands.add_parser("model-status")
    status.add_argument("--house", required=True)
    promote = commands.add_parser("promote")
    promote.add_argument("--house", required=True)
    promote.add_argument("--model", required=True)
    promote.add_argument("--product-run", required=True)
    demo = commands.add_parser("demo-evaluate")
    demo.add_argument("--manifest", type=Path, action="append", required=True)
    demo.add_argument("--mode", choices=["serving", "budget"], default="serving")
    args = parser.parse_args()
    if args.command == "migrate":
        command.upgrade(
            Config(str(Path(__file__).resolve().parents[1] / "alembic.ini")), "head"
        )
        return
    settings = Settings()
    store = EvaluationStore(settings.database_url)
    if args.command == "replay-failure":
        print(json.dumps(store.replay_failure(args.id, args.house)))
    elif args.command == "import-events":
        count = 0
        with args.file.open(encoding="utf-8-sig") as stream:
            for line in stream:
                event = Event.model_validate_json(line)
                if str(event.house_id) != args.house:
                    raise ValueError("Import cannot cross the granted household scope")
                count += int(store.ingest(event))
        print(json.dumps({"new_events": count, "house_id": args.house}))
    elif args.command == "evaluate":
        context = Context.model_validate_json(
            args.context.read_text(encoding="utf-8-sig")
        )
        profile = profiles(
            store.history(
                str(context.house_id), context.as_of, context.source_sequence
            ),
            context.as_of,
        )
        result = persist_comparison(
            store,
            context,
            experience_from_profiles(profile),
            args.job or str(uuid4()),
            args.seed,
            args.scenario,
            None if args.mode == "budget" else settings.optimizer_timeout_seconds,
            settings.optimizer_move_budget,
        )
        print(json.dumps(result))
    elif args.command == "train":
        report = run_experiment(
            store,
            args.house,
            args.target,
            settings.artifacts,
            datetime.now(timezone.utc),
        )
        print(
            json.dumps(
                {k: v for k, v in report.items() if k not in ("artifact_file",)},
                default=str,
            )
        )
    elif args.command == "model-status":
        with store.engine.connect() as db:
            items = [
                {
                    "id": row["id"],
                    "target": row["target"],
                    "capability": row["capability"],
                    "status": row["status"],
                }
                for row in db.execute(
                    select(models).where(models.c.house_id == args.house)
                ).mappings()
            ]
        print(json.dumps({"items": items}))
    elif args.command == "promote":
        promote(store, args.house, args.model, args.product_run, settings.artifacts)
        print(json.dumps({"status": "APPROVED", "model_version": args.model}))
    elif args.command == "demo-evaluate":
        reports = [
            import_demo(
                store,
                path,
                settings.artifacts,
                None if args.mode == "budget" else settings.optimizer_timeout_seconds,
                settings.optimizer_move_budget,
            )
            for path in args.manifest
        ]
        result = aggregate_longitudinal(store, reports)
        print(json.dumps(result, ensure_ascii=False))
    elif args.command == "export-contracts":
        root = Path(__file__).resolve().parents[1] / "contracts"
        root.mkdir(exist_ok=True)
        (root / "openapi.json").write_text(
            json.dumps(create_app(settings).openapi(), ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        (root / "profile-metrics.v1.json").write_text(
            json.dumps(
                {
                    "definition_version": METRIC_VERSION,
                    "coverage_scope": "OBSERVED_TELEMETRY_ONLY",
                    "zero_denominator": "NULL_INSUFFICIENT_DATA",
                    "metrics": {
                        key: {
                            "lineage_group": source,
                            "denominator_field": denominator,
                            "unit": unit,
                        }
                        for key, (
                            source,
                            denominator,
                            unit,
                        ) in METRIC_DEFINITIONS.items()
                    },
                },
                ensure_ascii=False,
                indent=2,
            ),
            encoding="utf-8",
        )


if __name__ == "__main__":
    main()
