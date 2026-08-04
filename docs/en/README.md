# Secure VPN Client (MVP)

**Cross-platform VPN client on Flutter with Xray-core and sing-box support**  
*Protection against unauthenticated local SOCKS5 proxy vulnerability (March 2026)*

[![Flutter](https://img.shields.io/badge/Flutter-3.22+-blue.svg)](https://flutter.dev)
[![Xray-core](https://img.shields.io/badge/Xray--core-1.8.24+-green.svg)](https://github.com/XTLS/Xray-core)
[![sing-box](https://img.shields.io/badge/sing--box-1.10+-orange.svg)](https://github.com/SagerNet/sing-box)
[![License](https://img.shields.io/badge/License-GPLv3-blue.svg)](../../LICENSE)

[Русская версия](../ru/README.md)

---

## Overview

**Secure VPN Client** is a secure and flexible VPN client built as an MVP. The app connects to VPN servers via VLESS, VMess, Shadowsocks, Trojan, and other protocols (through Xray-core and sing-box engines). The main difference from many existing clients is **complete elimination of the unauthenticated local SOCKS5 proxy vulnerability** discovered in spring 2026 in apps such as Hiddify, v2rayNG, Happ, and others.

The project is built from scratch on Flutter for five platforms: **Android, iOS, Windows, Linux, macOS**.

---

## Key security features

- **Dynamic SOCKS5 authentication** — unique username/password per VPN session; credentials are never saved to disk and are destroyed after disconnect.
- **No access for third-party apps** — local proxy binds to `127.0.0.1` only and requires authentication. On Android (VPN mode), an allowlist (`allowApps`) restricts which apps may use the proxy.
- **No open ports** — unlike vulnerable clients, the app does **not** listen on `0.0.0.0` and does **not** leave port `7890` without a password. Each session uses port `1080` (SOCKS) and `1081` (HTTP on desktop) with random credentials.
- **Switchable engines** — use Xray-core or sing-box; both are configured through the same secure wrapper.

---

## Tech stack

| Component | Technology |
|-----------|------------|
| UI and logic | Flutter (Dart) |
| VPN tunneling | Local fork [`packages/v2ray_box`](../../packages/v2ray_box) |
| Engine 1 | [Xray-core](https://github.com/XTLS/Xray-core) (Go, subprocess) |
| Engine 2 | [sing-box](https://github.com/SagerNet/sing-box) (Go, subprocess) |
| Native bridges | Android (Kotlin), iOS/macOS (Swift), Linux/Windows (C++ plugin) |

---

## Documentation

| Guide | Description |
|-------|-------------|
| [Getting started](getting_started.md) | Clone, dependencies, cores, run |
| [Linux setup](linux_setup.md) | Desktop proxy mode, browser extension |
| [Android setup](android_setup.md) | VPN mode, manifest, jniLibs |
| [iOS setup](ios_setup.md) | Network Extensions, entitlements |
| [Architecture](architecture.md) | Components and data flow |
| [Security](security.md) | SOCKS auth model and verification |
| [Browser extension](browser_extension.md) | Proxy auth helper for Chromium/Firefox |
| [Troubleshooting](troubleshooting.md) | Common errors and fixes |
| [Contributing](contributing.md) | PR checklist and edit targets |

---

## Repository structure

```
Secure-Cross-Platform-VPN-Client/
├── secure_vpn_client/       # Flutter app
├── packages/v2ray_box/      # Plugin fork (Linux desktop, Android patches)
├── scripts/                 # fetch_cores.sh, security_probe.sh
├── docs/en/                 # English documentation (this folder)
├── docs/ru/                 # Russian documentation
└── .cursor/                 # Agent docs (AGENTS.md)
```

---

## Roadmap (post-MVP)

- [x] Subscriptions (engine-specific User-Agent)
- [x] Xray / sing-box engine switch
- [x] Security unit tests
- [x] Linux desktop: proxy mode, all 4 engine × profile combinations
- [ ] Server picker from subscription list
- [ ] Full E2E on Android / iOS / Windows / macOS
- [ ] CI: `flutter analyze` + `flutter test`

---

## Contributing

1. `flutter analyze` must pass (`secure_vpn_client/analysis_options.yaml`).
2. Add tests for new security-related functionality.
3. Verify SOCKS5 vulnerability does not reappear (`test/security_test.dart`).

---

## License

**GNU General Public License v3.0** (GPLv3) — see [LICENSE](../../LICENSE).

---

## Disclaimer

This software is provided "as is" for educational and research purposes. Developers are not responsible for unlawful use. Users must comply with local laws.

---

## Acknowledgments

- **XTLS** team for Xray-core
- **SagerNet** for sing-box
- **v2ray_box** plugin authors (fork)
- Flutter community
