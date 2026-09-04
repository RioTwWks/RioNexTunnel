# Advanced DNS
English · [Русская версия](../ru/dns.md)
Mobile VPN/TUN: Settings → **Advanced DNS**. Desktop proxy mode does not intercept system DNS.
## Modes
| Mode | Description |
|------|-------------|
| Default | UDP 8.8.8.8 / 1.1.1.1 |
| Custom | User resolvers |
| Encrypted | DoH/DoT via detour: proxy |
## Leak protection
hijack-dns routing; iOS reads flutter.dns_system_servers.
## Desktop proxy
DNS injection skipped when proxyOnly: true.
