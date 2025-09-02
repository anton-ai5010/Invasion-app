# Invasion Universe - Руководство по тестированию

## 🚀 Быстрый старт

### 1. Запуск Backend
```bash
cd /Users/cooldom/Dev/invasion_universe
docker compose up --build
```

### 2. Проверка статуса
```bash
docker compose ps
```

Все контейнеры должны быть в статусе "Up":
- `invasion_universe-backend-1` - FastAPI сервер
- `invasion_universe-db-1` - PostgreSQL база данных  
- `invasion_universe-redis-1` - Redis кеш

## 🔍 Тестирование API

### Swagger UI
Откройте в браузере: http://localhost:8000/docs

### Основные эндпоинты

#### Здоровье системы
```bash
curl http://localhost:8000/healthz
```

#### Получение списка зон
```bash
curl http://localhost:8000/zones
```

#### Авторизация
```bash
# Администратор
curl -X POST http://localhost:8000/auth/login \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin@example.com&password=adminpass123"

# Обычный пользователь (создайте через /auth/register)
curl -X POST http://localhost:8000/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"user@test.com","password":"test123","full_name":"Test User"}'
```

### Автоматическое тестирование
```bash
python3 /Users/cooldom/Dev/invasion_universe/test_api.py
```

## 📱 Flutter Mobile App

### Запуск на iOS (iPhone)
```bash
cd /Users/cooldom/Dev/invasion_universe/iu_mobile
flutter run -d iphone
```

### Запуск на macOS
```bash
cd /Users/cooldom/Dev/invasion_universe/iu_mobile
flutter run -d macos
```

### Запуск в Chrome (Web)
```bash
cd /Users/cooldom/Dev/invasion_universe/iu_mobile
flutter run -d chrome
```

## ✅ Чек-лист тестирования

### Backend API
- [x] Health check работает
- [x] Миграции базы данных применены
- [x] Регистрация пользователей
- [x] Авторизация (JWT токены)
- [x] Получение списка зон
- [x] Получение схемы зала (layout)
- [x] Проверка доступности мест
- [ ] Создание бронирования
- [ ] Отмена бронирования  
- [ ] История бронирований

### Flutter Mobile
- [ ] Запуск приложения
- [ ] Экран авторизации
- [ ] Список зон
- [ ] Схема зала с местами
- [ ] Выбор даты и времени
- [ ] Создание бронирования
- [ ] Мои бронирования
- [ ] Отмена бронирования
- [ ] Push-уведомления (локальные)
- [ ] Офлайн кеширование
- [ ] Pull-to-refresh

### Admin Features
- [ ] Вход под админом
- [ ] Просмотр всех бронирований
- [ ] Изменение цен
- [ ] Управление зонами
- [ ] Статистика

## 🐛 Известные проблемы

### 1. Flutter не видит backend
**Решение**: Убедитесь что в `lib/api.dart` правильный URL:
```dart
static const String baseUrl = 'http://localhost:8000';
```

### 2. Ошибка миграций базы данных
**Решение**: Пересоздайте базу данных:
```bash
docker compose down -v
docker compose up --build
```

### 3. Redis connection refused
**Решение**: Проверьте что Redis контейнер запущен:
```bash
docker compose restart redis
```

## 📊 Мониторинг

### Логи Backend
```bash
docker compose logs -f backend
```

### Логи базы данных
```bash
docker compose logs -f db
```

### Все логи
```bash
docker compose logs -f
```

## 🔐 Тестовые учетные записи

| Роль | Email | Пароль |
|------|-------|--------|
| Администратор | admin@example.com | adminpass123 |
| Пользователь | testuser@example.com | testpass123 |

## 🛠 Полезные команды

### Перезапуск сервисов
```bash
docker compose restart
```

### Остановка всех сервисов
```bash
docker compose down
```

### Полная очистка (включая volumes)
```bash
docker compose down -v
```

### Пересборка контейнеров
```bash
docker compose build --no-cache
```

## 📝 Структура проекта

```
invasion_universe/
├── backend/          # FastAPI backend
│   ├── app/         # Основной код
│   ├── alembic/     # Миграции БД
│   └── tests/       # Тесты backend
├── iu_mobile/       # Flutter приложение
│   ├── lib/         # Dart код
│   ├── ios/         # iOS конфигурация
│   └── android/     # Android конфигурация
├── nginx/           # Конфигурация для production
└── docker-compose.yml
```

## 🚀 Production деплой

Для production используйте:
```bash
docker compose -f docker-compose.production.yml up -d
```

## 📞 Поддержка

При возникновении проблем:
1. Проверьте логи: `docker compose logs`
2. Убедитесь что все порты свободны: 8000, 5432, 6379
3. Проверьте Docker Desktop запущен
4. Попробуйте перезапустить: `docker compose restart`