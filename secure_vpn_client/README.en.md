# Secure VPN Client (Flutter app)

> **Language / Язык:** **English** | [Русский](README.md)

The main Flutter application of the [Secure-Cross-Platform-VPN-Client](../README.en.md) repository.

A cross-platform VPN client powered by **Xray-core** and **sing-box** with dynamic authentication for the local SOCKS5 proxy (`127.0.0.1:1080`).

## Quick start

```bash
# From the repository root — download cores and geo files
cd ..
./scripts/fetch_cores.sh

# Back to the app
cd secure_vpn_client
flutter pub get
flutter run -d linux    # or android / windows / macos / ios
```

After changes in `packages/v2ray_box/linux/`, a **full restart** (`flutter run`) is required — hot reload is not enough.

## Dependencies

- Local plugin fork: `packages/v2ray_box` (path dependency in `pubspec.yaml`)
- State management: **Riverpod**
- Dart SDK: `^3.11.0` (see `pubspec.yaml`)

## `lib/` structure

```
lib/
├── main.dart
├── models/          # Profile, VpnEngine, Credentials
├── providers/       # Riverpod (profiles, engine, VPN status)
├── screens/         # Home, Config (profiles), Settings
├── services/        # VpnService, CredentialService
├── utils/           # ConfigParser, LinkConfigBuilder, crypto
└── widgets/
```

## Tests and linter

```bash
flutter analyze
flutter test
```

## Platforms

| Platform | Mode | Documentation |
|----------|------|---------------|
| Linux | Proxy (SOCKS) | [docs/linux_setup.md](../docs/linux_setup.md) |
| Android | VPN (TUN) | [docs/android_setup.md](../docs/android_setup.md) |
| iOS | VPN | [docs/ios_setup.md](../docs/ios_setup.md) |
| Windows / macOS | Proxy | see the root README |

The `xray`, `sing-box`, `geoip.dat`, `geosite.dat` binaries live in `linux/runner/resources/` (and equivalents) — **not in git**, installed via `fetch_cores.sh`.

## Security

- SOCKS credentials are generated per session and wiped on disconnect.
- Details and checklist: [test/security_test.dart](test/security_test.dart), [../scripts/security_probe.sh](../scripts/security_probe.sh).

## For developers / AI agents

- [../.cursor/AGENTS.md](../.cursor/AGENTS.md) — repository map and agent rules
- [../.cursor/troubleshooting.md](../.cursor/troubleshooting.md) — common Linux and subscription errors
