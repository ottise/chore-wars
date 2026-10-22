"""observed_prediction_cache"""

from alembic import op
import sqlalchemy as sa

revision = "bf301aab6012"
down_revision = "b001e42fa973"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "observed_predictions",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("house_id", sa.String(36), nullable=False),
        sa.Column("episode_id", sa.String(36), nullable=False),
        sa.Column("target_version", sa.String(40), nullable=False),
        sa.Column("payload", sa.JSON(), nullable=False),
        sa.UniqueConstraint(
            "house_id",
            "episode_id",
            "target_version",
            name="uq_prediction_episode_target",
        ),
    )
    op.create_index(
        "ix_observed_predictions_house_id", "observed_predictions", ["house_id"]
    )


def downgrade():
    op.drop_table("observed_predictions")
