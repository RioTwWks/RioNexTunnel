# Desktop VPN (TUN) mode

<p align="right">
  <a href="../ru/desktop_vpn.md"><img src="https://img.shields.io/badge/lang-Русский-red?style=for-the-badge" alt="Russian version"></a>
</p>

## Overview

**Work mode → VPN** on Linux, Windows, or macOS starts the core with a **TUN inbound** (same idea as Android/iOS full tunnel). The app does **not** enable the system HTTP proxy in this mode — browsers and other apps use normal routing through the tunnel.

**Work mode → Proxy** (default on desktop for **Auto**) keeps the previous behavior: authenticated local SOCKS/HTTP and optional system proxy.

## Requirements

| Platform | Privilege |
|----------|-----------|
| **Linux** | `CAP_NET_ADMIN` on the `sing-box` or `xray` binary, or run the app as root |
| **Windows** | Run RioNexTunnel **as Administrator**; **`wintun.dll`** in `resources` next to `xray.exe` (`scripts/fetch_cores.sh` copies it from **Xray-windows-64.zip**) |
| **macOS** | Run with **sudo** / administrator (Network Extension packaging is future work) |

### Linux: set capabilities (recommended)

After `./scripts/fetch_cores.sh`, from the app bundle or resources directory:

```bash
sudo setcap cap_net_admin+ep /path/to/sing-box
# or
sudo setcap cap_net_admin+ep /path/to/xray
```

Verify:

```bash
getcap /path/to/sing-box
```

## Engines

- **sing-box** — TUN inbound injected in Dart (`tun-in`, `auto_route`, `strict_route`).
- **Xray** — on Windows: main core runs **without** TUN; a **TUN bridge** process (sing-box preferred, Xray fallback) forwards system traffic to authenticated local SOCKS. On Linux/macOS, TUN stays in the main Xray process.
- **SkadiCore** — desktop VPN not supported; use sing-box or Xray.

## Security

Local SOCKS on `127.0.0.1:1080` remains **password-protected** per session even in VPN mode (golden rules unchanged).

## Related

- [work_modes.md](work_modes.md)
- [linux_setup.md](linux_setup.md)
