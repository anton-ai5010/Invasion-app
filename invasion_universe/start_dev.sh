#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Starting Invasion Universe Development Environment${NC}"
echo ""

# Set environment variables for backend
export DATABASE_URL="sqlite:///./iu.db"
export JWT_SECRET="change_me_super_secret"
export ACCESS_TOKEN_EXPIRES_MIN="60"

# Function to cleanup on exit
cleanup() {
    echo -e "\n${RED}🛑 Stopping all services...${NC}"
    # Kill all child processes
    pkill -P $$
    exit 0
}

# Set trap to cleanup on script exit
trap cleanup EXIT INT TERM

# Check if database exists
if [ ! -f "backend/iu.db" ]; then
    echo -e "${BLUE}📦 Creating database...${NC}"
    cd backend
    python -c "
import os
os.environ['DATABASE_URL'] = 'sqlite:///./iu.db'
os.environ['JWT_SECRET'] = 'change_me_super_secret'

from app.models.user import User
from app.models.zone import Zone
from app.models.seat import Seat
from app.models.booking import Booking
from app.models.base import Base
from app.db import engine

Base.metadata.create_all(bind=engine)
print('Database created!')
"
    cd ..
fi

# Start backend in background
echo -e "${GREEN}🔧 Starting Backend on http://localhost:8000${NC}"
cd backend
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000 &
BACKEND_PID=$!
cd ..

# Wait for backend to start
echo -e "${BLUE}⏳ Waiting for backend to start...${NC}"
sleep 5

# Check if backend is running
if ! curl -s http://localhost:8000/docs > /dev/null; then
    echo -e "${RED}❌ Backend failed to start!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Backend is running!${NC}"
echo ""

# Start Flutter app
echo -e "${GREEN}📱 Starting Flutter app...${NC}"
cd iu_mobile

# Get list of available devices
echo -e "${BLUE}📱 Available devices:${NC}"
flutter devices

echo ""
echo -e "${BLUE}Select device to run on:${NC}"
echo "1) iOS Simulator"
echo "2) Chrome (Web)"
echo "3) Android Emulator"
echo -n "Enter choice [1-3]: "
read choice

case $choice in
    1)
        # Check if simulator is running
        if ! pgrep -x "Simulator" > /dev/null; then
            echo -e "${BLUE}📱 Opening iOS Simulator...${NC}"
            open -a Simulator
            sleep 3
        fi
        
        # Get iOS device ID
        DEVICE_ID=$(flutter devices | grep "iPhone" | grep -E "simulator" | head -1 | awk '{print $5}')
        if [ -z "$DEVICE_ID" ]; then
            echo -e "${RED}❌ No iOS simulator found!${NC}"
            exit 1
        fi
        
        echo -e "${GREEN}📱 Launching on iOS Simulator...${NC}"
        flutter run -d "$DEVICE_ID"
        ;;
    2)
        echo -e "${GREEN}🌐 Launching on Chrome...${NC}"
        flutter run -d chrome --web-port=3000
        ;;
    3)
        echo -e "${GREEN}🤖 Launching on Android...${NC}"
        flutter run -d android
        ;;
    *)
        echo -e "${RED}❌ Invalid choice!${NC}"
        exit 1
        ;;
esac

# Keep script running
wait $BACKEND_PID