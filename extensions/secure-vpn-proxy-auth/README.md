<p align="right">
  <a href="README.ru.md"><img src="https://img.shields.io/badge/lang-Русский-red?style=for-the-badge" alt="Русская версия"></a>
</p>

# RioNexTunnel Proxy Auth (browser extension)

One-time setup for Chromium and Firefox on Linux desktop.

Full guide: [docs/en/browser_extension.md](../../docs/en/browser_extension.md)

## Install extension

1. Open `chrome://extensions` (Chromium) or `about:debugging#/runtime/this-firefox` (Firefox).
2. Enable **Developer mode** (Chromium) or **Load Temporary Add-on** (Firefox).
3. Load this folder (`extensions/secure-vpn-proxy-auth`).

**Chromium extension ID:** `hlpppofeeecjldogljipggakkdeppoeb` (fixed via manifest `key`).

**Firefox extension ID:** `secure-vpn-proxy-auth@secure-vpn.local`

## Native messaging host

The VPN app installs the native host automatically on first `setup()` (connect once).

Host name: `com.secure.vpn.proxy_auth`

| Component | Path |
|-----------|------|
| Binary | `~/.local/share/v2ray_box/native_host/secure_vpn_native_host` |
| Chrome manifest | `~/.config/google-chrome/NativeMessagingHosts/com.secure.vpn.proxy_auth.json` |
| Chromium manifest | `~/.config/chromium/NativeMessagingHosts/com.secure.vpn.proxy_auth.json` |
| Firefox manifest | `~/.mozilla/native-messaging-hosts/com.secure.vpn.proxy_auth.json` |

## Verify

1. Connect VPN in the app.
2. Open the extension popup — should show `Ready: 127.0.0.1:1081`.
3. Open an IP check site — proxy login dialog should not appear.
