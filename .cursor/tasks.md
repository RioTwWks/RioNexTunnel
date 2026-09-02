# Project Tasks

> Agent entrypoint: [AGENTS.md](AGENTS.md) · Architecture: [architecture.md](architecture.md)

**Priorities:** P0 (critical) → P1 (key differentiators) → P2 (advanced) → P3 (UX polish)

**Recommended order:** P0 platforms + CI + reconnect → P1 kill switch / split tunnel / obfuscation UX / proxy-mgr panel → P2 DNS / routing UI / multihop → P3 UI polish / localization / extension store

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
- [ ] Windows: implement desktop plugin (mirror Linux `desktop_core.cc`)
- [ ] macOS: align plugin ports with injected inbounds (1080/1081), verify proxy mode
- [ ] Windows/macOS: `SystemProxy` integration (Linux-only today)

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

## P1 — proxy-mgr panel integration (optional, client-only)

> **Goal:** RioNexTunnel stays a universal VPN client (manual links, any VLESS/VMess/Trojan server) while optionally pairing with [proxy-mgr](https://github.com/RioTwWks/proxy-mgr) for subscriptions, stats, and remote commands. Panel features must be **opt-in** — if the user never configures a panel, behavior is unchanged.
>
> **Two-level model (client view):**
> 1. **Base layer** — standard protocols and subscription URLs; full compatibility with any third-party server/client.
> 2. **Extended layer** — optional REST/WebSocket API to proxy-mgr using a separate **device token** (does not affect transport protocol auth). If the panel is unreachable, the client keeps working from the last cached config.

### Known pain points to fix (Hiddify-class bugs)

- Subscription updates but client does not apply changes or crashes on invalid JSON
- Traffic stats lost on disconnect; panel shows wrong remaining quota
- Dynamic SOCKS5 creds on client vs subscription auth expectations on panel
- No fallback when panel is down — client hangs or wipes configs
- Ambiguous link formats — client expects one shape, panel emits another (extra params, wrong fields)

### 2.1 — `PanelManager` module

- [ ] New service: `lib/services/panel_manager.dart` (or `lib/services/panel/`)
- [ ] Persist `panel_url`, `device_token`, `subscription_url` in secure local storage (not credentials)
- [ ] REST client with timeouts, exponential backoff (max 3–5 retries), `X-API-Version: v1` header
- [ ] **Optional service:** if panel is not configured, all panel code paths are no-ops; local profiles only
- [ ] Riverpod provider wiring; Settings screen for panel URL + login/register

**Expected server API (implemented in proxy-mgr, consumed here):**

| Method | Path | Client use |
|--------|------|------------|
| `POST` | `/api/client/register` | First pairing → `device_token`, `subscription_url` |
| `GET` | `/api/client/config` | Fetch JSON config; `Authorization: Bearer <device_token>` or dedicated header |
| `POST` | `/api/client/stats` | Upload `{bytes_in, bytes_out, sessions, status, session_id}` |
| `GET` | `/api/client/commands` | Long poll / SSE for remote commands |
| `GET` | `/api/subscription/{token}` | Standard base64 subscription (fallback for any client) |

### 2.2 — Registration & config sync

- [ ] On first setup with `panel_url` + credentials → `POST /api/client/register`; store `device_token`
- [ ] Periodic sync + manual **Refresh** → `GET /api/client/config`
- [ ] Compare `config_hash` from server with local hash; skip rewrite if unchanged
- [ ] Apply config: server list, DNS, inbound hints → existing `Profile` / `ConfigParser` pipeline
- [ ] Cache last good config on disk (SharedPreferences / app support dir); use when offline
- [ ] Invalid JSON from panel → log error, keep previous config, show non-blocking warning (no crash)

### 2.3 — Stats upload

- [ ] Collect bytes in/out from core or platform counters during active session
- [ ] Background flush every ~60s and on disconnect → `POST /api/client/stats`
- [ ] Local queue when panel unreachable; batch replay when back online
- [ ] `session_id` per connect session for server-side deduplication
- [ ] Never include SOCKS passwords or transport secrets in stats payload

### 2.4 — Remote commands (push)

- [ ] Prefer WebSocket: `wss://<panel>/api/client/commands` with `device_token`
- [ ] Handle commands: `refresh_config`, `disconnect`, `switch_server` (as server defines)
- [ ] Fallback: long polling `GET /api/client/commands?last_seq=...` every ~5 min if WS unavailable
- [ ] Commands trigger existing `VpnService` / profile refresh — no duplicate connect logic

### 2.5 — SOCKS5 auth & panel configs

- [ ] **Default:** keep per-session random SOCKS creds (`CredentialService` + `injectSecureSocksInbound`)
- [ ] Setting: **Random per session** vs **Static from panel** (when panel JSON includes inbound auth)
- [ ] When panel supplies SOCKS params, align port/method with injected inbounds before connect
- [ ] Manual link import: option to disable dynamic SOCKS injection for broken third-party configs (advanced)
- [ ] Golden rule unchanged: `127.0.0.1` only, auth always required — static password from panel is still auth

### 2.6 — Errors & fallback

- [ ] All panel HTTP calls wrapped; failures never block connect if cached config exists
- [ ] User-visible state: `PanelSyncStatus` — synced / stale / offline / error (no secrets in message)
- [ ] First launch without panel or cache → existing manual link / subscription URL flow
- [ ] Subscription URL from panel works through standard `ConfigParser.parseFromUrl()` as universal path

### 2.7 — Third-party server compatibility

- [ ] No changes to `vless://` / `vmess://` / `trojan://` import parsers
- [ ] Panel-managed profiles and manual profiles coexist in same profile list
- [ ] Engine auto-select and server picker unchanged for non-panel subscriptions
- [ ] Document: panel integration is additive; uninstalling panel config does not remove manual profiles

### 3 — Client testing & observability (with proxy-mgr)

- [ ] Integration tests (Dart): register → config fetch → mock connect → stats queue → disconnect
- [ ] Test: panel pushes new `config_hash` → client refreshes without full app restart
- [ ] Test: network offline → cached config used → queued stats sent after restore
- [ ] Test: malformed config JSON → no throw; previous profile remains active
- [ ] Debug logging for sync lifecycle (device id hash only, never `device_token` in release logs)
- [ ] Optional: `integration_test/` scenario against local proxy-mgr docker/instance (document in `docs/`)

### Client roadmap (proxy-mgr track)

| Phase | RioNexTunnel tasks |
|-------|-------------------|
| **1** | `PanelManager` skeleton, register + config fetch + local cache + `config_hash` |
| **2** | Stats collector + offline queue + `session_id` |
| **3** | WebSocket / long-poll commands; reconnect on `refresh_config` |
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
| Desktop proxy mode | ✅ Linux; ⏳ Win/macOS | P0 |
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
| proxy-mgr panel API (optional) | ❌ Missing | **P1** |

---

## Agent maintenance

When fixing a new connect/config bug:

1. Add symptom → fix to [troubleshooting.md](troubleshooting.md)
2. Add regression test if Dart-side
3. Update [tasks.md](tasks.md) checklist or backlog

---

*Last updated: 2026-09-02 — added P1 proxy-mgr client integration backlog (panel API, sync, stats, commands).*
