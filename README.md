# Secure VPN Client (MVP)

**Cross-platform VPN client built with Flutter, powered by Xray-core and sing-box**  
*Implements protection against the unauthenticated SOCKS5 proxy vulnerability (March 2026)*

[![Flutter](https://img.shields.io/badge/Flutter-3.22+-blue.svg)](https://flutter.dev)
[![Xray-core](https://img.shields.io/badge/Xray--core-1.8.24+-green.svg)](https://github.com/XTLS/Xray-core)
[![sing-box](https://img.shields.io/badge/sing--box-1.10+-orange.svg)](https://github.com/SagerNet/sing-box)
[![License](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

[Русская версия](README_RU.md)

---

## 📌 Description

**Secure VPN Client** is a secure and flexible VPN client developed as an MVP (minimum viable product). The app connects to VPN servers using VLESS, VMess, Shadowsocks, Trojan, and other protocols (via the Xray-core and sing-box engines). The key difference from many existing clients is the **complete elimination of the vulnerability associated with an unauthenticated local SOCKS5 proxy**, which was discovered in spring 2026 in apps such as Hiddify, v2rayNG, Happ, and others.

The project is built from scratch with Flutter to run on five platforms: **Android, iOS, Windows, Linux, macOS**.

---

## 🔐 Key Security Features

- **Dynamic SOCKS5 authentication**  
  Every time the VPN starts, a unique login/password pair is generated for the local SOCKS5 proxy. Credentials are never saved to disk and are destroyed after the VPN stops.

- **No third-party app access**  
  The local proxy server is bound only to `127.0.0.1` and requires mandatory authentication. The core configuration specifies an allowlist of packages (`allowApps`) that may access the proxy; all other apps are denied.

- **No open ports**  
  Unlike vulnerable clients, our app **does not** listen on `0.0.0.0` and **does not** leave port `7890` unprotected. Each session uses a random port (default 1080) and random credentials.

- **Switchable engine**  
  You can use either Xray-core or sing-box. Both engines are configured uniformly through our secure wrapper.

---

## 🧱 Technology Stack

| Component          | Technology                                     |
|--------------------|------------------------------------------------|
| UI and logic       | Flutter (Dart)                                |
| VPN tunneling      | Local fork [`packages/v2ray_box`](packages/v2ray_box) (security patches) |
| Engine 1           | [Xray-core](https://github.com/XTLS/Xray-core) (Go, subprocess) |
| Engine 2           | [sing-box](https://github.com/SagerNet/sing-box) (Go, subprocess) |
| Native bridges     | Android (Kotlin), iOS/macOS (Swift), Linux/Windows (C++ plugin) |

---

## 📋 Developer Environment Requirements

- Flutter SDK `stable` (latest channel recommended)
- Dart SDK `^3.11.0` (see `secure_vpn_client/pubspec.yaml`)
- For Android: Android Studio, SDK 23+, NDK
- For iOS/macOS: Xcode 15+, CocoaPods
- For Windows: Visual Studio 2022 with the "Desktop development with C++" workload
- For Linux: `clang`, `cmake`, `ninja-build`, `gtk3`
- Go `1.21+` (only if you rebuild the core engines)

---

## 🚀 Quick Start (MVP Build)

### 1. Clone the repository
```bash
git clone https://github.com/RioTwWks/Secure-Cross-Platform-VPN-Client.git
cd Secure-Cross-Platform-VPN-Client/secure_vpn_client
```

> **For AI agents (Cursor):** see [.cursor/AGENTS.md](.cursor/AGENTS.md)

### 2. Install dependencies
```bash
flutter pub get
```

### 3. Configure native permissions

- **Android**  
  Open `android/app/src/main/AndroidManifest.xml` and verify that the `VpnService` `<service>` entry is present (see instructions in [`docs/android_setup.md`](docs/android_setup.md)).

- **iOS**  
  In Xcode add `com.apple.developer.networking.vpn.api` to entitlements. Details are in [`docs/ios_setup.md`](docs/ios_setup.md).

- **Linux**  
  See [`docs/linux_setup.md`](docs/linux_setup.md) (proxy mode, `fetch_cores.sh`, geo assets).

- **Windows / macOS**  
  Copy core binaries into `windows/runner/resources/`, `macos/Runner/Resources/` (using `./scripts/fetch_cores.sh` from the repository root).

### 4. Prepare core binaries (Xray-core, sing-box)

From the **repository root** (not `secure_vpn_client/`):

```bash
./scripts/fetch_cores.sh
```

The script downloads the latest releases of Xray-core and sing-box, plus `geoip.dat` / `geosite.dat` (required for xray subscriptions with `geosite:` / `geoip:` rules), and copies them to:

```
secure_vpn_client/linux/runner/resources/     # xray, sing-box, geoip.dat, geosite.dat
secure_vpn_client/windows/runner/resources/
secure_vpn_client/macos/Runner/Resources/
secure_vpn_client/assets/binaries/            # android, ios, …
```

Core binaries are **not stored in git** (see `.gitignore`). Each machine and CI job must run `fetch_cores.sh` once or before a release build.

### 5. Run on the target platform

```bash
# Android
flutter run -d android

# iOS (macOS only)
flutter run -d ios

# Windows
flutter run -d windows

# Linux
flutter run -d linux

# macOS
flutter run -d macos
```

---

## 🧪 Security Testing

After building, you can verify that the vulnerability is fixed:

1. Start the VPN connection.
2. Try connecting to the local SOCKS5 proxy (usually `127.0.0.1:1080`) without a password — the connection must be rejected.
3. Use a tool such as `curl --socks5 127.0.0.1:1080 https://api.ipify.org` — it should return your real IP; if you provide the wrong password, the request must fail.
4. Verification script from the repository root: `./scripts/security_probe.sh 1080` — unauthorized connection must fail.

On **Linux desktop**, proxy mode is used: applications must be configured to use SOCKS5 `127.0.0.1:1080` with the session login/password. Per-app isolation is available on Android (VPN mode).

---

## 📁 Repository Structure

```
Secure-Cross-Platform-VPN-Client/
├── secure_vpn_client/            # Flutter application (see secure_vpn_client/README.md)
│   ├── lib/
│   │   ├── services/             # VpnService, CredentialService
│   │   ├── utils/                # ConfigParser, LinkConfigBuilder
│   │   ├── models/               # Profile, VpnEngine, Credentials
│   │   ├── providers/            # Riverpod
│   │   ├── screens/              # Home, Config, Settings
│   │   └── widgets/
│   ├── test/                     # Unit + security tests
│   └── linux/runner/resources/   # xray, sing-box, geo (gitignored)
├── packages/v2ray_box/           # Plugin fork (Linux desktop plugin, Android patches)
├── scripts/
│   ├── fetch_cores.sh            # Download engines and geo files
│   ├── security_probe.sh         # SOCKS auth check
│   └── sync_v2ray_box.sh
├── docs/                         # android_setup, ios_setup, linux_setup (EN / RU)
└── .cursor/                      # AI agent docs (AGENTS.md)
```

---

## 🛠️ Roadmap (after MVP)

- [x] Subscription support (V2Ray / sing-box, engine-specific User-Agent)
- [x] Engine switching xray / sing-box
- [x] Security unit tests (`test/security_test.dart`, `test/config_parser_test.dart`)
- [x] Linux desktop: proxy mode, all 4 engine × profile combinations
- [ ] Server selection from subscription list (currently the first real entry)
- [ ] Android / iOS / Windows / macOS — full E2E on-device testing
- [ ] System proxy on desktop
- [ ] Split tunneling (per-app) on mobile platforms
- [ ] CI: `flutter analyze` + `flutter test` on push

Detailed backlog: [.cursor/tasks.md](.cursor/tasks.md)

---

## 🤝 Contributing

We welcome any fixes and improvements. Before submitting a Pull Request:

1. Make sure `flutter analyze` passes without errors (`secure_vpn_client/analysis_options.yaml`).
2. Add tests for any new security functionality.
3. Verify that the SOCKS5 vulnerability does not reappear (use scenarios from `test/security_test.dart`).

---

## 📄 License

The project is distributed under the **GNU General Public License v3.0** (GPLv3), because it uses components (Xray-core, sing-box) with similar conditions. The full license text is in the [LICENSE](LICENSE) file.

---

## ⚠️ Disclaimer

This software is provided "as is" for educational and research purposes. The developers are not responsible for any unlawful use of the application. The user is obliged to comply with the laws of their country.

---

## 🙏 Acknowledgments

- The **XTLS** team for Xray-core  
- **SagerNet** for sing-box  
- The authors of the `v2ray_box` plugin (fork)  
- The Flutter community for the excellent framework  

---

**Secure VPN Client** — your secure choice in the world of open VPN solutions. 🛡️
