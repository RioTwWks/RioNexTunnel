# Настройка Linux

> **Язык / Language:** **Русский** | [English](linux_setup.md)

## Зависимости

```bash
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev
```

Flutter SDK канала stable (версию Dart см. в `secure_vpn_client/pubspec.yaml`).

## Бинарники ядер

Из корня репозитория:

```bash
./scripts/fetch_cores.sh
```

В `secure_vpn_client/linux/runner/resources/` будут размещены:

- `xray`, `sing-box`
- `geoip.dat`, `geosite.dat` (нужны для xray-подписок с маршрутизацией по geosite/geoip)

Эти файлы добавлены в `.gitignore`; каждый разработчик/CI-джоб должен скачивать их самостоятельно.

## Запуск

```bash
cd secure_vpn_client
flutter pub get
flutter run -d linux
```

После правок в `packages/v2ray_box/linux/*` выполняйте **полный перезапуск** (не hot reload).

## Рабочие директории

| Путь | Назначение |
|------|-----------|
| `~/.local/share/v2ray_box/profiles/active_config.json` | Активный конфиг ядра (стирается при отключении) |
| `~/.local/share/v2ray_box/assets/` | Geo-базы Xray |

## Режим работы

На десктопном Linux используется **proxy mode**, а не системный TUN VPN. **Подключено** означает, что процесс ядра запущен и системный прокси настроен, — а не то, что весь трафик автоматически туннелируется без участия браузера.

При нажатии Connect приложение:

1. Запускает xray/sing-box с аутентифицированными локальными inbound'ами только на `127.0.0.1`.
2. Автоматически настраивает **системный прокси GNOME** (`setSystemProxy: true`) через GSettings.

| Порт | Протокол | Назначение |
|------|----------|-----------|
| `1080` | SOCKS5 (требуется авторизация) | Приложения с поддержкой SOCKS с логином/паролем |
| `1081` | HTTP (требуется авторизация) | Системный прокси GNOME / браузеров (GNOME не поддерживает SOCKS-авторизацию) |

Сессионные логин/пароль генерируются при каждом Connect, отображаются на экране **Home** и в **Settings → System proxy (this session)** и стираются при отключении. Это **учётные данные локального прокси**, а не логин вашего VPN-сервера.

### Браузерный помощник (рекомендуется — без диалога ввода логина)

Chromium **игнорирует** пароли прокси из GSettings. Установите одноразовое **расширение для браузера**, чтобы авторизация прокси подставлялась автоматически:

1. Запустите приложение один раз (оно установит native messaging host в `~/.local/share/v2ray_box/native_host/`).
2. Загрузите распакованное расширение: `extensions/secure-vpn-proxy-auth/` (см. [README расширения](../extensions/secure-vpn-proxy-auth/README.ru.md)).
3. Подключите VPN — проверьте **Settings → Browser helper** (все индикаторы зелёные).

| Компонент | Путь |
|-----------|------|
| Бинарник native host | `~/.local/share/v2ray_box/native_host/secure_vpn_native_host` |
| Манифест Chrome | `~/.config/google-chrome/NativeMessagingHosts/com.secure.vpn.proxy_auth.json` |
| Манифест Chromium | `~/.config/chromium/NativeMessagingHosts/com.secure.vpn.proxy_auth.json` |
| Манифест Firefox | `~/.mozilla/native-messaging-hosts/com.secure.vpn.proxy_auth.json` |

**ID расширения Chromium:** `hlpppofeeecjldogljipggakkdeppoeb`

### Ручной ввод логина прокси (запасной вариант)

Без расширения скопируйте логин/пароль с экрана Home или из Settings в диалог браузера при появлении запроса. После каждого переподключения учётные данные новые.

Подробности см. в разделе [Browser asks for proxy login](../.cursor/troubleshooting.md#browser-asks-for-proxy-login-1270011081) файла troubleshooting.

### Ручной SOCKS (опционально)

Для приложений, поддерживающих SOCKS5 с авторизацией (не GNOME), укажите `127.0.0.1:1080` с теми же сессионными учётными данными из Settings.

## Устранение неполадок

Подробное соответствие «ошибка → решение» см. в [.cursor/troubleshooting.md](../.cursor/troubleshooting.md).

## Проверка безопасности

При подключённом VPN:

```bash
./scripts/security_probe.sh 1080
```

Неавторизованная проверка должна завершиться ошибкой. Обязательная авторизация прокси — намеренная мера: она не даёт другим локальным процессам использовать прокси без учётных данных (см. класс уязвимостей неавторизованного `0.0.0.0:7890` в других клиентах, март 2026).
