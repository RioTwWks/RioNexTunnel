# Security

[Русская версия](../ru/security.md)

## Threat context (March 2026)

Several popular VPN clients exposed an **unauthenticated local SOCKS5 proxy** (often on `0.0.0.0:7890`). Any application on the device or LAN could:

- Read the user's real IP through the proxy
- Exfiltrate VPN configuration and routing rules

**Secure VPN Client** is designed to be immune to this class of vulnerability.

## Design principles

| Rule | Implementation |
|------|----------------|
| Bind to localhost only | Inbounds listen on `127.0.0.1`, never `0.0.0.0` |
| Mandatory authentication | SOCKS/HTTP inbounds use `auth: password` with per-session credentials |
| No credential persistence | `CredentialService` generates CSPRNG values; wiped on disconnect |
| No credential logging | Credentials passed via platform channel / env vars, not logs or disk |
| Desktop proxy mode | Linux/Windows/macOS use `VpnMode.proxy`, not open TUN without isolation |

## Per-session credentials

On each **Connect**:

1. `CredentialService` generates random username and password.
2. `ConfigParser.injectSecureSocksInbound()` injects them into core config.
3. Native side receives credentials via `secure_vpn/credentials` channel (Linux: env vars for child process).
4. On **Disconnect**, credentials and `active_config.json` are wiped.

These are **local proxy credentials** — not your VPN server account.

## Ports (Linux desktop)

| Port | Protocol | Use |
|------|----------|-----|
| `1080` | SOCKS5 + auth | Direct SOCKS clients |
| `1081` | HTTP + auth | GNOME system proxy (no SOCKS auth support) |

## Verification

### 1. Security probe script

With VPN connected:

```bash
./scripts/security_probe.sh 1080
```

Unauthenticated connection must **fail**.

### 2. Manual curl test

```bash
# Without auth — should fail or return real IP without routing
curl --socks5 127.0.0.1:1080 https://api.ipify.org

# With wrong password — should fail
curl --socks5 127.0.0.1:1080 --socks5-basic --proxy-user wrong:wrong https://api.ipify.org
```

### 3. Unit tests

```bash
cd secure_vpn_client
flutter test test/security_test.dart
flutter test test/config_parser_test.dart
```

Tests assert:

- Inbounds bind to `127.0.0.1`
- `auth` is `password`
- Credentials appear in config only during active session injection

## Browser proxy auth (Linux)

Chromium ignores GSettings proxy passwords. Use the [browser extension](browser_extension.md) or copy credentials from the app UI.

## Reporting security issues

Do not open public issues for undisclosed vulnerabilities. Contact repository maintainers privately.
