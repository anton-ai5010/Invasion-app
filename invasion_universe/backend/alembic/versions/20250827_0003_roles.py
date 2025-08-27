from __future__ import annotations
from alembic import op
import sqlalchemy as sa

revision = "20250827_0003"
down_revision = "20250827_0002"
branch_labels = None
depends_on = None

def upgrade() -> None:
    op.add_column("users", sa.Column("role", sa.String(16), nullable=False, server_default="user"))
    # сделаем первого пользователя админом (ты уже создал id=1)
    op.execute("UPDATE users SET role='admin' WHERE id=1")

def downgrade() -> None:
    op.drop_column("users", "role")