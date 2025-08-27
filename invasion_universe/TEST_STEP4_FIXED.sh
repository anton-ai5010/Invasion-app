#!/bin/bash
# Тестирование функциональности Шага 4 (исправленная версия)

BASE_URL="http://localhost:8000"

echo "=== 1. Регистрация нового админ-пользователя ==="
curl -s -X POST "$BASE_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@example.com",
    "username": "adminuser", 
    "password": "adminpass123"
  }' | jq '.'

echo -e "\n=== 2. Делаем пользователя админом через SQL ==="
docker exec invasion_universe-db-1 psql -U iu -d iu_db -c "UPDATE users SET role='admin' WHERE email='admin@example.com';"

echo -e "\n=== 3. Логин как админ ==="
TOKEN=$(curl -s -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin@example.com&password=adminpass123" | jq -r '.access_token')

echo "Token: ${TOKEN:0:30}..."

echo -e "\n=== 4. Проверка роли ==="
curl -s -X GET "$BASE_URL/auth/me" \
  -H "Authorization: Bearer $TOKEN" | jq '.'

echo -e "\n=== 5. Создание зоны (требует админа) ==="
ZONE_RESPONSE=$(curl -s -X POST "$BASE_URL/zones" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "Admin Test Zone", "code": "ADM"}')
echo "$ZONE_RESPONSE" | jq '.'
ZONE_ID=$(echo "$ZONE_RESPONSE" | jq -r '.id // empty')

echo -e "\n=== 6. Создание места в зоне ==="
SEAT_RESPONSE=$(curl -s -X POST "$BASE_URL/zones/$ZONE_ID/seats" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"label": "A-01", "seat_type": "FOCUS", "hourly_price_rub": 400}')
echo "$SEAT_RESPONSE" | jq '.'
SEAT_ID=$(echo "$SEAT_RESPONSE" | jq -r '.id // empty')

echo -e "\n=== 7. Создание брони ==="
BOOKING_RESPONSE=$(curl -s -X POST "$BASE_URL/bookings" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"seat_id\": $SEAT_ID,
    \"start_time\": \"2025-10-01T14:00:00Z\",
    \"hours\": 2
  }")
echo "$BOOKING_RESPONSE" | jq '.'
BOOKING_ID=$(echo "$BOOKING_RESPONSE" | jq -r '.id // empty')

echo -e "\n=== 8. Админ операция: mark_paid ==="
curl -s -X POST "$BASE_URL/admin/bookings/$BOOKING_ID/mark_paid" \
  -H "Authorization: Bearer $TOKEN" | jq '.'

echo -e "\n=== 9. Админ операция: complete ==="
curl -s -X POST "$BASE_URL/admin/bookings/$BOOKING_ID/complete" \
  -H "Authorization: Bearer $TOKEN" | jq '.'

echo -e "\n=== 10. Тест Redis локов (параллельные запросы) ==="
echo "Создаем две брони на одно время..."
(
  curl -s -X POST "$BASE_URL/bookings" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
      \"seat_id\": $SEAT_ID,
      \"start_time\": \"2025-10-02T10:00:00Z\",
      \"hours\": 1
    }" | jq -c '. | {id, detail}' &
    
  curl -s -X POST "$BASE_URL/bookings" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
      \"seat_id\": $SEAT_ID,
      \"start_time\": \"2025-10-02T10:00:00Z\",
      \"hours\": 1
    }" | jq -c '. | {id, detail}' &
)
wait

echo -e "\n=== 11. Тест защиты админ эндпоинтов (создаем обычного пользователя) ==="
curl -s -X POST "$BASE_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com", "username": "normaluser", "password": "userpass123"}' | jq -c '.'

USER_TOKEN=$(curl -s -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=user@example.com&password=userpass123" | jq -r '.access_token')

echo "Попытка создать зону обычным пользователем:"
curl -s -X POST "$BASE_URL/zones" \
  -H "Authorization: Bearer $USER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "Hacker Zone", "code": "HAK"}' | jq '.'

echo -e "\n=== Тест завершен успешно! ==="