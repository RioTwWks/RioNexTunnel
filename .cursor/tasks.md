# Project Tasks

> Agent entrypoint: [AGENTS.md](AGENTS.md) · Architecture: [architecture.md](architecture.md)

**Priorities:** P0 (critical) → P1 (key differentiators) → P2 (advanced) → P3 (UX polish)

**Recommended order:** P0 platforms + CI + reconnect → P1 kill switch / split tunnel / censorship resistance / RioNexGate panel → P2 DNS / routing UI / multihop → P3 UI polish / localization / extension store

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

## Completed — platform parity

Code-complete across targets; device E2E steps: [docs/en/platform_parity_checklist.md](../docs/en/platform_parity_checklist.md).

- [x] Linux desktop plugin + system proxy + browser helper (verified)
- [x] Windows: desktop plugin (`desktop_core.cpp`), `SystemProxy` (registry + WinINet)
- [x] macOS: ports 1080/1081, credentials channel, HTTP system proxy parity
- [x] Android: `xray_available` probe, session creds in `start_with_json`, `get_browser_helper_status` stub
- [x] iOS plugin: credentials channel, `get_core_info`, config persist/wipe, sing-box only
- [x] iOS app: PacketTunnel target + Runner entitlements (`scripts/setup_ios_packet_tunnel.py`)
- [x] Dart: `engine_auto_selector` iOS → sing-box heuristic
- [x] E2E smoke tests documented per platform (manual on device)

Deferred to P3:

- [ ] Windows browser helper (native messaging + extension) — Linux has full implementation; Windows returns `false` in `get_browser_helper_status`

---

## P0 — Foundation: stability

Kill Switch and Split Tunneling depend on reliable platform plumbing first.

### Engineering base

- [x] CI: `flutter analyze`, `flutter test` on push (`.github/workflows/ci.yml`)
- [x] Auto-run `security_probe.sh` in CI when Linux integration test connects (`linux-security-probe` job + `scripts/ci_security_probe_linux.sh`)
- [x] Fail closed if geo assets missing and config contains geosite/geoip rules (`VpnService` + `ConfigParser.configRequiresXrayGeoRules`)
- [x] Audit sing-box `mixed` / deprecated DNS paths on mobile VPN mode (`docs/en/mobile_vpn_config.md`)
- [x] Reduce `packages/v2ray_box/example/` from fork if not needed — **kept**; documented in `docs/en/v2ray_box_fork.md` (iOS PacketTunnel merge, integration tests)
- [x] Publish fork separately or document patch set vs upstream (`docs/en/v2ray_box_fork.md`, `docs/ru/v2ray_box_fork.md`)

### Connection stability

- [x] Auto-reconnect with exponential backoff on core/VPN drop (`VpnService._scheduleReconnect`)
- [x] Detailed connection states — Connecting / Reconnecting / Error with reason (`ConnectionDetail`, `StatusIndicator`)
- [x] Connection stats in UI — upload/download, uptime (`vpnStatsProvider`, `connectionUptimeProvider`, Home screen)

---

## P1 — Key differentiators (external feedback focus)

> Agent split: [p1-agent-distribution.md](p1-agent-distribution.md) — Kill Switch → **Agent A** · Split Tunneling → **Agent B** · Obfuscation → **Agent C** · RioNexGate → **Agent D** (optional)

### Kill Switch

