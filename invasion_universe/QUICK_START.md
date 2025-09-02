# 🚀 Быстрый запуск Invasion Universe

## 📋 Предварительные требования

- Python 3.11+
- Flutter 3.x
- Xcode (для iOS)
- Chrome (для веб-версии)

## 🎮 Запуск одной командой

### iOS Симулятор (рекомендуется)
```bash
./start_ios.sh
```

### С выбором платформы
```bash
./start_dev.sh
```

## 🔑 Тестовые аккаунты

| Роль | Email | Пароль |
|------|-------|--------|
| Пользователь | testuser@example.com | testpass123 |
| Администратор | admin@example.com | adminpass123 |

## 🏢 Тестовые данные

- **Основной зал**: 15 мест (A1-A5, B1-B5, C1-C5) по 300₽/час
- **VIP зал**: 3 места (VIP1-VIP3) по 500₽/час

## 🛠 Отдельные команды

### Только Backend
```bash
cd backend
export DATABASE_URL="sqlite:///./iu.db"
export JWT_SECRET="change_me_super_secret"
python -m uvicorn app.main:app --reload
```

### Только Frontend
```bash
cd iu_mobile
flutter run
```

### Создать тестовые данные
```bash
python create_test_data.py
```

## 🎨 Особенности UI

- Тёмная тема с неоновыми акцентами
- Анимированные карточки залов
- Интерактивная карта мест в стиле кинотеатра
- VIP места с фиолетовой подсветкой
- Современные формы входа

## ⚠️ Troubleshooting

### Backend не запускается
```bash
pip install -r backend/requirements.txt
```

### Flutter зависимости
```bash
cd iu_mobile && flutter pub get
```

### Очистить данные
```bash
rm backend/iu.db
```