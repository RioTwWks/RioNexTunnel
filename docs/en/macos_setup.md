# macOS setup

<p align="right">
  <a href="../ru/macos_setup.md"><img src="https://img.shields.io/badge/lang-Русский-red?style=for-the-badge" alt="Русская версия"></a>
</p>


## Prerequisites

- **macOS 10.15 (Catalina) or later** (64-bit Intel or Apple Silicon)
- [Flutter SDK](https://docs.flutter.dev/get-started/install/macos) `stable` (Dart version in `secure_vpn_client/pubspec.yaml`)
- **Xcode 15+** with command-line tools (`xcode-select --install`)
- **CocoaPods** (usually installed with Flutter macOS toolchain)

Verify Flutter desktop support:

```bash
flutter doctor
flutter config --enable-macos-desktop
```

## Platform status

| Area | Status |
|------|--------|
| Flutter app shell | Builds and runs |
| `v2ray_box` macOS plugin | **Implemented** — `XrayProcess` / `SingboxProcess`, `start_with_json`, system proxy via `networksetup` |
| Secure inbound injection | Done in Dart (`ConfigParser.injectSecureSocksInbound`) before `connectWithJson` |
| System proxy integration | Uses `networksetup` on active network services (Wi‑Fi, Ethernet, …) |
| E2E connect verification | **Pending** — see backlog in `.cursor/tasks.md` |
| Browser extension / proxy auth helper | **Linux only today** — macOS has no native messaging host yet |

macOS desktop uses **proxy mode** (`VpnMode.proxy`), not a system TUN VPN. **Connected** means the core process is running and system proxy is configured — not that all traffic is automatically tunneled without browser cooperation.

> **Known gap:** the Swift plugin reads proxy port from `ConfigOptions` (`mixed-port` / `socks-port` defaults), while RioNexTunnel injects secure inbounds on ports **1080** (SOCKS) and **1081** (HTTP). Until the plugin is aligned with Linux (`system_proxy.cc`), verify proxy settings in **System Settings → Network → … → Details → Proxies** after Connect.

## Core binaries

From repository root:

```bash
./scripts/fetch_cores.sh
```

Copies into `secure_vpn_client/macos/Runner/Resources/`:

- `xray`, `sing-box`
- `geoip.dat`, `geosite.dat` (required for xray subscriptions with `geosite:` / `geoip:` routing)

These files are gitignored; each developer and CI job must fetch them.

### Manual download

1. Download the latest [Xray-core `Xray-macos-64.zip`](https://github.com/XTLS/Xray-core/releases) and [sing-box `darwin-amd64` archive](https://github.com/SagerNet/sing-box/releases) (use `darwin-arm64` on Apple Silicon if available).
2. Place `xray` and `sing-box` in `secure_vpn_client/macos/Runner/Resources/`.
3. Make them executable: `chmod +x macos/Runner/Resources/{xray,sing-box}`.
4. Download [`geoip.dat`](https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat) and [`geosite.dat`](https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat) into the same folder.

### Alternative path (`Frameworks/`)

The `v2ray_box` podspec also documents `macos/Frameworks/` as a binary location. `fetch_cores.sh` targets `Runner/Resources/`; the plugin searches both `Contents/Resources/` and `Contents/Frameworks/` at runtime.

Override search paths with environment variables:

- `V2RAY_BOX_XRAY_PATH` / `V2RAY_BOX_SINGBOX_PATH`
- `V2RAY_BOX_CORE_DIR`

## Run

```bash
cd secure_vpn_client
flutter pub get
flutter run -d macos
```

After editing `packages/v2ray_box/macos/*`, do a **full restart** (not hot reload).

Open the workspace in Xcode when debugging native code:

```bash
open macos/Runner.xcworkspace
```

### Build output layout

Debug bundle (paths vary by build mode):

```
build/macos/Build/Products/Debug/secure_vpn_client.app/Contents/
├── MacOS/secure_vpn_client
└── Resources/
    ├── xray
    ├── sing-box
    ├── geoip.dat
    └── geosite.dat
```

## Mode

On Connect, the Flutter app:

1. Resolves subscription or config link via `ConfigParser` / `LinkConfigBuilder`.
2. Injects authenticated local inbounds on `127.0.0.1` only (`injectSecureSocksInbound`, `proxyOnly: true`).
3. Calls `connectWithJson` — the macOS plugin writes `active_config.json` and spawns xray or sing-box.
4. Enables system proxy via `/usr/sbin/networksetup` on active network services.

| Port | Protocol | Purpose |
|------|----------|---------|
| `1080` | SOCKS5 (auth required) | Apps that support SOCKS with username/password |
| `1081` | HTTP (auth required) | Intended for system / browser proxy (see platform status note above) |

Session username/password are generated per Connect, shown on **Home** and in **Settings → System proxy (this session)**, and wiped on disconnect. They are **local proxy credentials**, not your VPN server login.

### Manual proxy login (fallback)

Without a macOS browser helper extension, copy username/password from Home or Settings into the browser dialog when prompted. Credentials change on each reconnect.

### Manual SOCKS (optional)

For apps that support SOCKS5 with auth, point them at `127.0.0.1:1080` with session credentials from Settings.

## Runtime directories

| Path | Purpose |
|------|---------|
| `~/Library/Application Support/V2rayBox/working/profiles/active_config.json` | Active core config |
| `~/Library/Application Support/V2rayBox/working/` | Plugin working directory |
| `~/Library/Application Support/<bundle-id>/v2ray_box/cores/` | Optional user-installed cores |

Geo assets are read from the directory next to the core binary (`geoip.dat`, `geosite.dat` in `Resources/`).

## Security check

With VPN connected (from macOS Terminal or Linux):

```bash
./scripts/security_probe.sh 1080
```

Unauthenticated probe must fail. See [security.md](security.md).

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `xray binary not found` / `sing-box binary not found` | Empty `Runner/Resources/` | Run `fetch_cores.sh`; `chmod +x` binaries; rebuild |
| Core exits immediately | Missing geo assets or bad subscription JSON | Check Console.app stderr; ensure `geoip.dat` / `geosite.dat` present |
| **Connected** but browser has no VPN | System proxy port mismatch | Set HTTP proxy manually to `127.0.0.1:1081` with session creds from Settings |
| `networksetup` has no effect | No admin rights or no active interface | Connect Wi‑Fi/Ethernet; check **System Settings → Network → Proxies** |
| `geosite.dat: no such file` | v2rayNG subscription uses geo rules | Run `fetch_cores.sh`; keep geo files next to `xray` in `Resources/` |
| Hot reload after Swift changes | Native code not reloaded | Stop app; `flutter run -d macos` again |

See also [troubleshooting.md](troubleshooting.md) for subscription and config issues shared across platforms.

## Contributing (macOS native)

Priority items for parity with Linux:

1. Align `getProxyPort()` / `enableSystemProxy()` with Dart secure ports (`1081` HTTP with auth).
2. Port Linux credential channel + browser native messaging for Chromium proxy auth.
3. E2E smoke test: all four engine × profile combinations.
4. Wipe `active_config.json` and proxy settings on disconnect (mirror Linux `wipe_sensitive_files`).

See [contributing.md](contributing.md).
