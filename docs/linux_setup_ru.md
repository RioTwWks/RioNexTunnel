# Настройка Linux

[English version](linux_setup.md)

## Предварительные требования

```bash
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev
```

Flutter stable SDK (версию Dart см. в `secure_vpn_client/pubspec.yaml`).

## Бинарные файлы ядер

Из корня репозитория:

```bash
./scripts/fetch_cores.sh
```

Скрипт помещает в `secure_vpn_client/linux/runner/resources/`:

- `xray`, `sing-box`
- `geoip.dat`, `geosite.dat` (требуются для xray-подписок с маршрутизацией geosite/geoip)

Эти файлы исключены из git; каждый разработчик и CI-задача должны их загружать.

## Запуск

```bash
cd secure_vpn_client
flutter pub get
flutter run -d linux
```

После правки файлов `packages/v2ray_box/linux/*` делайте **полный перезапуск** (не hot reload).

## Рабочие директории

| Путь | Назначение |
|------|------------|
| `~/.local/share/v2ray_box/profiles/active_config.json` | Активная конфигурация ядра (удаляется при отключении) |
| `~/.local/share/v2ray_box/assets/` | Geo-базы Xray |

## Режим работы

Десктоп Linux использует **proxy mode**, а не системный TUN VPN. Статус **Connected** означает, что ядро запущено и системный прокси настроен — не то, что весь трафик автоматически туннелируется без участия браузера.

При подключении приложение:

1. Запускает xray/sing-box с аутентифицированными локальными inbounds только на `127.0.0.1`.
2. Автоматически настраивает **системный прокси GNOME** (`setSystemProxy: true`) через GSettings.

| Порт | Протокол | Назначение |
|------|----------|------------|
| `1080` | SOCKS5 (требуется auth) | Приложения с поддержкой SOCKS и логином/паролем |
| `1081` | HTTP (требуется auth) | Системный прокси GNOME / браузера (GNOME не поддерживает auth SOCKS) |

Сессионный логин/пароль генерируются при каждом подключении, отображаются на **Home** и в **Settings → System proxy (this session)** и удаляются при отключении. Это **локальные учётные данные прокси**, а не логин вашего VPN-сервера.

### Браузерный помощник (рекомендуется — без диалога логина)

Chromium **игнорирует** пароли прокси из GSettings. Установите одноразовое **расширение браузера**, чтобы аутентификация прокси заполнялась автоматически:

1. Запустите приложение один раз (устанавливается native messaging host в `~/.local/share/v2ray_box/native_host/`).
2. Загрузите распакованное расширение: `extensions/secure-vpn-proxy-auth/` (см. [README расширения](../extensions/secure-vpn-proxy-auth/README.md)).
3. Подключите VPN — проверьте **Settings → Browser helper** (все индикаторы зелёные).

| Компонент | Путь |
|-----------|------|
| Бинарник native host | `~/.local/share/v2ray_box/native_host/secure_vpn_native_host` |
| Манифест Chrome | `~/.config/google-chrome/NativeMessagingHosts/com.secure.vpn.proxy_auth.json` |
| Манифест Chromium | `~/.config/chromium/NativeMessagingHosts/com.secure.vpn.proxy_auth.json` |
| Манифест Firefox | `~/.mozilla/native-messaging-hosts/com.secure.vpn.proxy_auth.json` |

**ID расширения Chromium:** `hlpppofeeecjldogljipggakkdeppoeb`

### Ручной ввод логина прокси (запасной вариант)

Без расширения скопируйте логин/пароль из Home или Settings в диалог браузера при запросе. После каждого переподключения создаются новые учётные данные.

Подробности см. в разделе [Браузер запрашивает логин прокси](../.cursor/troubleshooting.md#browser-asks-for-proxy-login-1270011081) troubleshooting.

### Ручной SOCKS (опционально)

Для приложений с поддержкой SOCKS5 с auth (не GNOME) направьте их на `127.0.0.1:1080` с теми же сессионными учётными данными из Settings.

## Устранение неполадок

См. [.cursor/troubleshooting.md](../.cursor/troubleshooting.md) для детального сопоставления ошибок и решений.

## Проверка безопасности

При подключённом VPN:

```bash
./scripts/security_probe.sh 1080
```

Неаутентифицированный зонд должен завершиться ошибкой. Обязательная аутентификация прокси — это намеренно: она предотвращает использование прокси другими локальными процессами без учётных данных (см. класс уязвимостей March 2026 с неаутентифицированным `0.0.0.0:7890` в других клиентах).
