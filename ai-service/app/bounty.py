from uuid import UUID

from pydantic import AwareDatetime, Field

from app.allocation import find_start, preference
from app.behavior import experience_from_profiles, profiles
from app.schemas import Context, Contract


class Offer(Contract):
    id: UUID
    occurrence_id: UUID
    amount: float = Field(gt=0)
    expires_at: AwareDatetime


class BountyInput(Contract):
    context: Context
    offers: list[Offer] = Field(max_length=2000)


def suggestions(request: BountyInput, actor: UUID, history: list[dict]) -> dict:
    context = request.context
    member = next((m for m in context.members if m.id == actor), None)
    if member is None or context.status != "ACTIVE":
        raise ValueError("Active member and season required")
    experience = experience_from_profiles(profiles(history, context.as_of))
    tasks = {t.id: t for t in context.tasks}
    result = []
    for offer in request.offers:
        task = tasks.get(offer.occurrence_id)
        if (
            not task
            or task.assigned_to == actor
            or offer.expires_at <= context.as_of
            or task.due_at <= context.as_of
        ):
            continue
        start = find_start(task, member, context.tasks, context.as_of)
        if start is None:
            continue
        fit = preference(task, member)
        known = experience.get(
            f"{actor}:{task.history_template_id or task.template_id}", 0
        )
        result.append(
            {
                "bounty_id": str(offer.id),
                "occurrence_id": str(task.id),
                "name": task.name,
                "amount": offer.amount,
                "expires_at": offer.expires_at.isoformat(),
                "possible_start": start.isoformat(),
                "declared_preference": {
                    1: "DISLIKED",
                    0: "UNSPECIFIED",
                    -1: "PREFERRED",
                }[fit],
                "historical_completions_capped": known,
                "reason": "DECLARED_PREFERENCE"
                if fit == -1
                else ("PRIOR_EXPERIENCE" if known else "AVAILABLE_CAPACITY"),
                "sort_key": (fit, -known, str(offer.id)),
            }
        )
    result.sort(key=lambda r: r["sort_key"])
    for row in result:
        del row["sort_key"]
    return {
        "items": result[:10],
        "inference_source": "PROFILE_AND_DECLARED_RULES",
        "push_notifications": False,
        "acceptance_probability": None,
        "claim": "Voluntary suggestions do not increase assigned quota. Core acceptance validates current state.",
    }
