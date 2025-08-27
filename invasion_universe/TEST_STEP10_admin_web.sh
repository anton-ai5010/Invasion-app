#!/bin/bash
# Тестирование веб-админки

echo "=== Шаг 10: Admin Light на Flutter Web ==="
echo ""
echo "Backend изменения:"
echo "✅ Добавлен эндпоинт GET /admin/bookings/today"
echo "✅ Добавлен эндпоинт POST /admin/zones/{zone_id}/rows/{row}/price"
echo "✅ Роль уже возвращается в /auth/me"
echo ""
echo "Flutter Web админка:"
echo "✅ Включена поддержка Flutter Web"
echo "✅ Создан admin_app.dart как отдельная точка входа"
echo "✅ Экран AdminDashboard с таблицей сегодняшних броней"
echo "✅ Экран ZonePricingScreen для массового изменения цен"
echo "✅ Проверка роли admin при входе"
echo ""
echo "=== Как запустить админку ==="
echo ""
echo "1. Перезапустите Docker compose для применения изменений backend"
echo ""
echo "2. Запустите веб-админку:"
echo "   cd iu_mobile"
echo "   flutter run -d chrome -t lib/admin_app.dart"
echo ""
echo "3. Войдите как администратор:"
echo "   Email: admin@example.com"
echo "   Пароль: adminpass123"
echo ""
echo "=== Функционал админки ==="
echo ""
echo "Экран 'Сегодня':"
echo "- Таблица с бронями на сегодня"
echo "- Фильтр по зоне"
echo "- Кнопки действий:"
echo "  • paid - отметить как оплаченную"
echo "  • complete - завершить бронь"
echo "  • no_show - отметить неявку"
echo ""
echo "Экран 'Цены по ряду':"
echo "- Массовое изменение цен для всего ряда"
echo "- Изменение типа места (standard/vip)"
echo "- Активация/деактивация мест"
echo ""
echo "=== Тест API эндпоинтов ==="

BASE_URL="http://localhost:8000"
TOKEN=$(curl -s -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin@example.com&password=adminpass123" | jq -r '.access_token')

echo -e "\n1. Получение броней на сегодня:"
curl -s -X GET "$BASE_URL/admin/bookings/today" \
  -H "Authorization: Bearer $TOKEN" | jq '.'

echo -e "\n2. Изменение цен для ряда A в зоне 1:"
curl -s -X POST "$BASE_URL/admin/zones/1/rows/A/price" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"hourly_price_rub": 550, "seat_type": "vip"}' | jq '.'