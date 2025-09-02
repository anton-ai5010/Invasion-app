# Invasion Universe Booking System

## Project Overview

This project is a comprehensive booking and management system for the "Invasion Universe" computer club. It consists of a full-stack application with a separate mobile client for users and a web-based administrative panel for staff.

The architecture is composed of:
*   **Backend API:** A robust API built with Python and the **FastAPI** framework. It handles all business logic, including user authentication (JWT), zone and seat management, booking, and administrative functions.
*   **Database:** A **PostgreSQL** database for persistent data storage, managed with **Alembic** for schema migrations.
*   **Cache / Locking:** **Redis** is used for caching and to handle concurrency control for bookings, preventing double-booking of the same time slot.
*   **Mobile App (iOS/Android):** A cross-platform mobile application for users, built with **Flutter**. It allows users to view zones, check seat availability, make bookings, and manage their reservations.
*   **Admin Web App:** A separate web-based administrative interface, also built with **Flutter Web**. It provides staff with tools to view daily bookings, manage their status (e.g., mark as paid, completed), and perform bulk administrative tasks like updating seat prices.
*   **Containerization:** The entire backend stack (API, PostgreSQL, Redis) is containerized using **Docker** and orchestrated with **Docker Compose**, ensuring a consistent and reproducible development environment.

## Building and Running

The project is divided into a backend and a frontend (`iu_mobile` directory), which contains both the user mobile app and the admin web app.

### 1. Running the Backend

The backend services are managed by Docker Compose.

```bash
# From the project root directory (/Users/cooldom/Dev/invasion_universe)
# This command builds the containers and starts the API, database, and Redis.
docker compose up --build
```

*   **API Endpoint:** `http://localhost:8000`
*   **API Documentation (Swagger UI):** `http://localhost:8000/docs`

### 2. Running the Mobile App (for Users)

The user-facing mobile app is a Flutter application.

```bash
# Navigate to the mobile app directory
cd iu_mobile

# Run on the selected emulator (e.g., 'ios', 'android')
flutter run
```

*   The app is pre-configured to connect to `http://localhost:8000` on the iOS Simulator and `http://10.0.2.2:8000` on the Android Emulator.

### 3. Running the Admin Web App

The administrative panel is a separate Flutter web application.

```bash
# Navigate to the mobile app directory
cd iu_mobile

# Run the admin app specifically, targeting a web browser
flutter run -d chrome -t lib/admin_app.dart
```

*   The admin app will open in Chrome and is configured to connect to the local backend API.

## Development Conventions

*   **Backend:**
    *   The API follows a standard structure separating `models` (SQLAlchemy), `schemas` (Pydantic), `services` (business logic), and `api/routes` (endpoints).
    *   Database migrations are handled by Alembic. New model changes require a new migration script.
    *   Error handling is centralized in `utils/errors.py` and supports i18n for user-facing messages (RU/EN).
    *   Dependencies are managed in `backend/requirements.txt`.

*   **Frontend (Flutter):**
    *   The project contains two separate entry points: `lib/main.dart` for the user app and `lib/admin_app.dart` for the admin panel.
    *   A shared `Api` class in `lib/api.dart` encapsulates all communication with the backend.
    *   The app uses `shared_preferences` for local storage of the JWT authentication token.
    *   Local notifications are used to remind users of upcoming bookings.
    *   Offline capability is partially supported by caching zone and layout data locally.
Ты — аналитик бизнес-требований и технический архитектор. Твоя задача — провести первичное интервью с заказчиком, чтобы собрать ключевые данные для подготовки общей спецификации мобильного приложения для компьютерного клуба Invasion Universe, которое будет выложено в App Store и Google Play. Проанализируй действующий сайт (указать ссылку: {{https://uni.invasion.ru/}}), выяви сильные и слабые стороны, и на основе этого предложи концепцию мобильного приложения, включающую оригинальные функции и «фишки», которые повысят вовлечённость пользователей и подчеркнут уникальность клуба. Структура результата: Общее описание проекта — цель создания приложения, ожидаемый эффект для бизнеса. Профиль целевой аудитории — кто пользователи, какие сценарии использования у них приоритетны. Основные модули приложения — перечисли ключевые разделы (например: бронь компьютеров, афиша турниров, личный кабинет, бонусная система, магазин и т. п.) Уникальные фичи — предложи минимум 3 оригинальных функции, которых нет у конкурентов (например, внутриигровой рейтинг, AR-тур по клубу и др.) Интеграции и технические особенности — укажи необходимые внешние сервисы (оплата, push-уведомления, карта зала и т. д.) Визуальные и UX-ориентиры — предложи стилистическое направление и подход к навигации, ориентируясь на геймерскую аудиторию. План выкладки и поддержки — кратко опиши требования к публикации в App Store / Play Market, заложи процессы обновления и поддержки. Вопросы к заказчику — сформулируй список уточняющих вопросов, без которых невозможно перейти к техническому проектированию (например: есть ли у клуба CRM, кто будет заниматься контентом, нужна ли локализация и т. п.)