# RioNexTunnel Proxy Auth (браузерное расширение)

> **Язык / Language:** **Русский** | [English](README.md)

Одноразовая настройка для Chromium и Firefox на десктопном Linux.

Полное руководство: [docs/ru/browser_extension.md](../../docs/ru/browser_extension.md) · [EN](../../docs/en/browser_extension.md)

## Установка расширения

1. Откройте `chrome://extensions` (Chromium: `chrome://extensions`, Firefox: `about:debugging#/runtime/this-firefox`).
2. Включите **Режим разработчика** (Chromium) или **Загрузить временное дополнение** (Firefox).
3. Загрузите эту папку (`extensions/secure-vpn-proxy-auth`).

**ID расширения Chromium:** `hlpppofeeecjldogljipggakkdeppoeb` (фиксирован через `key` в манифесте).

**ID расширения Firefox:** `secure-vpn-proxy-auth@secure-vpn.local`

## Native messaging host

VPN-приложение устанавливает native host автоматически при первом `setup()` (подключитесь один раз).

Имя хоста: `com.secure.vpn.proxy_auth`

Пути для ручной установки:

- Бинарник: `~/.local/share/v2ray_box/native_host/secure_vpn_native_host`
- Манифест Chrome: `~/.config/google-chrome/NativeMessagingHosts/com.secure.vpn.proxy_auth.json`
- Манифест Chromium: `~/.config/chromium/NativeMessagingHosts/com.secure.vpn.proxy_auth.json`
- Манифест Firefox: `~/.mozilla/native-messaging-hosts/com.secure.vpn.proxy_auth.json`

## Проверка

1. Подключите VPN в приложении.
2. Откройте popup расширения — должно отображаться `Ready: 127.0.0.1:1081`.
3. Откройте сайт проверки IP — диалог ввода логина прокси не должен появляться.
