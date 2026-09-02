# iOS setup

<p align="right">
  <a href="../ru/ios_setup.md"><img src="https://img.shields.io/badge/lang-Русский-red?style=for-the-badge" alt="Русская версия"></a>
</p>


1. Open `secure_vpn_client/ios/Runner.xcworkspace` in Xcode.
2. Run `python3 scripts/setup_ios_packet_tunnel.py` from the repo root if the **PacketTunnel** target is missing (merges extension from `v2ray_box` example).
3. Copy `Libbox.xcframework` into `secure_vpn_client/ios/Frameworks/` (not in git).
4. Add the **Network Extensions** capability and enable **Packet Tunnel** on Runner and PacketTunnel targets.
5. Align App Group `group.com.example.secureVpnClient` in entitlements with your bundle ID for production.
6. Configure a valid development team and provisioning profile.
7. Run `flutter run -d ios` from `secure_vpn_client/` on macOS.

See [platform_parity_checklist.md](platform_parity_checklist.md) for a full device smoke-test list.

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
