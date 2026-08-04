# Secure VPN Client (MVP)

**Cross-platform Flutter VPN client with Xray-core and sing-box**  
*Immune to unauthenticated local SOCKS5 proxy vulnerability (March 2026)*

**Кроссплатформенный VPN-клиент на Flutter с Xray-core и sing-box**  
*Защита от неавторизованного локального SOCKS5-прокси (март 2026)*

[![Flutter](https://img.shields.io/badge/Flutter-3.22+-blue.svg)](https://flutter.dev)
[![Xray-core](https://img.shields.io/badge/Xray--core-1.8.24+-green.svg)](https://github.com/XTLS/Xray-core)
[![sing-box](https://img.shields.io/badge/sing--box-1.10+-orange.svg)](https://github.com/SagerNet/sing-box)
[![License](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

---

## Documentation / Документация

| Language | Index |
|----------|-------|
| **English** | [docs/en/README.md](docs/en/README.md) |
| **Русский** | [docs/ru/README.md](docs/ru/README.md) |

Full index: [docs/README.md](docs/README.md)

| Topic | EN | RU |
|-------|----|----|
| Getting started | [en/getting_started.md](docs/en/getting_started.md) | [ru/getting_started.md](docs/ru/getting_started.md) |
| Linux | [en/linux_setup.md](docs/en/linux_setup.md) | [ru/linux_setup.md](docs/ru/linux_setup.md) |
| Android | [en/android_setup.md](docs/en/android_setup.md) | [ru/android_setup.md](docs/ru/android_setup.md) |
| iOS | [en/ios_setup.md](docs/en/ios_setup.md) | [ru/ios_setup.md](docs/ru/ios_setup.md) |
| Architecture | [en/architecture.md](docs/en/architecture.md) | [ru/architecture.md](docs/ru/architecture.md) |
| Security | [en/security.md](docs/en/security.md) | [ru/security.md](docs/ru/security.md) |
| Browser extension | [en/browser_extension.md](docs/en/browser_extension.md) | [ru/browser_extension.md](docs/ru/browser_extension.md) |
| Troubleshooting | [en/troubleshooting.md](docs/en/troubleshooting.md) | [ru/troubleshooting.md](docs/ru/troubleshooting.md) |
| Contributing | [en/contributing.md](docs/en/contributing.md) | [ru/contributing.md](docs/ru/contributing.md) |

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

**Быстрый старт:** клонируйте репозиторий, выполните `fetch_cores.sh`, затем `flutter run` из `secure_vpn_client/`. Подробности — в [docs/ru/getting_started.md](docs/ru/getting_started.md).

---

## Security highlights

- SOCKS5 on `127.0.0.1` only, **password auth required**, per-session random credentials
- No `0.0.0.0` binding, no unauthenticated port `7890`
- Credentials wiped on disconnect; never logged or persisted

**Безопасность:** SOCKS только на `127.0.0.1` с паролем, случайные creds на сессию, стирание при disconnect. См. [docs/ru/security.md](docs/ru/security.md).

---

## Repository structure

```
├── secure_vpn_client/       # Flutter app → secure_vpn_client/README.md
├── packages/v2ray_box/      # Plugin fork
├── scripts/                 # fetch_cores.sh, security_probe.sh
├── docs/en/                 # English docs
├── docs/ru/                 # Russian docs
└── extensions/secure-vpn-proxy-auth/  # Linux browser helper
```

---

## License

[GNU General Public License v3.0](LICENSE) (GPLv3)

## Disclaimer

Educational and research use. Users must comply with local laws. / Образовательное использование. Соблюдайте законы вашей страны.
