"""Add topic_summary column to user_conversation table.

This column was added in lightspeed-stack v0.3.0.

Revision ID: 001
Create Date: 2025-02-23
"""

from alembic import op
from sqlalchemy import text

revision = "001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    conn = op.get_bind()
    result = conn.execute(
        text(
            "SELECT EXISTS (SELECT 1 FROM information_schema.tables "
            "WHERE table_schema = 'lightspeed-stack' AND table_name = 'user_conversation')"
        )
    )
    if result.scalar():
        op.execute(
            text(
                'ALTER TABLE "lightspeed-stack"."user_conversation" '
                "ADD COLUMN IF NOT EXISTS topic_summary text"
            )
        )


def downgrade() -> None:
    op.execute(
        'ALTER TABLE "lightspeed-stack"."user_conversation" '
        "DROP COLUMN IF EXISTS topic_summary"
    )
