#!/bin/bash
# Скрипт установки зависимостей для Invasion Universe

echo "🚀 Установка зависимостей для Invasion Universe"
echo ""

# Проверяем необходимые инструменты
check_tool() {
    if ! command -v $1 &> /dev/null; then
        echo "❌ $1 не найден. Пожалуйста, установите $1"
        return 1
    else
        echo "✅ $1 установлен"
        return 0
    fi
}

echo "📋 Проверка системных зависимостей:"
check_tool python3 || exit 1
check_tool pip3 || exit 1
check_tool flutter || exit 1
check_tool docker || exit 1
check_tool "docker compose" || exit 1

echo ""
echo "📦 Установка Python зависимостей..."
cd backend
if [ ! -d "venv" ]; then
    echo "Создание виртуального окружения..."
    python3 -m venv venv
fi

echo "Активация виртуального окружения и установка пакетов..."
source venv/bin/activate
pip install -r requirements.txt

echo ""
echo "📦 Установка Flutter зависимостей..."
cd ../iu_mobile
flutter pub get

echo ""
echo "✅ Все зависимости установлены!"
echo ""
echo "Для запуска проекта используйте:"
echo "  ./start.sh"