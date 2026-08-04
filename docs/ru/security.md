# Безопасность

[English version](../en/security.md)

## Контекст угрозы (март 2026)

Несколько популярных VPN-клиентов открывали **неаутентифицированный локальный SOCKS5** (часто `0.0.0.0:7890`). Любое приложение на устройстве или в LAN могло:

- Читать реальный IP через прокси
- Извлекать конфигурацию VPN и правила маршрутизации

**Secure VPN Client** спроектирован так, чтобы быть невосприимчивым к этому классу уязвимостей.

## Принципы проектирования

| Правило | Реализация |
|---------|------------|
| Только localhost | Inbound на `127.0.0.1`, никогда `0.0.0.0` |
| Обязательная аутентификация | SOCKS/HTTP inbound с `auth: password` и per-session creds |
| Без сохранения creds | `CredentialService` генерирует CSPRNG; стирание при disconnect |
| Без логирования creds | Передача через platform channel / env vars, не в логи и не на диск |
| Desktop proxy mode | Linux/Windows/macOS — `VpnMode.proxy`, не открытый TUN |

## Учётные данные на сессию

При каждом **Connect**:

1. `CredentialService` генерирует случайный логин и пароль.
2. `ConfigParser.injectSecureSocksInbound()` внедряет их в конфиг ядра.
3. Нативная сторона получает creds через channel `secure_vpn/credentials` (Linux: env vars для child).
4. При **Disconnect** creds и `active_config.json` стираются.

Это **локальные учётные данные прокси**, не аккаунт VPN-сервера.

## Порты (Linux desktop)

| Порт | Протокол | Использование |
|------|----------|---------------|
| `1080` | SOCKS5 + auth | Прямые SOCKS-клиенты |
| `1081` | HTTP + auth | Системный прокси GNOME |

## Проверка

### 1. Скрипт security_probe

При подключённом VPN:

```bash
./scripts/security_probe.sh 1080
```

Неавторизованное подключение должно **завершиться ошибкой**.

### 2. Ручная проверка curl

```bash
# Без auth — должна быть ошибка или реальный IP без маршрутизации
curl --socks5 127.0.0.1:1080 https://api.ipify.org

# С неверным паролем — ошибка
curl --socks5 127.0.0.1:1080 --socks5-basic --proxy-user wrong:wrong https://api.ipify.org
```

### 3. Unit-тесты

```bash
cd secure_vpn_client
flutter test test/security_test.dart
flutter test test/config_parser_test.dart
```

Тесты проверяют:

- Inbound на `127.0.0.1`
- `auth` = `password`
- Creds в конфиге только при активной сессии

## Авторизация прокси в браузере (Linux)

Chromium игнорирует пароли прокси из GSettings. Используйте [расширение браузера](browser_extension.md) или копируйте creds из UI приложения.

## Сообщение об уязвимостях

Не открывайте публичные issues для нераскрытых уязвимостей. Свяжитесь с maintainers приватно.
