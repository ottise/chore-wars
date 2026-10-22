"""season_training_jobs"""

from alembic import op
import sqlalchemy as sa

revision = "a10de0002341"
down_revision = "90f2bb001aef"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "training_jobs",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("house_id", sa.String(36), nullable=False),
        sa.Column(
            "source_event_id",
            sa.String(36),
            sa.ForeignKey("event_inbox.id", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column("target", sa.String(20), nullable=False),
        sa.Column("status", sa.String(32), nullable=False),
        sa.Column("cutoff", sa.DateTime(timezone=True), nullable=False),
        sa.Column("lease_until", sa.DateTime(timezone=True)),
        sa.Column("attempts", sa.Integer(), nullable=False),
        sa.Column("error_code", sa.String(80)),
        sa.UniqueConstraint(
            "source_event_id", "target", name="uq_training_source_target"
        ),
    )
    op.create_index("ix_training_jobs_house_id", "training_jobs", ["house_id"])


def downgrade():
    op.drop_table("training_jobs")
