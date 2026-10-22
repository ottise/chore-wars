from datetime import timedelta
from uuid import NAMESPACE_URL, UUID, uuid5

from pydantic import Field

from app.allocation import find_start
from app.schemas import Context, Contract, Task


class MicroTask(Contract):
    key: str = Field(min_length=1, max_length=40)
    name: str = Field(min_length=1, max_length=100)
    description: str = Field(max_length=500)
    difficulty: str = Field(pattern="^(EASY|MEDIUM|HARD)$")
    dependencies: list[str] = Field(default_factory=list, max_length=20)
    resources: list[str] = Field(default_factory=list, max_length=10)


class Decomposition(Contract):
    chores: list[MicroTask] = Field(min_length=1, max_length=20)
    missing_fields: list[str] = Field(default_factory=list)
    limitations: list[str] = Field(default_factory=list)


class UrgentInput(Contract):
    context: Context
    text: str = Field(min_length=1, max_length=8000)
    deadline_minutes: int = Field(ge=1, le=1440)
    participant_ids: list[UUID] = Field(min_length=1, max_length=50)
    resources: list[str] = Field(default_factory=list, max_length=30)


def plan_urgent(request: UrgentInput, decomposition: Decomposition) -> dict:
    context = request.context
    if context.status != "ACTIVE":
        raise ValueError("Active season required")
    if decomposition.missing_fields:
        return {
            "status": "NEEDS_CLARIFICATION",
            "missing_fields": decomposition.missing_fields,
            "limitations": decomposition.limitations,
        }
    chores = {t.key: t for t in decomposition.chores}
    if len(chores) != len(decomposition.chores) or any(
        d not in chores or d == t.key for t in chores.values() for d in t.dependencies
    ):
        raise ValueError("Invalid dependency references")
    if any(r not in request.resources for t in chores.values() for r in t.resources):
        raise ValueError("Unconfirmed resources cannot be assumed")
    members = {m.id: m for m in context.members if m.id in request.participant_ids}
    if set(members) != set(request.participant_ids):
        raise ValueError("Only active participants are allowed")
    deadline = context.as_of + timedelta(minutes=request.deadline_minutes)
    waiting = set(chores)
    scheduled = {}
    tasks = list(context.tasks)
    resource_until = {}
    loads = {m: 0 for m in members}
    while waiting:
        ready = sorted(
            k for k in waiting if all(d in scheduled for d in chores[k].dependencies)
        )
        if not ready:
            return {
                "status": "INFEASIBLE",
                "reason": "DEPENDENCY_CYCLE_OR_BLOCKED",
                "unplaced": sorted(waiting),
                "tasks": list(scheduled.values()),
            }
        for key in ready:
            item = chores[key]
            minutes = {"EASY": 15, "MEDIUM": 30, "HARD": 45}[item.difficulty]
            earliest = max(
                [context.as_of]
                + [scheduled[d]["end_at"] for d in item.dependencies]
                + [resource_until.get(r, context.as_of) for r in item.resources]
            )
            identity = uuid5(
                NAMESPACE_URL,
                f"{context.house_id}/{context.season_id}/urgent/{context.as_of.isoformat()}/{key}",
            )
            options = []
            for actor, member in sorted(members.items(), key=lambda pair: str(pair[0])):
                candidate = Task(
                    id=identity,
                    template_id=identity,
                    name=item.name,
                    minutes=minutes,
                    karma=0,
                    due_at=deadline,
                    assigned_to=actor,
                )
                start = find_start(candidate, member, tasks, earliest)
                if start is not None:
                    options.append((start, loads[actor], str(actor), candidate))
            waiting.remove(key)
            if not options:
                return {
                    "status": "INFEASIBLE",
                    "reason": "CAPACITY_RESOURCE_OR_DEADLINE",
                    "unplaced": [key, *sorted(waiting)],
                    "tasks": list(scheduled.values()),
                }
            start, _, _, candidate = min(options, key=lambda row: row[:3])
            candidate.start_at = start
            tasks.append(candidate)
            end = start + timedelta(minutes=minutes)
            loads[candidate.assigned_to] += minutes
            scheduled[key] = {
                "key": key,
                "name": item.name,
                "description": item.description,
                "difficulty": item.difficulty,
                "assigned_to": str(candidate.assigned_to),
                "start_at": start,
                "end_at": end,
                "minutes": minutes,
                "dependencies": item.dependencies,
                "resources": item.resources,
            }
            for resource in item.resources:
                resource_until[resource] = end
    timeline = list(scheduled.values())
    return {
        "status": "READY",
        "tasks": timeline,
        "deadline_at": deadline,
        "limitations": decomposition.limitations,
        "duration_source": "STANDARD_EFFORT_ESTIMATE",
        "requires_confirmation": True,
        "urgent_payload": {
            "SeasonId": str(context.season_id),
            "DeadlineMinutes": request.deadline_minutes,
            "PlanVersion": "blitz-v1",
            "Chores": [
                {
                    "Name": t["name"],
                    "Description": t["description"],
                    "KarmaPoints": 0,
                    "Difficulty": t["difficulty"],
                    "AssignedUserId": t["assigned_to"],
                    "PlanKey": t["key"],
                    "PlannedOffsetMinutes": int(
                        (t["start_at"] - context.as_of).total_seconds() // 60
                    ),
                    "DependsOn": t["dependencies"],
                    "Resources": t["resources"],
                }
                for t in timeline
            ],
        },
    }
