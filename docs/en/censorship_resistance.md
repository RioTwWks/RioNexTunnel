# Censorship resistance & transport presets

RioNexTunnel supports standard VLESS/VMess/Trojan links from any provider. **Censorship mode** adds presets and client-side options to improve resilience against DPI (including RKN/TSPU) without custom Xray forks.

## When to use which stack

| Situation | Recommended stack | Notes |
|-----------|-------------------|--------|
| Modern RU DPI (2026), server supports it | **VLESS + REALITY + XHTTP** (`mode: stream-one`) | Primary recommendation; avoids raw TCP Reality fingerprint |
| Server offers REALITY but not XHTTP | **VLESS/Trojan + REALITY + TCP** | Works; more fingerprintable than XHTTP |
| CDN or reverse proxy in front | **WebSocket + TLS** or **HTTPUpgrade + TLS** | Good when port 443 looks like normal HTTPS |
| gRPC allowed on network | **gRPC + TLS** | Alternative when WebSocket is throttled |
| Mobile operator blocks, no XHTTP | **VLESS + TLS + mux** (concurrency 8) | Enable mux in censorship wizard |
| Legacy / simple server | **Plain TLS (TCP)** | Easiest for DPI to classify; use only if required |
| Trojan vs VLESS+REALITY | Prefer **VLESS+REALITY** when available | Trojan+TLS is fine behind CDN; REALITY hides proxy TLS without a real cert |

**Do not use** unmaintained REALITY forks (e.g. REALITY-rkn-fix). RioNexTunnel uses **official Xray-core** from `scripts/fetch_cores.sh`.

## uTLS fingerprint

The censorship wizard lets you pick a **ClientHello fingerprint**: `firefox`, `edge`, `chrome`, `safari`, or `random`.

- Default: **firefox** (when link has no `fp` param)
- In restrictive networks, **firefox** or **edge** are often safer than chrome/safari
- Link `fp` is honored; profile override applies when censorship mode is enabled

## Censorship wizard

When adding or editing a profile (Profiles tab):

1. Paste link or subscription URL → **Add profile**
2. **Censorship mode** wizard opens (can Skip)
3. Auto-detect shows current transport from link metadata
4. Pick preset, fingerprint, optional mux and **RU sites direct**
5. For link profiles, transport params are applied to the share link

## RU sites direct

Routes `geosite:ru` and `geoip:ru` to **direct** outbound (Russian sites without foreign IP).

- Requires **geo assets** (`geoip.dat`, `geosite.dat`) for Xray — run `scripts/fetch_cores.sh`
- App **fails closed** if geo rules are present but assets are missing
- Desktop **proxy mode**: OS/browser may not honor all routing rules (see split tunnel docs)

## Security (unchanged)

- Local SOCKS/HTTP stays on **127.0.0.1** with **password auth** per session
- Transport secrets and credentials are **never logged**
- RU direct routing does not expose unauthenticated localhost

## Subscription JSON (XHTTP)

Full JSON subscriptions (v2rayNG array or single-object configs) use different field names per engine. `ConfigParser.injectSecureSocksInbound` normalizes XHTTP on connect:

| Engine | Transport location | Mode field |
|--------|-------------------|------------|
| Xray | `outbounds[].streamSettings.network: "xhttp"` + `xhttpSettings` | `xhttpSettings.mode` |
| sing-box | `outbounds[].transport.type: "xhttp"` | `transport.mode` |

`path`, `host`, and other XHTTP keys from the subscription are preserved. Missing or `auto` mode is coerced to **`stream-one`** (same default as `vless://` links via `LinkConfigBuilder`).

## Troubleshooting

| Symptom | Try |
|---------|-----|
| Works on Wi‑Fi, fails on mobile operator | Enable **mux**; ask provider for XHTTP or AmneziaWG node |
| XHTTP connect errors | Ensure server uses `mode: stream-one` (not `auto`) |
| RU direct / geo errors | Run `scripts/fetch_cores.sh` or disable RU preset |
| iOS XHTTP+REALITY issues | Prefer TCP+REALITY+Vision node from same subscription |

## Platform & engine policy

### iOS transport selection

When **Automatic (best latency)** is enabled on a subscription that lists both **XHTTP+REALITY** and **TCP+REALITY+Vision** nodes, RioNexTunnel **deprioritizes XHTTP on iOS** and prefers Vision-capable TCP+REALITY entries. On other platforms, XHTTP remains the default censorship stack when both are reachable.

This is **server ranking only** (§6) — not a connect-time fallback chain (§5). If only XHTTP nodes exist, iOS still connects to the best reachable XHTTP entry.

### Official Xray-core only

RioNexTunnel ships **official [Xray-core](https://github.com/XTLS/Xray-core)** binaries from `scripts/fetch_cores.sh`. We **do not** vendor custom Xray builds for REALITY certificate randomization or other fork-only tweaks (e.g. unmaintained [REALITY-rkn-fix](https://github.com/fwflunky/REALITY-rkn-fix)).

Mitigations against static REALITY fingerprints are **transport choice** (prefer XHTTP where supported), **uTLS fingerprints**, and **server-side** configuration — not patched client cores.

### Core version gate (XHTTP)

The app compares the bundled Xray version against the pin in `scripts/fetch_cores.sh` (`DEFAULT_XRAY_VERSION`, currently **26.3.27**). When connecting with **XHTTP+REALITY** and the bundled core is older:

- A **non-blocking warning** is logged at connect time
- **Settings → Core engine** shows a reminder to run `scripts/fetch_cores.sh`

Update cores with `./scripts/fetch_cores.sh` from the repo root, then rebuild the app.

### Upstream REALITY improvements

When official Xray-core adds features inspired by community forks (dynamic REALITY certs, ServerHello fragmentation, etc.), RioNexTunnel adopts them via **normal core updates** in `fetch_cores.sh` — not by maintaining a private fork. Track upstream:

- [XTLS/Xray-core releases](https://github.com/XTLS/Xray-core/releases)
- [XTLS/Xray-core issues](https://github.com/XTLS/Xray-core/issues) (REALITY / XHTTP tags)

See also [security.md](security.md) and [troubleshooting.md](troubleshooting.md).
