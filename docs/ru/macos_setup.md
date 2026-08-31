# Настройка macOS

<p align="right">
  <a href="../en/macos_setup.md"><img src="https://img.shields.io/badge/lang-English-blue?style=for-the-badge" alt="English version"></a>
</p>


## Предварительные требования

- **macOS 10.15 (Catalina) или новее** (64-bit Intel или Apple Silicon)
- [Flutter SDK](https://docs.flutter.dev/get-started/install/macos) `stable` (версия Dart в `secure_vpn_client/pubspec.yaml`)
- **Xcode 15+** с command-line tools (`xcode-select --install`)
- **CocoaPods** (обычно устанавливается вместе с Flutter macOS toolchain)

Проверка поддержки desktop:

```bash
flutter doctor
flutter config --enable-macos-desktop
```

## Статус платформы

| Область | Статус |
|---------|--------|
| Оболочка Flutter-приложения | Собирается и запускается |
| Плагин `v2ray_box` для macOS | **Реализован** — `XrayProcess` / `SingboxProcess`, `start_with_json`, системный прокси через `networksetup` |
| Безопасные inbound | Инъекция в Dart (`ConfigParser.injectSecureSocksInbound`) перед `connectWithJson` |
| Системный прокси | `networksetup` на активных сетевых интерфейсах (Wi‑Fi, Ethernet, …) |
| E2E-проверка Connect | **В процессе** — см. backlog в `.cursor/tasks.md` |
| Расширение браузера / proxy auth | **Только Linux** — native messaging host для macOS пока нет |

На macOS desktop используется **proxy mode** (`VpnMode.proxy`), не системный TUN VPN. Статус **Connected** означает, что ядро запущено и системный прокси настроен — не что весь трафик автоматически идёт через VPN без участия браузера.

> **Известный разрыв:** Swift-плагин берёт порт прокси из `ConfigOptions` (дефолты `mixed-port` / `socks-port`), а RioNexTunnel инжектирует безопасные inbound на порты **1080** (SOCKS) и **1081** (HTTP). Пока плагин не выровнен с Linux (`system_proxy.cc`), после Connect проверяйте **Системные настройки → Сеть → … → Подробнее → Прокси**.

## Бинарники ядер

Из корня репозитория:

```bash
./scripts/fetch_cores.sh
```

Копирует в `secure_vpn_client/macos/Runner/Resources/`:

- `xray`, `sing-box`
- `geoip.dat`, `geosite.dat` (нужны для подписок xray с правилами `geosite:` / `geoip:`)

Файлы не в git — на каждой машине и в CI нужно запускать `fetch_cores.sh`.

### Ручная загрузка

1. Скачайте последние [Xray-core `Xray-macos-64.zip`](https://github.com/XTLS/Xray-core/releases) и архив sing-box [`darwin-amd64`](https://github.com/SagerNet/sing-box/releases) (на Apple Silicon — `darwin-arm64`, если доступен).
2. Положите `xray` и `sing-box` в `secure_vpn_client/macos/Runner/Resources/`.
3. Сделайте исполняемыми: `chmod +x macos/Runner/Resources/{xray,sing-box}`.
4. Скачайте [`geoip.dat`](https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat) и [`geosite.dat`](https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat) в ту же папку.

### Альтернативный путь (`Frameworks/`)

Podspec `v2ray_box` также указывает `macos/Frameworks/` как место для бинарников. `fetch_cores.sh` кладёт файлы в `Runner/Resources/`; плагин ищет и в `Contents/Resources/`, и в `Contents/Frameworks/`.

Переопределение путей через переменные окружения:

- `V2RAY_BOX_XRAY_PATH` / `V2RAY_BOX_SINGBOX_PATH`
- `V2RAY_BOX_CORE_DIR`

## Запуск

```bash
cd secure_vpn_client
flutter pub get
flutter run -d macos
```

После правок в `packages/v2ray_box/macos/*` — **полный перезапуск** (не hot reload).

Для отладки нативного кода откройте workspace в Xcode:

```bash
open macos/Runner.xcworkspace
```

### Структура сборки

Debug bundle (пути зависят от режима сборки):

```
build/macos/Build/Products/Debug/secure_vpn_client.app/Contents/
├── MacOS/secure_vpn_client
└── Resources/
    ├── xray
    ├── sing-box
    ├── geoip.dat
    └── geosite.dat
```

## Режим работы

При Connect приложение:

1. Разбирает подписку или config link через `ConfigParser` / `LinkConfigBuilder`.
2. Инжектирует аутентифицированные inbound только на `127.0.0.1` (`injectSecureSocksInbound`, `proxyOnly: true`).
3. Вызывает `connectWithJson` — плагин macOS пишет `active_config.json` и запускает xray или sing-box.
4. Включает системный прокси через `/usr/sbin/networksetup` на активных сетевых сервисах.

| Порт | Протокол | Назначение |
|------|----------|------------|
| `1080` | SOCKS5 (с auth) | Приложения с поддержкой SOCKS и логина/пароля |
| `1081` | HTTP (с auth) | Системный / браузерный прокси (см. примечание о статусе платформы выше) |

Логин и пароль генерируются на каждое подключение, отображаются на **Home** и в **Settings → System proxy (this session)**, стираются при disconnect. Это **локальные учётные данные прокси**, не логин VPN-сервера.

### Ручной ввод прокси (fallback)

Без расширения браузера для macOS скопируйте логин/пароль с Home или Settings в диалог браузера. После каждого reconnect — новые учётные данные.

### Ручная настройка SOCKS (опционально)

Для приложений с SOCKS5 + auth: `127.0.0.1:1080` с учётными данными из Settings.

## Рабочие директории

| Путь | Назначение |
|------|------------|
| `~/Library/Application Support/V2rayBox/working/profiles/active_config.json` | Активный конфиг ядра |
| `~/Library/Application Support/V2rayBox/working/` | Рабочая директория плагина |
| `~/Library/Application Support/<bundle-id>/v2ray_box/cores/` | Опциональные пользовательские ядра |

Geo-файлы читаются из каталога рядом с бинарником ядра (`geoip.dat`, `geosite.dat` в `Resources/`).

## Проверка безопасности

При подключённом VPN (из Terminal на macOS или Linux):

```bash
./scripts/security_probe.sh 1080
```

Неавторизованная проверка должна завершиться ошибкой. См. [security.md](security.md).

## Устранение неполадок

| Симптом | Вероятная причина | Решение |
|---------|-------------------|---------|
| `xray binary not found` / `sing-box binary not found` | Пустой `Runner/Resources/` | Запустите `fetch_cores.sh`; `chmod +x`; пересоберите |
| Ядро сразу завершается | Нет geo-файлов или неверный JSON подписки | Смотрите stderr в Console.app; проверьте `geoip.dat` / `geosite.dat` |
| **Connected**, но браузер без VPN | Несовпадение порта системного прокси | Вручную HTTP-прокси `127.0.0.1:1081` с учётными данными из Settings |
| `networksetup` не срабатывает | Нет прав или нет активного интерфейса | Подключите Wi‑Fi/Ethernet; **Системные настройки → Сеть → Прокси** |
| `geosite.dat: no such file` | Подписка v2rayNG с geo-правилами | `fetch_cores.sh`; geo-файлы рядом с `xray` в `Resources/` |
| Hot reload после правок Swift | Нативный код не перезагружается | Остановите приложение; снова `flutter run -d macos` |

См. также [troubleshooting.md](troubleshooting.md) для проблем с подписками и конфигами на всех платформах.

## Участие в разработке (macOS native)

Приоритеты для паритета с Linux:

1. Выровнять `getProxyPort()` / `enableSystemProxy()` с портами Dart (`1081` HTTP с auth).
2. Портировать credential channel и browser native messaging с Linux.
3. E2E smoke test: все четыре комбинации engine × profile.
4. Очистка `active_config.json` и настроек прокси при disconnect (как Linux `wipe_sensitive_files`).

См. [contributing.md](contributing.md).
