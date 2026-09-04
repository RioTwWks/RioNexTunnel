# Mobile VPN config — sing-box `mixed` and DNS

English · [Русская версия](../ru/mobile_vpn_config.md)

This document records the **audit** of sing-box mobile (Android/iOS VPN / TUN mode) config paths for RioNexTunnel.

## `mixed` inbound on mobile

On **mobile VPN mode**, the plugin may add a sing-box `mixed` inbound (`127.0.0.1`, local SOCKS+HTTP) alongside TUN. This is **expected**:

- Used for local app ↔ core traffic bridging (same pattern as upstream v2ray_box example)
- Binds to **`127.0.0.1` only** — not exposed on `0.0.0.0`
- On **desktop proxy mode**, `ConfigParser.injectSecureSocksInbound(..., proxyOnly: true)` **strips** `mixed` and `tun` inbounds and injects authenticated SOCKS (+ HTTP on desktop) only

Relevant code:

- `packages/v2ray_box/ios/Classes/ConfigBuilder.swift` — `buildInbounds` adds `mixed-in`
- `packages/v2ray_box/android/.../SingboxConfigParser.kt` — `mixed` inbound for VPN bridge
- `secure_vpn_client/lib/utils/config_parser.dart` — `_isValidSingboxInboundForProxy` rejects `mixed` when sanitizing for proxy mode

**Security conclusion:** `mixed` on mobile is acceptable when listen is localhost; desktop proxy path does not ship subscription `mixed` inbounds to users.

## Deprecated sing-box DNS (`legacy DNS servers`)

Subscriptions and share links may contain legacy DNS blocks (`dns.servers` as string list or `address` fields). Before connect, the app runs:

- `ConfigParser._migrateSingboxLegacyDns` — converts to modern `type` / `server` / `tag` objects
- `ConfigParser._ensureSingboxRemoteDns` — VPN-safe resolver defaults when missing

If sing-box still logs `legacy DNS servers is deprecated`, the subscription body needs a newer DNS schema; see [Troubleshooting](troubleshooting.md).

## Advanced DNS (P2)

See [dns.md](dns.md).

## Xray `geosite:` / `geoip:` rules

When a config uses Xray-style `geosite:` or `geoip:` routing and **geo assets are missing**, connect **fails closed** with a clear error (run `scripts/fetch_cores.sh` or use sing-box). Auto engine also demotes xray when geo is required but assets are absent.

## Tests

- `secure_vpn_client/test/config_parser_test.dart` — proxyOnly strips mixed, DNS migration
- `secure_vpn_client/test/engine_auto_selector_test.dart` — geo rule detection
- `secure_vpn_client/test/split_tunnel_settings_test.dart` — whitelist/blacklist model

## Split tunneling (per-app)

Android VPN mode supports per-app include/exclude via `VpnService`. See [split_tunneling.md](split_tunneling.md). iOS has no equivalent per-app API.
