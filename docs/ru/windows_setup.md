# Настройка Windows

<p align="right">
  <a href="../en/windows_setup.md"><img src="https://img.shields.io/badge/lang-English-blue?style=for-the-badge" alt="English version"></a>
</p>


## Предварительные требования

- **Windows 10 или новее** (64-bit)
- [Flutter SDK](https://docs.flutter.dev/get-started/install/windows) `stable` (версия Dart в `secure_vpn_client/pubspec.yaml`)
- **Visual Studio 2022** с workload **«Разработка классических приложений на C++»** (MSVC, Windows SDK, CMake)
- **Git for Windows** (рекомендуется) — для запуска `fetch_cores.sh` из Git Bash

Проверка поддержки desktop:

```powershell
flutter doctor
flutter config --enable-windows-desktop
```

## Статус платформы

| Область | Статус |
|---------|--------|
| Оболочка Flutter-приложения | Собирается и запускается |
| Бинарники ядер в bundle | CMake копирует `runner/resources/` → `{exe_dir}/resources/` |
| Плагин `v2ray_box` для Windows | **Заглушка** — сейчас только `getPlatformVersion` |
| Connect / proxy mode | **Ещё нет** — нужны `desktop_core` + `SystemProxy` (см. backlog в `.cursor/tasks.md`) |

На Windows desktop планируется **proxy mode** (`VpnMode.proxy`), как на Linux: аутентифицированные inbound только на `127.0.0.1`, без системного TUN VPN. Пока нативный плагин не реализован, можно собрать и изучить UI, но **Connect не запустит xray/sing-box**.

## Бинарники ядер

Из корня репозитория (Git Bash, WSL или Linux/macOS):

```bash
./scripts/fetch_cores.sh
```

Копирует в `secure_vpn_client/windows/runner/resources/`:

- `xray.exe`, `sing-box.exe`
- `geoip.dat`, `geosite.dat` (нужны для подписок xray с правилами `geosite:` / `geoip:`)

Файлы не в git — на каждой машине и в CI нужно запускать `fetch_cores.sh`.

### Ручная загрузка (без Bash)

1. Скачайте последние [Xray-core `Xray-windows-64.zip`](https://github.com/XTLS/Xray-core/releases) и [sing-box `windows-amd64.zip`](https://github.com/SagerNet/sing-box/releases).
2. Извлеките `xray.exe` и `sing-box.exe` в `secure_vpn_client/windows/runner/resources/`.
3. Скачайте [`geoip.dat`](https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat) и [`geosite.dat`](https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat) в ту же папку.

## Запуск

```powershell
cd secure_vpn_client
flutter pub get
flutter run -d windows
```

После правок в `packages/v2ray_box/windows/*` — **полный перезапуск** (не hot reload).

### Структура сборки

CMake устанавливает ядра рядом с исполняемым файлом:

```
build\windows\x64\runner\Debug\
├── secure_vpn_client.exe
└── resources\
    ├── xray.exe
    ├── sing-box.exe
    ├── geoip.dat
    └── geosite.dat
```

Поиск бинарников (после реализации плагина) будет аналогичен Linux: переменные окружения → `{exe_dir}/resources/` → каталог данных пользователя.

## Режим работы (планируется)

После достижения паритета с Linux:

1. Запуск xray/sing-box с аутентифицированными inbound на `127.0.0.1`.
2. Установка **системного прокси Windows** (WinINet / реестр) на HTTP `127.0.0.1:1081` с учётными данными сессии.

| Порт | Протокол | Назначение |
|------|----------|------------|
| `1080` | SOCKS5 (с auth) | Приложения с поддержкой SOCKS и логина/пароля |
| `1081` | HTTP (с auth) | Системный / браузерный прокси |

Логин и пароль генерируются на каждое подключение, отображаются на **Home** и в **Settings → System proxy (this session)**, стираются при disconnect. Это **локальные учётные данные прокси**, не логин VPN-сервера.

### Авторизация прокси в браузере (планируется)

Chromium на Windows может игнорировать сохранённые пароли прокси. Планируется расширение браузера и native messaging host (как на Linux); до реализации — ручной ввод учётных данных с Home/Settings.

## Рабочие директории (планируется)

| Путь | Назначение |
|------|------------|
| `%LOCALAPPDATA%\v2ray_box\profiles\active_config.json` | Активный конфиг ядра (удаляется при disconnect) |
| `%LOCALAPPDATA%\v2ray_box\assets\` | Geo-файлы Xray |

На Linux используется `~/.local/share/v2ray_box/`; на Windows — эквивалент в `%LOCALAPPDATA%`.

## Проверка безопасности

После реализации Connect, при подключённом VPN из Git Bash или WSL:

```bash
./scripts/security_probe.sh 1080
```

Неавторизованная проверка должна завершиться ошибкой. См. [security.md](security.md).

## Устранение неполадок

| Симптом | Вероятная причина | Решение |
|---------|-------------------|---------|
| `flutter run -d windows` падает на MSVC | Нет workload C++ в VS 2022 | Установите **«Разработка классических приложений на C++»** в Visual Studio Installer |
| Нет устройства Windows | Desktop не включён | `flutter config --enable-windows-desktop` |
| Connect не работает / `NotImplemented` | Плагин Windows — заглушка | Ожидаемо сейчас; см. `.cursor/tasks.md` |
| Ядра не найдены после сборки | Пустой `runner/resources/` | Запустите `fetch_cores.sh` или ручную загрузку; пересоберите |
| Ошибки geo-маршрутизации | Нет `geoip.dat` / `geosite.dat` | Как и ядра — положите в `runner/resources/` |

См. также [troubleshooting.md](troubleshooting.md) для проблем с подписками и конфигами на всех платформах.

## Участие в разработке (Windows native)

Для реализации desktop proxy mode на Windows:

1. Портировать `packages/v2ray_box/linux/desktop_core.cc` → `packages/v2ray_box/windows/desktop_core.cpp` (spawn процесса, stderr, копирование geo).
2. Портировать `linux/system_proxy.cc` → системный прокси Windows (WinINet / реестр).
3. Подключить method channel в `v2ray_box_plugin.cpp` (по образцу `linux/v2ray_box_plugin.cc`).
4. Полный перезапуск + smoke test всех четырёх комбинаций engine × profile.

См. [contributing.md](contributing.md).
