# Browser extension (Linux)

[← Documentation index](README.md) · [Русский](../ru/browser-extension.md)

One-time setup for Chromium and Firefox on Linux desktop. Source: `extensions/secure-vpn-proxy-auth/`.

Chromium ignores proxy passwords from GSettings. The extension answers HTTP `407` proxy-auth challenges using session credentials published by the VPN app over native messaging.

## Install extension

1. Open `chrome://extensions` (Chromium: `chrome://extensions`, Firefox: `about:debugging#/runtime/this-firefox`).
2. Enable **Developer mode** (Chromium) or **Load Temporary Add-on** (Firefox).
3. Load this folder: `extensions/secure-vpn-proxy-auth`.

**Chromium extension ID:** `hlpppofeeecjldogljipggakkdeppoeb` (fixed via manifest `key`).

**Firefox extension ID:** `secure-vpn-proxy-auth@secure-vpn.local`

## Native messaging host

The VPN app installs the native host automatically on first `setup()` (Connect once).

Host name: `com.secure.vpn.proxy_auth`

| Component | Path |
|-----------|------|
| Binary | `~/.local/share/v2ray_box/native_host/secure_vpn_native_host` |
| Chrome manifest | `~/.config/google-chrome/NativeMessagingHosts/com.secure.vpn.proxy_auth.json` |
| Chromium manifest | `~/.config/chromium/NativeMessagingHosts/com.secure.vpn.proxy_auth.json` |
| Firefox manifest | `~/.mozilla/native-messaging-hosts/com.secure.vpn.proxy_auth.json` |

## Verify

1. Connect VPN in the app.
2. Open extension popup — should show `Ready: 127.0.0.1:1081`.
3. Browse to an IP check site — no proxy login dialog.
4. In the app: **Settings → Browser helper** — all indicators green.

## Fallback

Without the extension, copy username/password from **Home** or **Settings → System proxy (this session)** into the browser dialog. Credentials rotate on every reconnect.

## Security note

The extension does **not** create an unauthenticated proxy. It only supplies the same per-session credentials that the core already requires on `127.0.0.1:1081`.
