import hmac
from datetime import datetime, timezone
from typing import Annotated
from uuid import UUID

from fastapi import Depends, FastAPI, Header, HTTPException, Query, Request
from fastapi.responses import JSONResponse
from sqlalchemy import select, text

from app.allocation import optimize
from app.behavior import experience_from_profiles, parse_time, profiles
from app.bounty import BountyInput, suggestions
from app.config import Settings
from app.dataset import build_dataset
from app.evaluation import comparison, persist_comparison
from app.labels import readiness
from app.provider import GeminiClient, ProviderUnavailable
from app.readiness import build_version, schema_status
from app.registry import predict_observed
from app.schemas import (
    Event,
    LanguageInput,
    ObservedRiskInput,
    ProposalInput,
    SwapInput,
    VisionInput,
)
from app.storage import (
    EvaluationStore,
    aggregates,
    canonical_hash,
    events,
    failures,
    learning,
    models,
    training,
)
from app.stream import stream_status
from app.swap import find_swap
from app.urgent import UrgentInput, plan_urgent


def create_app(settings: Settings | None = None) -> FastAPI:
    config = settings or Settings()
    store = EvaluationStore(config.database_url)
    provider = GeminiClient(config)
    api = FastAPI(title="Chore Wars AI", version="1.0.0")
    api.state.store, api.state.config = store, config

    async def scope(
        request: Request,
        x_ai_key: Annotated[str, Header()] = "",
        x_house_id: Annotated[str, Header()] = "",
        x_actor_id: Annotated[str, Header()] = "",
        x_core_sequence: Annotated[int | None, Header(ge=0)] = None,
    ):
        if not hmac.compare_digest(x_ai_key.encode(), config.service_key.get_secret_value().encode()):
            raise HTTPException(401, "Service authentication required")
        try:
            house, actor = UUID(x_house_id), UUID(x_actor_id)
        except ValueError:
            raise HTTPException(403, "Core-issued house/actor scope required")
        route = request.path_params.get("house")
        if route is not None and str(route) != str(house):
            raise HTTPException(403, "House scope mismatch")
        return house, actor, x_core_sequence

    @api.exception_handler(ProviderUnavailable)
    async def provider_error(request, error):
        return JSONResponse(
            status_code=503, content={"code": str(error), "manual_available": True}
        )

    @api.get("/health/live")
    def live():
        return {"status": "live"}

    @api.get("/health/ready")
    def ready():
        status = schema_status(store.engine)
        return JSONResponse(status_code=200 if status["ready"] else 503,
                            content={"status": "ready" if status["ready"] else "not_ready"})

    @api.get("/health/version")
    def version():
        return {"sha": build_version()}

    @api.get("/health/service-auth")
    def service_auth(x_ai_key: Annotated[str, Header()] = ""):
        if not hmac.compare_digest(x_ai_key.encode(), config.service_key.get_secret_value().encode()):
            raise HTTPException(401, "Service authentication required")
        status = schema_status(store.engine)
        return JSONResponse(status_code=200 if status["ready"] else 503, content={
            "authenticated": True, "schema_ready": status["ready"],
            "provider_configured": bool(config.gemini_api_key.get_secret_value()),
            "worker": "unverified", "trainer": "unverified",
        })

    @api.get("/v1/houses/{house}/profiles")
    def get_profiles(
        house: UUID,
        period: str = "all-time",
        season_id: UUID | None = None,
        auth=Depends(scope),
    ):
        history = store.history(str(house), source_sequence=auth[2])
        try:
            result = profiles(
                history, period=period, season_id=str(season_id) if season_id else None
            )
        except ValueError as error:
            raise HTTPException(422, str(error))
        for member in result["items"]:
            if member["member_id"] != str(auth[1]):
                member.pop("preference_profile", None)
        result.update(stream_status(history, auth[2]))
        result["data_status"] = (
            "READY" if result["telemetry_complete"] else "INCOMPLETE_TELEMETRY"
        )
        for member in result["items"]:
            for metric in member["metrics"].values():
                metric["data_status"] = result["data_status"]
                if not result["telemetry_complete"]:
                    metric["status"] = "PROVISIONAL"
        return result

    @api.get("/v1/houses/{house}/learning-status")
    def learning_status(house: UUID, auth=Depends(scope)):
        history = store.history(str(house), source_sequence=auth[2])
        profile = get_profiles(house, auth=auth)
        dataset = build_dataset(history, datetime.now(timezone.utc))
        rows = dataset["rows"]
        with store.engine.connect() as db:
            model_rows = [
                dict(r)
                for r in db.execute(
                    select(
                        models.c.id,
                        models.c.target,
                        models.c.status,
                        models.c.capability,
                    ).where(models.c.house_id == str(house))
                ).mappings()
            ]
            train_rows = [
                dict(r)
                for r in db.execute(
                    select(training.c.id, training.c.target, training.c.status).where(
                        training.c.house_id == str(house)
                    )
                ).mappings()
            ]
        return {
            "valid_event_count": len(history),
            "observed_interaction_count": sum(
                e["event_type"] == "interaction.upsert" for e in history
            ),
            "profile_evidence_count": profile["evidence_count"],
            "profile_version": profile["profile_version"],
            "telemetry_complete": profile["telemetry_complete"],
            "targets": [readiness(rows, "T1"), readiness(rows, "T2")],
            "training_status": "APPROVED_MODEL_AVAILABLE"
            if any(r["status"] == "APPROVED" for r in model_rows)
            else "NO_APPROVED_MODEL",
            "models": model_rows,
            "training_runs": train_rows,
            "interpretation": "More events do not prove better recommendations.",
        }

    @api.get("/v1/houses/{house}/models/status")
    def model_status(house: UUID, auth=Depends(scope)):
        data = learning_status(house, auth)
        return {"items": data["models"], "training_runs": data["training_runs"]}

    @api.get("/v1/houses/{house}/evidence/{event_id}")
    def evidence(house: UUID, event_id: UUID, auth=Depends(scope)):
        with store.engine.connect() as db:
            event = db.execute(
                select(events.c.payload).where(
                    events.c.house_id == str(house), events.c.id == str(event_id)
                )
            ).scalar_one_or_none()
        allowed = {
            "preference": {
                "member_id",
                "template_id",
                "history_template_id",
                "chore_name",
                "type",
                "effective_at",
                "deleted",
            },
            "bounty": {
                "occurrence_id",
                "poster_id",
                "amount",
                "status",
                "created_at",
                "expires_at",
            },
            "proposal": {"actor_id", "type", "status", "requested_at"},
            "payment": {
                "occurrence_id",
                "creditor_id",
                "debtor_id",
                "amount",
                "status",
                "confirmed_by",
                "paid_at",
            },
            "occurrence": {
                "season_id",
                "name",
                "minutes",
                "karma",
                "assigned_to",
                "completed_by",
                "completed_at",
                "due_at",
                "status",
                "template_id",
            },
            "episode": {
                "occurrence_id",
                "member_id",
                "reason",
                "started_at",
                "ended_at",
                "completed_by",
                "deadline",
                "snapshot_id",
            },
            "ledger": {
                "member_id",
                "amount",
                "type",
                "created_at",
                "season_id",
                "reference_id",
            },
            "ranking": {
                "member_id",
                "rank",
                "member_count",
                "total_karma",
                "chores_completed",
                "finalized_at",
                "season_id",
            },
        }
        kind = event["event_type"].removesuffix(".upsert") if event else None
        if not event or kind not in allowed:
            raise HTTPException(404, "Public business evidence not found")
        if kind == "preference" and event["payload"].get("member_id") != str(auth[1]):
            raise HTTPException(404, "Business evidence not found")
        return {
            **{
                k: event[k]
                for k in (
                    "event_id",
                    "entity_id",
                    "event_type",
                    "recorded_at",
                    "house_sequence",
                    "data_source",
                )
            },
            "payload": {
                k: v for k, v in event["payload"].items() if k in allowed[kind]
            },
            "private_source_context": "REDACTED",
        }

    @api.get("/v1/houses/{house}/evaluations/aggregates")
    def aggregate_reports(house: UUID, auth=Depends(scope)):
        with store.engine.connect() as db:
            rows = list(
                db.execute(
                    select(aggregates.c.id, aggregates.c.payload)
                    .where(aggregates.c.house_id == str(house))
                    .limit(50)
                ).mappings()
            )
        return {"items": [dict(row) for row in rows]}

    @api.get("/v1/houses/{house}/learning/timeline")
    def timeline(
        house: UUID, page: Annotated[int, Query(ge=1)] = 1, auth=Depends(scope)
    ):
        with store.engine.connect() as db:
            items = list(
                db.execute(
                    select(learning.c.payload)
                    .where(learning.c.house_id == str(house))
                    .order_by(learning.c.as_of.desc())
                    .offset((page - 1) * 20)
                    .limit(20)
                ).scalars()
            )
        return {"items": items, "page": page, "page_size": 20}

    @api.get("/v1/houses/{house}/learning/training-runs")
    def training_reports(
        house: UUID, page: Annotated[int, Query(ge=1)] = 1, auth=Depends(scope)
    ):
        with store.engine.connect() as db:
            rows = list(
                db.execute(
                    select(training.c.payload)
                    .where(training.c.house_id == str(house))
                    .order_by(training.c.id)
                    .offset((page - 1) * 20)
                    .limit(20)
                ).scalars()
            )
        return {
            "items": [
                {
                    key: row.get(key)
                    for key in (
                        "run_id",
                        "target",
                        "evaluated_at",
                        "status",
                        "family",
                        "model_version",
                        "quality_passed",
                        "product_passed",
                    )
                }
                for row in rows
            ],
            "page": page,
        }

    @api.get("/v1/houses/{house}/learning/training-runs/{run_id}")
    def training_report(house: UUID, run_id: UUID, auth=Depends(scope)):
        with store.engine.connect() as db:
            report = db.execute(
                select(training.c.payload).where(
                    training.c.house_id == str(house), training.c.id == str(run_id)
                )
            ).scalar_one_or_none()
        if report is None:
            raise HTTPException(404, "Training run not found")
        return {key: value for key, value in report.items() if key != "artifact_file"}

    @api.get("/v1/houses/{house}/evaluations/runs")
    def list_runs(
        house: UUID,
        page: Annotated[int, Query(ge=1)] = 1,
        source: str | None = None,
        auth=Depends(scope),
    ):
        return store.list_runs(str(house), page, source)

    @api.get("/v1/houses/{house}/evaluations/runs/{run_id}")
    def run(house: UUID, run_id: UUID, auth=Depends(scope)):
        result = store.get_run(str(house), str(run_id))
        if result is None:
            raise HTTPException(404, "Run not found")
        return result

    @api.get("/v1/houses/{house}/evaluations/runs/{run_id}/examples")
    def run_examples(
        house: UUID,
        run_id: UUID,
        page: Annotated[int, Query(ge=1)] = 1,
        auth=Depends(scope),
    ):
        result = store.run_examples(str(house), str(run_id), page)
        if result is None:
            raise HTTPException(404, "Run not found")
        return result

    @api.get("/v1/houses/{house}/evaluations/comparisons/{group}")
    def compare(house: UUID, group: UUID, auth=Depends(scope)):
        try:
            return comparison(store, str(house), str(group))
        except LookupError:
            raise HTTPException(404, "Comparison not found")

    @api.post("/v1/schedules/propose")
    def propose(request: ProposalInput, auth=Depends(scope)):
        if request.context.house_id != auth[0]:
            raise HTTPException(403, "House scope mismatch")
        if request.context.status != "DRAFT":
            raise HTTPException(409, "Draft context required")
        history = store.history(
            str(auth[0]), request.context.as_of, request.context.source_sequence
        )
        profile = profiles(history, request.context.as_of)
        complete = stream_status(history, request.context.source_sequence)[
            "telemetry_complete"
        ]
        experience = (
            experience_from_profiles(profile)
            if request.history_enabled and complete
            else {}
        )
        # Unbounded benchmark mode is a CLI operation, never exposed through mobile inference.
        if request.mode != "SERVING_DEADLINE":
            raise HTTPException(
                403, "Benchmark mode requires the internal evaluation runner"
            )
        result = optimize(
            request.context,
            experience,
            config.optimizer_move_budget,
            config.optimizer_timeout_seconds,
        )
        result["profile_status"] = (
            "COMPLETE_AT_SOURCE_CUTOFF"
            if complete
            else "INCOMPLETE_TELEMETRY_RULE_FALLBACK"
        )
        return result

    @api.post("/v1/interpret")
    async def interpret(request: LanguageInput, auth=Depends(scope)):
        if request.house_id != auth[0] or request.actor_id != auth[1]:
            raise HTTPException(403, "Actor scope mismatch")
        return await provider.interpret(request)

    @api.post("/v1/bounties/suggestions")
    def bounties(request: BountyInput, auth=Depends(scope)):
        if request.context.house_id != auth[0]:
            raise HTTPException(403, "House scope mismatch")
        try:
            history = store.history(
                str(auth[0]), request.context.as_of, request.context.source_sequence
            )
            return suggestions(
                request,
                auth[1],
                history
                if stream_status(history, request.context.source_sequence)[
                    "telemetry_complete"
                ]
                else [],
            )
        except ValueError as error:
            raise HTTPException(409, str(error))

    @api.post("/v1/urgent/plan")
    async def urgent(request: UrgentInput, auth=Depends(scope)):
        if (
            request.context.house_id != auth[0]
            or auth[1] not in request.participant_ids
        ):
            raise HTTPException(403, "House and participating creator scope required")
        try:
            return plan_urgent(request, await provider.decompose(request))
        except ValueError as error:
            raise HTTPException(422, str(error))

    @api.post("/v1/schedules/replan")
    def replan(request: ProposalInput, auth=Depends(scope)):
        if request.context.house_id != auth[0] or request.context.status != "ACTIVE":
            raise HTTPException(403, "Active house context required")
        history = store.history(
            str(auth[0]), request.context.as_of, request.context.source_sequence
        )
        profile = profiles(history, request.context.as_of)
        complete = stream_status(history, request.context.source_sequence)[
            "telemetry_complete"
        ]
        return optimize(
            request.context,
            experience_from_profiles(profile)
            if request.history_enabled and complete
            else {},
            config.optimizer_move_budget,
            config.optimizer_timeout_seconds,
        )

    @api.post("/v1/schedules/swap")
    def swap(request: SwapInput, auth=Depends(scope)):
        if request.context.house_id != auth[0]:
            raise HTTPException(403, "House scope mismatch")
        try:
            return find_swap(request.context, request.source_occurrence_id, auth[1])
        except ValueError as error:
            raise HTTPException(409, str(error))

    @api.post("/v1/seasons/evolve")
    def evolve(request: ProposalInput, auth=Depends(scope)):
        return propose(request, auth)

    @api.post("/v1/vision/verify-proof")
    async def vision(request: VisionInput, auth=Depends(scope)):
        if request.house_id != auth[0]:
            raise HTTPException(403, "House scope mismatch")
        try:
            return await provider.vision(request)
        except ValueError:
            raise HTTPException(422, "Invalid image")

    @api.post("/v1/predictions/evaluate-batch")
    def predict(request: ObservedRiskInput, auth=Depends(scope)):
        if request.house_id != auth[0]:
            raise HTTPException(403, "House scope mismatch")
        history = store.history(str(auth[0]), source_sequence=auth[2])
        cutoff = datetime.now(timezone.utc)
        dataset = build_dataset(history, cutoff)
        facts_by_episode = {
            f["entity_id"]: f["payload"]
            for f in store.house_facts(str(auth[0]), "episode")
        }
        output = []
        for episode_id in request.episode_ids:
            episode = facts_by_episode.get(str(episode_id))
            if episode is None:
                output.append(
                    {
                        "episode_id": str(episode_id),
                        "status": "WAITING_FOR_TELEMETRY",
                        "p_late": None,
                    }
                )
                continue
            if episode["member_id"] != str(auth[1]):
                raise HTTPException(
                    403, "Only own observed responsibility may be evaluated"
                )

            if episode.get("ended_at") or parse_time(episode["deadline"]) <= cutoff:
                output.append(
                    {
                        "episode_id": str(episode_id),
                        "status": "RETROSPECTIVE_ONLY",
                        "p_late": None,
                    }
                )
                continue
            row = next(
                (r for r in dataset["rows"] if r["episode_id"] == str(episode_id)), None
            )
            if (
                not row
                or not row["features"]
                or not stream_status(history, auth[2])["telemetry_complete"]
            ):
                output.append(
                    {
                        "episode_id": str(episode_id),
                        "status": "INSUFFICIENT_SOURCE_CONTEXT",
                        "p_late": None,
                    }
                )
                continue

            source = next(
                e["data_source"]
                for e in reversed(history)
                if str(e["entity_id"]) == str(episode_id)
            )
            result = predict_observed(
                store, str(auth[0]), row["features"], source, config.artifacts
            )
            value = {
                "episode_id": str(episode_id),
                "occurrence_id": episode["occurrence_id"],
                "member_id": episode["member_id"],
                "snapshot_id": episode.get("snapshot_id"),
                "logical_prediction_time": episode["started_at"],
                "executed_at": cutoff.isoformat(),
                **result,
            }
            output.append(
                store.remember_prediction(str(auth[0]), str(episode_id), value)
            )
        return {
            "items": output,
            "push_notifications": False,
            "capability": "OBSERVED_RESPONSIBILITY_ONLY",
            "interpretation": "Estimates use the original responsibility context. No penalties or reassignment are automatic.",
        }

    @api.post("/internal/events")
    def import_events(request: list[Event], auth=Depends(scope)):
        if len(request) > 500 or any(e.house_id != auth[0] for e in request):
            raise HTTPException(403, "Batch exceeds granted house scope")
        try:
            return {"new_events": sum(int(store.ingest(e)) for e in request)}
        except ValueError:
            raise HTTPException(409, "Event identity conflict")

    @api.post("/internal/evaluations")
    def evaluate(request: ProposalInput, auth=Depends(scope)):
        if request.context.house_id != auth[0]:
            raise HTTPException(403, "House scope mismatch")

        profile = profiles(
            store.history(
                str(auth[0]), request.context.as_of, request.context.source_sequence
            ),
            request.context.as_of,
        )
        return persist_comparison(
            store,
            request.context,
            experience_from_profiles(profile),
            canonical_hash(request.model_dump(mode="json")),
            None,
            "core-snapshot",
            config.optimizer_timeout_seconds,
            config.optimizer_move_budget,
        )

    @api.get("/v1/houses/{house}/failures")
    def failed(house: UUID, page: Annotated[int, Query(ge=1)] = 1, auth=Depends(scope)):
        with store.engine.connect() as db:
            rows = db.execute(
                select(
                    failures.c.id,
                    failures.c.status,
                    failures.c.error_code,
                    failures.c.replay_count,
                )
                .where(failures.c.house_id == str(house))
                .order_by(failures.c.id)
                .offset((page - 1) * 100)
                .limit(100)
            ).mappings()
            return {"items": [dict(r) for r in rows], "page": page, "page_size": 100}

    return api
