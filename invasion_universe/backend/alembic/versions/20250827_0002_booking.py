from __future__ import annotations
from alembic import op
import sqlalchemy as sa

revision = "20250827_0002"
down_revision = "20250827_0001"
branch_labels = None
depends_on = None

def upgrade() -> None:
    op.create_table(
        "zones",
        sa.Column("id", sa.BigInteger, primary_key=True),
        sa.Column("name", sa.String(120), nullable=False),
        sa.Column("code", sa.String(64), nullable=False, unique=True),
        sa.Column("is_active", sa.Boolean, nullable=False, server_default=sa.text("true"))
    )
    op.create_index("ix_zones_code", "zones", ["code"], unique=True)

    op.create_table(
        "seats",
        sa.Column("id", sa.BigInteger, primary_key=True),
        sa.Column("zone_id", sa.BigInteger, sa.ForeignKey("zones.id", ondelete="CASCADE"), nullable=False, index=True),
        sa.Column("label", sa.String(32), nullable=False, index=True),
        sa.Column("seat_type", sa.String(32), nullable=False, server_default="standard"),
        sa.Column("hourly_price_cents", sa.Integer, nullable=False, server_default="30000"),
        sa.Column("is_active", sa.Boolean, nullable=False, server_default=sa.text("true"))
    )

    op.create_table(
        "bookings",
        sa.Column("id", sa.BigInteger, primary_key=True),
        sa.Column("user_id", sa.BigInteger, nullable=False, index=True),
        sa.Column("seat_id", sa.BigInteger, sa.ForeignKey("seats.id", ondelete="RESTRICT"), nullable=False, index=True),
        sa.Column("start_time", sa.DateTime(timezone=True), nullable=False, index=True),
        sa.Column("end_time", sa.DateTime(timezone=True), nullable=False, index=True),
        sa.Column("status", sa.String(16), nullable=False, server_default="pending"),
        sa.Column("price_cents", sa.Integer, nullable=False, server_default="0"),
        sa.Column("penalty_cents", sa.Integer, nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False)
    )
    op.create_index("ix_bookings_seat_time", "bookings", ["seat_id", "start_time", "end_time"])
    op.create_index("ix_seats_zone", "seats", ["zone_id"])

def downgrade() -> None:
    op.drop_index("ix_bookings_seat_time", table_name="bookings")
    op.drop_table("bookings")
    op.drop_index("ix_seats_zone", table_name="seats")
    op.drop_table("seats")
    op.drop_index("ix_zones_code", table_name="zones")
    op.drop_table("zones")
