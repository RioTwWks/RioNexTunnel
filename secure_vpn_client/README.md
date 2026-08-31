# RioNexTunnel (Flutter app)

Main Flutter application of the RioNexTunnel project ([repository root](../README.md)).

Cross-platform VPN client on **Xray-core** and **sing-box** with dynamic local SOCKS5 authentication (`127.0.0.1:1080`).

Основное Flutter-приложение репозитория. Кроссплатформенный VPN-клиент с динамической аутентификацией локального SOCKS5.

---

## Documentation / Документация

| Language | Guide |
|----------|-------|
| English | [docs/en/getting_started.md](../docs/en/getting_started.md) |
| Русский | [docs/ru/getting_started.md](../docs/ru/getting_started.md) |

| Platform | EN | RU |
|----------|----|----|
| Linux | [linux_setup](../docs/en/linux_setup.md) | [linux_setup](../docs/ru/linux_setup.md) |
| Android | [android_setup](../docs/en/android_setup.md) | [android_setup](../docs/ru/android_setup.md) |
| iOS | [ios_setup](../docs/en/ios_setup.md) | [ios_setup](../docs/ru/ios_setup.md) |

---

## Quick start / Быстрый старт

```bash
# From repo root — fetch cores and geo files
cd ..
./scripts/fetch_cores.sh

cd secure_vpn_client
flutter pub get
flutter run -d linux    # or android / windows / macos / ios
```

After changes in `packages/v2ray_box/linux/` — **full restart** (`flutter run`), not hot reload.

---

## `lib/` structure

```
lib/
├── main.dart
├── models/          # Profile, VpnEngine, Credentials
├── providers/       # Riverpod
├── screens/         # Home, Config, Settings
├── services/        # VpnService, CredentialService
├── utils/           # ConfigParser, LinkConfigBuilder, crypto
└── widgets/
```

---

## Tests

```bash
flutter analyze
flutter test
```

Security tests: [test/security_test.md](test/security_test.dart), [../scripts/security_probe.sh](../scripts/security_probe.sh).

---

## Developers / AI agents

- [../.cursor/AGENTS.md](../.cursor/AGENTS.md)
- [../docs/en/troubleshooting.md](../docs/en/troubleshooting.md) · [RU](../docs/ru/troubleshooting.md)

Core binaries (`xray`, `sing-box`, `geoip.dat`, `geosite.dat`) in `linux/runner/resources/` — **not in git**, installed via `fetch_cores.sh`.
