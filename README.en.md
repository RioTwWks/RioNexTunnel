# Secure VPN Client (MVP)

**Cross-platform Flutter VPN client with Xray-core and sing-box**  
*Hardened against the unauthenticated local SOCKS5 proxy vulnerability class (March 2026)*

[Русский](README.ru.md) · [Documentation](docs/en/README.md)

[![Flutter](https://img.shields.io/badge/Flutter-3.22+-blue.svg)](https://flutter.dev)
[![Xray-core](https://img.shields.io/badge/Xray--core-1.8.24+-green.svg)](https://github.com/XTLS/Xray-core)
[![sing-box](https://img.shields.io/badge/sing--box-1.10+-orange.svg)](https://github.com/SagerNet/sing-box)
[![License](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

---

## Overview

**Secure VPN Client** is a secure, flexible VPN client (MVP). Connect via VLESS, VMess, Shadowsocks, Trojan, and related protocols through Xray-core and sing-box. Unlike many existing clients, it **eliminates the unauthenticated local SOCKS5 proxy vulnerability** found in spring 2026 in apps such as Hiddify, v2rayNG, Happ, and others.

Platforms: **Android, iOS, Windows, Linux, macOS**.

Full documentation: [docs/en/](docs/en/README.md)

---

## Security highlights

- **Dynamic SOCKS5 authentication** — unique username/password per VPN start; never written to disk; wiped on stop.
- **Localhost only** — proxies bound to `127.0.0.1` with mandatory auth.
- **No open ports** — never listen on `0.0.0.0`, never leave port `7890` without a password.
- **Switchable engines** — Xray-core or sing-box through one secure wrapper.

Details: [docs/en/security.md](docs/en/security.md)

---

## Tech stack

| Component | Technology |
|-----------|------------|
| UI & logic | Flutter (Dart) |
| Tunneling | Local fork [`packages/v2ray_box`](packages/v2ray_box) |
| Core 1 | [Xray-core](https://github.com/XTLS/Xray-core) |
| Core 2 | [sing-box](https://github.com/SagerNet/sing-box) |
| Native bridges | Android (Kotlin), iOS/macOS (Swift), Linux/Windows (C++ plugin) |

---

## Quick start

```bash
git clone https://github.com/RioTwWks/Secure-Cross-Platform-VPN-Client.git
cd Secure-Cross-Platform-VPN-Client
./scripts/fetch_cores.sh
cd secure_vpn_client
flutter pub get
flutter run -d linux    # or android / windows / macos / ios
```

Full guide: [docs/en/getting-started.md](docs/en/getting-started.md)

| Platform | Guide |
|----------|-------|
| Linux | [docs/en/linux_setup.md](docs/en/linux_setup.md) |
| Android | [docs/en/android_setup.md](docs/en/android_setup.md) |
| iOS | [docs/en/ios_setup.md](docs/en/ios_setup.md) |
| Browser extension | [docs/en/browser-extension.md](docs/en/browser-extension.md) |

> For Cursor AI agents: [.cursor/AGENTS.md](.cursor/AGENTS.md)

---

## Security testing

```bash
# With VPN connected, from repository root
./scripts/security_probe.sh 1080
```

Unauthenticated access to the local SOCKS proxy must fail. See [docs/en/security.md](docs/en/security.md).

---

## Repository layout

```
Secure-Cross-Platform-VPN-Client/
├── secure_vpn_client/            # Flutter app
├── packages/v2ray_box/           # Plugin fork
├── scripts/                      # fetch_cores, security_probe, sync
├── docs/en/ · docs/ru/           # Documentation (EN / RU)
├── extensions/                   # Browser helper (Linux)
└── .cursor/                      # Agent-oriented docs
```

---

## Roadmap (post-MVP)

- [x] Subscriptions, engine switching, security tests
- [x] Linux desktop: proxy mode, 4 engine × profile combinations
- [ ] Server picker from subscription list
- [ ] E2E on Android / iOS / Windows / macOS
- [ ] Split tunneling on mobile
- [ ] CI: `flutter analyze` + `flutter test`

Backlog: [.cursor/tasks.md](.cursor/tasks.md)

---

## Contributing

See [docs/en/contributing.md](docs/en/contributing.md). Before a PR: `flutter analyze` and `flutter test` in `secure_vpn_client/`.

---

## License and disclaimer

**GNU GPLv3** — [LICENSE](LICENSE).

Software is provided “as is” for educational and research purposes. Users must comply with the laws of their jurisdiction.

## Acknowledgements

XTLS (Xray-core), SagerNet (sing-box), `v2ray_box` authors, Flutter community.
