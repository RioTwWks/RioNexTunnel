# Kill switch

RioNexTunnel can block outbound internet when the VPN tunnel or local core stops unexpectedly. This reduces leaks if xray/sing-box crashes or the tunnel drops while you still expect to be protected.

## Modes

| Mode | Behavior |
|------|----------|
| **Off** | Normal disconnect — apps may use direct internet if proxy/VPN stops. |
| **Strict** | Block **all** outbound traffic when tunnel/core is down until you reconnect or disconnect. |
| **Adaptive** | Per-app blocking — uses **Split tunneling** app list on Android. |

Configure in **Settings → Kill switch**.

## Proxy mode (Linux, Windows, macOS)

Desktop builds use **proxy mode**, not a full-system TUN VPN.

### What Strict does

1. While connected, firewall rules (Linux: iptables/nftables) allow only loopback and the authenticated local proxy ports (`127.0.0.1:1080` SOCKS, `1081` HTTP).
2. If the core process exits, system proxy is cleared and outbound traffic is **dropped** (fail closed).
3. On user disconnect, all rules are removed.

### Limitations

- **Linux**: firewall rules need `iptables` or `nft` with sufficient privileges (often root or `CAP_NET_ADMIN`). Without them, kill switch reports `available: false` and cannot block at the OS level.
- **Windows / macOS**: full WFP / `pf` firewall integration is not shipped yet. Strict mode still tears down system proxy and blocks via proxy-mode fallback; apps that ignore the system proxy may still connect directly. See [security.md](security.md).
- **Browser extension**: traffic that uses the system HTTP proxy with extension auth is protected; apps with hardcoded direct sockets are not fully covered in proxy mode.

## TUN mode (Android, iOS)

Mobile builds use `VpnService` / `NEPacketTunnelProvider`.

### What Strict does

- **Android**: `VpnService.Builder.setBlocking(true)` — when the VPN interface goes down, Android blocks non-VPN traffic. If the core dies, the tunnel stays up without forwarding (traffic blocked).
- **iOS**: `includeAllNetworks` when Strict is enabled — non-VPN interfaces are blocked while the tunnel is active.

### Limitations

- **iOS**: per-app adaptive kill switch is not available until split tunneling lands.
- **DNS / split apps**: full leak protection still depends on routing inside the tunnel config; kill switch blocks at the OS VPN layer, not inside arbitrary app sockets on desktop proxy mode.

## Security notes

- Kill switch never opens unauthenticated SOCKS on `127.0.0.1`.
- Session credentials are still wiped on disconnect.
- Strict + auto-reconnect: traffic stays blocked during reconnect attempts until the tunnel is healthy again.

## Related

- [security.md](security.md) — SOCKS auth and local bind rules
- [split_tunneling.md](split_tunneling.md) — prerequisite for Adaptive mode
- [linux_setup.md](linux_setup.md) — firewall privileges on Linux
