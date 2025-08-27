#!/bin/bash
# Тестирование i18n функциональности

BASE_URL="http://localhost:8000"

echo "=== 1. Тест с английским языком (неверный пароль) ==="
curl -s -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -H "Accept-Language: en" \
  -d "username=admin@example.com&password=wrong" | jq '.'

echo -e "\n=== 2. Тест с русским языком (неверный пароль) ==="
curl -s -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -H "Accept-Language: ru" \
  -d "username=admin@example.com&password=wrong" | jq '.'

echo -e "\n=== 3. Тест без языка (fallback на русский) ==="
curl -s -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin@example.com&password=wrong" | jq '.'

echo -e "\n=== 4. Получаем токен для дальнейших тестов ==="
TOKEN=$(curl -s -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin@example.com&password=adminpass123" | jq -r '.access_token')
echo "Token получен"

echo -e "\n=== 5. Тест несуществующего Bearer токена (EN) ==="
curl -s -X GET "$BASE_URL/auth/me" \
  -H "Authorization: Bearer invalid_token_123" \
  -H "Accept-Language: en" | jq '.'

echo -e "\n=== 6. Тест несуществующего Bearer токена (RU) ==="
curl -s -X GET "$BASE_URL/auth/me" \
  -H "Authorization: Bearer invalid_token_123" \
  -H "Accept-Language: ru" | jq '.'

echo -e "\n=== 7. Тест попытки создать зону обычным пользователем (EN) ==="
# Создаем обычного пользователя
USER_EMAIL="regular$(date +%s)@example.com"
curl -s -X POST "$BASE_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"email\": \"$USER_EMAIL\", \"username\": \"regular\", \"password\": \"pass123\"}" > /dev/null

USER_TOKEN=$(curl -s -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=$USER_EMAIL&password=pass123" | jq -r '.access_token')

curl -s -X POST "$BASE_URL/zones" \
  -H "Authorization: Bearer $USER_TOKEN" \
  -H "Content-Type: application/json" \
  -H "Accept-Language: en" \
  -d '{"name": "Hacker Zone", "code": "HACK"}' | jq '.'

echo -e "\n=== 8. Тест попытки создать зону обычным пользователем (RU) ==="
curl -s -X POST "$BASE_URL/zones" \
  -H "Authorization: Bearer $USER_TOKEN" \
  -H "Content-Type: application/json" \
  -H "Accept-Language: ru" \
  -d '{"name": "Hacker Zone", "code": "HACK"}' | jq '.'

echo -e "\n=== 9. Тест конфликта при создании брони (создаем две брони на одно время) ==="
# Сначала создаем успешную бронь
BOOKING1=$(curl -s -X POST "$BASE_URL/bookings" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -H "Accept-Language: en" \
  -d '{
    "seat_id": 2,
    "start_time": "2025-12-01T10:00:00Z",
    "hours": 2
  }')
echo "Первая бронь создана"

# Теперь пробуем создать конфликтующую бронь
echo -e "\n=== 10. Конфликт бронирования (EN) ==="
curl -s -X POST "$BASE_URL/bookings" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -H "Accept-Language: en" \
  -d '{
    "seat_id": 2,
    "start_time": "2025-12-01T10:00:00Z",
    "hours": 2
  }' | jq '.'

echo -e "\n=== 11. Конфликт бронирования (RU) ==="
curl -s -X POST "$BASE_URL/bookings" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -H "Accept-Language: ru" \
  -d '{
    "seat_id": 2,
    "start_time": "2025-12-01T11:00:00Z",
    "hours": 1
  }' | jq '.'

echo -e "\n=== 12. Тест попытки создать дубликат зоны (EN) ==="
curl -s -X POST "$BASE_URL/zones" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -H "Accept-Language: en" \
  -d '{"name": "Main Hall Copy", "code": "MAIN"}' | jq '.'

echo -e "\n=== Тест i18n завершен успешно! ==="