# Secure VPN Client — Documentation (English)

Cross-platform Flutter VPN client using **Xray-core** and **sing-box**, with mandatory authenticated local SOCKS5/HTTP proxies.

[Русская версия](../ru/README.md) · [Repository README](../../README.md)

## Contents

| Guide | Description |
|-------|-------------|
| [Getting started](getting-started.md) | Clone, fetch cores, run on a platform |
| [Linux setup](linux_setup.md) | Desktop proxy mode, GNOME proxy, browser helper |
| [Android setup](android_setup.md) | VPN service, JNI cores, permissions |
| [iOS setup](ios_setup.md) | Network Extension, entitlements |
| [Architecture](architecture.md) | Components and data flow |
| [Security](security.md) | SOCKS auth model, probes, threat context |
| [Browser extension](browser-extension.md) | Auto proxy-auth on Linux desktop |
| [Contributing](contributing.md) | Tests, PR checklist, coding rules |

## Platform status (MVP)

| Platform | Mode | Status |
|----------|------|--------|
| Linux | Proxy | Verified — engine × profile combinations |
| Android | VPN | Scaffold + fork patches; needs device test |
| iOS | VPN | Scaffold + docs; needs device test |
| Windows | Proxy | Plugin stub; cores via CMake install |
| macOS | Proxy | XrayProcess pattern in fork |

## Security highlights

- Local proxies bind to `127.0.0.1` only — never `0.0.0.0`
- Per-session random username/password; wiped on disconnect
- Never log or persist credentials
- No unauthenticated port `7890` pattern (March 2026 vulnerability class)

## Agent / maintainer docs

Internal Cursor agent notes live under [`.cursor/`](../../.cursor/AGENTS.md) (English).
