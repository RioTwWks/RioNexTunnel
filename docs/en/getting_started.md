# Getting started

<p align="right">
  <a href="../ru/getting_started.md"><img src="https://img.shields.io/badge/lang-Русский-red?style=for-the-badge" alt="Русская версия"></a>
</p>


## Requirements

- Flutter SDK `stable` (see `secure_vpn_client/pubspec.yaml` for Dart `^3.11.0`)
- **Android:** Android Studio, SDK 23+, NDK
- **iOS/macOS:** Xcode 15+, CocoaPods
- **Windows:** Visual Studio 2022 with C++ desktop workload
- **Linux:** `clang`, `cmake`, `ninja-build`, `gtk3`
- Go `1.21+` (only if rebuilding cores from source)

## 1. Clone the repository

```bash
git clone https://github.com/RioTwWks/Secure-Cross-Platform-VPN-Client.git
cd Secure-Cross-Platform-VPN-Client/secure_vpn_client
```

> For Cursor AI agents, see [.cursor/AGENTS.md](../../.cursor/AGENTS.md).

## 2. Install dependencies

```bash
flutter pub get
```

## 3. Platform setup

| Platform | Guide |
|----------|-------|
| Linux | [linux_setup.md](linux_setup.md) |
| Windows | [windows_setup.md](windows_setup.md) |
| macOS | [macos_setup.md](macos_setup.md) |
| Android | [android_setup.md](android_setup.md) |
| iOS | [ios_setup.md](ios_setup.md) |

## 4. Fetch core binaries

From **repository root** (not `secure_vpn_client/`):

```bash
./scripts/fetch_cores.sh
```

Downloads Xray-core, sing-box, and `geoip.dat` / `geosite.dat` into:

- `secure_vpn_client/linux/runner/resources/`
- `secure_vpn_client/windows/runner/resources/`
- `secure_vpn_client/macos/Runner/Resources/`
- `secure_vpn_client/assets/binaries/` (mobile)

Core binaries are **not in git** — run `fetch_cores.sh` on each machine and before release builds.

## 5. Run the app

```bash
cd secure_vpn_client
flutter run -d linux      # or android, windows, macos, ios
```

After native plugin changes (`packages/v2ray_box/linux/`, `packages/v2ray_box/windows/`, or `packages/v2ray_box/macos/`), use a **full restart**, not hot reload.

## Verify security

```bash
# From repo root, with VPN connected
./scripts/security_probe.sh 1080
```

Unauthenticated SOCKS probe must fail. See [security.md](security.md).

## Tests

```bash
cd secure_vpn_client
flutter analyze
flutter test
```
