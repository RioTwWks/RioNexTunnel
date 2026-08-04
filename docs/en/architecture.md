# Architecture

[Русская версия](../ru/architecture.md)

## High-level flow

```mermaid
sequenceDiagram
    participant UI as Flutter UI
    participant VS as VpnService
    participant CP as ConfigParser
    participant VB as v2ray_box plugin
    participant Core as xray / sing-box

    UI->>VS: connect(profile)
    VS->>CP: parseFromUrl / buildFromLink
    VS->>CP: injectSecureSocksInbound(credentials)
    VS->>VB: connectWithJson(secureConfig)
    VB->>VB: write active_config.json
    VB->>VB: SystemProxy::Enable (Linux GNOME)
    VB->>Core: spawn subprocess
    Core-->>VB: stderr on failure
    VB-->>UI: status events
```

## Flutter app (`secure_vpn_client`)

### State management

- **Riverpod** — `vpn_providers.dart`
  - `vpnServiceProvider`, `engineProvider`, `profilesProvider`, `selectedProfileProvider`
  - Profiles persisted via `shared_preferences`

### Security layer (Dart)

1. **`CredentialService`** — CSPRNG username/password per session (`crypto_utils.dart`).
2. **`ConfigParser.injectSecureSocksInbound()`** — removes unsafe SOCKS inbounds, adds authenticated SOCKS on `127.0.0.1:1080`; when `proxyOnly: true` (desktop), also adds HTTP inbound on `socksPort + 1` (default `1081`) with the same session credentials for GNOME system proxy.
3. **`ConfigParser` subscription handling** — User-Agent selection, decoy skipping, v2rayNG JSON array parsing, sing-box DNS migration, proxy-only inbound stripping on desktop.
4. **`LinkConfigBuilder`** — builds minimal xray/sing-box JSON from share links (`vless://`, `vmess://`, `trojan://`, `ss://`).

### VpnService

- `initialize()` — sets `VpnMode.proxy` on desktop, `enableTun: false` in `ConfigOptions`.
- `resolveProfileConfig()` — subscription URL → normalized link or JSON; config link → `LinkConfigBuilder`.
- `connect()` — inject secure inbound → `checkConfigJson` → set credentials channel → `connectWithJson`.

## v2ray_box fork (`packages/v2ray_box`)

Path dependency in `secure_vpn_client/pubspec.yaml`:

```yaml
v2ray_box:
  path: ../packages/v2ray_box
```

### Linux desktop plugin

| File | Role |
|------|------|
| `linux/v2ray_box_plugin.cc` | Method channel `v2ray_box`, credentials channel `secure_vpn/credentials`; calls `SystemProxy::Enable`/`Disable` on start/stop |
| `linux/desktop_core.cc` | FindBinary, Start/Stop subprocess, geo asset copy, stderr capture, orphan process cleanup on ports 1080/1081 |
| `linux/desktop_core.h` | Shared helpers (paths, WriteTextFile, EnsureXrayGeoAssets) |
| `linux/system_proxy.cc` | GNOME GSettings backup/restore; sets HTTP proxy `127.0.0.1:1081` with session auth |
| `linux/native_messaging.cc` | Installs native host + browser manifests; publishes session creds for extension |
| `linux/native_messaging_host.cc` | Standalone stdio host (`secure_vpn_native_host`) for Chrome/Firefox extension |
| `extensions/secure-vpn-proxy-auth/` | Browser extension: `onAuthRequired` + native messaging |

**Runtime paths:**

- Working dir: `~/.local/share/v2ray_box/`
- Active config: `~/.local/share/v2ray_box/profiles/active_config.json`
- Xray geo assets: `~/.local/share/v2ray_box/assets/{geoip,geosite}.dat`
- Bundled cores: `{app_bundle}/lib/resources/{xray,sing-box}`

**Environment variables (child process):**

- `XRAY_LOCATION_ASSET` → assets dir
- `SECURE_VPN_SOCKS_USER`, `SECURE_VPN_SOCKS_PASS`, `SECURE_VPN_SOCKS_PORT`

### Android / iOS / macOS

Fork includes secure credential plugins and config builders. Android uses `VpnService` / `BoxService`; iOS/macOS use Swift `ConfigBuilder` + process wrappers.

## Config formats

### Xray (subscription via v2rayNG UA)

Server returns JSON **array** of configs. First real entry has `vless`/`vmess`/`trojan` outbound. Routing may use `geosite:` / `geoip:` rules → requires geo `.dat` files.

Placeholder `outboundTag: "proxy"` is rewritten to the actual outbound tag in `ConfigParser`.

### sing-box (subscription via `sing-box` UA)

Server returns base64-encoded **link list**. First non-decoy `vless://` link is parsed by `LinkConfigBuilder`.

### Hiddify JSON (avoid on desktop)

Default Dart `http` User-Agent (`Dart/x.x (dart:io)`) may return full sing-box JSON with `tun-in`, legacy DNS — **do not use**; always set explicit UA in `parseFromUrl`.

## Security model (desktop proxy mode)

```
[Browser] --system proxy--> 127.0.0.1:1081 HTTP (auth required)
     ^                           ^
     |                           |
[Extension] <--native messaging-- [Flutter app] --> session.json + GSettings
[Other apps] --> 127.0.0.1:1080 SOCKS (auth required, same session creds)
                              |
                    [xray/sing-box] --> remote outbound
```

Auth is mandatory by design — per-session random credentials on `127.0.0.1` only; wiped on disconnect. Chromium ignores GSettings proxy passwords; the **browser extension** auto-fills `407` challenges via native messaging.

Vulnerable pattern we avoid:

```
[Any app on LAN/localhost] --> 0.0.0.0:7890 (no auth)  # CVE-class issue, March 2026
```

See [security.md](security.md) for verification steps.