> **Agent A** — [distribution plan](p1-agent-distribution.md#agent-a--kill-switch)

> Block traffic when VPN/core drops unexpectedly — critical security feature.

- [x] Architecture design — separate behavior for Proxy mode (desktop) vs TUN mode (mobile)
- [x] Strict mode — block all outbound internet when core/tunnel is down
- [ ] Adaptive mode — block only selected apps (per-app) — deferred for Agent B split tunneling
- [x] Linux — iptables/nftables or NetworkManager firewall rules; remove on clean disconnect
- [x] Android/iOS — VPNService / NEPacketTunnelProvider integration (block non-VPN traffic)
- [x] Windows/macOS — WFP / pf or equivalent for proxy-mode fallback
- [x] UI — Strict / Adaptive / Off toggle in Settings
- [x] Tests — simulate core crash, verify no leak (integration test)
- [x] Docs — kill switch limitations in proxy mode vs TUN mode

### Split Tunneling

> **Agent B** — [distribution plan](p1-agent-distribution.md#agent-b--split-tunneling)

> Route selected apps through VPN; others direct. Requires strict isolation (see `.cursorrules`).

- [x] Model design — whitelist (only these via VPN) vs blacklist (all except these)
- [x] Android — per-app via `VpnService.Builder.addAllowedApplication` / `addDisallowedApplication`
- [x] iOS — document NE limitations; per-app split tunneling is limited on iOS
- [x] Desktop proxy mode — document that split tunneling is OS/app-level, not TUN
- [ ] Linux TUN (if added) — policy routing / cgroup + no bypass via localhost scan
- [x] UI — installed app list with toggles (mobile) or desktop warning
- [x] Security — no bypass via unauthenticated localhost; leak test with split tunnel enabled
- [x] Tests — unit + platform smoke for whitelist/blacklist

### Traffic obfuscation (DPI bypass UX)

> **Agent C** — [distribution plan](p1-agent-distribution.md#agent-c--censorship-resistance--obfuscation-ux) (includes censorship resistance below)

> Protocols supported by cores, but no presets or wizard for censorship bypass. See **P1 — censorship resistance** below for RKN/TSPU-specific backlog.

- [x] Transport presets — WebSocket+TLS, gRPC, HTTPUpgrade, REALITY (xray), uTLS fingerprint
- [x] UI wizard — "censorship mode" when importing or editing a profile
- [x] Auto-detect — suggest transport from subscription metadata when available
- [x] Docs — when to use Trojan/VLESS+REALITY vs plain TLS
- [x] Tests — validate generated xray/sing-box JSON (no real DPI test needed)

---

## P1 — RioNexGate panel integration (optional, client-only)

> **Agent D** — [distribution plan](p1-agent-distribution.md#agent-d--rionexgate-panel-integration-optional)

> **Goal:** RioNexTunnel stays a universal VPN client (manual links, any VLESS/VMess/Trojan server) while optionally pairing with [RioNexGate](https://github.com/RioTwWks/RioNexGate) for subscriptions, stats, and remote commands. Panel features must be **opt-in** — if the user never configures a panel, behavior is unchanged.
>
> **Two-level model (client view):**
> 1. **Base layer** — standard protocols and subscription URLs; full compatibility with any third-party server/client.
> 2. **Extended layer** — optional REST/WebSocket API to RioNexGate using a separate **device token** (does not affect transport protocol auth). If the panel is unreachable, the client keeps working from the last cached config.

### Known pain points to fix (Hiddify-class bugs)

- Subscription updates but client does not apply changes or crashes on invalid JSON
- Traffic stats lost on disconnect; panel shows wrong remaining quota
- Dynamic SOCKS5 creds on client vs subscription auth expectations on panel
- No fallback when panel is down — client hangs or wipes configs
- Ambiguous link formats — client expects one shape, panel emits another (extra params, wrong fields)

### 2.1 — `PanelManager` module

- [x] New service: `lib/services/panel_manager.dart` (or `lib/services/panel/`)
- [x] Persist `panel_url`, `device_token`, `subscription_url` in secure local storage (not credentials) — SharedPreferences MVP; migrate to secure storage later
- [x] REST client with timeouts, exponential backoff (max 3–5 retries), `X-API-Version: v1` header
- [x] **Optional service:** if panel is not configured, all panel code paths are no-ops; local profiles only
- [x] Riverpod provider wiring; Settings screen for panel URL + login/register (`PanelSettingsSection`, `PanelStatusCard`)

**Expected server API (implemented in RioNexGate, consumed here):**

| Method | Path | Client use |
|--------|------|------------|
| `POST` | `/api/client/register` | First pairing → `device_token`, `subscription_url` |
| `GET` | `/api/client/config` | Fetch JSON config; `Authorization: Bearer <device_token>` or dedicated header |
| `POST` | `/api/client/stats` | Upload `{bytes_in, bytes_out, sessions, status, session_id}` |
| `GET` | `/api/client/commands` | Long poll / SSE for remote commands |
| `GET` | `/api/subscription/{token}` | Standard base64 subscription (fallback for any client) |

### 2.2 — Registration & config sync

- [x] On first setup with `panel_url` + credentials → `POST /api/client/register`; store `device_token`
- [x] Manual **Refresh** → `GET /api/client/config` (periodic sync — **partial**, not yet scheduled)
- [x] Compare `config_hash` from server with local hash; skip rewrite if unchanged
- [x] Apply config: subscription URL → `Profile` named RioNexGate + `ConfigParser` pipeline (**partial** — full JSON config apply pending)
- [x] Cache last good config on disk (SharedPreferences); use when offline (**stale** status)
- [x] Invalid JSON from panel → log error, keep previous config, show non-blocking warning (no crash)

### 2.3 — Stats upload

- [x] Collect bytes in/out from core counters on disconnect (`VpnStats` uplink/downlink totals)
- [ ] Background flush every ~60s and on disconnect → `POST /api/client/stats` (**partial** — disconnect flush only)
- [x] Local queue when panel unreachable; batch replay when back online
- [x] `session_id` per connect session for server-side deduplication
- [x] Never include SOCKS passwords or transport secrets in stats payload

### 2.4 — Remote commands (push)

- [x] Prefer WebSocket: `wss://<panel>/api/client/commands` with `device_token`
- [x] Handle commands: `refresh_config`, `disconnect`, `switch_server` (as server defines)
- [x] Fallback: long polling `GET /api/client/commands?last_seq=...` every ~5 min if WS unavailable
- [x] Commands trigger existing `VpnService` / profile refresh — no duplicate connect logic

### 2.5 — SOCKS5 auth & panel configs

- [ ] **Default:** keep per-session random SOCKS creds (`CredentialService` + `injectSecureSocksInbound`)
- [ ] Setting: **Random per session** vs **Static from panel** (when panel JSON includes inbound auth)
- [ ] When panel supplies SOCKS params, align port/method with injected inbounds before connect
- [ ] Manual link import: option to disable dynamic SOCKS injection for broken third-party configs (advanced)
- [ ] Golden rule unchanged: `127.0.0.1` only, auth always required — static password from panel is still auth

### 2.6 — Errors & fallback

- [x] All panel HTTP calls wrapped; failures never block connect if cached config exists
- [x] User-visible state: `PanelSyncStatus` — synced / stale / offline / error (no secrets in message)
- [x] First launch without panel or cache → existing manual link / subscription URL flow
- [x] Subscription URL from panel works through standard `ConfigParser.parseFromUrl()` as universal path

### 2.7 — Third-party server compatibility

- [x] No changes to `vless://` / `vmess://` / `trojan://` import parsers
- [x] Panel-managed profiles and manual profiles coexist in same profile list
- [x] Engine auto-select and server picker unchanged for non-panel subscriptions
- [ ] Document: panel integration is additive; uninstalling panel config does not remove manual profiles

### 3 — Client testing & observability (with RioNexGate)

- [x] Unit tests (Dart): register → config fetch → stats queue (`test/panel_manager_test.dart`)
- [ ] Integration tests (Dart): register → config fetch → mock connect → stats queue → disconnect
- [ ] Test: panel pushes new `config_hash` → client refreshes without full app restart
- [ ] Test: network offline → cached config used → queued stats sent after restore
- [ ] Test: malformed config JSON → no throw; previous profile remains active
- [x] Debug logging for sync lifecycle (device id hash only, never `device_token` in release logs)
- [ ] Optional: `integration_test/` scenario against local RioNexGate docker/instance (document in `docs/`)

### Client roadmap (RioNexGate track)

| Phase | RioNexTunnel tasks |
|-------|-------------------|
| **1** | `PanelManager` skeleton, register + config fetch + local cache + `config_hash` — **done (MVP)** |
| **2** | Stats collector + offline queue + `session_id` — **partial** (disconnect flush; no 60s timer) |
| **3** | WebSocket / long-poll commands; reconnect on `refresh_config` — **done (§2.4)** |
| **4** | SOCKS mode toggle; integration tests; RU/EN docs for panel pairing |

### Expected outcomes

| Pain point | Client fix |
|------------|------------|
| Unreliable sync | Cached config + hash diff + retries |
| Lost stats | Queue + batch upload + `session_id` |
| Auth confusion | Device token for panel only; transport auth separate |
| Panel down | Stale cache + warning; VPN keeps running |
| Format mismatch | Strict JSON schema validation; fallback to subscription URL import |

---

## P1 — censorship resistance (RKN/TSPU, client-only)

> **Agent C** — [distribution plan](p1-agent-distribution.md#agent-c--censorship-resistance--obfuscation-ux)

> **Goal:** RioNexTunnel stays effective against modern Russian DPI (ТСПУ/РКН) in 2026 without sacrificing universality. Censorship-bypass features are **presets and fallbacks** on top of standard VLESS/VMess/Trojan — the client must still connect to any third-party server.
>
> **Core policy — no abandoned Xray forks:** Do **not** ship or depend on [fwflunky/REALITY-rkn-fix](https://github.com/fwflunky/REALITY-rkn-fix) (unmaintained, untested). Use **official Xray-core** from `scripts/fetch_cores.sh` with correct transport/TLS settings. Treat the fork as an ideas reference only; if upstream adds dynamic REALITY certs, adopt via normal core updates.

### Threat model (why naive VLESS+Reality TCP fails)

- **Signature detection** — static REALITY cert structure (`SerialNumber = 0`, empty Subject, identical body per connection) is fingerprintable; mitigated by server config + transport choice, not a custom client fork
- **TLS handshake timing** — DPI drops long handshakes or persistent TCP after TLS without HTTP-like behavior → prefer **XHTTP** over raw TCP
- **Packet size analysis** — ~200-byte ServerHello in one segment is a signal; server-side ServerHello fragmentation is out of scope here; client must not make PPS worse by over-fragmenting locally

### Recommended stacks (client must parse, generate, and connect)

| Priority | Stack | Client role |
|----------|-------|-------------|
| **Primary** | `VLESS + Reality + XHTTP` | Parse `type=xhttp` links; ensure outbound JSON includes `"network": "xhttp"` and **`"mode": "stream-one"`** (never rely on `auto` — known bugs) |
| **Fallback** | `VLESS + TLS (non-443) + mux` (`concurrency: 8`) | Toggle mux in profile/advanced settings; mobile-first; desktop may omit mux UI |
| **iOS fallback** | `TCP + Reality + Vision` | When subscription offers both XHTTP and TCP+Vision, prefer XHTTP except on iOS where XHTTP+Reality may be unsupported — auto-select TCP+Vision inbound |
| **Reserve protocol** | **AmneziaWG** | Evaluate sing-box/xray WG obfuscation or separate AmneziaWG core path; standard WireGuard is widely blocked in RU mobile networks |

### 1 — XHTTP transport

- [x] `LinkConfigBuilder` — parse `vless://` / subscription params: `type=xhttp`, `path`, `host`, `mode`
- [x] Default generated XHTTP outbound: `"mode": "stream-one"` when mode omitted
- [ ] `ConfigParser` — preserve XHTTP fields from full JSON subscriptions (xray + sing-box mapping)
- [x] Validation warning if `mode: auto` detected in imported config
- [x] Tests — round-trip XHTTP link → JSON → required fields present (`stream-one`)
- [x] Docs — XHTTP+Reality as 2026 default; link param reference in `docs/`

### 2 — mux (mobile fallback stack)

- [x] Profile setting: **Enable mux** with `concurrency` (default `8`) for VLESS+TLS profiles
- [x] Apply mux only when user enables or profile tag is `mux` / `mobile` (do not force globally)
- [ ] Desktop proxy mode — document that mux is optional and often unnecessary when XHTTP is available
- [ ] `ping_config_builder` — respect mux for latency probes or strip consistently (today: strips mux)
- [x] Tests — mux injected only when setting on; sing-box vs xray field names

### 3 — uTLS / TLS fingerprint (ClientHello obfuscation)

- [x] UI: **TLS fingerprint** picker — `firefox`, `edge`, `chrome`, `safari`, `random` (advanced)
- [x] Sensible default: **`firefox`** or **`edge`** (2026 RU blocks reportedly flag `chrome`/`safari` more often)
- [x] `LinkConfigBuilder` — stop defaulting `fp` to `chrome` when absent; use profile default or `firefox`
- [x] Ensure xray `fingerprint` + sing-box `utls.fingerprint` stay in sync when editing profile
- [x] Subscription import — honor `fp` from link; allow override in profile without rewriting server URL
- [x] Tests — fingerprint flows into outbound JSON for both engines

### 4 — Smart routing (RU split tunnel preset)

> Overlaps with **Split Tunneling** above; this preset is censorship-specific.

- [x] Preset: **RU direct** — `geosite:ru`, `geoip:ru`, and common RU domains (Yandex, Gosuslugi, major banks) → `direct` / bypass tunnel
- [x] All other traffic → proxy outbound (existing subscription routing merged, not replaced)
- [x] Desktop proxy mode — document limits (browser/OS may ignore app routing rules)
- [x] Requires geo assets (`geoip.dat`, `geosite.dat`); fail closed with clear error if rules reference geo but assets missing
- [x] Security — direct path must not expose unauthenticated localhost SOCKS; no bypass via `127.0.0.1` scanning
- [x] UI toggle: **Censorship preset: RU sites direct** in Advanced → Routing
- [x] Tests — generated routing rules contain expected `geosite:ru` / `geoip:ru` tags

### 5 — Protocol & server auto-fallback

- [ ] Extend server picker / `SubscriptionManager`: ordered probe list per subscription entry tags
- [ ] Default probe order: `VLESS+Reality+XHTTP` → `VLESS+TLS+mux` → `TCP+Reality+Vision` → `AmneziaWG` (if present)
- [ ] On connect failure or mid-session drop — try next candidate with exponential backoff (reuse P0 reconnect)
- [ ] Persist last working stack per server (latency + success rate) for faster reconnect
- [x] UI: show active transport stack (e.g. "XHTTP · Reality · firefox") without secrets
- [ ] Tests — mock failure on first outbound, assert fallback to second profile fragment

### 6 — Platform & engine notes

- [ ] iOS — detect platform; deprioritize XHTTP+Reality, prioritize TCP+Reality+Vision from same subscription
- [ ] Engine version gate — warn if bundled Xray is older than feature requiring XHTTP (compare against `fetch_cores.sh` pin)
- [ ] **Do not** vendor custom Xray builds for REALITY cert randomization; track [XTLS/Xray-core](https://github.com/XTLS/Xray-core) issues/PRs instead
- [ ] Optional: document upstream REALITY improvements in `docs/` when official core catches up to fork ideas

### 7 — Testing & docs (client)

- [x] Config fixture tests for each recommended stack (XHTTP stream-one, mux, Vision, AmneziaWG link samples)
- [x] No live DPI test in CI — validate JSON shape and parser resilience only
- [x] `docs/en/` + `docs/ru/` — censorship preset guide, fingerprint choice, fallback behavior, iOS caveats
- [x] Troubleshooting entry: "works on Wi‑Fi, fails on mobile operator" → suggest mux / AmneziaWG fallback

### Client roadmap (censorship resistance track)

| Phase | RioNexTunnel tasks |
|-------|-------------------|
| **1** | XHTTP parse/generate + `stream-one` default + tests |
| **2** | Fingerprint UI + non-chrome defaults + mux toggle |
| **3** | RU direct routing preset + geo asset guard |
| **4** | Multi-stack auto-fallback + iOS transport selection + docs |

### Expected outcomes

| Threat | Client mitigation |
|--------|-------------------|
| TCP Reality fingerprint | Prefer XHTTP; fallback stacks in subscription |
| ClientHello inspection | uTLS fingerprint picker; firefox/edge defaults |
| RU site via foreign IP | RU direct routing preset |
| Mobile operator blocks | mux + AmneziaWG in fallback chain |
| iOS XHTTP gap | Auto-select TCP+Reality+Vision |
| Fork maintenance risk | Official Xray-core only |

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

- [ ] Windows browser helper (native messaging host; Linux reference in `packages/v2ray_box/linux/`)
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
| Desktop proxy mode | ✅ Linux + Windows + macOS (checklist: `docs/en/platform_parity_checklist.md`) | — |
| Subscriptions + server picker | ✅ Done | — |
| Auto best server by latency | ✅ Done | — |
| Open Source, zero telemetry | ✅ Done | — |
| Kill Switch | ✅ Strict + plumbing (Adaptive deferred) | **P1** |
| Split Tunneling | ✅ Android + docs | **P1** |
| Obfuscation / DPI (UX) | ✅ Wizard + presets | **P1** |
| XHTTP + stream-one | ✅ Link builder | **P1** |
| TLS fingerprint UI (uTLS) | ✅ Picker + firefox default | **P1** |
| mux toggle (mobile) | ✅ Profile wizard | **P1** |
| RU direct routing preset | ✅ ConfigEnhancer + UI | **P1** |
| Protocol auto-fallback chain | ⚠️ Latency pick only | **P1** |
| AmneziaWG | ❌ Missing | P1/P2 |
| Double VPN / Multihop | ❌ Missing | P2 |
| DNS leak protection, DoH/DoT | ⚠️ Basic DNS only | P2 |
| Custom routing UI | ⚠️ Subscription JSON only | P2 |
| Auto-reconnect | ✅ Done | — |
| Minimalist UI | ⚠️ Partial | P3 |
| Connection stats | ✅ Done | — |
| RioNexGate panel API (optional) | ⚠️ MVP (register, sync, stats queue, Settings UI) | **P1** |

---

## Agent maintenance

When fixing a new connect/config bug:

1. Add symptom → fix to [troubleshooting.md](troubleshooting.md)
2. Add regression test if Dart-side
3. Update [tasks.md](tasks.md) checklist or backlog

---

*Last updated: 2026-09-02 — P0 Foundation stability; P1 split tunneling (Android + docs), kill switch strict mode, censorship resistance (XHTTP, uTLS, mux, RU routing), RioNexGate panel MVP; official Xray only, no REALITY-rkn-fix fork.*
