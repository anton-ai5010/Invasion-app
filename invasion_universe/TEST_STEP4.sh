#!/bin/bash
# Тестирование функциональности Шага 4

BASE_URL="http://localhost:8000"

echo "=== 1. Логин как админ ==="
TOKEN=$(curl -s -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=test@example.com&password=testpass123" | jq -r '.access_token')

echo "Token: ${TOKEN:0:20}..."

echo -e "\n=== 2. Проверка роли ==="
curl -s -X GET "$BASE_URL/auth/me" \
  -H "Authorization: Bearer $TOKEN" | jq '.role // "role field not found"'

echo -e "\n=== 3. Создание зоны (требует админа) ==="
curl -s -X POST "$BASE_URL/zones" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "Test Zone", "code": "TEST"}' | jq '.'

echo -e "\n=== 4. Создание брони для тестирования ==="
BOOKING_ID=$(curl -s -X POST "$BASE_URL/bookings" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "seat_id": 1,
    "start_time": "2025-09-15T10:00:00Z",
    "hours": 2
  }' | jq -r '.id // "error"')

echo "Booking ID: $BOOKING_ID"

echo -e "\n=== 5. Админ операция: mark_paid ==="
curl -X POST "$BASE_URL/admin/bookings/$BOOKING_ID/mark_paid" \
  -H "Authorization: Bearer $TOKEN" -v 2>&1 | grep -E "HTTP|{" | tail -2

echo -e "\n=== 6. Проверка Redis ==="
docker exec invasion_universe-redis-1 redis-cli ping

echo -e "\n=== Тест завершен ==="