# Security

[← Documentation index](README.md) · [Русский](../ru/security.md)

## Threat context

In March 2026, several popular VPN clients (Hiddify, v2rayNG, Happ, and others) were found to expose an **unauthenticated local SOCKS5 proxy** (often on port `7890`, sometimes bound to `0.0.0.0`). Any local app could then:

- Discover the user’s real IP
- Read or abuse routing through the VPN tunnel
- Inspect or interfere with traffic that should stay inside the client

This project is designed to be immune to that class of issues.

## Non-negotiable rules

| Rule | Requirement |
|------|-------------|
| Bind address | `127.0.0.1` only — never `0.0.0.0` |
| Authentication | SOCKS5 / HTTP local inbounds always require password auth |
| Credentials | Per-session random username/password (CSPRNG) |
| Lifetime | Generate on connect, wipe on disconnect |
| Persistence | Never write credentials to disk or logs |
| Port `7890` | Do not leave an unauthenticated listener on this (or any) port |

## Implementation points

- **Dart:** `CredentialService` + `ConfigParser.injectSecureSocksInbound(...)`
- **Desktop:** `proxyOnly: true` strips VPN-only inbounds; adds authenticated HTTP on `1081` for system proxy
- **Native (Linux):** credentials channel `secure_vpn/credentials`; env vars for the child process; config file wiped on stop
- **Browser:** optional extension fills HTTP `407` challenges — still uses the same session credentials (no open forwarder)

## How to verify

1. Connect VPN in the app.
2. Probe without credentials (must fail):

```bash
# From repository root
./scripts/security_probe.sh 1080
```

3. Optional manual check:

```bash
curl --socks5 127.0.0.1:1080 https://api.ipify.org
# Without user:pass → should fail / not use the tunnel
```

4. Automated coverage: `secure_vpn_client/test/security_test.dart`, `test/config_parser_test.dart`.

```bash
cd secure_vpn_client
flutter test test/security_test.dart
```

## What “Connected” means on desktop

On Linux/Windows/macOS the app uses **proxy mode**, not a full TUN VPN. Traffic goes through the local authenticated proxy only when apps (or the system proxy + browser helper) are configured to use it. That is intentional isolation — not a bypass hole via open localhost scanning.
