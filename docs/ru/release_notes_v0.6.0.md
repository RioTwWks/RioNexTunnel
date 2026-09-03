# RioNexTunnel v0.6.0 — примечания к выпуску

**Дата:** 2026-09-03  
[English version](../en/release_notes_v0.6.0.md) · Русский

---

## Главное

- **Интеграция RioNexGate (фазы 2–4)** — удалённые команды, устойчивая синхронизация конфига, режимы SOCKS-аутентификации и автотесты поверх MVP v0.5.0.
- **Удалённые команды** — WebSocket с fallback на long-poll для `refresh_config`, `disconnect` и `switch_server` ([#61](https://github.com/RioTwWks/RioNexTunnel/pull/61)).
- **Устойчивая синхронизация** — битый JSON панели не роняет клиент; офлайн-кэш и повторная отправка очереди статистики ([#62](https://github.com/RioTwWks/RioNexTunnel/pull/62)).
- **Режимы SOCKS5** — случайные на сессию (по умолчанию), статичные из панели или отключение подмены inbound для расширенных сценариев ([#63](https://github.com/RioTwWks/RioNexTunnel/pull/63)).
- **Документация по тестам панели** — руководство EN/RU для CI и опциональной проверки с живой панелью ([rionexgate_testing.md](rionexgate_testing.md)).

---

## Интеграция RioNexGate

RioNexTunnel по-прежнему универсальный VPN-клиент. Сопряжение с панелью **опционально** — без настройки RioNexGate поведение не меняется относительно v0.5.x.

В этом выпуске завершён клиентский трек из tasks §2.1–2.5 (на базе MVP v0.5.0, PR [#51](https://github.com/RioTwWks/RioNexTunnel/pull/51)).

### Регистрация и синхронизация конфига

- **Настройки → RioNexGate (опционально)** — URL панели, токен сопряжения, **Зарегистрировать**, ручное **Обновить** и **Сбросить сопряжение**.
- REST-клиент **`PanelManager`** — `POST /api/client/register`, `GET /api/client/config`, `POST /api/client/stats` с заголовком `X-API-Version: v1`, таймаутами и экспоненциальными повторами (до 4 попыток).
- **Сравнение `config_hash`** — без перезаписи кэша, если хеш не изменился; URL подписки применяется к профилю **RioNexGate** через стандартный пайплайн `ConfigParser`.
- **Офлайн-кэш** — последний рабочий конфиг на диске; карточка статуса: **Synced**, **Cached (stale)**, **Offline** или **Error** (`PanelSyncStatus`).
- **Битый JSON** — некорректный `config` логируется, прежний кэш и хеш сохраняются, показывается ненавязчивое предупреждение (без падения приложения).

### Загрузка статистики

- Bytes in/out с счётчиков ядра при **отключении**, отправка с уникальным `session_id` на сессию.
- **Локальная очередь** при недоступности панели; **пакетный replay** через `flushStats()` после восстановления связи.
- В payload статистики нет паролей SOCKS и секретов транспорта.

### Удалённые команды (push)

- **`PanelCommandService`** — предпочитает WebSocket: `wss://<panel>/api/client/commands` с `Authorization: Bearer <device_token>`.
- **Обрабатываемые команды:** `refresh_config`, `disconnect`, `switch_server` (опционально `server_index` / `server_name`).
- **Fallback** — long poll `GET /api/client/commands?last_seq=...` примерно каждые 5 минут, если WebSocket недоступен; задержка переподключения ~30 с.
- Команды делегируются существующим путям `VpnService` / обновления профиля — без дублирования логики connect.
- Номера последовательности (`seq`) сохраняются локально, чтобы не повторять уже выполненные команды.

### Режимы SOCKS5

Новая настройка: **Настройки → SOCKS5 аутентификация**

| Режим | Поведение |
|-------|-----------|
| **Случайные на сессию** (по умолчанию) | Новый логин/пароль при каждом connect через `CredentialService` и `injectSecureSocksInbound`. |
| **Статичные из панели** | Учётные данные SOCKS из JSON RioNexGate, если указаны; иначе fallback на случайный режим. |
| **Отключить подмену SOCKS (расширенное)** | Пропуск secure inbound для «сломанных» сторонних конфигов (опция на экране Config при ручном импорте). |

Если панель передаёт параметры SOCKS, порт выравнивается перед connect. Базовое правило неизменно: **только `127.0.0.1`, пароль обязателен**.

---

## Тестирование и надёжность

### Автотесты (CI)

Из каталога `secure_vpn_client/`:

```bash
flutter analyze
flutter test test/panel_manager_test.dart
flutter test test/panel_integration_test.dart
flutter test test/panel_command_service_test.dart
```

| Файл | Покрытие |
|------|----------|
| `panel_manager_test.dart` | Регистрация, skip/update по `config_hash`, flush очереди stats |
| `panel_integration_test.dart` | Полный цикл с `FakePanelServer`; офлайн-кэш; битый JSON; Riverpod `refreshConfig` |
| `panel_command_service_test.dart` | Разбор команд, порядок по `seq`, dispatch WebSocket/long-poll |

Подробности — в [rionexgate_testing.md](rionexgate_testing.md).

### Улучшения надёжности (PR #62)

- Панель offline → кэш сохраняется; stats в очереди и отправляются при восстановлении сети.
- Плохой JSON → без исключения; активный профиль не сбрасывается.
- Новый `config_hash` → обновление кэша и URL профиля **RioNexGate** без перезапуска приложения.

---

## Безопасность

Базовые инварианты в v0.6.0 **не изменились**:

| Принцип | Реализация |
|---------|------------|
| Только localhost | SOCKS/HTTP на `127.0.0.1` — никогда `0.0.0.0` |
| Обязательная auth | Пароль на каждом локальном прокси |
| Нет порта 7890 | Неаутентифицированный SOCKS отклоняется в `validateSecure()` |
| Жизненный цикл credentials | SOCKS-сессия стирается при disconnect; удаляется `active_config.json` |
| Без логирования секретов | Пароли и `device_token` не попадают в release-логи |

**Разделение для панели:**

- **Device token** — только для REST/WebSocket RioNexGate (`Authorization: Bearer …`). Хранится локально вместе с URL панели и URL подписки; не смешивается с auth транспорта VPN.
- **Auth транспорта** — VLESS/VMess/Trojan и т.д. из подписки или share-ссылок, без изменений.
- **SOCKS auth** — по-прежнему обязательна на localhost; режим «статичные из панели» использует пароль из JSON панели, но binding остаётся `127.0.0.1`.

Проверка после connect:

```bash
./scripts/security_probe.sh 1080
```

См. [security.md](security.md).

---

## Обновление

**Breaking changes не ожидаются.** RioNexGate опционален.

1. **Текущие пользователи** — действий не требуется; ручные ссылки и сторонние подписки работают как раньше.
2. **Пользователи панели** — обновитесь до v0.6.0 для удалённых команд и настроек SOCKS. Повторная регистрация нужна только при ротации pairing token администратором.
3. **Режим SOCKS** — по умолчанию **Случайные на сессию** (рекомендуется). **Статичные из панели** — только если JSON RioNexGate содержит matching SOCKS inbound.
4. **Десктоп** — перед connect с geo-правилами или пресетами обхода выполните `./scripts/fetch_cores.sh` (как в v0.5.x).

---

## Известные ограничения

- **Фоновый flush stats (~60 с)** — не реализован; отправка при **disconnect** и при flush очереди после восстановления связи (tasks §2.3).
- **Периодическая sync конфига** — только ручное **Обновить**; фоновый таймер ещё не подключён.
- **Полное применение JSON конфига** — JSON панели валидируется и кэшируется; основной путь — **URL подписки → Profile** (прямая инъекция raw JSON — в планах).
- **Схема JSON сервера** — клиент ориентирован на API RioNexGate v1; лишние поля игнорируются, но некорректные структуры могут пропустить обновление (кэш сохраняется).
- **Документация** — сброс сопряжения с панелью не удаляет вручную импортированные профили (бэклог tasks §2.7).

---

## Связанная документация

| Тема | English | Русский |
|------|---------|---------|
| Тесты панели | [rionexgate_testing.md](../en/rionexgate_testing.md) | [rionexgate_testing.md](rionexgate_testing.md) |
| Безопасность | [security.md](../en/security.md) | [security.md](security.md) |
| Архитектура | [architecture.md](../en/architecture.md) | [architecture.md](architecture.md) |
| Устранение неполадок | [troubleshooting.md](../en/troubleshooting.md) | [troubleshooting.md](troubleshooting.md) |
| Сервер RioNexGate | [github.com/RioTwWks/RioNexGate](https://github.com/RioTwWks/RioNexGate) | тот же |

### Pull request'ы этого выпуска

- [#61](https://github.com/RioTwWks/RioNexTunnel/pull/61) — удалённые команды (WebSocket + long-poll)
- [#62](https://github.com/RioTwWks/RioNexTunnel/pull/62) — интеграционные тесты и устойчивая sync конфига
- [#63](https://github.com/RioTwWks/RioNexTunnel/pull/63) — режимы SOCKS5 (random / static / disable injection)
