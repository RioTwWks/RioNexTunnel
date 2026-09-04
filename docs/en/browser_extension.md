# Browser extension (proxy auth)

One-time setup for Chromium and Firefox on **Linux, Windows, and macOS desktop**.

Extension path: `extensions/secure-vpn-proxy-auth/`

## Why it is needed

On desktop, the app sets system proxy to HTTP `127.0.0.1:1081` with authentication. Chromium and Firefox often ignore stored proxy passwords and show a login dialog. The extension receives session credentials via native messaging and answers `407` automatically.

## Native messaging host

Host name: `com.secure.vpn.proxy_auth` — installed on first `setup()`.

### Linux

| Component | Path |
|-----------|------|
| Binary | `~/.local/share/v2ray_box/native_host/secure_vpn_native_host` |
| Chrome manifest | `~/.config/google-chrome/NativeMessagingHosts/com.secure.vpn.proxy_auth.json` |
| Firefox manifest | `~/.mozilla/native-messaging-hosts/com.secure.vpn.proxy_auth.json` |

### Windows

| Component | Path |
|-----------|------|
| Binary | `%LOCALAPPDATA%\v2ray_box\native_host\secure_vpn_native_host.exe` |
| Chrome registry | `HKCU\Software\Google\Chrome\NativeMessagingHosts\com.secure.vpn.proxy_auth` |
| Edge registry | `HKCU\Software\Microsoft\Edge\NativeMessagingHosts\com.secure.vpn.proxy_auth` |
| Firefox manifest | `%APPDATA%\Mozilla\NativeMessagingHosts\com.secure.vpn.proxy_auth.json` |

### macOS

| Component | Path |
|-----------|------|
| Binary (installed) | `~/Library/Application Support/V2rayBox/working/native_host/secure_vpn_native_host` |
| Chrome manifest | `~/Library/Application Support/Google/Chrome/NativeMessagingHosts/com.secure.vpn.proxy_auth.json` |
| Chromium manifest | `~/Library/Application Support/Chromium/NativeMessagingHosts/com.secure.vpn.proxy_auth.json` |
| Edge manifest | `~/Library/Application Support/Microsoft Edge/NativeMessagingHosts/com.secure.vpn.proxy_auth.json` |
| Firefox manifest | `~/Library/Application Support/Mozilla/NativeMessagingHosts/com.secure.vpn.proxy_auth.json` |

The host binary is bundled in the app / plugin resources and copied on `setup()`. Credentials are written to `session.json` only while connected; never logged.

Store submission: `extensions/secure-vpn-proxy-auth/store/SUBMISSION_CHECKLIST.md`.
