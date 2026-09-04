# Расширение браузера (авторизация прокси)

<p align="right">
  <a href="../en/browser_extension.md"><img src="https://img.shields.io/badge/lang-English-blue?style=for-the-badge" alt="English version"></a>
</p>


Одноразовая настройка для Chromium и Firefox на **Linux, Windows и macOS desktop**.

Путь: `extensions/secure-vpn-proxy-auth/`

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

Публикация в store: `extensions/secure-vpn-proxy-auth/store/SUBMISSION_CHECKLIST.md`.
