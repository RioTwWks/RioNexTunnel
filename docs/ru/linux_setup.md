# Настройка Linux

[← Оглавление документации](README.md) · [English](../en/linux_setup.md)

## Предварительные требования

```bash
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev
```

Flutter SDK канала `stable` (версия Dart — в `secure_vpn_client/pubspec.yaml`).

## Бинарники ядер

Из корня репозитория:

```bash
./scripts/fetch_cores.sh
```

Файлы копируются в `secure_vpn_client/linux/runner/resources/`:

- `xray`, `sing-box`
- `geoip.dat`, `geosite.dat` (нужны для подписок xray с правилами geosite/geoip)

Файлы в `.gitignore`; каждый разработчик и CI должны скачивать их самостоятельно.

## Запуск

```bash
cd secure_vpn_client
flutter pub get
flutter run -d linux
```

После правок в `packages/v2ray_box/linux/*` нужен **полный перезапуск** (не hot reload).

## Каталоги во время работы

| Путь | Назначение |
|------|------------|
| `~/.local/share/v2ray_box/profiles/active_config.json` | Активный конфиг ядра (удаляется при disconnect) |
| `~/.local/share/v2ray_box/assets/` | Geo-базы Xray |

## Режим работы

На Linux desktop используется **proxy mode**, а не системный TUN VPN. Статус **Connected** означает, что процесс ядра запущен и системный прокси настроен — не то, что весь трафик туннелируется без участия браузера/приложений.

При Connect приложение:

1. Запускает xray/sing-box с аутентифицированными локальными inbound только на `127.0.0.1`.
2. Автоматически выставляет **системный прокси GNOME** (`setSystemProxy: true`) через GSettings.

| Порт | Протокол | Назначение |
|------|----------|------------|
| `1080` | SOCKS5 (нужен auth) | Приложения с поддержкой SOCKS + логин/пароль |
| `1081` | HTTP (нужен auth) | Системный прокси GNOME / браузера (GNOME не поддерживает SOCKS auth) |

Логин/пароль сессии генерируются на каждый Connect, показываются на **Home** и в **Settings → System proxy (this session)**, уничтожаются при disconnect. Это **учётные данные локального прокси**, а не логин VPN-сервера.

### Помощник браузера (рекомендуется — без диалога логина)

Chromium **игнорирует** пароли прокси из GSettings. Установите одноразово **расширение браузера** для автозаполнения auth:

1. Запустите приложение один раз (установит native messaging host в `~/.local/share/v2ray_box/native_host/`).
2. Загрузите распакованное расширение: `extensions/secure-vpn-proxy-auth/` — см. [browser-extension.md](browser-extension.md).
3. Подключите VPN — в **Settings → Browser helper** все индикаторы должны быть зелёными.

| Компонент | Путь |
|-----------|------|
| Бинарник native host | `~/.local/share/v2ray_box/native_host/secure_vpn_native_host` |
| Манифест Chrome | `~/.config/google-chrome/NativeMessagingHosts/com.secure.vpn.proxy_auth.json` |
| Манифест Chromium | `~/.config/chromium/NativeMessagingHosts/com.secure.vpn.proxy_auth.json` |
| Манифест Firefox | `~/.mozilla/native-messaging-hosts/com.secure.vpn.proxy_auth.json` |

**ID расширения Chromium:** `hlpppofeeecjldogljipggakkdeppoeb`

### Ручной ввод proxy login (запасной вариант)

Без расширения скопируйте логин/пароль с Home или Settings в диалог браузера. После каждого reconnect — новые учётные данные.

### Ручной SOCKS (опционально)

Для приложений с SOCKS5 + auth (не GNOME) укажите `127.0.0.1:1080` и те же сессионные учётные данные из Settings.

## Устранение неполадок

Подробная карта ошибок → исправлений: [`.cursor/troubleshooting.md`](../../.cursor/troubleshooting.md).

## Проверка безопасности

При активном VPN:

```bash
./scripts/security_probe.sh 1080
```

Неавторизованный probe должен завершиться ошибкой. Обязательная аутентификация прокси намеренна — она не даёт другим локальным процессам использовать прокси без учётных данных (класс проблем марта 2026: открытый `0.0.0.0:7890` без auth в других клиентах).
