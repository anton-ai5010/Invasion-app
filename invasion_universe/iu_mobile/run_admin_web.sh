#!/bin/bash
# Запуск админки с отключенной безопасностью Chrome для разработки
echo "Запуск Flutter Web админки..."
echo "Используется Chrome с отключенной CORS проверкой для разработки"
echo ""
flutter run -d chrome -t lib/admin_app.dart --web-browser-flag "--disable-web-security" --web-browser-flag "--user-data-dir=/tmp/chrome_dev"