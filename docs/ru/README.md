# Secure VPN Client (MVP)

**Кроссплатформенный VPN-клиент на Flutter с поддержкой Xray-core и sing-box**  
*Защита от уязвимости неавторизованного локального SOCKS5-прокси (март 2026)*

[![Flutter](https://img.shields.io/badge/Flutter-3.22+-blue.svg)](https://flutter.dev)
[![Xray-core](https://img.shields.io/badge/Xray--core-1.8.24+-green.svg)](https://github.com/XTLS/Xray-core)
[![sing-box](https://img.shields.io/badge/sing--box-1.10+-orange.svg)](https://github.com/SagerNet/sing-box)
[![License](https://img.shields.io/badge/License-GPLv3-blue.svg)](../../LICENSE)

[English version](../en/README.md)

---

## Описание

**Secure VPN Client** — безопасный и гибкий VPN-клиент, разработанный в рамках MVP. Приложение подключается к VPN-серверам по протоколам VLESS, VMess, Shadowsocks, Trojan, Hysteria/Hysteria2, TUIC, WireGuard, SSH и другим (через ядра Xray-core и sing-box). Главное отличие от многих существующих клиентов — **полное устранение уязвимости неаутентифицированного локального SOCKS5-прокси**, обнаруженной весной 2026 года в Hiddify, v2rayNG, Happ и др.

Проект создан на Flutter для пяти платформ: **Android, iOS, Windows, Linux, macOS**.

---

## Ключевые особенности безопасности

- **Динамическая аутентификация SOCKS5** — уникальная пара логин/пароль на каждую сессию VPN; учётные данные не сохраняются на диске и уничтожаются после остановки.
- **Запрет доступа для сторонних приложений** — локальный прокси привязан только к `127.0.0.1` и требует авторизации. На Android (VPN mode) белый список пакетов (`allowApps`) ограничивает доступ к прокси.
- **Отсутствие открытых портов** — приложение **не** слушает `0.0.0.0` и **не** оставляет порт `7890` без пароля. На каждую сессию: порт `1080` (SOCKS) и `1081` (HTTP на desktop) со случайными учётными данными.
- **Переключение ядер** — Xray-core или sing-box через единый безопасный враппер.

---

## Технологический стек

| Компонент | Технология |
|-----------|------------|
| Интерфейс и логика | Flutter (Dart) |
| VPN-туннелирование | Локальный форк [`packages/v2ray_box`](../../packages/v2ray_box) |
| Ядро 1 | [Xray-core](https://github.com/XTLS/Xray-core) (Go, subprocess) |
| Ядро 2 | [sing-box](https://github.com/SagerNet/sing-box) (Go, subprocess) |
| Нативные мосты | Android (Kotlin), iOS/macOS (Swift), Linux/Windows (C++ plugin) |

---

## Документация

| Руководство | Описание |
|-------------|----------|
| [Быстрый старт](getting_started.md) | Клонирование, зависимости, ядра, запуск |
| [Настройка Linux](linux_setup.md) | Proxy mode, расширение браузера |
| [Настройка Android](android_setup.md) | VPN mode, manifest, jniLibs |
| [Настройка iOS](ios_setup.md) | Network Extensions, entitlements |
| [Архитектура](architecture.md) | Компоненты и поток данных |
| [Безопасность](security.md) | Модель SOCKS-аутентификации |
| [Расширение браузера](browser_extension.md) | Авто-авторизация прокси |
| [Устранение неполадок](troubleshooting.md) | Типичные ошибки и решения |
| [Участие в разработке](contributing.md) | Чеклист PR и пути правок |

---

## Структура репозитория

```
Secure-Cross-Platform-VPN-Client/
├── secure_vpn_client/       # Flutter-приложение
├── packages/v2ray_box/      # Форк плагина
├── scripts/                 # fetch_cores.sh, security_probe.sh
├── docs/en/                 # Документация (английский)
├── docs/ru/                 # Документация (русский, эта папка)
└── .cursor/                 # Документация для AI-агентов
```

---

## Планы развития (после MVP)

- [x] Подписки (engine-specific User-Agent)
- [x] Переключение ядер xray / sing-box
- [x] Модульные тесты безопасности
- [x] Linux desktop: proxy mode, все 4 комбинации engine × profile
- [x] Выбор сервера из списка подписки
- [x] Автовыбор сервера с лучшей задержкой
- [x] Автовыбор ядра (доступность / формат / fallback connect)
- [ ] Полноценный E2E на Android / iOS / Windows / macOS
- [ ] CI: `flutter analyze` + `flutter test`

---

## Вклад в проект

1. `flutter analyze` должен проходить без ошибок.
2. Добавьте тесты для новой функциональности безопасности.
3. Проверьте, что уязвимость SOCKS5 не возвращается (`test/security_test.dart`).

---

## Лицензия

**GNU General Public License v3.0** (GPLv3) — см. [LICENSE](../../LICENSE).

---

## Отказ от ответственности

Программное обеспечение предоставляется «как есть» в образовательных и исследовательских целях. Разработчики не несут ответственности за незаконное использование. Пользователь должен соблюдать законодательство своей страны.

---

## Благодарности

- Команде **XTLS** за Xray-core
- **SagerNet** за sing-box
- Авторам плагина **v2ray_box** (форк)
- Сообществу Flutter
