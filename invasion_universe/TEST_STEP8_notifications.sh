#!/bin/bash
# Тестирование системы уведомлений

BASE_URL="http://localhost:8000"

echo "=== Шаг 8: Уведомления и подготовка к пушам ==="
echo ""
echo "Backend изменения:"
echo "✅ Создана модель Device для хранения токенов устройств"
echo "✅ Создан сервис notify.py с заготовкой под FCM"
echo "✅ Добавлены API endpoints /devices"
echo "✅ Создана миграция 20250827_0004_devices"
echo "✅ Добавлены триггеры уведомлений в booking.py"
echo ""
echo "Flutter изменения:"
echo "✅ Добавлены зависимости flutter_local_notifications и timezone"
echo "✅ Создан сервис Notifier для локальных уведомлений"
echo "✅ Настроено напоминание за 10 минут до брони"
echo "✅ Обновление напоминаний при загрузке броней"
echo ""
echo "=== Тестируем API устройств ==="

# Получаем токен
TOKEN=$(curl -s -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin@example.com&password=adminpass123" | jq -r '.access_token')

echo -e "\n1. Проверка списка устройств (пока пусто):"
curl -s -X GET "$BASE_URL/devices/me" \
  -H "Authorization: Bearer $TOKEN" | jq '.'

echo -e "\n2. Регистрация тестового устройства:"
curl -s -X POST "$BASE_URL/devices/register" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "platform": "ios",
    "token": "test_token_123456789",
    "locale": "ru",
    "app_version": "1.0.0"
  }' | jq '.'

echo -e "\n3. Проверка списка после регистрации:"
curl -s -X GET "$BASE_URL/devices/me" \
  -H "Authorization: Bearer $TOKEN" | jq '.'

echo -e "\n=== Инструкции для проверки уведомлений ==="
echo ""
echo "1. Запустите Flutter приложение:"
echo "   cd iu_mobile && flutter run"
echo ""
echo "2. Создайте бронь на ближайший час + 15 минут"
echo "   → Должно запланироваться уведомление за 10 минут до старта"
echo ""
echo "3. Проверьте в консоли бэкенда логи [PUSH:DRY]"
echo "   → При создании/отмене брони"
echo ""
echo "4. За 10 минут до брони получите локальное уведомление на устройстве"
echo ""
echo "Примечание: FCM пуши будут работать после добавления FCM_SERVER_KEY в .env"