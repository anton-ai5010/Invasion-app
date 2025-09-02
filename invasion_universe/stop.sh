#!/bin/bash
# Скрипт остановки Invasion Universe

echo "🛑 Остановка Invasion Universe"
echo ""

echo "📦 Остановка Docker контейнеров..."
docker compose down

echo ""
echo "✅ Все сервисы остановлены"