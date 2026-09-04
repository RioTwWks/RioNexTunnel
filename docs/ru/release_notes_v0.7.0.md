# RioNexTunnel v0.7.0 — примечания к выпуску

**Дата:** 2026-09-04  
[English version](../en/release_notes_v0.7.0.md) · Русский

---

## Главное

- **Цензуроустойчивость (P1)** — сохранение XHTTP в JSON-подписках, автоматический fallback по транспортным стекам, платформенный ранжировщик серверов и честные замеры задержки.
- **Транспорт XHTTP** — полные JSON-подписки сохраняют `path`, `host` и прочие поля XHTTP; `mode: auto` приводится к `stream-one` при подключении ([#69](https://github.com/RioTwWks/RioNexTunnel/pull/69)).
- **Авто-fallback протокола** — упорядоченный перебор стеков (XHTTP+Reality → TLS+mux → TCP+Vision → AmneziaWG), ротация при переподключении и статистика успеха по стекам ([#68](https://github.com/RioTwWks/RioNexTunnel/pull/68)).
- **Платформа и ядро** — на iOS XHTTP понижен в авто-выборе; `CoreVersionGate` предупреждает, если Xray старее пина в `fetch_cores.sh`; политика только официального Xray ([#67](https://github.com/RioTwWks/RioNexTunnel/pull/67)).
- **Mux и desktop proxy** — документация EN/RU о том, когда mux нужен; `PingConfigBuilder` убирает mux из проб, чтобы сравнивать базовый транспорт ([#66](https://github.com/RioTwWks/RioNexTunnel/pull/66)).

Опирается на работу **v0.6.0** по RioNexGate (удалённые команды, устойчивая синхронизация, режимы SOCKS).

---

## Цензуроустойчивость

### Транспорт XHTTP (PR #69)

Провайдеры всё чаще отдают узлы **VLESS + REALITY + XHTTP** как полный JSON (массив v2rayNG или один объект), а не share-ссылку. `ConfigParser.injectSecureSocksInbound` теперь нормализует XHTTP для обоих движков при connect:

| Движок | Где транспорт | Поле mode |
|--------|---------------|-----------|
| Xray | `outbounds[].streamSettings.network: "xhttp"` + `xhttpSettings` | `xhttpSettings.mode` |
| sing-box | `outbounds[].transport.type: "xhttp"` | `transport.mode` |

- **`path`, `host` и остальные ключи XHTTP** из подписки сохраняются — не пересобираются из дефолтов.
- Отсутствующий или **`mode: auto`** приводится к **`stream-one`** (как у `vless://` через `LinkConfigBuilder`).
- `configHasXhttpAutoMode()` находит подписки с `auto` до нормализации (для диагностики).

### Mux и desktop proxy (PR #66)

**Mux** (мультиплексирование) по-прежнему включается в мастере цензуроустойчивости — полезен в сетях оператора с **VLESS + TLS**, но на десктопе обычно не нужен, если доступен XHTTP.

- Новый раздел **Desktop proxy mode и mux** в [censorship_resistance.md](censorship_resistance.md).
- **`PingConfigBuilder`** убирает `mux` / `multiplex` из временных конфигов проб — выбор сервера и **Авто (лучшая задержка)** сравнивают базовый RTT транспорта.
- Настройка mux в профиле по-прежнему применяется при **Connect** через `ConfigEnhancer`.

### Авто-fallback протокола (PR #68)

Если в подписке для одного хоста несколько вариантов транспорта (например, отдельные узлы XHTTP и Vision для `cdn.example.com`), RioNexTunnel группирует их в **логические серверы** и при сбое connect перебирает стеки по порядку.

**`TransportStackClassifier`** помечает каждую запись:

| Стек | Тег | Приоритет по умолчанию |
|------|-----|------------------------|
| VLESS + REALITY + XHTTP | `XHTTP` | 0 (первый) |
| VLESS + TLS + mux | `TLS+mux` | 1 |
| TCP + REALITY + Vision | `Vision` | 2 |
| AmneziaWG / WireGuard | `AmneziaWG` | 3 |

**`SubscriptionManager`** группирует строки подписки по хосту (`serverKey`) или нормализованному имени, убирает дубликаты стеков и упорядочивает кандидатов с учётом сохранённой статистики.

**Поток connect в `VpnService`:**

1. Получить упорядоченный список проб для выбранного сервера.
2. Пробовать каждый стек; при ошибке — лог и переход к следующему с экспоненциальной задержкой.
3. При **переподключении** после обрыва — переход к **следующему стеку** в ротации.
4. Записывать успех/неудачу и задержку в **`TransportStackStore`** (`SharedPreferences`, ключ `transport_stack_stats_v1`).

**Выбор сервера** показывает логические записи с тегами стеков, например `Мой узел (XHTTP · Vision)`.

### Платформа и ядро (PR #67)

**`PlatformTransportSelector`** корректирует ранжирование **Авто (лучшая задержка)**:

| Платформа | Предпочтительный стек при нескольких доступных |
|-----------|--------------------------------------------------|
| iOS | TCP + REALITY + Vision |
| Android / desktop | XHTTP + REALITY |

На iOS записи XHTTP+REALITY получают наименьший приоритет (100), если в том же наборе проб есть узлы с Vision. Это **только ранжирование серверов** — не цепочка fallback при connect.

**`CoreVersionGate`** сравнивает версию Xray с `DEFAULT_XRAY_VERSION` в `scripts/fetch_cores.sh` (сейчас **26.3.27**):

- Неблокирующее предупреждение при connect с XHTTP на старом ядре.
- **Настройки → Ядро** напоминает выполнить `./scripts/fetch_cores.sh`.

**Только официальный Xray-core** — кастомные сборки (например, REALITY-rkn-fix) не используются. Защита — выбор транспорта, отпечатки uTLS и конфигурация на стороне сервера.

---

## Тестирование и надёжность

Из каталога `secure_vpn_client/`:

```bash
flutter analyze
flutter test test/config_parser_test.dart
flutter test test/ping_config_builder_test.dart
flutter test test/censorship_transport_test.dart
flutter test test/subscription_manager_test.dart
flutter test test/protocol_fallback_test.dart
flutter test test/platform_transport_selector_test.dart
flutter test test/core_version_gate_test.dart
```

| Файл | Покрытие |
|------|----------|
| `config_parser_test.dart` | Сохранение полей XHTTP, `mode: auto` → `stream-one`, JSON Xray + sing-box |
| `ping_config_builder_test.dart` | Удаление mux из конфигов проб задержки |
| `censorship_transport_test.dart` | Определение пресетов и доработка ссылок |
| `subscription_manager_test.dart` | Группировка серверов, дедуп стеков, порядок по статистике |
| `protocol_fallback_test.dart` | Имитация сбоя connect → fallback на второй стек |
| `platform_transport_selector_test.dart` | Приоритет стеков iOS vs остальные в `selectBest` |
| `core_version_gate_test.dart` | Сравнение semver с пином `fetch_cores.sh` |

Тесты панели из v0.6.0 (`panel_*_test.dart`) и `security_test.dart` без изменений.

---

## Безопасность

Базовые инварианты **не изменились** в v0.7.0:

| Принцип | Реализация |
|---------|------------|
| Только localhost | SOCKS/HTTP на `127.0.0.1` — не `0.0.0.0` |
| Обязательная auth | Пароль на каждом локальном прокси |
| Нет открытого 7890 | Неаутентифицированный SOCKS отклоняется в `ConfigParser.validateSecure()` |
| Жизненный цикл учётных данных | SOCKS-сессия стирается при disconnect; `active_config.json` удаляется |
| Без логирования секретов | Пароли, секреты транспорта и токены панели не логируются |

**Для цензуроустойчивости:**

- Статистика стеков хранит **только успехи и задержку** — без секретов outbound.
- Только **официальные** бинарники Xray из `scripts/fetch_cores.sh`.
- RU direct по-прежнему требует geo-ассеты и fail-closed при их отсутствии.

Проверка после connect:

```bash
./scripts/security_probe.sh 1080
```

См. [security.md](security.md).

---

## Обновление

**Критичных breaking changes не ожидается.** Надстройка над v0.6.0 без изменения поведения RioNexGate.

1. **Текущие пользователи** — подписки и share-ссылки работают как раньше; JSON-узлы XHTTP теперь подключаются с сохранёнными полями сервера.
2. **Пользователи XHTTP** — выполните `./scripts/fetch_cores.sh` из корня репозитория, если в настройках есть предупреждение о версии ядра, затем пересоберите приложение.
3. **Подписки с несколькими стеками** — включите **Авто (лучшая задержка)** или выберите логический сервер; при сбое connect автоматически пробуются альтернативные стеки.
4. **Desktop** — mux необязателен; предпочитайте XHTTP, если провайдер его отдаёт. См. [censorship_resistance.md](censorship_resistance.md).
5. **iOS** — при сбое XHTTP+REALITY выберите узел Vision вручную или полагайтесь на понижение XHTTP в авто-выборе, когда оба варианта есть.

---

## Известные ограничения

- **Пробел XHTTP на iOS** — XHTTP+REALITY понижен в авто-выборе и может быть ненадёжен в Network Extensions; предпочитайте TCP+REALITY+Vision, когда доступен. Если в подписке только XHTTP, iOS всё равно подключается к лучшему доступному узлу XHTTP.
- **Порядок fallback vs авто-выбор** — fallback при connect (`TransportStackClassifier`: сначала XHTTP) и авто-выбор на iOS (`PlatformTransportSelector`: сначала Vision) — **разные пути кода**. В будущем порядок стеков будет унифицирован, чтобы переподключение учитывало платформенные предпочтения.
- **AmneziaWG** — классифицируется и входит в порядок fallback, но полная поддержка клиента AmneziaWG остаётся в планах (tasks §5).
- **Документация платформы и ядра** — подробный раздел **Platform & engine policy** из PR #67 может быть добавлен в [censorship_resistance.md](censorship_resistance.md) отдельным doc-PR.

---

## Связанная документация

| Тема | English | Русский |
|------|---------|---------|
| Цензуроустойчивость | [censorship_resistance.md](../en/censorship_resistance.md) | [censorship_resistance.md](censorship_resistance.md) |
| Безопасность | [security.md](../en/security.md) | [security.md](security.md) |
| Linux desktop / proxy mode | [linux_setup.md](../en/linux_setup.md) | [linux_setup.md](linux_setup.md) |
| Устранение неполадок | [troubleshooting.md](../en/troubleshooting.md) | [troubleshooting.md](troubleshooting.md) |
| Примечания v0.6.0 | [release_notes_v0.6.0.md](../en/release_notes_v0.6.0.md) | [release_notes_v0.6.0.md](release_notes_v0.6.0.md) |

### Pull request'ы в этом выпуске

- [#69](https://github.com/RioTwWks/RioNexTunnel/pull/69) — XHTTP: сохранение полей JSON-подписки в ConfigParser
- [#68](https://github.com/RioTwWks/RioNexTunnel/pull/68) — Авто-fallback протокола со статистикой стеков
- [#67](https://github.com/RioTwWks/RioNexTunnel/pull/67) — Платформенный селектор транспорта и проверка версии Xray
- [#66](https://github.com/RioTwWks/RioNexTunnel/pull/66) — Документация mux и честные пробы задержки
