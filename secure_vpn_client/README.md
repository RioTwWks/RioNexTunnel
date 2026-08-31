<p align="right">
  <a href="../README_RU.md"><img src="https://img.shields.io/badge/lang-Русский-red?style=for-the-badge" alt="Русская версия"></a>
</p>

# RioNexTunnel (Flutter app)

Main Flutter application of the RioNexTunnel project ([repository root](../README.md)).

Cross-platform VPN client on **Xray-core** and **sing-box** with dynamic local SOCKS5 authentication (`127.0.0.1:1080`).

---

## Documentation

| Guide | Description |
|-------|-------------|
| [Getting started](../docs/en/getting_started.md) | Clone, dependencies, cores, run |
| [Linux setup](../docs/en/linux_setup.md) | Desktop proxy mode |
| [Android setup](../docs/en/android_setup.md) | VPN mode |
| [iOS setup](../docs/en/ios_setup.md) | Network Extensions |
| [Troubleshooting](../docs/en/troubleshooting.md) | Common errors |

Russian guides: [docs/ru/](../docs/ru/README.md)

---

## Quick start

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

Security tests: [test/security_test.dart](test/security_test.dart), [../scripts/security_probe.sh](../scripts/security_probe.sh).

---

## Developers / AI agents

- [../.cursor/AGENTS.md](../.cursor/AGENTS.md)
- [../docs/en/troubleshooting.md](../docs/en/troubleshooting.md)

Core binaries (`xray`, `sing-box`, `geoip.dat`, `geosite.dat`) in `linux/runner/resources/` — **not in git**, installed via `fetch_cores.sh`.
