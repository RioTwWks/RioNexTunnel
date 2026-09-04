# Split tunneling

<p align="right">
  <a href="../ru/split_tunneling.md"><img src="https://img.shields.io/badge/lang-Русский-red?style=for-the-badge" alt="Русская версия"></a>
</p>

Split tunneling controls **which apps** use the VPN tunnel on mobile. RioNexTunnel uses Android `VpnService` per-app APIs; desktop proxy mode has different limits (see below).

## Modes (Android VPN)

| Mode | Behavior | Native API |
|------|----------|------------|
| **Off** | All apps use VPN | No per-app rules |
| **VPN only** (whitelist / include) | Only selected apps use VPN | `addAllowedApplication` |
| **Bypass** (blacklist / exclude) | Selected apps connect directly | `addDisallowedApplication` |

Configure in **Settings → Split tunneling**. After changing apps or mode, **reconnect VPN** so `VpnService.Builder` picks up the new list.

The VPN app itself is always excluded from the tunnel (cannot route its own traffic through itself).

## Security

Split tunneling does **not** weaken local proxy security:

- SOCKS/HTTP inbounds remain on **`127.0.0.1` only** with **mandatory password auth**
- No unauthenticated port `7890` or `0.0.0.0` bind
- Per-session credentials are wiped on disconnect

Excluded apps connect **directly** to the internet (bypass VPN). They must not be able to reach an open local proxy — RioNexTunnel never exposes one.

### Leak testing

With VPN connected and split tunnel enabled:

```bash
./scripts/security_probe.sh 1080
```

Unauthenticated SOCKS must still **fail**. See [Security](security.md).

## Desktop (Linux / Windows / macOS)

Desktop uses **proxy mode**, not system TUN VPN. Per-app split tunneling is **not implemented** in the app:

- Traffic routing is per-application (browser proxy, app settings, OS firewall)
- Settings shows a disclaimer card on desktop
- Local proxies still require session auth on `127.0.0.1`

## iOS (Network Extension)

Apple's Network Extension framework does **not** offer Android-style per-app VPN routing in a third-party client:

- `NEPacketTunnelProvider` routes traffic at the **interface** level
- Per-app include/exclude lists are **not available** like `VpnService.Builder` on Android
- Split tunneling UI is **Android-only** today

For iOS, use **routing rules inside the core config** (domain/IP lists) — see Agent C "RU direct routing preset" — not per-app toggles.

Documented limits: [iOS setup](ios_setup.md#split-tunneling).

## Linux TUN (future — not implemented)

**Status:** deferred. Desktop Linux today uses **proxy mode only** (`VpnMode.proxy`). There is no TUN interface, no `VpnService`-style tunnel, and no per-app routing at the OS level on Linux desktop.

If a future **Linux TUN mode** workstream is added, per-app split tunneling would require:

| Requirement | Rationale |
|-------------|-----------|
| Policy routing (`ip rule` / `nftables`) or cgroups v2 egress | Route only selected apps through the tunnel |
| Block bypass via localhost scanning | Apps must not reach an unauthenticated SOCKS on `127.0.0.1` |
| Kill switch integration | Tunnel drop must not leak excluded apps incorrectly |
| Separate from proxy mode | Proxy mode split tunnel remains OS/app-level only |

Until TUN mode ships, the unchecked `tasks.md` item **Linux TUN split tunnel** is documentation-only — do not expect per-app toggles on Linux desktop.

## Related code

| Component | Path |
|-----------|------|
| Model | `secure_vpn_client/lib/models/split_tunnel_settings.dart` |
| Service | `secure_vpn_client/lib/services/split_tunnel_service.dart` |
| Provider | `secure_vpn_client/lib/providers/per_app_proxy_provider.dart` |
| Android VPN | `packages/v2ray_box/android/.../bg/VPNService.kt` |
| Plugin API | `PerAppProxyMode` in `packages/v2ray_box/lib/src/models/vpn_status.dart` |

## Tests

```bash
cd secure_vpn_client
flutter test test/split_tunnel_settings_test.dart
flutter test test/per_app_proxy_provider_test.dart
flutter test test/security_test.dart
```
