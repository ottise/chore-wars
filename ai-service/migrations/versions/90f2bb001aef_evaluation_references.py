"""evaluation_references"""

from alembic import op

revision = "90f2bb001aef"
down_revision = "5a82dc61fbd5"
branch_labels = None
depends_on = None


def upgrade():
    op.create_foreign_key(
        "fk_metrics_run",
        "evaluation_metrics",
        "evaluation_runs",
        ["run_id"],
        ["id"],
        ondelete="RESTRICT",
    )
    op.create_foreign_key(
        "fk_examples_run",
        "evaluation_examples",
        "evaluation_runs",
        ["run_id"],
        ["id"],
        ondelete="RESTRICT",
    )


def downgrade():
    op.drop_constraint("fk_examples_run", "evaluation_examples", type_="foreignkey")
    op.drop_constraint("fk_metrics_run", "evaluation_metrics", type_="foreignkey")
