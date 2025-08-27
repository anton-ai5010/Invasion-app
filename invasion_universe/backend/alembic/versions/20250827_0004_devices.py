from __future__ import annotations
from alembic import op
import sqlalchemy as sa

revision = "20250827_0004"
down_revision = "20250827_0003"
branch_labels = None
depends_on = None

def upgrade() -> None:
    op.create_table(
        "devices",
        sa.Column("id", sa.BigInteger, primary_key=True),
        sa.Column("user_id", sa.BigInteger, nullable=False, index=True),
        sa.Column("platform", sa.String(16), nullable=False),
        sa.Column("token", sa.String(512), nullable=False, unique=True),
        sa.Column("locale", sa.String(8), nullable=False, server_default="ru"),
        sa.Column("app_version", sa.String(32), nullable=False, server_default="dev"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("last_seen_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("badge", sa.Integer, nullable=False, server_default="0")
    )
    op.create_index("ix_devices_user", "devices", ["user_id"])

def downgrade() -> None:
    op.drop_index("ix_devices_user", table_name="devices")
    op.drop_table("devices")