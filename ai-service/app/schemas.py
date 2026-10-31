from datetime import date
from enum import StrEnum
from typing import Annotated, Any, Literal
from uuid import UUID

from pydantic import AwareDatetime, BaseModel, ConfigDict, Field, model_validator
from app.supplies import SupplyCatalogItem, SupplyCandidate


URGENT_MAX_MINUTES = 48 * 60


class Contract(BaseModel):
    model_config = ConfigDict(extra="forbid")


class DataSource(StrEnum):
    REAL = "REAL"
    DEMO_SYNTHETIC = "DEMO_SYNTHETIC"


class Window(Contract):
    start: Annotated[int, Field(ge=0, le=1439)]
    end: Annotated[int, Field(ge=1, le=1440)]

    @model_validator(mode="after")
    def ordered(self):
        if self.start >= self.end:
            raise ValueError("Window must have positive length")
        return self


class Availability(Contract):
    day: Annotated[int, Field(ge=0, le=6)]
    available: bool
    slots: list[Window] = Field(default_factory=list, max_length=24)


class Member(Contract):
    id: UUID
    name: str = ""
    max_chores_per_week: Annotated[int, Field(ge=0, le=1000)] = 20
    max_minutes_per_day: Annotated[int, Field(ge=0, le=1440)] = 120
    availability: list[Availability] = Field(default_factory=list, max_length=7)
    date_exceptions: dict[str, list[Window]] = Field(default_factory=dict)
    preferences: dict[str, Literal["PREFERRED", "DISLIKED"]] = Field(
        default_factory=dict
    )

    @model_validator(mode="after")
    def unique_days(self):
        if len({a.day for a in self.availability}) != len(self.availability):
            raise ValueError("Duplicate availability day")
        return self


class Task(Contract):
    id: UUID
    template_id: UUID
    history_template_id: UUID | None = None
    name: str = ""
    due_at: AwareDatetime
    minutes: Annotated[int, Field(ge=1, le=1440)]
    karma: Annotated[int, Field(ge=0, le=100000)]
    assigned_to: UUID | None = None
    start_at: AwareDatetime | None = None
    locked: bool = False
    category: str | None = None
    status: Literal[
        "ASSIGNED", "COMPLETED", "OVERDUE", "CRITICAL_OVERDUE", "SKIPPED"
    ] = "ASSIGNED"


class Context(Contract):
    house_id: UUID
    owner_id: UUID | None = None
    season_id: UUID
    revision: int
    source_sequence: int | None = Field(default=None, ge=0)
    constraint_task_ids: list[UUID] = Field(default_factory=list, max_length=2000)
    status: Literal["DRAFT", "ACTIVE", "COMPLETED"]
    as_of: AwareDatetime
    data_source: DataSource = DataSource.REAL
    members: list[Member] = Field(max_length=50)
    tasks: list[Task] = Field(max_length=2000)

    @model_validator(mode="after")
    def unique_resources(self):
        if len({m.id for m in self.members}) != len(self.members) or len(
            {t.id for t in self.tasks}
        ) != len(self.tasks):
            raise ValueError("Duplicate resource ID")
        if any(
            t.assigned_to
            and t.assigned_to not in {m.id for m in self.members}
            and not (
                self.status != "DRAFT"
                and t.locked
                and (t.status in ("COMPLETED", "SKIPPED") or t.due_at <= self.as_of)
            )
            for t in self.tasks
        ):
            raise ValueError("Assignment references an inactive member")
        return self


class Event(Contract):
    event_id: UUID
    schema_version: Literal[1] = 1
    house_id: UUID
    house_sequence: Annotated[int, Field(ge=1)]
    capture_batch_id: UUID | None = None
    batch_last_sequence: int | None = Field(default=None, ge=1)
    event_type: str = Field(min_length=1, max_length=80)
    entity_id: UUID
    occurred_at: AwareDatetime
    recorded_at: AwareDatetime
    data_source: DataSource = DataSource.REAL
    payload: dict[str, Any]


class ProposalInput(Contract):
    context: Context
    history_enabled: bool = True
    mode: Literal["SERVING_DEADLINE", "BUDGET_COMPLETE"] = "SERVING_DEADLINE"


class SwapInput(ProposalInput):
    source_occurrence_id: UUID | None = None
    target_member_id: UUID | None = None


class LanguageInput(Contract):
    house_id: UUID
    actor_id: UUID
    text: str = Field(min_length=1, max_length=8000)
    now: AwareDatetime
    member_names: dict[str, str] = Field(default_factory=dict)
    chore_names: dict[str, str] = Field(default_factory=dict)
    occurrence_names: dict[str, str] = Field(default_factory=dict)
    supply_catalog: dict[str, SupplyCatalogItem] = Field(default_factory=dict)
    consent_version: str
    purpose: Literal["interpret", "chat", "urgent"] = "interpret"


class AvailabilityCandidate(Contract):
    kind: Literal["BUSY", "FREE"]
    local_date: date | None = None
    start_minute: int | None = Field(default=None, ge=0, le=1439)
    end_minute: int | None = Field(default=None, ge=1, le=1440)

    @model_validator(mode="after")
    def valid_interval(self):
        if (
            self.start_minute is not None
            and self.end_minute is not None
            and self.start_minute >= self.end_minute
        ):
            raise ValueError("Availability interval must have positive length")
        return self


class UrgentCandidate(Contract):
    deadline_minutes: int | None = Field(default=None, ge=1, le=URGENT_MAX_MINUTES)
    ready_by: AwareDatetime | None = None
    guest_count: int | None = Field(default=None, ge=1, le=10000)
    participant_ids: list[UUID] = Field(default_factory=list, max_length=50)
    resources: list[str] = Field(default_factory=list, max_length=30)


class LanguageResult(Contract):
    intent: Literal[
        "availability",
        "create_chore",
        "allocate",
        "swap",
        "replan",
        "evolve",
        "urgent",
        "supply_purchase",
        "supply_reminder",
        "help",
        "unknown",
    ]
    summary: str = Field(max_length=1500)
    entities: dict[str, str] = Field(default_factory=dict)
    missing_fields: list[str] = Field(default_factory=list)
    evidence_quotes: list[str] = Field(default_factory=list)
    requires_confirmation: Literal[True] = True
    availability: AvailabilityCandidate | None = None
    urgent: UrgentCandidate | None = None
    supply: SupplyCandidate | None = None


class VisionInput(Contract):
    house_id: UUID
    evidence_id: UUID
    chore: str = Field(max_length=1000)
    mime_type: Literal["image/jpeg", "image/png", "image/webp"]
    image_base64: str = Field(max_length=8_000_000)


class VisionResult(Contract):
    result: Literal["RELEVANT", "NOT_RELEVANT", "UNCERTAIN"]
    observations: list[str]
    limitations: list[str]
    can_complete_automatically: Literal[False] = False


class ObservedRiskInput(Contract):
    house_id: UUID
    episode_ids: list[UUID] = Field(min_length=1, max_length=100)
