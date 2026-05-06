"""Add topic_summary column to user_conversation table.

This column was added in lightspeed-stack v0.3.0.

Revision ID: 001
Create Date: 2025-02-23
"""

from alembic import op

revision = "001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        'ALTER TABLE "lightspeed-stack"."user_conversation" '
        "ADD COLUMN IF NOT EXISTS topic_summary text"
    )


def downgrade() -> None:
    op.execute(
        'ALTER TABLE "lightspeed-stack"."user_conversation" '
        "DROP COLUMN IF EXISTS topic_summary"
    )
