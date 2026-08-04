# Secure VPN Client (MVP)

**Кроссплатформенный VPN-клиент на Flutter с поддержкой Xray-core и sing-box**  
*Реализована защита от уязвимости неавторизованного SOCKS5-прокси (март 2026)*

[English](README.en.md) · [Документация](docs/ru/README.md)

[![Flutter](https://img.shields.io/badge/Flutter-3.22+-blue.svg)](https://flutter.dev)
[![Xray-core](https://img.shields.io/badge/Xray--core-1.8.24+-green.svg)](https://github.com/XTLS/Xray-core)
[![sing-box](https://img.shields.io/badge/sing--box-1.10+-orange.svg)](https://github.com/SagerNet/sing-box)
[![License](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

---

## Описание

**Secure VPN Client** — безопасный и гибкий VPN-клиент (MVP). Подключение к серверам по протоколам VLESS, VMess, Shadowsocks, Trojan и другим через ядра Xray-core и sing-box. Главное отличие от многих клиентов — **устранение уязвимости неаутентифицированного локального SOCKS5-прокси** (весна 2026: Hiddify, v2rayNG, Happ и др.).

Платформы: **Android, iOS, Windows, Linux, macOS**.

Полная документация: [docs/ru/](docs/ru/README.md)

---

## Ключевые особенности безопасности

- **Динамическая аутентификация SOCKS5** — уникальная пара логин/пароль на каждый запуск VPN; не сохраняется на диске; уничтожается после остановки.
- **Только localhost** — прокси на `127.0.0.1` с обязательной авторизацией.
- **Нет открытых портов** — не слушаем `0.0.0.0`, не оставляем порт `7890` без пароля.
- **Переключение ядер** — Xray-core или sing-box через единый безопасный враппер.

Подробнее: [docs/ru/security.md](docs/ru/security.md)

---

## Технологический стек

| Компонент | Технология |
|-----------|------------|
| Интерфейс и логика | Flutter (Dart) |
| VPN-туннелирование | Локальный форк [`packages/v2ray_box`](packages/v2ray_box) |
| Ядро 1 | [Xray-core](https://github.com/XTLS/Xray-core) |
| Ядро 2 | [sing-box](https://github.com/SagerNet/sing-box) |
| Нативные мосты | Android (Kotlin), iOS/macOS (Swift), Linux/Windows (C++ plugin) |

---

## Быстрый старт

```bash
git clone https://github.com/RioTwWks/Secure-Cross-Platform-VPN-Client.git
cd Secure-Cross-Platform-VPN-Client
./scripts/fetch_cores.sh
cd secure_vpn_client
flutter pub get
flutter run -d linux    # или android / windows / macos / ios
```

Подробно: [docs/ru/getting-started.md](docs/ru/getting-started.md)

| Платформа | Руководство |
|-----------|-------------|
| Linux | [docs/ru/linux_setup.md](docs/ru/linux_setup.md) |
| Android | [docs/ru/android_setup.md](docs/ru/android_setup.md) |
| iOS | [docs/ru/ios_setup.md](docs/ru/ios_setup.md) |
| Расширение браузера | [docs/ru/browser-extension.md](docs/ru/browser-extension.md) |

> Для AI-агентов (Cursor): [.cursor/AGENTS.md](.cursor/AGENTS.md)

---

## Тестирование безопасности

```bash
# При активном VPN, из корня репозитория
./scripts/security_probe.sh 1080
```

Неавторизованное подключение к локальному SOCKS должно завершаться ошибкой. См. [docs/ru/security.md](docs/ru/security.md).

---

## Структура репозитория

```
Secure-Cross-Platform-VPN-Client/
├── secure_vpn_client/            # Flutter-приложение
├── packages/v2ray_box/           # Форк плагина
├── scripts/                      # fetch_cores, security_probe, sync
├── docs/en/ · docs/ru/           # Документация (EN / RU)
├── extensions/                   # Browser helper (Linux)
└── .cursor/                      # Документация для AI-агентов
```

---

## Планы развития (после MVP)

- [x] Подписки, переключение ядер, тесты безопасности
- [x] Linux desktop: proxy mode, 4 комбинации engine × profile
- [ ] Выбор сервера из списка подписки
- [ ] E2E на Android / iOS / Windows / macOS
- [ ] Split tunneling на мобильных платформах
- [ ] CI: `flutter analyze` + `flutter test`

Backlog: [.cursor/tasks.md](.cursor/tasks.md)

---

## Вклад в проект

См. [docs/ru/contributing.md](docs/ru/contributing.md). Перед PR: `flutter analyze` и `flutter test` в `secure_vpn_client/`.

---

## Лицензия и отказ от ответственности

**GNU GPLv3** — [LICENSE](LICENSE).

ПО предоставляется «как есть» в образовательных и исследовательских целях. Пользователь обязан соблюдать законодательство своей страны.

## Благодарности

XTLS (Xray-core), SagerNet (sing-box), авторы `v2ray_box`, сообщество Flutter.
