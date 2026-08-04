# Linux setup

> **Language / Язык:** **English** | [Русский](linux_setup.ru.md)

## Prerequisites

```bash
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev
```

Flutter stable SDK (see `secure_vpn_client/pubspec.yaml` for Dart version).

## Core binaries

From repository root:

```bash
./scripts/fetch_cores.sh
```

This places into `secure_vpn_client/linux/runner/resources/`:

- `xray`, `sing-box`
- `geoip.dat`, `geosite.dat` (required for xray subscriptions with geosite/geoip routing)

These files are gitignored; each developer/CI job must fetch them.

## Run

```bash
cd secure_vpn_client
flutter pub get
flutter run -d linux
```

After editing `packages/v2ray_box/linux/*`, do a **full restart** (not hot reload).

## Runtime directories

| Path | Purpose |
|------|---------|
| `~/.local/share/v2ray_box/profiles/active_config.json` | Active core config (wiped on disconnect) |
| `~/.local/share/v2ray_box/assets/` | Xray geo databases |

## Mode

Linux desktop uses **proxy mode**, not a system TUN VPN. **Connected** means the core process is running and system proxy is configured — not that all traffic is automatically tunneled without browser cooperation.

On Connect, the app:

1. Starts xray/sing-box with authenticated local inbounds on `127.0.0.1` only.
2. Sets **GNOME system proxy** automatically (`setSystemProxy: true`) via GSettings.

| Port | Protocol | Purpose |
|------|----------|---------|
| `1080` | SOCKS5 (auth required) | Apps that support SOCKS with username/password |
| `1081` | HTTP (auth required) | GNOME / browser system proxy (GNOME does not support SOCKS auth) |

Session username/password are generated per Connect, shown on **Home** and in **Settings → System proxy (this session)**, and wiped on disconnect. They are **local proxy credentials**, not your VPN server login.

### Browser helper (recommended — no login dialog)

Chromium **ignores** GSettings proxy passwords. Install the one-time **browser extension** so proxy auth is filled automatically:

1. Run the app once (installs the native messaging host under `~/.local/share/v2ray_box/native_host/`).
2. Load unpacked extension: `extensions/secure-vpn-proxy-auth/` (see [extension README](../extensions/secure-vpn-proxy-auth/README.md)).
3. Connect VPN — check **Settings → Browser helper** (all indicators green).

| Component | Path |
|-----------|------|
| Native host binary | `~/.local/share/v2ray_box/native_host/secure_vpn_native_host` |
| Chrome manifest | `~/.config/google-chrome/NativeMessagingHosts/com.secure.vpn.proxy_auth.json` |
| Chromium manifest | `~/.config/chromium/NativeMessagingHosts/com.secure.vpn.proxy_auth.json` |
| Firefox manifest | `~/.mozilla/native-messaging-hosts/com.secure.vpn.proxy_auth.json` |

**Chromium extension ID:** `hlpppofeeecjldogljipggakkdeppoeb`

### Manual proxy login (fallback)

Without the extension, copy username/password from Home or Settings into the browser dialog when prompted. New credentials after each reconnect.

See [Browser asks for proxy login](../.cursor/troubleshooting.md#browser-asks-for-proxy-login-1270011081) in troubleshooting for details.

### Manual SOCKS (optional)

For apps that support SOCKS5 with auth (not GNOME), point them at `127.0.0.1:1080` with the same session credentials from Settings.

## Troubleshooting

See [.cursor/troubleshooting.md](../.cursor/troubleshooting.md) for detailed error → fix mapping.

## Security check

With VPN connected:

```bash
./scripts/security_probe.sh 1080
```

Unauthenticated probe must fail. Mandatory proxy authentication is intentional — it prevents other local processes from using the proxy without credentials (see March 2026 unauthenticated `0.0.0.0:7890` class of issues in other clients).
