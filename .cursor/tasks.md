# Project Tasks

> Agent entrypoint: [AGENTS.md](AGENTS.md) · Architecture: [architecture.md](architecture.md)

**Priorities:** P0 (critical) → P1 (key differentiators) → P2 (advanced) → P3 (UX polish)

**Recommended order:** P0 platforms + CI + reconnect → P1 kill switch / split tunnel / obfuscation UX → P2 DNS / routing UI / multihop → P3 UI polish / localization / extension store

---

## Completed — core

- [x] Project structure, `.cursorrules`, Riverpod UI
- [x] `CredentialService` + secure SOCKS injection (`ConfigParser`)
- [x] Local fork `packages/v2ray_box` with credential channel
- [x] `scripts/fetch_cores.sh` (xray, sing-box, geo assets)
- [x] Engine switching (xray / singbox) + auto engine selection
- [x] Profile management (config link + subscription URL)
- [x] Security tests + `security_probe.sh`
- [x] Integration / widget tests
- [x] Protocol support via cores: VLESS, VMess, Shadowsocks, Trojan, Hysteria/Hysteria2, TUIC, WireGuard, SSH
- [x] Open Source (GPLv3), zero telemetry by design
- [x] Basic DNS: sing-box legacy migration, VPN-safe resolvers in `LinkConfigBuilder`
- [x] Routing from subscriptions: `geosite:` / `geoip:` when geo assets present

## Completed — Linux desktop

- [x] Linux plugin: setup, stop, start_with_json, status + credentials channels
- [x] Core discovery `bundle/lib/resources/`
- [x] Config write path fix + stale directory cleanup
- [x] Core stderr → UI error message
- [x] Geo assets copy to `~/.local/share/v2ray_box/assets/`
- [x] Subscription UA + decoy skipping + v2rayNG array selection
- [x] proxyOnly inbound sanitization + sing-box DNS migration
- [x] Xray routing `proxy` tag rewrite
- [x] **Verified:** xray/singbox × subscription/config (4 combinations)
- [x] GNOME system proxy via GSettings (`system_proxy.cc`)
- [x] HTTP inbound on `socksPort + 1` for desktop (`proxyOnly` in `ConfigParser`)
- [x] Session credentials passed to native plugin (`connectWithJson` → `SystemProxy::Enable`)
- [x] Orphan process cleanup on ports 1080/1081
- [x] UI: proxy credentials in Settings when Connected
- [x] Browser helper: extension + native messaging host (auto proxy-auth)
- [x] UI: proxy credentials on Home + Copy both + RU/EN strings
- [x] Settings: Browser helper status card

## Completed — UX & profiles

- [x] Server picker when subscription returns multiple v2rayNG entries
- [x] Auto-select best subscription server by TCP latency
- [x] Auto engine (xray/sing-box): availability, subscription format, connect fallback
- [x] `docs/linux_setup.md` in `docs/` (mirror android/ios)

## Security checklist (never break)

- [x] No hardcoded credentials
- [x] Bind 127.0.0.1 only
- [x] Mandatory SOCKS auth
- [x] Per-session credentials
- [x] Credentials cleared on stop

---

## P0 — Foundation: stability & platform parity

Kill Switch and Split Tunneling depend on reliable platform plumbing first.

### Platform parity

- [ ] Android: end-to-end connect on physical device (VPN/TUN mode)
- [ ] iOS: Network Extension + connect smoke test
- [x] Windows: implement desktop plugin (mirror Linux `desktop_core.cc`)
- [x] macOS: align plugin ports with injected inbounds (1080/1081)
- [ ] macOS: E2E verify proxy mode connect with bundled cores
- [x] Windows: `SystemProxy` integration (registry + WinINet)
- [x] macOS: session credentials channel + HTTP port 1081 parity with Linux
- [ ] Windows: browser helper (native messaging host + extension)

### Engineering base

- [ ] CI: `flutter analyze`, `flutter test` on push
- [ ] Auto-run `security_probe.sh` in CI when Linux integration test connects
- [ ] Fail closed if geo assets missing and config contains geosite/geoip rules
- [ ] Audit sing-box `mixed` / deprecated DNS paths on mobile VPN mode
- [ ] Reduce `packages/v2ray_box/example/` from fork if not needed (size)
- [ ] Publish fork separately or document patch set vs upstream

### Connection stability

- [ ] Auto-reconnect with exponential backoff on core/VPN drop
- [ ] Detailed connection states — Connecting / Reconnecting / Error with reason (not just Connected/Disconnected)
- [ ] Connection stats in UI — upload/download, uptime

---

## P1 — Key differentiators (external feedback focus)

### Kill Switch

> Block traffic when VPN/core drops unexpectedly — critical security feature.

- [ ] Architecture design — separate behavior for Proxy mode (desktop) vs TUN mode (mobile)
- [ ] Strict mode — block all outbound internet when core/tunnel is down
- [ ] Adaptive mode — block only selected apps (per-app)
- [ ] Linux — iptables/nftables or NetworkManager firewall rules; remove on clean disconnect
- [ ] Android/iOS — VPNService / NEPacketTunnelProvider integration (block non-VPN traffic)
- [ ] Windows/macOS — WFP / pf or equivalent for proxy-mode fallback
- [ ] UI — Strict / Adaptive / Off toggle in Settings
- [ ] Tests — simulate core crash, verify no leak (integration test)
- [ ] Docs — kill switch limitations in proxy mode vs TUN mode

### Split Tunneling

> Route selected apps through VPN; others direct. Requires strict isolation (see `.cursorrules`).

