# Расширение браузера (авторизация прокси)

[English version](../en/browser_extension.md)

Одноразовая настройка для Chromium и Firefox на **Linux desktop**.

Путь: `extensions/secure-vpn-proxy-auth/`

## Зачем нужно

На Linux desktop приложение устанавливает системный прокси GNOME на HTTP `127.0.0.1:1081` с аутентификацией. **Chromium и некоторые браузеры игнорируют пароли прокси из GSettings** и показывают диалог входа. Расширение получает учётные данные сессии через native messaging и автоматически отвечает на `407 Proxy Authentication Required`.

## Установка расширения

1. Откройте `chrome://extensions` (Firefox: `about:debugging#/runtime/this-firefox`).
2. Включите **Режим разработчика** (Chromium) или **Загрузить временное дополнение** (Firefox).
3. Загрузите папку `extensions/secure-vpn-proxy-auth`.

**Chromium extension ID:** `hlpppofeeecjldogljipggakkdeppoeb` (фиксирован через `key` в manifest).

**Firefox extension ID:** `secure-vpn-proxy-auth@secure-vpn.local`

## Native messaging host

VPN-приложение устанавливает native host автоматически при первом `setup()` (один раз Connect).

Имя host: `com.secure.vpn.proxy_auth`

| Компонент | Путь |
|-----------|------|
| Бинарник | `~/.local/share/v2ray_box/native_host/secure_vpn_native_host` |
| Chrome manifest | `~/.config/google-chrome/NativeMessagingHosts/com.secure.vpn.proxy_auth.json` |
| Chromium manifest | `~/.config/chromium/NativeMessagingHosts/com.secure.vpn.proxy_auth.json` |
| Firefox manifest | `~/.mozilla/native-messaging-hosts/com.secure.vpn.proxy_auth.json` |

## Проверка

1. Подключите VPN в приложении.
2. Откройте popup расширения — должно быть `Ready: 127.0.0.1:1081`.
3. Откройте сайт проверки IP — без диалога прокси.
4. В приложении: **Settings → Browser helper** — все индикаторы зелёные.

## Fallback (вручную)

Скопируйте логин/пароль с **Home** или **Settings → System proxy (this session)** в диалог браузера. При каждом reconnect — новые creds.

См. [troubleshooting.md](troubleshooting.md), если диалог всё ещё появляется.
