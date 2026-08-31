# Windows setup

<p align="right">
  <a href="../ru/windows_setup.md"><img src="https://img.shields.io/badge/lang-Русский-red?style=for-the-badge" alt="Русская версия"></a>
</p>


## Prerequisites

- **Windows 10 or later** (64-bit)
- [Flutter SDK](https://docs.flutter.dev/get-started/install/windows) `stable` (Dart version in `secure_vpn_client/pubspec.yaml`)
- **Visual Studio 2022** with the **Desktop development with C++** workload (includes MSVC, Windows SDK, CMake)
- **Git for Windows** (recommended) — to run `fetch_cores.sh` from Git Bash

Verify Flutter desktop support:

```powershell
flutter doctor
flutter config --enable-windows-desktop
```

## Platform status

| Area | Status |
|------|--------|
| Flutter app shell | Builds and runs |
| Core binaries in bundle | CMake copies `runner/resources/` → `{exe_dir}/resources/` |
| `v2ray_box` Windows plugin | **Stub** — only `getPlatformVersion` today |
| Connect / proxy mode | **Not yet** — needs `desktop_core` + `SystemProxy` (see backlog in `.cursor/tasks.md`) |

Windows desktop is intended to use **proxy mode** (`VpnMode.proxy`), same as Linux: authenticated local inbounds on `127.0.0.1` only, not a system TUN VPN. Until the native plugin is implemented, you can build and explore the UI, but **Connect will not start xray/sing-box**.

## Core binaries

From repository root (Git Bash, WSL, or Linux/macOS):

```bash
./scripts/fetch_cores.sh
```

Copies into `secure_vpn_client/windows/runner/resources/`:

- `xray.exe`, `sing-box.exe`
- `geoip.dat`, `geosite.dat` (required for xray subscriptions with `geosite:` / `geoip:` routing)

These files are gitignored; each developer and CI job must fetch them.

### Manual download (without Bash)

1. Download the latest [Xray-core `Xray-windows-64.zip`](https://github.com/XTLS/Xray-core/releases) and [sing-box `windows-amd64.zip`](https://github.com/SagerNet/sing-box/releases).
2. Extract `xray.exe` and `sing-box.exe` into `secure_vpn_client/windows/runner/resources/`.
3. Download [`geoip.dat`](https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat) and [`geosite.dat`](https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat) into the same folder.

## Run

```powershell
cd secure_vpn_client
flutter pub get
flutter run -d windows
```

After editing `packages/v2ray_box/windows/*`, do a **full restart** (not hot reload).

### Build output layout

CMake installs bundled cores next to the executable:

```
build\windows\x64\runner\Debug\
├── secure_vpn_client.exe
└── resources\
    ├── xray.exe
    ├── sing-box.exe
    ├── geoip.dat
    └── geosite.dat
```

Binary discovery (when the plugin is implemented) will follow the same order as Linux: env overrides → `{exe_dir}/resources/` → user data dir.

## Mode (planned)

When the Windows plugin reaches parity with Linux:

1. Start xray/sing-box with authenticated local inbounds on `127.0.0.1` only.
2. Set **Windows system proxy** (WinINet / registry) to HTTP `127.0.0.1:1081` with session credentials.

| Port | Protocol | Purpose |
|------|----------|---------|
| `1080` | SOCKS5 (auth required) | Apps that support SOCKS with username/password |
| `1081` | HTTP (auth required) | System / browser proxy |

Session username/password are generated per Connect, shown on **Home** and in **Settings → System proxy (this session)**, and wiped on disconnect. They are **local proxy credentials**, not your VPN server login.

### Browser proxy auth (planned)

Chromium on Windows may ignore stored proxy passwords. A browser extension and native messaging host (similar to Linux) are planned; until then, manual credential entry from Home/Settings is the fallback.

## Runtime directories (planned)

| Path | Purpose |
|------|---------|
| `%LOCALAPPDATA%\v2ray_box\profiles\active_config.json` | Active core config (wiped on disconnect) |
| `%LOCALAPPDATA%\v2ray_box\assets\` | Xray geo databases |

Linux uses `~/.local/share/v2ray_box/`; Windows will use the equivalent under `%LOCALAPPDATA%`.

## Security check

When Connect is implemented, with VPN connected run from Git Bash or WSL:

```bash
./scripts/security_probe.sh 1080
```

Unauthenticated probe must fail. See [security.md](security.md).

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `flutter run -d windows` fails on MSVC | Missing VS 2022 C++ workload | Install **Desktop development with C++** in Visual Studio Installer |
| No Windows device | Desktop not enabled | `flutter config --enable-windows-desktop` |
| Connect does nothing / `NotImplemented` | Windows plugin is still a stub | Expected today; track `.cursor/tasks.md` |
| Cores not found after build | `runner/resources/` empty | Run `fetch_cores.sh` or manual download; rebuild |
| Geo routing errors | Missing `geoip.dat` / `geosite.dat` | Same as cores — place in `runner/resources/` |

See also [troubleshooting.md](troubleshooting.md) for subscription and config issues shared across platforms.

## Contributing (Windows native)

To implement Windows desktop proxy mode:

1. Port `packages/v2ray_box/linux/desktop_core.cc` → `packages/v2ray_box/windows/desktop_core.cpp` (process spawn, stderr capture, geo copy).
2. Port `linux/system_proxy.cc` → Windows WinINet / registry system proxy.
3. Wire method channel handlers in `v2ray_box_plugin.cpp` (mirror `linux/v2ray_box_plugin.cc`).
4. Full restart + smoke test all four engine × profile combinations.

See [contributing.md](contributing.md).
