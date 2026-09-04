# Multihop (Double VPN)

RioNexTunnel can route traffic through **two or more VPN servers in sequence** (multihop / double VPN).

## How it works

1. Use a **subscription profile** with at least two servers.
2. On **Home**, pick the **entry server**.
3. Enable **Multihop (Double VPN)** and select additional hops.
4. Connect as usual.

- **Xray-core** uses `proxySettings` chains between outbounds.
- **sing-box** uses `detour` on outbounds.

The local authenticated SOCKS/HTTP proxy on `127.0.0.1` is unchanged — multihop does **not** open extra listen ports.

## Latency vs anonymity

Multihop adds latency (each hop adds RTT) in exchange for routing through multiple nodes. Use it when you need that extra layer, not for everyday speed.

## Limitations

- Subscription profiles only.
- At least two distinct servers.
- WireGuard/SSH/Hysteria cannot be intermediate hops (may work as exit on sing-box).

## Security

- Hop credentials are never logged.
- Per-session SOCKS auth on `127.0.0.1` remains mandatory.
- Secure inbound injection is unchanged.
