# Secure VPN Client (MVP)

**English** · **Русский**

Cross-platform Flutter VPN client with **Xray-core** and **sing-box**, hardened against unauthenticated local SOCKS5 proxies (March 2026 vulnerability class).

Кроссплатформенный VPN-клиент на Flutter с **Xray-core** и **sing-box**; защита от неаутентифицированного локального SOCKS5-прокси (класс уязвимостей марта 2026).

[![Flutter](https://img.shields.io/badge/Flutter-3.22+-blue.svg)](https://flutter.dev)
[![Xray-core](https://img.shields.io/badge/Xray--core-1.8.24+-green.svg)](https://github.com/XTLS/Xray-core)
[![sing-box](https://img.shields.io/badge/sing--box-1.10+-orange.svg)](https://github.com/SagerNet/sing-box)
[![License](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

---

## Choose language / Выберите язык

| | Overview | Full documentation |
|--|----------|--------------------|
| **English** | [README.en.md](README.en.md) | [docs/en/](docs/en/README.md) |
| **Русский** | [README.ru.md](README.ru.md) | [docs/ru/](docs/ru/README.md) |

---

## Quick start / Быстрый старт

```bash
git clone https://github.com/RioTwWks/Secure-Cross-Platform-VPN-Client.git
cd Secure-Cross-Platform-VPN-Client
./scripts/fetch_cores.sh
cd secure_vpn_client
flutter pub get
flutter run -d linux
```

| Topic | English | Русский |
|-------|---------|---------|
| Getting started | [docs/en/getting-started.md](docs/en/getting-started.md) | [docs/ru/getting-started.md](docs/ru/getting-started.md) |
| Linux | [docs/en/linux_setup.md](docs/en/linux_setup.md) | [docs/ru/linux_setup.md](docs/ru/linux_setup.md) |
| Android | [docs/en/android_setup.md](docs/en/android_setup.md) | [docs/ru/android_setup.md](docs/ru/android_setup.md) |
| iOS | [docs/en/ios_setup.md](docs/en/ios_setup.md) | [docs/ru/ios_setup.md](docs/ru/ios_setup.md) |
| Security | [docs/en/security.md](docs/en/security.md) | [docs/ru/security.md](docs/ru/security.md) |
| Architecture | [docs/en/architecture.md](docs/en/architecture.md) | [docs/ru/architecture.md](docs/ru/architecture.md) |
| Browser extension | [docs/en/browser-extension.md](docs/en/browser-extension.md) | [docs/ru/browser-extension.md](docs/ru/browser-extension.md) |
| Contributing | [docs/en/contributing.md](docs/en/contributing.md) | [docs/ru/contributing.md](docs/ru/contributing.md) |

Docs index: [docs/README.md](docs/README.md)

---

## Security / Безопасность

Local SOCKS5/HTTP proxies bind to `127.0.0.1` only, always require password auth, and use per-session credentials wiped on disconnect.

Локальные SOCKS5/HTTP-прокси только на `127.0.0.1`, всегда с password auth и сессионными учётными данными, уничтожаемыми при disconnect.

```bash
./scripts/security_probe.sh 1080   # unauthenticated probe must fail
```

---

## License / Лицензия

**GNU GPLv3** — [LICENSE](LICENSE)

For Cursor AI agents: [.cursor/AGENTS.md](.cursor/AGENTS.md)
