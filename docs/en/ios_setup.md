# iOS setup

<p align="right">
  <a href="../ru/ios_setup.md"><img src="https://img.shields.io/badge/lang-Русский-red?style=for-the-badge" alt="Русская версия"></a>
</p>


1. Open `secure_vpn_client/ios/Runner.xcworkspace` in Xcode.
2. Add the **Network Extensions** capability and enable **Packet Tunnel**.
3. Add entitlement `com.apple.developer.networking.vpn.api` to the Runner target and tunnel extension.
4. Configure a valid development team and provisioning profile.
5. Copy core binaries to the paths expected by `v2ray_box` (see plugin README) or use bundled xcframeworks.
6. Run `flutter run -d ios` from `secure_vpn_client/` on macOS.

iOS requires a paid Apple Developer account for on-device VPN testing.

## Release signing (optional)

Signed App Store / ad-hoc builds use `./scripts/setup-ios-signing.sh` with these GitHub secrets (or the same env vars locally):

| Secret / variable | Description |
|-------------------|-------------|
| `IOS_DISTRIBUTION_CERTIFICATE_BASE64` | Apple Distribution `.p12` (base64) |
| `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD` | Certificate password |
| `IOS_PROVISIONING_PROFILE_BASE64` | `.mobileprovision` (base64) |
| `IOS_DEVELOPMENT_TEAM` | Apple Team ID |
| `KEYCHAIN_PASSWORD` | Temporary keychain password (CI) |
| `IOS_EXPORT_METHOD` | Repository variable: `app-store` (default), `ad-hoc`, etc. |

When secrets are **not** set, CI builds `flutter build ios --release --no-codesign` and packages an unsigned `.app` zip. With secrets, CI produces a signed `.ipa`.
