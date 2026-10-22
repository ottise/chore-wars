"""house_sequence_integrity"""

from alembic import op

revision = "b001e42fa973"
down_revision = "a10de0002341"
branch_labels = None
depends_on = None


def upgrade():
    op.create_unique_constraint(
        "uq_inbox_house_sequence", "event_inbox", ["house_id", "sequence"]
    )


def downgrade():
    op.drop_constraint("uq_inbox_house_sequence", "event_inbox", type_="unique")
