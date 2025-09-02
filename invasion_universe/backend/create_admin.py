from sqlalchemy import select
from app.db import SessionLocal
from app.models.user import User
from app.utils.security import hash_password

def create_admin():
    with SessionLocal() as session:
        # Проверяем, есть ли admin
        result = session.execute(
            select(User).where(User.email == "admin@example.com")
        )
        admin = result.scalar_one_or_none()
        
        if admin:
            print("Admin already exists")
            print(f"Email: {admin.email}")
            print(f"Role: {admin.role}")
            print(f"Password hash exists: {bool(admin.password_hash)}")
        else:
            # Создаем admin
            admin = User(
                email="admin@example.com",
                password_hash=hash_password("adminpass123"),
                role="admin",
                full_name="Administrator"
            )
            session.add(admin)
            session.commit()
            print("Admin created successfully")
            print(f"Email: admin@example.com")
            print(f"Password: adminpass123")

if __name__ == "__main__":
    create_admin()