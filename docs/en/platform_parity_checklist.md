# Platform parity verification checklist

<p align="right">
  <a href="../ru/platform_parity_checklist.md"><img src="https://img.shields.io/badge/lang-Русский-red?style=for-the-badge" alt="Русская версия"></a>
</p>

Use this checklist after `scripts/fetch_cores.sh` (desktop) or plugin-native setup (mobile). All platforms must keep **SOCKS on `127.0.0.1` with per-session password auth** — never unauthenticated `0.0.0.0:7890`.

## E2E sign-off template

Record results when verifying on a physical device or VM. Update the table in [README](README.md#e2e-device-verification) when a platform is signed off.

| Field | Value |
|-------|-------|
| **Date** | YYYY-MM-DD |
| **Tester** | name / handle |
| **App version** | git tag or commit |
| **Platform** | e.g. Windows 11 x64, macOS 14 arm64 |
| **Engine × profile** | xray/sing-box × config link / subscription |
| **Connect** | pass / fail + notes |
| **Security probe** | pass / fail / N/A |
| **Browser helper** | pass / fail / N/A (desktop only) |
| **Blockers** | open issues or PR links |

## Linux (reference — verified)

| Step | Expected |
|------|----------|
| `flutter run -d linux` | App starts |
| Connect (xray + sing-box × config/subscription) | Status **Connected** |
| `ss -lntp \| grep 1080` | Listener on `127.0.0.1:1080` only |
| `curl` without proxy creds | Connection refused or auth error |
| Disconnect | Ports 1080/1081 closed; credentials cleared in Settings |
| Browser helper card | Native host + manifest paths shown when installed |

## Windows

| Step | Expected |
|------|----------|
| Fetch cores into bundle `resources/` | `xray.exe`, `sing-box.exe`, geo assets |
| `flutter build windows` or `flutter run -d windows` | App starts |
| Connect (proxy mode) | **Connected** |
| System proxy | HTTP proxy `127.0.0.1:1081` (WinINet / registry) |
| `netstat -ano \| findstr 1080` | `127.0.0.1:1080` LISTENING |
| Disconnect | System proxy disabled; config wiped |
| Browser helper | Native host + Chrome/Edge registry + Firefox manifest; Settings card shows status |

**CI note:** Windows desktop build runs in the `windows-build` CI job on `windows-latest` (PR + main).

## macOS

| Step | Expected |
|------|----------|
| Fetch cores | Binaries in app bundle `Resources/` |
| `flutter run -d macos` | App starts |
| Connect (proxy mode) | **Connected** |
| System proxy | HTTP `127.0.0.1:1081` when enabled in app |
| SOCKS | `127.0.0.1:1080` with session auth |
| Credentials channel | Settings shows proxy user/pass while connected |
| Browser helper | On first `setup()`, host copied to `~/Library/Application Support/V2rayBox/working/native_host/secure_vpn_native_host`; manifests under Chrome/Chromium/Edge/Firefox `NativeMessagingHosts/` |
| Install extension | Load unpacked from `extensions/secure-vpn-proxy-auth/` (dev) or store build; Settings → Browser helper card shows **Ready** when connected |
| Disconnect | Proxy off; credentials cleared; `session.json` removed |

### macOS browser helper paths

| Component | Path |
|-----------|------|
| Native host (installed) | `~/Library/Application Support/V2rayBox/working/native_host/secure_vpn_native_host` |
| Chrome manifest | `~/Library/Application Support/Google/Chrome/NativeMessagingHosts/com.secure.vpn.proxy_auth.json` |
| Edge manifest | `~/Library/Application Support/Microsoft Edge/NativeMessagingHosts/com.secure.vpn.proxy_auth.json` |
| Firefox manifest | `~/Library/Application Support/Mozilla/NativeMessagingHosts/com.secure.vpn.proxy_auth.json` |

## Android

| Step | Expected |
|------|----------|
| Physical device + USB debugging | Not emulator-only for VPN |
| VPN permission granted | System dialog accepted |
| `get_core_info` | `xray_available` reflects AAR presence |
| Connect (TUN / VPN mode) | Foreground service + **Connected** |
| `start_with_json` | Receives `socksUsername` / `socksPassword` / `socksPort` |
| Disconnect | VPN stopped; credentials cleared |
| Browser helper | N/A on mobile — status all `false` |

## iOS

| Step | Expected |
|------|----------|
| Run `python3 scripts/setup_ios_packet_tunnel.py` | PacketTunnel target in Xcode project |
| Copy `Libbox.xcframework` | `secure_vpn_client/ios/Frameworks/` |
| Xcode: Network Extension capability | Runner + PacketTunnel entitlements |
| App Group | `group.com.example.secureVpnClient` (change for production) |
| Device build | `flutter run -d <device>` on macOS |
| Connect | VPN profile starts; tunnel extension loads |
| `get_core_info` | `singbox_available: true`, `xray_available: false` |
| Disconnect | Config files wiped from app group |

## Security regression (all platforms)

Run from repo root when Linux desktop connect works:

```bash
./scripts/security_probe.sh
```

Confirm: no listener on `0.0.0.0`, SOCKS requires auth, credentials rotate each session.
