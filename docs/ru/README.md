<p align="center">
  <img src="../../secure_vpn_client/assets/images/app_logo.png" alt="Логотип RioNexTunnel" width="220">
</p>

# RioNexTunnel

<p align="right">
  <a href="../en/README.md"><img src="https://img.shields.io/badge/lang-English-blue?style=for-the-badge" alt="English version"></a>
</p>


**Кроссплатформенный VPN-клиент на Flutter с поддержкой Xray-core и sing-box**  
*RIO — надёжная интернет-прослойка. Nexus + Tunnel — «связующий туннель».*  
*Защита от уязвимости неавторизованного локального SOCKS5-прокси (март 2026)*

[![Flutter](https://img.shields.io/badge/Flutter-3.22+-blue.svg)](https://flutter.dev)
[![Xray-core](https://img.shields.io/badge/Xray--core-1.8.24+-green.svg)](https://github.com/XTLS/Xray-core)
[![sing-box](https://img.shields.io/badge/sing--box-1.10+-orange.svg)](https://github.com/SagerNet/sing-box)
[![License](https://img.shields.io/badge/License-GPLv3-blue.svg)](../../LICENSE)

---

## Описание

**RioNexTunnel** (RIO — надёжная интернет-прослойка; Nexus + Tunnel — «связующий туннель») — безопасный и гибкий VPN-клиент. Приложение объединяет конфиги и платформы в защищённый канал и подключается к VPN-серверам по протоколам VLESS, VMess, Shadowsocks, Trojan, Hysteria/Hysteria2, TUIC, WireGuard, SSH и другим (через ядра Xray-core и sing-box). Главное отличие от многих существующих клиентов — **полное устранение уязвимости неаутентифицированного локального SOCKS5-прокси**, обнаруженной весной 2026 года в Hiddify, v2rayNG, Happ и др.

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
| [Настройка Windows](windows_setup.md) | Proxy mode, Visual Studio, бинарники ядер |
| [Настройка macOS](macos_setup.md) | Proxy mode, Xcode, бинарники ядер |
| [Настройка Android](android_setup.md) | VPN mode, manifest, jniLibs |
| [Настройка iOS](ios_setup.md) | Network Extensions, entitlements |
| [Чеклист platform parity](platform_parity_checklist.md) | Smoke-тесты по платформам |
| [Архитектура](architecture.md) | Компоненты и поток данных |
| [Безопасность](security.md) | Модель SOCKS-аутентификации |
| [Расширение браузера](browser_extension.md) | Авто-авторизация прокси |
| [Устранение неполадок](troubleshooting.md) | Типичные ошибки и решения |
| [Участие в разработке](contributing.md) | Чеклист PR и пути правок |
| [Форк v2ray_box](v2ray_box_fork.md) | Патчи относительно upstream, зачем example |
| [Мобильный VPN config](mobile_vpn_config.md) | Аудит sing-box `mixed` и DNS |
| [Тесты RioNexGate](rionexgate_testing.md) | Интеграционные тесты панели (CI и опционально живая панель) |
| [Release notes v0.6.0](release_notes_v0.6.0.md) | RioNexGate фазы 2–4: команды, sync, режимы SOCKS |

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

## Планы развития

- [x] Подписки (engine-specific User-Agent)
- [x] Переключение ядер xray / sing-box
- [x] Модульные тесты безопасности
- [x] Linux desktop: proxy mode, все 4 комбинации engine × profile
- [x] Выбор сервера из списка подписки
- [x] Автовыбор сервера с лучшей задержкой
- [x] Автовыбор ядра (доступность / формат / fallback connect)
- [ ] Полноценный E2E на Android / iOS / Windows / macOS
- [x] CI: `flutter analyze` + `flutter test` + Linux `security_probe.sh`

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
