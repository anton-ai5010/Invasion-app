# Руководство по тестированию API в VS Code

## 1. Запуск контейнеров через Docker расширение

1. Откройте боковую панель Docker (иконка кита)
2. Найдите раздел **Composes**
3. Найдите `invasion_universe/docker-compose.yml`
4. Правый клик → **Compose Up** (запустит db и backend)
5. Для просмотра логов: **Containers** → правый клик по `invasion_universe-backend-1` → **View Logs**
6. Для остановки: правый клик → **Compose Down**

## 2. Открытие Swagger в VS Code

1. `Cmd+Shift+P` → **Simple Browser: Show**
2. Введите: `http://localhost:8000/docs`
3. Swagger откроется как вкладка внутри VS Code

## 3. Использование Thunder Client

### Импорт коллекции
1. Откройте Thunder Client (иконка молнии)
2. Нажмите **Collections** → **Import**
3. Выберите `.thunder-client/thunder-collection_Invasion API.json`

### Настройка окружения
1. В Thunder Client откройте **Env**
2. Импортируйте `.thunder-client/thunder-environment_Local.json`
3. Выберите окружение **Local**

### Тестирование API

#### 1. Регистрация
- Откройте запрос **Register**
- Измените данные в body если нужно
- Нажмите **Send**

#### 2. Авторизация
- Откройте запрос **Login**
- Используйте те же учетные данные
- После успешного входа скопируйте `access_token` из ответа
- Перейдите в **Env** → **Local** → вставьте токен в переменную `access_token`

#### 3. Защищенные запросы
- Теперь можете выполнять запросы:
  - **Get Current User**
  - **Get All Characters**
  - **Create Character**

## 4. Горячие клавиши Thunder Client

- `Cmd+Enter` - отправить запрос
- `Cmd+S` - сохранить запрос
- `Cmd+D` - дублировать запрос
- `Cmd+Shift+E` - переключиться на окружение

## 5. Альтернатива: REST Client (.http файлы)

Если предпочитаете работать с .http файлами, создайте файл `api-tests.http`:

```http
### Register
POST http://localhost:8000/auth/register
Content-Type: application/json

{
  "email": "test@example.com",
  "username": "testuser",
  "password": "testpass123"
}

### Login
POST http://localhost:8000/auth/login
Content-Type: application/x-www-form-urlencoded

username=testuser&password=testpass123

### Get Current User
GET http://localhost:8000/auth/me
Authorization: Bearer YOUR_TOKEN_HERE

### Get Characters
GET http://localhost:8000/characters/
Authorization: Bearer YOUR_TOKEN_HERE

### Create Character
POST http://localhost:8000/characters/
Authorization: Bearer YOUR_TOKEN_HERE
Content-Type: application/json

{
  "name": "Commander Alpha",
  "class": "SOLDIER"
}
```

Для использования установите расширение **REST Client** и кликайте на **Send Request** над каждым запросом.