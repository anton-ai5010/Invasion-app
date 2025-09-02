#!/bin/bash
# Скрипт запуска Invasion Universe

echo "🚀 Запуск Invasion Universe"
echo ""

# Проверяем, запущен ли Docker
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker не запущен. Запустите Docker и попробуйте снова."
    exit 1
fi

echo "📦 Запуск Docker контейнеров..."
docker compose up -d

# Ждем, пока контейнеры запустятся
echo "⏳ Ожидание запуска сервисов..."
sleep 5

# Проверяем состояние контейнеров
if docker compose ps | grep -q "healthy"; then
    echo "✅ Все сервисы запущены"
else
    echo "⚠️  Некоторые сервисы еще запускаются..."
fi

echo ""
echo "📱 Доступные сервисы:"
echo "  - Backend API: http://localhost:8000"
echo "  - PostgreSQL: localhost:5432"
echo "  - Redis: localhost:6379"
echo ""
echo "📱 Для запуска мобильного приложения:"
echo "  cd iu_mobile && flutter run"
echo ""
echo "🌐 Для запуска веб-админки:"
echo "  cd iu_mobile && flutter run -d chrome -t lib/admin_app.dart"
echo ""
echo "🔑 Учетные данные админа:"
echo "  Email: admin@example.com"
echo "  Пароль: adminpass123"