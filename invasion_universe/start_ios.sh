#!/bin/bash

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🚀 Starting Invasion Universe (iOS)${NC}"

# Set environment variables
export DATABASE_URL="sqlite:///./iu.db"
export JWT_SECRET="change_me_super_secret"

# Cleanup function
cleanup() {
    echo -e "\n${RED}🛑 Stopping all services...${NC}"
    pkill -P $$
    exit 0
}

trap cleanup EXIT INT TERM

# Start backend
echo -e "${GREEN}🔧 Starting Backend...${NC}"
cd backend
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000 &
BACKEND_PID=$!
cd ..

# Wait for backend
sleep 3

# Create test data if needed
if [ ! -f "backend/iu.db" ]; then
    echo -e "${BLUE}📦 Creating test data...${NC}"
    python create_test_data.py
fi

# Open iOS Simulator
if ! pgrep -x "Simulator" > /dev/null; then
    echo -e "${BLUE}📱 Opening iOS Simulator...${NC}"
    open -a Simulator
    sleep 3
fi

# Launch Flutter app
echo -e "${GREEN}📱 Launching Flutter app...${NC}"
cd iu_mobile
flutter run

wait $BACKEND_PID