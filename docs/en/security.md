# Security

<p align="right">
  <a href="../ru/security.md"><img src="https://img.shields.io/badge/lang-Русский-red?style=for-the-badge" alt="Русская версия"></a>
</p>


## Threat context (March 2026)

Several popular VPN clients exposed an **unauthenticated local SOCKS5 proxy** (often on `0.0.0.0:7890`). Any application on the device or LAN could:

- Read the user's real IP through the proxy
- Exfiltrate VPN configuration and routing rules

**RioNexTunnel** is designed to be immune to this class of vulnerability.

## Design principles

| Rule | Implementation |
|------|----------------|
| Bind to localhost only | Inbounds listen on `127.0.0.1`, never `0.0.0.0` |
| Mandatory authentication | SOCKS/HTTP inbounds use `auth: password` with per-session credentials |
| No credential persistence | `CredentialService` generates CSPRNG values; wiped on disconnect |
| No credential logging | Credentials passed via platform channel / env vars, not logs or disk |
| No LAN exposure | Never listen on `0.0.0.0` (the March 2026 incident class) |

## VPN mode vs Proxy mode on desktop

These solve different problems. **Do not mix them** (for example system HTTP proxy plus “VPN connected” without a working TUN).

| | **VPN (TUN)** | **Proxy** |
|---|---------------|-----------|
| How apps reach the tunnel | OS routes IP packets into the virtual adapter (Wintun on Windows) | Apps that honor system proxy or SOCKS/HTTP settings |
| System HTTP proxy | **Off** — avoids WinINET apps breaking on proxy auth | Optional (`127.0.0.1:1081`) |
| Local SOCKS `1080` | Still **password-protected** for extensions and manual clients; normal apps do **not** need it | Same; primary path for `curl --socks5` with credentials |
| Split / bypass | Routing rules in core config (and Android per-app UI) | Per-app: do not set proxy; use direct rules in subscription |

### Why keep local proxy auth at all?

The March 2026 issue was **unauthenticated** SOCKS on a port any process could use (often `0.0.0.0:7890`). RioNexTunnel binds to **`127.0.0.1` only** and requires a **per-session password** so another local app cannot silently steal your tunnel or read routing config through the proxy.

That auth is **not** a substitute for VPN on Windows: most games, messengers, and WinINET apps cannot use an authenticated system proxy. **VPN mode must use TUN** (admin + `wintun.dll` for Xray on Windows). If you only need a browser, use **Proxy mode** and the [browser extension](browser_extension.md) or copy SOCKS credentials from the UI.

Removing local auth would not make TUN “more secure”; it would only make it easier for malware on the same machine to use your open localhost proxy. Excluding apps from the tunnel is done with **routing / split tunneling**, not by dropping localhost auth.

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

### Split tunneling

Per-app split tunneling changes **which apps use the VPN tunnel** on Android. It does **not** change local inbound security. Run the probe with VPN connected and split tunnel enabled — unauthenticated SOCKS must still fail.

See [split_tunneling.md](split_tunneling.md).

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

## Subscription certificate pinning (optional)

By default, subscription fetch uses normal TLS certificate validation (system CAs). You can opt in to **SPKI certificate pinning** in **Settings → Advanced security**.

| Behavior | Detail |
|----------|--------|
| Default | Pinning **off** — third-party subscriptions keep working |
| Scope | Subscription HTTP fetch only (`ConfigParser.fetchSubscriptionBody`) |
| Pin format | `sha256/<base64 SHA-256 of SubjectPublicKeyInfo>` |
| Host matching | Pins are stored per subscription hostname (case-insensitive) |
| Enforcement | When enabled, only hosts with saved pins are checked; other hosts still use normal TLS |
| Panel API | RioNexGate panel HTTP is **not** pinned (separate code path) |

### Limitations

- When a panel rotates TLS certificates (for example Let's Encrypt renewal), you must **update the pin** or subscription refresh will fail with a pin mismatch error.
- When pinning is enabled for a host, CA trust is replaced by the saved SPKI pin for that host.
- Certificate pinning is **not supported on web** builds.
- Pins and credentials are **never written to logs**.

### Verify

```bash
cd secure_vpn_client
flutter test test/subscription_pinning_test.dart
```


## Reporting security issues

Do not open public issues for undisclosed vulnerabilities. Contact repository maintainers privately.
