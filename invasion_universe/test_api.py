#!/usr/bin/env python3
"""
API Testing Script for Invasion Universe
Tests all major functionality
"""

import requests
import json
from datetime import datetime, timedelta

BASE_URL = "http://localhost:8000"

# Test credentials
ADMIN_EMAIL = "admin@example.com"
ADMIN_PASSWORD = "adminpass123"
USER_EMAIL = "testuser@example.com"
USER_PASSWORD = "testpass123"

# Color codes for output
GREEN = '\033[92m'
RED = '\033[91m'
YELLOW = '\033[93m'
BLUE = '\033[94m'
END = '\033[0m'

def print_test(test_name, status, details=""):
    status_text = f"{GREEN}✓ PASSED{END}" if status else f"{RED}✗ FAILED{END}"
    print(f"{BLUE}[TEST]{END} {test_name}: {status_text}")
    if details:
        print(f"  → {details}")

def test_health():
    """Test health endpoint"""
    try:
        resp = requests.get(f"{BASE_URL}/healthz")
        success = resp.status_code == 200 and resp.json()["status"] == "ok"
        print_test("Health Check", success, f"Status: {resp.status_code}")
        return success
    except Exception as e:
        print_test("Health Check", False, str(e))
        return False

def register_user():
    """Register a test user"""
    try:
        resp = requests.post(f"{BASE_URL}/auth/register", json={
            "email": USER_EMAIL,
            "password": USER_PASSWORD,
            "full_name": "Test User",
            "locale": "ru"
        })
        success = resp.status_code in [200, 409]  # OK or already exists
        print_test("User Registration", success, f"Status: {resp.status_code}")
        return success
    except Exception as e:
        print_test("User Registration", False, str(e))
        return False

def login_user(email, password):
    """Login and get token"""
    try:
        resp = requests.post(f"{BASE_URL}/auth/login", data={
            "username": email,
            "password": password
        })
        if resp.status_code == 200:
            token = resp.json()["access_token"]
            print_test(f"Login ({email})", True, f"Token received")
            return token
        else:
            print_test(f"Login ({email})", False, f"Status: {resp.status_code}")
            return None
    except Exception as e:
        print_test(f"Login ({email})", False, str(e))
        return None

def test_zones(token):
    """Test zones endpoints"""
    headers = {"Authorization": f"Bearer {token}"}
    
    # Get zones
    try:
        resp = requests.get(f"{BASE_URL}/zones", headers=headers)
        zones = resp.json()
        success = resp.status_code == 200 and len(zones) > 0
        print_test("Get Zones", success, f"Found {len(zones)} zones")
        
        if zones:
            # Get zone layout
            zone_id = zones[0]["id"]
            resp = requests.get(f"{BASE_URL}/zones/{zone_id}/layout", headers=headers)
            layout = resp.json()
            success = resp.status_code == 200 and "rows" in layout
            rows_count = len(layout.get("rows", []))
            seats_count = sum(len(row.get("seats", [])) for row in layout.get("rows", []))
            print_test("Get Zone Layout", success, f"Zone {zone_id}: {rows_count} rows, {seats_count} seats")
            
            return zones[0] if zones else None
    except Exception as e:
        print_test("Zones Test", False, str(e))
        return None

def test_availability(token, zone_id):
    """Test availability check"""
    headers = {"Authorization": f"Bearer {token}"}
    tomorrow = (datetime.now() + timedelta(days=1)).strftime("%Y-%m-%d")
    
    try:
        resp = requests.get(
            f"{BASE_URL}/bookings/availability",
            params={"zone_id": zone_id, "date": tomorrow},
            headers=headers
        )
        availability = resp.json()
        success = resp.status_code == 200 and len(availability) > 0
        print_test("Check Availability", success, 
                  f"Date: {tomorrow}, Found {len(availability)} seats")
        
        # Find an available slot
        for seat in availability:
            for slot in seat.get("slots", []):
                if slot["is_free"]:
                    return {
                        "seat_id": seat["seat_id"],
                        "start_time": slot["start_time"],
                        "end_time": slot["end_time"],
                        "label": seat["label"]
                    }
        return None
    except Exception as e:
        print_test("Availability Test", False, str(e))
        return None

def test_booking(token, slot):
    """Test booking creation and cancellation"""
    headers = {"Authorization": f"Bearer {token}"}
    
    # Create booking
    try:
        resp = requests.post(f"{BASE_URL}/bookings", json={
            "seat_id": slot["seat_id"],
            "start_time": slot["start_time"],
            "end_time": slot["end_time"]
        }, headers=headers)
        
        if resp.status_code == 200:
            booking = resp.json()
            booking_id = booking["id"]
            print_test("Create Booking", True, 
                      f"Booking #{booking_id} for seat {slot['label']}")
            
            # Get booking details
            resp = requests.get(f"{BASE_URL}/bookings/{booking_id}", headers=headers)
            success = resp.status_code == 200
            print_test("Get Booking Details", success)
            
            # Cancel booking
            resp = requests.post(f"{BASE_URL}/bookings/{booking_id}/cancel", 
                               headers=headers)
            success = resp.status_code == 200
            print_test("Cancel Booking", success, f"Booking #{booking_id} cancelled")
            
            return True
        else:
            print_test("Create Booking", False, f"Status: {resp.status_code}")
            return False
    except Exception as e:
        print_test("Booking Test", False, str(e))
        return False

def test_admin_endpoints(token):
    """Test admin-only endpoints"""
    headers = {"Authorization": f"Bearer {token}"}
    
    # Admin stats
    try:
        resp = requests.get(f"{BASE_URL}/admin/stats", headers=headers)
        success = resp.status_code == 200
        if success:
            stats = resp.json()
            print_test("Admin Stats", True, 
                      f"Users: {stats.get('total_users', 0)}, "
                      f"Bookings: {stats.get('total_bookings', 0)}")
        else:
            print_test("Admin Stats", False, f"Status: {resp.status_code}")
    except Exception as e:
        print_test("Admin Stats", False, str(e))
    
    # Admin bookings
    try:
        resp = requests.get(f"{BASE_URL}/admin/bookings", headers=headers)
        success = resp.status_code == 200
        print_test("Admin Bookings List", success)
    except Exception as e:
        print_test("Admin Bookings", False, str(e))

def main():
    print(f"\n{YELLOW}=== Invasion Universe API Test Suite ==={END}\n")
    
    # 1. Health check
    if not test_health():
        print(f"\n{RED}Backend not responding. Make sure Docker is running.{END}")
        return
    
    # 2. User registration
    register_user()
    
    # 3. User login
    user_token = login_user(USER_EMAIL, USER_PASSWORD)
    
    # 4. Admin login
    admin_token = login_user(ADMIN_EMAIL, ADMIN_PASSWORD)
    
    if user_token:
        # 5. Test zones
        zone = test_zones(user_token)
        
        if zone:
            # 6. Test availability
            slot = test_availability(user_token, zone["id"])
            
            if slot:
                # 7. Test booking
                test_booking(user_token, slot)
    
    if admin_token:
        # 8. Test admin endpoints
        print(f"\n{YELLOW}Admin Tests:{END}")
        test_admin_endpoints(admin_token)
    
    print(f"\n{YELLOW}=== Test Suite Complete ==={END}\n")

if __name__ == "__main__":
    main()