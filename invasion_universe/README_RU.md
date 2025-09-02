# Invasion Universe - Система бронирования коворкинга

## 📋 Требования

- macOS, Linux или Windows с WSL
- Python 3.11+
- Flutter 3.29+
- Docker и Docker Compose
- PostgreSQL 15 (через Docker)
- Redis 7 (через Docker)

## 🚀 Быстрый старт

### 1. Установка зависимостей
```bash
chmod +x setup.sh
./setup.sh
```

### 2. Запуск проекта
```bash
chmod +x start.sh stop.sh
./start.sh
```

### 3. Доступ к сервисам

**Backend API**: http://localhost:8000
- Документация API: http://localhost:8000/docs
- Альтернативная документация: http://localhost:8000/redoc

**Мобильное приложение**:
```bash
cd iu_mobile
flutter run
```

**Веб-админка**:
```bash
cd iu_mobile
flutter run -d chrome -t lib/admin_app.dart
```

## 🔑 Учетные данные

### Администратор
- Email: admin@example.com
- Пароль: adminpass123

### Тестовый пользователь
- Email: user@example.com
- Пароль: userpass123

## 📱 Функциональность

### Мобильное приложение
- Регистрация и авторизация пользователей
- Просмотр доступных зон коворкинга
- Выбор места на схеме зала
- Бронирование на конкретное время
- Управление своими бронями
- Поддержка офлайн-режима
- Push-уведомления о предстоящих бронях

### Веб-админка
- Просмотр всех броней на сегодня
- Управление статусами броней
- Массовое изменение цен по рядам
- Активация/деактивация мест

## 🛠 Разработка

### Backend (FastAPI)
```bash
cd backend
source venv/bin/activate
uvicorn app.main:app --reload
```

### Frontend (Flutter)
```bash
cd iu_mobile
flutter run
```

### База данных

Создание миграций:
```bash
docker compose exec backend alembic revision --autogenerate -m "описание"
```

Применение миграций:
```bash
docker compose exec backend alembic upgrade head
```

## 🧪 Тестирование

Каждый шаг реализации имеет свой тестовый скрипт:
```bash
./TEST_STEP1_basic_auth.sh
./TEST_STEP2_zones_crud.sh
# и т.д.
```

## 📁 Структура проекта

```
invasion_universe/
├── backend/              # Backend на FastAPI
│   ├── app/             # Основной код приложения
│   ├── alembic/         # Миграции БД
│   ├── requirements.txt # Python зависимости
│   └── Dockerfile       
├── iu_mobile/           # Flutter приложение
│   ├── lib/             # Dart код
│   ├── pubspec.yaml     # Flutter зависимости
│   └── web/             # Файлы для веб-версии
├── docker-compose.yml   # Конфигурация Docker
├── .env                 # Переменные окружения
└── TEST_STEP*.sh       # Тестовые скрипты
```

## 🐛 Решение проблем

### CORS ошибки в веб-админке
Убедитесь, что в `.env` файле установлено:
```
CORS_ORIGINS=*
```

### Контейнеры не запускаются
```bash
docker compose logs
docker compose down -v
docker compose up -d
```

### Flutter зависимости устарели
```bash
cd iu_mobile
flutter clean
flutter pub get
```

## 📞 Поддержка

При возникновении проблем проверьте:
1. Логи Docker: `docker compose logs`
2. Состояние контейнеров: `docker compose ps`
3. Flutter doctor: `flutter doctor`