<p align="right">
  <a href="README_RU.md"><img src="https://img.shields.io/badge/lang-Русский-red?style=for-the-badge" alt="Русская версия"></a>
</p>

# RioNexTunnel (MVP)

**RIO — Reliable Internet Overlay.** Cross-platform Flutter VPN client with Xray-core and sing-box  
*Nexus + Tunnel — a secure linking channel across configs and platforms.*  
*Immune to unauthenticated local SOCKS5 proxy vulnerability (March 2026)*

[![Flutter](https://img.shields.io/badge/Flutter-3.22+-blue.svg)](https://flutter.dev)
[![Xray-core](https://img.shields.io/badge/Xray--core-1.8.24+-green.svg)](https://github.com/XTLS/Xray-core)
[![sing-box](https://img.shields.io/badge/sing--box-1.10+-orange.svg)](https://github.com/SagerNet/sing-box)
[![License](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

---

## Overview

**RioNexTunnel** unifies configs and platforms into a protected channel. The app connects to VPN servers via VLESS, VMess, Shadowsocks, Trojan, Hysteria/Hysteria2, TUIC, WireGuard, SSH, and other protocols through **Xray-core** and **sing-box** engines.

Built on Flutter for **Android, iOS, Windows, Linux, and macOS**.

---

## Documentation

| Guide | Description |
|-------|-------------|
| [Getting started](docs/en/getting_started.md) | Clone, dependencies, cores, run |
| [Linux setup](docs/en/linux_setup.md) | Desktop proxy mode, browser extension |
| [Android setup](docs/en/android_setup.md) | VPN mode, manifest, jniLibs |
| [iOS setup](docs/en/ios_setup.md) | Network Extensions, entitlements |
| [Architecture](docs/en/architecture.md) | Components and data flow |
| [Security](docs/en/security.md) | SOCKS auth model and verification |
| [Browser extension](docs/en/browser_extension.md) | Proxy auth helper for Chromium/Firefox |
| [Troubleshooting](docs/en/troubleshooting.md) | Common errors and fixes |
| [Contributing](docs/en/contributing.md) | PR checklist and edit targets |

Full documentation index: [docs/README.md](docs/README.md) · Russian: [docs/ru/README.md](docs/ru/README.md)

For Cursor AI agents: [.cursor/AGENTS.md](.cursor/AGENTS.md)

---

## Quick start

```bash
git clone https://github.com/RioTwWks/Secure-Cross-Platform-VPN-Client.git
cd Secure-Cross-Platform-VPN-Client
./scripts/fetch_cores.sh
cd secure_vpn_client
flutter pub get
flutter run -d linux    # or android, windows, macos, ios
```

Details: [docs/en/getting_started.md](docs/en/getting_started.md)

---

## Security highlights

- SOCKS5 on `127.0.0.1` only, **password auth required**, per-session random credentials
- No `0.0.0.0` binding, no unauthenticated port `7890`
- Credentials wiped on disconnect; never logged or persisted

See [docs/en/security.md](docs/en/security.md) for the full security model.

---

## Repository structure

```
├── secure_vpn_client/       # Flutter app → secure_vpn_client/README.md
├── packages/v2ray_box/      # Plugin fork
├── scripts/                 # fetch_cores.sh, security_probe.sh
├── docs/en/                 # English documentation
├── docs/ru/                 # Russian documentation
└── extensions/secure-vpn-proxy-auth/  # Linux browser helper
```

---

## License

[GNU General Public License v3.0](LICENSE) (GPLv3)

## Disclaimer

Educational and research use. Users must comply with local laws.
