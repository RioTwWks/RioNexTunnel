# Настройка Linux

[English version](../en/linux_setup.md)

## Предварительные требования

```bash
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev
```

Flutter stable SDK (версия Dart в `secure_vpn_client/pubspec.yaml`).

## Бинарники ядер

Из корня репозитория:

```bash
./scripts/fetch_cores.sh
```

Копирует в `secure_vpn_client/linux/runner/resources/`:

- `xray`, `sing-box`
- `geoip.dat`, `geosite.dat` (нужны для подписок xray с правилами `geosite:` / `geoip:`)

Файлы не в git — на каждой машине и в CI нужно запускать `fetch_cores.sh`.

## Запуск

```bash
cd secure_vpn_client
flutter pub get
flutter run -d linux
```

После правок в `packages/v2ray_box/linux/*` — **полный перезапуск** (не hot reload).

## Рабочие директории

| Путь | Назначение |
|------|------------|
| `~/.local/share/v2ray_box/profiles/active_config.json` | Активный конфиг ядра (удаляется при disconnect) |
| `~/.local/share/v2ray_box/assets/` | Geo-файлы Xray |

## Режим работы

На Linux desktop используется **proxy mode**, не системный TUN VPN. Статус **Connected** означает, что ядро запущено и системный прокси настроен — не что весь трафик автоматически идёт через VPN без участия браузера.

При Connect приложение:

1. Запускает xray/sing-box с аутентифицированными inbound на `127.0.0.1`.
2. Устанавливает **системный прокси GNOME** через GSettings.

| Порт | Протокол | Назначение |
|------|----------|------------|
| `1080` | SOCKS5 (с auth) | Приложения с поддержкой SOCKS и логина/пароля |
| `1081` | HTTP (с auth) | Системный прокси GNOME / браузер (GNOME не поддерживает auth для SOCKS) |

Логин и пароль генерируются на каждое подключение, отображаются на **Home** и в **Settings → System proxy (this session)**, стираются при disconnect. Это **локальные учётные данные прокси**, не логин VPN-сервера.

### Расширение браузера (рекомендуется)

Chromium **игнорирует** пароли прокси из GSettings. Установите **расширение браузера** для автоматической авторизации:

1. Запустите приложение один раз (устанавливает native messaging host в `~/.local/share/v2ray_box/native_host/`).
2. Загрузите unpacked extension: `extensions/secure-vpn-proxy-auth/` — см. [browser_extension.md](browser_extension.md).
3. Подключите VPN — в **Settings → Browser helper** все индикаторы должны быть зелёными.

| Компонент | Путь |
|-----------|------|
| Native host | `~/.local/share/v2ray_box/native_host/secure_vpn_native_host` |
| Chrome manifest | `~/.config/google-chrome/NativeMessagingHosts/com.secure.vpn.proxy_auth.json` |
| Chromium manifest | `~/.config/chromium/NativeMessagingHosts/com.secure.vpn.proxy_auth.json` |
| Firefox manifest | `~/.mozilla/native-messaging-hosts/com.secure.vpn.proxy_auth.json` |

**Chromium extension ID:** `hlpppofeeecjldogljipggakkdeppoeb`

### Ручной ввод прокси (fallback)

Без расширения скопируйте логин/пароль с Home или Settings в диалог браузера. После каждого reconnect — новые учётные данные.

См. [troubleshooting.md](troubleshooting.md#браузер-запрашивает-логин-прокси-1270011081).

### Ручная настройка SOCKS (опционально)

Для приложений с SOCKS5 + auth (не GNOME): `127.0.0.1:1080` с учётными данными из Settings.

## Проверка безопасности

При подключённом VPN:

```bash
./scripts/security_probe.sh 1080
```

Неавторизованная проверка должна завершиться ошибкой.

## Устранение неполадок

См. [troubleshooting.md](troubleshooting.md).
