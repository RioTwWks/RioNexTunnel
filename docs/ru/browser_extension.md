# Расширение браузера (авторизация прокси)

<p align="right">
  <a href="../en/browser_extension.md"><img src="https://img.shields.io/badge/lang-English-blue?style=for-the-badge" alt="English version"></a>
</p>


Одноразовая настройка для Chromium и Firefox на **Linux, Windows и macOS desktop**.

Путь: `extensions/secure-vpn-proxy-auth/`

## Зачем нужно

На desktop приложение устанавливает системный HTTP-прокси на `127.0.0.1:1081` с аутентификацией. **Chromium и Firefox часто игнорируют сохранённые пароли прокси** и показывают диалог входа. Расширение получает учётные данные сессии через native messaging и автоматически отвечает на `407 Proxy Authentication Required`.

## Native messaging host

Имя host: `com.secure.vpn.proxy_auth` — устанавливается при первом `setup()`.

### Linux

| Компонент | Путь |
|-----------|------|
| Бинарник | `~/.local/share/v2ray_box/native_host/secure_vpn_native_host` |
| Chrome manifest | `~/.config/google-chrome/NativeMessagingHosts/com.secure.vpn.proxy_auth.json` |
| Firefox manifest | `~/.mozilla/native-messaging-hosts/com.secure.vpn.proxy_auth.json` |

### Windows

| Компонент | Путь |
|-----------|------|
| Бинарник | `%LOCALAPPDATA%\v2ray_box\native_host\secure_vpn_native_host.exe` |
| Chrome (реестр) | `HKCU\Software\Google\Chrome\NativeMessagingHosts\com.secure.vpn.proxy_auth` |
| Edge (реестр) | `HKCU\Software\Microsoft\Edge\NativeMessagingHosts\com.secure.vpn.proxy_auth` |
| Firefox manifest | `%APPDATA%\Mozilla\NativeMessagingHosts\com.secure.vpn.proxy_auth.json` |

### macOS

| Компонент | Путь |
|-----------|------|
| Бинарник (установленный) | `~/Library/Application Support/V2rayBox/working/native_host/secure_vpn_native_host` |
| Chrome manifest | `~/Library/Application Support/Google/Chrome/NativeMessagingHosts/com.secure.vpn.proxy_auth.json` |
| Edge manifest | `~/Library/Application Support/Microsoft Edge/NativeMessagingHosts/com.secure.vpn.proxy_auth.json` |
| Firefox manifest | `~/Library/Application Support/Mozilla/NativeMessagingHosts/com.secure.vpn.proxy_auth.json` |

Бинарник host копируется из bundle приложения при `setup()`. `session.json` существует только при Connected; пароли не логируются.

Публикация в store: `extensions/secure-vpn-proxy-auth/store/SUBMISSION_CHECKLIST.md`.

## Установка расширения

1. Откройте `chrome://extensions` (Firefox: `about:debugging#/runtime/this-firefox`).
2. Включите **Режим разработчика** (Chromium) или **Загрузить временное дополнение** (Firefox).
3. Загрузите папку `extensions/secure-vpn-proxy-auth/`.

**Chromium extension ID:** `hlpppofeeecjldogljipggakkdeppoeb`

**Firefox extension ID:** `secure-vpn-proxy-auth@secure-vpn.local`

## Проверка

1. Подключите VPN в приложении.
2. Popup расширения — `Ready: 127.0.0.1:1081`.
3. Сайт проверки IP — без диалога прокси.
4. **Settings → Browser helper** — все индикаторы зелёные.

## Fallback (вручную)

Скопируйте логин/пароль с **Home** или **Settings → System proxy (this session)**. При reconnect — новые creds.

См. [troubleshooting.md](troubleshooting.md).
