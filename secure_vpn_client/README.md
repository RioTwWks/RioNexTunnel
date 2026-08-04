# Secure VPN Client (Flutter app)

**English** · **Русский**

Main Flutter application of [Secure-Cross-Platform-VPN-Client](../README.md).

Cross-platform VPN client on **Xray-core** and **sing-box** with dynamic authenticated local SOCKS5 (`127.0.0.1:1080`).

Кроссплатформенный VPN-клиент на **Xray-core** и **sing-box** с динамической аутентификацией локального SOCKS5 (`127.0.0.1:1080`).

## Documentation / Документация

| | English | Русский |
|--|---------|---------|
| Project overview | [README.en.md](../README.en.md) | [README.ru.md](../README.ru.md) |
| Docs index | [docs/en/](../docs/en/README.md) | [docs/ru/](../docs/ru/README.md) |
| Getting started | [getting-started.md](../docs/en/getting-started.md) | [getting-started.md](../docs/ru/getting-started.md) |

## Quick start / Быстрый старт

```bash
# From repository root — download cores and geo assets
cd ..
./scripts/fetch_cores.sh

# Back to the app
cd secure_vpn_client
flutter pub get
flutter run -d linux    # or android / windows / macos / ios
```

After changes in `packages/v2ray_box/linux/`, use a **full restart** (`flutter run`), not hot reload.

После правок в `packages/v2ray_box/linux/` нужен **полный перезапуск**, не hot reload.

## Dependencies / Зависимости

- Local plugin fork: `packages/v2ray_box` (path dependency in `pubspec.yaml`)
- State management: **Riverpod**
- Dart SDK: `^3.11.0` (see `pubspec.yaml`)

## `lib/` layout / Структура `lib/`

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

## Tests / Тесты

```bash
flutter analyze
flutter test
```

## Platforms / Платформы

| Platform | Mode | English | Русский |
|----------|------|---------|---------|
| Linux | Proxy (SOCKS/HTTP) | [linux_setup.md](../docs/en/linux_setup.md) | [linux_setup.md](../docs/ru/linux_setup.md) |
| Android | VPN (TUN) | [android_setup.md](../docs/en/android_setup.md) | [android_setup.md](../docs/ru/android_setup.md) |
| iOS | VPN | [ios_setup.md](../docs/en/ios_setup.md) | [ios_setup.md](../docs/ru/ios_setup.md) |
| Windows / macOS | Proxy | see [README.en.md](../README.en.md) | см. [README.ru.md](../README.ru.md) |

Binaries `xray`, `sing-box`, `geoip.dat`, `geosite.dat` live under `linux/runner/resources/` (and equivalents) — **not in git**; install via `fetch_cores.sh`.

## Security / Безопасность

- SOCKS credentials are generated per session and wiped on disconnect.
- Details: [docs/en/security.md](../docs/en/security.md) · [docs/ru/security.md](../docs/ru/security.md)
- Tests / probe: [test/security_test.dart](test/security_test.dart), [../scripts/security_probe.sh](../scripts/security_probe.sh)

## Developers / AI agents

- [../.cursor/AGENTS.md](../.cursor/AGENTS.md) — repository map and agent rules
- [../.cursor/troubleshooting.md](../.cursor/troubleshooting.md) — Linux and subscription failures
