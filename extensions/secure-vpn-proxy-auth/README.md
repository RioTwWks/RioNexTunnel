# Secure VPN Proxy Auth (browser extension)

> **Language / Язык:** **English** | [Русский](README.ru.md)

One-time setup for Chromium and Firefox on Linux desktop.

## Install extension

1. Open `chrome://extensions` (Chromium: `chrome://extensions`, Firefox: `about:debugging#/runtime/this-firefox`).
2. Enable **Developer mode** (Chromium) or **Load Temporary Add-on** (Firefox).
3. Load this folder (`extensions/secure-vpn-proxy-auth`).

**Chromium extension ID:** `hlpppofeeecjldogljipggakkdeppoeb` (fixed via manifest `key`).

**Firefox extension ID:** `secure-vpn-proxy-auth@secure-vpn.local`

## Native messaging host

The VPN app installs the native host automatically on first `setup()` (Connect once).

Host name: `com.secure.vpn.proxy_auth`

Manual paths:

- Binary: `~/.local/share/v2ray_box/native_host/secure_vpn_native_host`
- Chrome manifest: `~/.config/google-chrome/NativeMessagingHosts/com.secure.vpn.proxy_auth.json`
- Chromium manifest: `~/.config/chromium/NativeMessagingHosts/com.secure.vpn.proxy_auth.json`
- Firefox manifest: `~/.mozilla/native-messaging-hosts/com.secure.vpn.proxy_auth.json`

## Verify

1. Connect VPN in the app.
2. Open extension popup — should show `Ready: 127.0.0.1:1081`.
3. Browse to an IP check site — no proxy login dialog.