- [ ] Model design — whitelist (only these via VPN) vs blacklist (all except these)
- [ ] Android — per-app via `VpnService.Builder.addAllowedApplication` / `addDisallowedApplication`
- [ ] iOS — document NE limitations; per-app split tunneling is limited on iOS
- [ ] Desktop proxy mode — document that split tunneling is OS/app-level, not TUN
- [ ] Linux TUN (if added) — policy routing / cgroup + no bypass via localhost scan
- [ ] UI — installed app list with toggles (mobile) or desktop warning
- [ ] Security — no bypass via unauthenticated localhost; leak test with split tunnel enabled
- [ ] Tests — unit + platform smoke for whitelist/blacklist

### Traffic obfuscation (DPI bypass UX)

> Protocols supported by cores, but no presets or wizard for censorship bypass.

- [ ] Transport presets — WebSocket+TLS, gRPC, HTTPUpgrade, REALITY (xray), uTLS fingerprint
- [ ] UI wizard — "censorship mode" when importing or editing a profile
- [ ] Auto-detect — suggest transport from subscription metadata when available
- [ ] Docs — when to use Trojan/VLESS+REALITY vs plain TLS
- [ ] Tests — validate generated xray/sing-box JSON (no real DPI test needed)

---

## P2 — Advanced security & routing

### Multihop (Double VPN / chains)

- [ ] Chain model — 2+ outbounds in config (xray `chain` / sing-box `detour`)
- [ ] UI — pick second (and further) hop from subscription server list
- [ ] Validation — incompatible protocols, timeouts, detour order
- [ ] Docs — latency vs anonymity tradeoff

### Advanced DNS

- [ ] DNS leak protection — force DNS through tunnel in TUN mode; leak test
- [ ] DoH / DoT — configurable encrypted DNS upstream in UI
- [ ] Custom DNS — user resolvers (IP, DoH URL, DoT host)
- [ ] DNS leak test — built-in check or link from Settings
- [ ] Desktop proxy mode — document DNS behavior differences vs full VPN

### Custom routing UI

- [ ] Rule editor — domains, IP/CIDR, geo (geosite/geoip) without raw JSON
- [ ] Import/export — routing rules as a separate profile
- [ ] Presets — "blocked sites only", "RU direct / rest proxy"
- [ ] Merge — user rules with routing from subscription

### Security hardening (optional)

- [ ] Certificate pinning for subscription fetch

---

## P3 — UX, transparency & competitive edge

Avoid cluttered UI (PIA anti-pattern); advanced settings in a separate section.

### Minimal UI

- [ ] Connect in 1–2 taps — Home: profile + prominent Connect button
- [ ] Advanced settings screen — routing, DNS, kill switch, split tunnel grouped separately
- [ ] Full app localization (RU/EN) beyond proxy/browser helper strings
- [ ] Dark/light theme aligned with system preference

### Profile management

- [ ] Profile import from clipboard / QR (`vless://`, `trojan://`, etc.)
- [ ] Scheduled subscription auto-refresh + manual refresh
- [ ] Server groups — tags, favorites, last used

### Transparency

- [ ] Privacy policy doc — zero telemetry, what is stored locally
- [ ] User-facing log viewer (no credentials); Info / Debug levels
- [ ] Keep this file synced with releases / GitHub Issues

### Work modes (document & unify)

- [ ] VPN Mode (TUN) — mobile: full tunnel, kill switch, split tunnel
- [ ] Proxy Mode — desktop: system proxy + browser extension; document kill switch limits
- [ ] Unified mode switch — auto-detect per platform with power-user override

### Other UX

- [ ] Publish browser extension to Chrome Web Store / Firefox AMO

---

## Anti-patterns — do not repeat

| Anti-pattern | Our position |
|--------------|--------------|
| Unreliable kill switch | Test core drop; fail closed |
| Cluttered UI | Minimal Home; Advanced section separate |
| Telemetry / closed source | GPLv3, zero telemetry by design |
| Unauthenticated localhost proxy | **Never** — project golden rule |
| In-app ads / upsell | No ads, no upsell in UI |
| Opaque status | Detailed states + logs without secrets |

---

## Feedback → status matrix

| Feature | Status | Priority |
|---------|--------|----------|
| Cross-platform (Flutter) | ✅ Done | — |
| Xray + sing-box | ✅ Done | — |
| Secure SOCKS5 (auth, 127.0.0.1) | ✅ Done | — |
| Desktop proxy mode | ✅ Linux + Windows + macOS (verify on device) | P0 |
| Subscriptions + server picker | ✅ Done | — |
| Auto best server by latency | ✅ Done | — |
| Open Source, zero telemetry | ✅ Done | — |
| Kill Switch | ❌ Missing | **P1** |
| Split Tunneling | ❌ Missing | **P1** |
| Obfuscation / DPI (UX) | ⚠️ Via protocols, no UI | **P1** |
| Double VPN / Multihop | ❌ Missing | P2 |
| DNS leak protection, DoH/DoT | ⚠️ Basic DNS only | P2 |
| Custom routing UI | ⚠️ Subscription JSON only | P2 |
| Auto-reconnect | ❌ Missing | P0 |
| Minimalist UI | ⚠️ Partial | P3 |
| Connection stats | ❌ Missing | P0 |

---

## Agent maintenance

When fixing a new connect/config bug:

1. Add symptom → fix to [troubleshooting.md](troubleshooting.md)
2. Add regression test if Dart-side
3. Update [tasks.md](tasks.md) checklist or backlog

---

*Last updated: 2026-09-02 — merged external feedback roadmap into agent backlog.*
