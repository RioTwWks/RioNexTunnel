# Getting started

[← Documentation index](README.md) · [Русский](../ru/getting-started.md)

## Requirements

- Flutter SDK `stable` (see Dart version in `secure_vpn_client/pubspec.yaml`, currently `^3.11.0`)
- **Android:** Android Studio, SDK 23+, NDK
- **iOS / macOS:** Xcode 15+, CocoaPods
- **Windows:** Visual Studio 2022 with C++ desktop workload
- **Linux:** `clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`
- Go `1.21+` only if you rebuild cores yourself

## 1. Clone

```bash
git clone https://github.com/RioTwWks/Secure-Cross-Platform-VPN-Client.git
cd Secure-Cross-Platform-VPN-Client
```

## 2. Fetch core binaries

Cores (`xray`, `sing-box`) and geo assets (`geoip.dat`, `geosite.dat`) are **not in git**. From the repository root:

```bash
./scripts/fetch_cores.sh
```

Files are installed under platform `runner/resources/` (and Android `jniLibs` / assets). Run this once per machine or before a release build.

## 3. Install Flutter dependencies

```bash
cd secure_vpn_client
flutter pub get
```

## 4. Platform-specific setup

| Platform | Guide |
|----------|-------|
| Linux | [linux_setup.md](linux_setup.md) |
| Android | [android_setup.md](android_setup.md) |
| iOS | [ios_setup.md](ios_setup.md) |
| Windows / macOS | Copy cores via `fetch_cores.sh`, then `flutter run -d windows` / `-d macos` |

## 5. Run

```bash
# From secure_vpn_client/
flutter run -d linux      # or android / windows / macos / ios
```

After changes under `packages/v2ray_box/`, do a **full restart** — hot reload is not enough for native code.

## 6. Verify security

With VPN connected:

```bash
# From repository root
./scripts/security_probe.sh 1080
```

Unauthenticated access to the local SOCKS proxy must fail. See [security.md](security.md).

## Next steps

- Understand the stack: [architecture.md](architecture.md)
- Linux browser traffic: [browser-extension.md](browser-extension.md)
- Contribute: [contributing.md](contributing.md)
