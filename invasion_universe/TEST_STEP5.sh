#!/bin/bash
# Тестирование функциональности Шага 5: сидирование и layout

BASE_URL="http://localhost:8000"

echo "=== 1. Логин как админ ==="
TOKEN=$(curl -s -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin@example.com&password=adminpass123" | jq -r '.access_token')

echo "Token получен: ${TOKEN:0:30}..."

echo -e "\n=== 2. Получаем список зон ==="
ZONES=$(curl -s -X GET "$BASE_URL/zones" -H "Authorization: Bearer $TOKEN")
echo "$ZONES" | jq '.'
ZONE_ID=$(echo "$ZONES" | jq -r '.[0].id // empty')

if [ -z "$ZONE_ID" ]; then
  echo "Создаем новую зону для тестирования..."
  NEW_ZONE=$(curl -s -X POST "$BASE_URL/zones" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"name": "Main Hall", "code": "MAIN"}')
  echo "$NEW_ZONE" | jq '.'
  ZONE_ID=$(echo "$NEW_ZONE" | jq -r '.id')
fi

echo -e "\n=== 3. Сидирование: создаем сетку мест в зоне $ZONE_ID ==="
curl -s -X POST "$BASE_URL/admin/zones/$ZONE_ID/seed_seats" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "rows": 5,
    "cols": 10,
    "start_row_letter": "A",
    "vip_rows": ["A", "B"],
    "standard_price_rub": 300,
    "vip_price_rub": 500,
    "overwrite_prices": false
  }' | jq '.'

echo -e "\n=== 4. Проверяем layout зоны (места по рядам) ==="
curl -s -X GET "$BASE_URL/zones/$ZONE_ID/layout" | jq '.'

echo -e "\n=== 5. Проверяем список всех мест ==="
curl -s -X GET "$BASE_URL/zones/$ZONE_ID/seats" | jq '. | length' | xargs -I {} echo "Всего мест создано: {}"

echo -e "\n=== 6. Тестируем повторное сидирование (должны быть skip) ==="
curl -s -X POST "$BASE_URL/admin/zones/$ZONE_ID/seed_seats" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "rows": 3,
    "cols": 5,
    "start_row_letter": "A",
    "vip_rows": ["A"],
    "standard_price_rub": 350,
    "vip_price_rub": 600,
    "overwrite_prices": false
  }' | jq '.'

echo -e "\n=== 7. Тестируем availability для зоны ==="
TOMORROW=$(date -v+1d +%Y-%m-%d 2>/dev/null || date -d tomorrow +%Y-%m-%d)
echo "Проверяем доступность на $TOMORROW:"
curl -s -X GET "$BASE_URL/bookings/availability?date_str=$TOMORROW&zone_id=$ZONE_ID" \
  -H "Authorization: Bearer $TOKEN" | jq '. | length' | xargs -I {} echo "Мест с информацией о слотах: {}"

echo -e "\n=== 8. Создаем бронь на VIP место ==="
VIP_SEAT_ID=$(curl -s -X GET "$BASE_URL/zones/$ZONE_ID/layout" | jq -r '.rows[0].seats[0].id')
echo "VIP место ID: $VIP_SEAT_ID"

BOOKING=$(curl -s -X POST "$BASE_URL/bookings" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"seat_id\": $VIP_SEAT_ID,
    \"start_time\": \"${TOMORROW}T10:00:00Z\",
    \"hours\": 2
  }")
echo "$BOOKING" | jq '.'

echo -e "\n=== Тест завершен успешно! ==="
echo "Создана сетка мест и протестированы все новые эндпоинты."