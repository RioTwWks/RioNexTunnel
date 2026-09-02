# Platform parity verification checklist

<p align="right">
  <a href="../ru/platform_parity_checklist.md"><img src="https://img.shields.io/badge/lang-Русский-red?style=for-the-badge" alt="Русская версия"></a>
</p>

Use this checklist after `scripts/fetch_cores.sh` (desktop) or plugin-native setup (mobile). All platforms must keep **SOCKS on `127.0.0.1` with per-session password auth** — never unauthenticated `0.0.0.0:7890`.

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
| `flutter run -d windows` | App starts |
| Connect (proxy mode) | **Connected** |
| System proxy | HTTP proxy `127.0.0.1:1081` (WinINet / registry) |
| `netstat -ano \| findstr 1080` | `127.0.0.1:1080` LISTENING |
| Disconnect | System proxy disabled; config wiped |
| Browser helper | **Not yet on Windows** — UI shows all `false` (see P3 backlog) |

## macOS

| Step | Expected |
|------|----------|
| Fetch cores | Binaries in app bundle `resources/` |
| `flutter run -d macos` | App starts |
| Connect (proxy mode) | **Connected** |
| System proxy | HTTP `127.0.0.1:1081` when enabled in app |
| SOCKS | `127.0.0.1:1080` with session auth |
| Credentials channel | Settings shows proxy user/pass while connected |
| Disconnect | Proxy off; credentials cleared |

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
