# Work modes

| Mode | Behavior |
|------|----------|
| Auto | Mobile VPN, desktop Proxy |
| VPN | Full tunnel (TUN). Desktop: no system proxy; apps use OS routing into the tunnel |
| Proxy | Auth localhost SOCKS/HTTP + optional system proxy (browsers / WinINET) |

Reconnect after change. Desktop VPN needs elevated privileges — see [desktop_vpn.md](desktop_vpn.md). Local proxy passwords protect **Proxy mode** and optional SOCKS clients in VPN mode — they are not how normal Windows apps reach the internet in VPN mode.
