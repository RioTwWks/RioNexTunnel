# Расширение браузера (Linux)

[← Оглавление документации](README.md) · [English](../en/browser-extension.md)

Одноразовая настройка для Chromium и Firefox на Linux desktop. Исходники: `extensions/secure-vpn-proxy-auth/`.

Chromium игнорирует пароли прокси из GSettings. Расширение отвечает на HTTP `407` (proxy-auth), подставляя сессионные учётные данные, которые VPN-приложение публикует через native messaging.

## Установка расширения

1. Откройте `chrome://extensions` (Chromium: `chrome://extensions`, Firefox: `about:debugging#/runtime/this-firefox`).
2. Включите **Developer mode** (Chromium) или **Load Temporary Add-on** (Firefox).
3. Загрузите каталог: `extensions/secure-vpn-proxy-auth`.

**ID расширения Chromium:** `hlpppofeeecjldogljipggakkdeppoeb` (зафиксирован через `key` в манифесте).

**ID расширения Firefox:** `secure-vpn-proxy-auth@secure-vpn.local`

## Native messaging host

Приложение VPN устанавливает native host автоматически при первом `setup()` (достаточно один раз подключиться).

Имя host: `com.secure.vpn.proxy_auth`

| Компонент | Путь |
|-----------|------|
| Бинарник | `~/.local/share/v2ray_box/native_host/secure_vpn_native_host` |
| Манифест Chrome | `~/.config/google-chrome/NativeMessagingHosts/com.secure.vpn.proxy_auth.json` |
| Манифест Chromium | `~/.config/chromium/NativeMessagingHosts/com.secure.vpn.proxy_auth.json` |
| Манифест Firefox | `~/.mozilla/native-messaging-hosts/com.secure.vpn.proxy_auth.json` |

## Проверка

1. Подключите VPN в приложении.
2. Откройте popup расширения — должно быть `Ready: 127.0.0.1:1081`.
3. Откройте сайт проверки IP — диалога логина прокси быть не должно.
4. В приложении: **Settings → Browser helper** — все индикаторы зелёные.

## Запасной вариант

Без расширения скопируйте логин/пароль с **Home** или **Settings → System proxy (this session)** в диалог браузера. Учётные данные меняются при каждом reconnect.

## Замечание по безопасности

Расширение **не** создаёт неаутентифицированный прокси. Оно только передаёт те же сессионные учётные данные, которые ядро уже требует на `127.0.0.1:1081`.
