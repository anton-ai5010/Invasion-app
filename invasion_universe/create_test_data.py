#!/usr/bin/env python3
import os
import sys

# Set environment variables
os.environ['DATABASE_URL'] = 'sqlite:///./iu.db'
os.environ['JWT_SECRET'] = 'change_me_super_secret'

# Add backend to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'backend'))

from app.db import SessionLocal
from app.models.user import User
from app.models.zone import Zone
from app.models.seat import Seat
from passlib.context import CryptContext

pwd_context = CryptContext(schemes=['bcrypt'], deprecated='auto')

def create_test_data():
    db = SessionLocal()
    
    try:
        # Check if data already exists
        if db.query(User).first():
            print("❗ Data already exists. Skipping...")
            return
        
        print("🔧 Creating test users...")
        
        # Create admin
        admin = User(
            email='admin@example.com',
            password_hash=pwd_context.hash('adminpass123'),
            role='admin'
        )
        db.add(admin)
        
        # Create test user
        test_user = User(
            email='testuser@example.com',
            password_hash=pwd_context.hash('testpass123'),
            role='user'
        )
        db.add(test_user)
        
        print("🏢 Creating zones...")
        
        # Create zones
        zone1 = Zone(name='Основной зал', code='MAIN')
        zone2 = Zone(name='VIP зал', code='VIP')
        db.add(zone1)
        db.add(zone2)
        db.flush()
        
        print("💺 Creating seats...")
        
        # Create seats for zone1
        for row in ['A', 'B', 'C']:
            for i in range(1, 6):
                seat = Seat(
                    zone_id=zone1.id,
                    label=f'{row}{i}',
                    seat_type='standard',
                    hourly_price_cents=30000  # 300 руб
                )
                db.add(seat)
        
        # Create VIP seats for zone2
        for i in range(1, 4):
            seat = Seat(
                zone_id=zone2.id,
                label=f'VIP{i}',
                seat_type='vip',
                hourly_price_cents=50000  # 500 руб
            )
            db.add(seat)
        
        db.commit()
        
        print("\n✅ Test data created successfully!")
        print("\n📧 Test accounts:")
        print("  Admin: admin@example.com / adminpass123")
        print("  User:  testuser@example.com / testpass123")
        print("\n🏢 Zones:")
        print("  - Основной зал (15 seats)")
        print("  - VIP зал (3 seats)")
        
    except Exception as e:
        print(f"❌ Error: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    create_test_data()