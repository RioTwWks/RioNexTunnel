# P1 — распределение работы между агентами

> **Для пользователя (кратко):** Раздел P1 разбит на **четыре независимых потока** (три обязательных + один опциональный). **Agent A** (Kill Switch), **Agent B** (Split Tunneling) и **Agent C** (обфускация + цензуроустойчивость) можно **запускать параллельно**, но **Agent A** должен дождаться merge **Agent B** перед реализацией режима *Adaptive* (per-app). **Agent D** (RioNexGate) полностью изолирован и может идти параллельно с любым из них.
>
> Рекомендуемый порядок merge в `main`: **C → B → A → D** (опционально). P0 (reconnect, connection states, CI security probe) уже завершён — это база для kill switch и split tunnel.
>
> Детали по каждому агенту, матрица параллелизации и риски конфликтов — ниже. Ветки: `cursor/<slug>-ddc7`.

---

## Overview

| Agent | ID | Branch | Mission | Rationale |
|-------|-----|--------|---------|-----------|
| **A** | Kill Switch | `cursor/kill-switch-ddc7` | Блокировка трафика при падении core/VPN | Критичная security-фича; требует native firewall/VPN hooks на всех платформах |
| **B** | Split Tunneling | `cursor/split-tunneling-ddc7` | Per-app whitelist/blacklist + изоляция | Уже есть scaffold (`per_app_proxy_*`); нужно довести модель, include-режим, тесты, docs |
| **C** | Censorship & Obfuscation UX | `cursor/censorship-obfuscation-ddc7` | XHTTP, uTLS, mux, пресеты, RU routing, fallback | Объединяет *Traffic obfuscation* и *censorship resistance* — общий слой `LinkConfigBuilder` / `ConfigParser` / Profile |
| **D** *(optional)* | RioNexGate Panel | `cursor/rionexgate-panel-ddc7` | Опциональная интеграция с панелью | Изолированный модуль `PanelManager`; не трогает transport security |

**Почему 4 потока, а не 3:** RioNexGate — отдельный REST/WebSocket трек с минимальным пересечением с kill switch / split tunnel. Censorship resistance логично слить с Traffic obfuscation (один агент по config/UX), иначе два агента будут править `link_config_builder.dart` и `profile.dart` одновременно.

**P0 dependencies (уже выполнены):**
- Auto-reconnect (`VpnService._scheduleReconnect`) — kill switch должен отличать user disconnect vs crash
- Connection states (`ConnectionDetail`, `StatusIndicator`) — UI kill switch status
- Geo fail-closed (`ConfigParser.configRequiresXrayGeoRules`) — RU routing preset (Agent C)
- CI + `security_probe.sh` — leak tests для Agents A и B

---

## Agent A — Kill Switch

**Branch:** `cursor/kill-switch-ddc7`

### Owned subsections (`tasks.md` checkboxes)

**P1 — Key differentiators → Kill Switch** (all items):
- [ ] Architecture design — separate behavior for Proxy mode (desktop) vs TUN mode (mobile)
- [ ] Strict mode — block all outbound internet when core/tunnel is down
- [ ] Adaptive mode — block only selected apps (per-app)
- [ ] Linux — iptables/nftables or NetworkManager firewall rules; remove on clean disconnect
- [ ] Android/iOS — VPNService / NEPacketTunnelProvider integration (block non-VPN traffic)
- [ ] Windows/macOS — WFP / pf or equivalent for proxy-mode fallback
- [ ] UI — Strict / Adaptive / Off toggle in Settings
- [ ] Tests — simulate core crash, verify no leak (integration test)
- [ ] Docs — kill switch limitations in proxy mode vs TUN mode

### Files / directories likely touched

| Layer | Paths |
|-------|-------|
| Dart model + service | `secure_vpn_client/lib/models/kill_switch_mode.dart` *(new)*, `lib/services/kill_switch_service.dart` *(new)*, `lib/services/vpn_service.dart` (hooks on status change / reconnect) |
| Riverpod | `lib/providers/kill_switch_provider.dart` *(new)*, `lib/providers/vpn_providers.dart` |
| UI | `lib/screens/settings_screen.dart` (Security section — Strict/Adaptive/Off) |
| Plugin API | `packages/v2ray_box/lib/v2ray_box.dart`, `lib/v2ray_box_method_channel.dart`, `lib/v2ray_box_platform_interface.dart` |
| Linux | `packages/v2ray_box/linux/kill_switch.{h,cc}` *(new)*, `linux/v2ray_box_plugin.cc`, `linux/desktop_core.cc` (core crash detection) |
| Windows | `packages/v2ray_box/windows/kill_switch.{h,cpp}` *(new)*, `windows/v2ray_box_plugin.cpp`, `windows/desktop_core.cpp` |
| macOS | `packages/v2ray_box/macos/Classes/KillSwitch.swift` *(new)*, `V2rayBoxPlugin.swift` |
| Android | `packages/v2ray_box/android/.../bg/VPNService.kt`, `BoxService.kt`, `V2rayBoxPlugin.kt` |
| iOS | `packages/v2ray_box/ios/PacketTunnel/PacketTunnelProvider.swift`, `ios/Classes/V2rayBoxPlugin.swift` |
| Tests | `secure_vpn_client/test/kill_switch_*_test.dart` *(new)*, `integration_test/kill_switch_leak_test.dart` *(new)* |
| Docs | `docs/en/kill_switch.md`, `docs/ru/kill_switch.md` *(new)* |
| CI | `.github/workflows/ci.yml` (optional kill-switch integration job) |

### Dependencies on other agents

| Dependency | Agent | Blocking? |
|------------|-------|-----------|
| Adaptive mode per-app list | **B** | **Yes** — Adaptive merges only after B exposes unified `SplitTunnelSettings` (include/exclude packages) |
| Reconnect vs kill semantics | P0 (done) | No — use `_userInitiatedDisconnect` + `ConnectionDetail` |
| RU routing / obfuscation | C | No |

### Suggested implementation order (within agent)

1. **Architecture doc** in branch (`docs/en/kill_switch.md` draft) — Proxy vs TUN matrix per platform
2. Dart model `KillSwitchMode { off, strict, adaptive }` + persisted preference (SharedPreferences)
3. Plugin method channel: `enableKillSwitch(mode)`, `disableKillSwitch()`, `getKillSwitchStatus`
4. **Mobile TUN first** (Android `VPNService` + iOS `PacketTunnelProvider`) — Strict mode
5. **Desktop proxy fallback** (Linux iptables/nft → Windows WFP → macOS pf) — document limitations
6. Wire into `VpnService`: on unexpected `VpnStatus.stopped` / core stderr death → engage kill switch; on user disconnect → disengage + cleanup rules
7. UI toggle in Settings → Security section
8. **Adaptive mode** — integrate with Agent B's split-tunnel package list (rebase after B merges)
9. Integration test: kill core subprocess, assert no outbound leak (Linux CI job)
10. RU/EN docs finalization

### Security constraints (must not break)

- Kill switch rules must **not** expose unauthenticated SOCKS/HTTP on `127.0.0.1`
- Firewall rules removed on **clean disconnect** and app exit
- Adaptive mode must not bypass secure inbound auth (no open proxy while "blocking")
- Never log credentials; kill switch state is non-secret
- Desktop proxy mode: document that kill switch is **best-effort** (non-browser apps may bypass system proxy)

### Definition of done

- [ ] Strict mode blocks outbound traffic on Android/iOS TUN when core crashes (manual or integration test)
- [ ] Desktop Strict mode documented + implemented where OS APIs allow (Linux minimum for CI)
- [ ] Adaptive mode uses per-app list from Agent B
- [ ] Settings UI: Off / Strict / Adaptive with platform-specific disclaimer
- [ ] Rules cleaned up on disconnect; no orphan iptables/WFP rules after stop
- [ ] `flutter analyze` + `flutter test` pass; optional CI leak probe green
- [ ] `docs/en/kill_switch.md` + `docs/ru/kill_switch.md` describe proxy vs TUN limits

---

## Agent B — Split Tunneling

**Branch:** `cursor/split-tunneling-ddc7`

### Owned subsections (`tasks.md` checkboxes)

**P1 — Key differentiators → Split Tunneling** (all items):
- [ ] Model design — whitelist (only these via VPN) vs blacklist (all except these)
- [ ] Android — per-app via `VpnService.Builder.addAllowedApplication` / `addDisallowedApplication`
- [ ] iOS — document NE limitations; per-app split tunneling is limited on iOS
- [ ] Desktop proxy mode — document that split tunneling is OS/app-level, not TUN
- [ ] Linux TUN (if added) — policy routing / cgroup + no bypass via localhost scan
- [ ] UI — installed app list with toggles (mobile) or desktop warning
- [ ] Security — no bypass via unauthenticated localhost; leak test with split tunnel enabled
- [ ] Tests — unit + platform smoke for whitelist/blacklist

**Coordination note (not owned, but interface for C):** Agent C owns *censorship §4 — RU direct routing preset* (geo routing rules). Agent B owns **per-app** split only. Agree on naming: per-app = "Split Tunneling", geo preset = "RU sites direct" (Agent C).

### Files / directories likely touched

| Layer | Paths |
|-------|-------|
| Dart model | `lib/models/split_tunnel_settings.dart` *(new)* — unify whitelist/blacklist |
| Provider | `lib/providers/per_app_proxy_provider.dart` (extend: include mode, rename to `split_tunnel_provider.dart` or alias) |
| UI | `lib/screens/per_app_proxy_screen.dart` (include/exclude toggle, whitelist UI), `lib/screens/settings_screen.dart` (Split Tunneling section) |
| Plugin (existing API) | `packages/v2ray_box/lib/src/models/vpn_status.dart` (`PerAppProxyMode`), `v2ray_box_method_channel.dart` |
| Android native | `android/.../bg/VPNService.kt`, `BoxService.kt`, `Settings.kt`, `constant/PerAppProxyMode.kt` |
| iOS | `ios/PacketTunnel/PacketTunnelProvider.swift` (if NE per-app ever supported — likely docs only) |
| Tests | `secure_vpn_client/test/per_app_proxy_provider_test.dart`, `test/split_tunnel_settings_test.dart` *(new)* |
| Security | `scripts/security_probe.sh` (split-tunnel variant), `secure_vpn_client/test/security_test.dart` |
| Docs | `docs/en/split_tunneling.md`, `docs/ru/split_tunneling.md`, `docs/en/mobile_vpn_config.md` (iOS limits) |

### Dependencies on other agents

| Dependency | Agent | Blocking? |
|------------|-------|-----------|
| P0 platform plumbing | done | No |
| Kill switch Adaptive | **A** | No (A waits on B, not vice versa) |
| RU geo routing preset | **C** | No — separate feature |

### Suggested implementation order (within agent)

1. Model: `SplitTunnelMode { off, include, exclude }` mapping to `PerAppProxyMode`
2. Extend `PerAppProxyNotifier` — expose include list + mode picker
3. Android: verify `VPNService.kt` / `BoxService.kt` apply both `addAllowedApplication` and `addDisallowedApplication`
4. UI: mode selector (whitelist / blacklist / off) + app list (reuse `PerAppProxyScreen`)
5. Settings: desktop warning banner when not Android VPN
6. iOS + desktop docs (limitations)
7. Security test: split tunnel enabled → `security_probe.sh` still requires SOCKS auth
8. Unit tests for include/exclude state machine

### Security constraints (must not break)

- Split tunnel must **not** route traffic through unauthenticated `127.0.0.1:7890` or any open port
- `ConfigParser.injectSecureSocksInbound` unchanged — auth always required
- No bypass via localhost port scan while VPN up
- Excluded apps on Android must not reach remote via leaked DNS

### Definition of done

- [ ] Whitelist (include) and blacklist (exclude) modes work on Android
- [ ] UI shows mode + app list; reconnect hint after change
- [ ] iOS + desktop limitations documented (RU/EN)
- [ ] Security probe passes with split tunnel enabled
- [ ] Unit tests for model/provider; `flutter test` green

---

## Agent C — Censorship Resistance & Obfuscation UX

**Branch:** `cursor/censorship-obfuscation-ddc7`

### Owned subsections (`tasks.md` checkboxes)

**P1 — Traffic obfuscation (DPI bypass UX)** (all items):
- [ ] Transport presets — WebSocket+TLS, gRPC, HTTPUpgrade, REALITY (xray), uTLS fingerprint
- [ ] UI wizard — "censorship mode" when importing or editing a profile
- [ ] Auto-detect — suggest transport from subscription metadata when available
- [ ] Docs — when to use Trojan/VLESS+REALITY vs plain TLS
- [ ] Tests — validate generated xray/sing-box JSON (no real DPI test needed)

**P1 — censorship resistance (RKN/TSPU)** (all items):
- §1 XHTTP transport (6 checkboxes)
- §2 mux (5 checkboxes)
- §3 uTLS / TLS fingerprint (6 checkboxes)
- §4 Smart routing — RU direct preset (7 checkboxes)
- §5 Protocol & server auto-fallback (6 checkboxes)
- §6 Platform & engine notes (4 checkboxes)
- §7 Testing & docs (4 checkboxes)

### Files / directories likely touched

| Layer | Paths |
|-------|-------|
| Config builders | `lib/utils/link_config_builder.dart`, `lib/utils/config_parser.dart`, `lib/utils/ping_config_builder.dart` |
| Profile model | `lib/models/profile.dart` (mux, fingerprint, censorship preset flags), `lib/models/transport_preset.dart` *(new)* |
| Engine / subscription | `lib/utils/engine_auto_selector.dart`, `lib/utils/subscription_latency_probe.dart`, `lib/models/subscription_server.dart` |
| Services | `lib/services/vpn_service.dart` (fallback chain on connect — **coordinate with A**: only extend reconnect path, do not add kill-switch logic) |
| UI | `lib/screens/config_screen.dart`, `lib/screens/settings_screen.dart` (Advanced → Routing: RU preset), new `lib/screens/censorship_wizard_screen.dart` *(new)*, `lib/widgets/transport_stack_chip.dart` *(new)* |
| Providers | `lib/providers/vpn_providers.dart`, `lib/providers/profile_advanced_provider.dart` *(new)* |
| Tests | `test/link_config_builder_test.dart`, `test/config_parser_test.dart`, `test/ping_config_builder_test.dart`, `test/censorship_*_test.dart` *(new)*, fixtures in `test/fixtures/` |
| Docs | `docs/en/censorship_resistance.md`, `docs/ru/censorship_resistance.md`, updates to `docs/README.md` |
| Scripts | `scripts/fetch_cores.sh` (version pin reference for XHTTP gate) |

### Dependencies on other agents

| Dependency | Agent | Blocking? |
|------------|-------|-----------|
| Geo fail-closed (P0) | done | No — reuse `configRequiresXrayGeoRules` |
| Per-app split tunnel | **B** | No — RU preset is routing rules, not per-app |
| Kill switch | **A** | No |
| Reconnect backoff (P0) | done | No — extend for transport fallback |

### Suggested implementation order (within agent)

Follow censorship roadmap phases from `tasks.md`:

1. **Phase 1 — XHTTP:** `LinkConfigBuilder` parse `type=xhttp`, default `mode: stream-one`; `ConfigParser` preserve fields; tests
2. **Phase 2 — Fingerprint + mux:** Profile settings, stop defaulting `fp` to `chrome`; mux toggle; `ping_config_builder` consistency
3. **Phase 3 — RU direct preset:** routing rules `geosite:ru` / `geoip:ru`; UI toggle; geo asset guard
4. **Phase 4 — Auto-fallback:** extend server picker / connect to try XHTTP → mux → Vision → AmneziaWG; iOS transport selection
5. **Obfuscation UX:** transport presets + censorship wizard on profile import/edit
6. **Docs + fixtures:** all recommended stacks; troubleshooting "Wi‑Fi vs mobile operator"

### Security constraints (must not break)

- **No** [fwflunky/REALITY-rkn-fix](https://github.com/fwflunky/REALITY-rkn-fix) fork — official Xray-core only
- `injectSecureSocksInbound` unchanged; RU direct rules must not expose unauth localhost
- Never log transport secrets or panel tokens
- `mode: auto` for XHTTP → warn or coerce to `stream-one`
- AmneziaWG: evaluate only; do not ship unmaintained cores

### Definition of done

- [ ] XHTTP links round-trip with `stream-one` default
- [ ] TLS fingerprint picker + non-chrome defaults in generated JSON (xray + sing-box)
- [ ] Mux toggle applies only when enabled
- [ ] RU direct preset merges with subscription routing; fails closed without geo assets
- [ ] Connect fallback tries ordered stacks; shows active transport in UI
- [ ] Censorship wizard + transport presets on profile import
- [ ] Fixture tests for all stacks; `flutter test` green
- [ ] `docs/en/` + `docs/ru/` censorship guides

---

## Agent D — RioNexGate Panel Integration *(optional)*

**Branch:** `cursor/rionexgate-panel-ddc7`

### Owned subsections (`tasks.md` checkboxes)

**P1 — RioNexGate panel integration** (all items in §2.1–2.7, §3, roadmap phases 1–4):
- §2.1 `PanelManager` module (6 checkboxes)
- §2.2 Registration & config sync (6 checkboxes)
- §2.3 Stats upload (5 checkboxes)
- §2.4 Remote commands (4 checkboxes)
- §2.5 SOCKS5 auth & panel configs (5 checkboxes)
- §2.6 Errors & fallback (4 checkboxes)
- §2.7 Third-party compatibility (4 checkboxes)
- §3 Client testing & observability (6 checkboxes)

### Files / directories likely touched

| Layer | Paths |
|-------|-------|
| New module | `lib/services/panel/panel_manager.dart`, `panel_api_client.dart`, `panel_stats_queue.dart`, `panel_sync_status.dart` *(all new)* |
| Models | `lib/models/panel_config.dart`, `panel_credentials.dart` *(new — device token only, not SOCKS)* |
| Providers | `lib/providers/panel_provider.dart` *(new)* |
| UI | `lib/screens/settings_screen.dart` (Panel section — **coordinate**: add new `_SectionCard`, do not refactor existing sections), `lib/screens/panel_setup_screen.dart` *(new)* |
| Integration | `lib/services/vpn_service.dart` (thin hooks: stats flush, `refresh_config` command — **minimal diffs**) |
| Config | `lib/utils/config_parser.dart` (panel JSON → Profile pipeline only) |
| Storage | secure storage for `device_token`; SharedPreferences for cache path |
| Tests | `test/panel_manager_test.dart`, `test/panel_stats_queue_test.dart`, mock HTTP |
| Docs | `docs/en/rionexgate_pairing.md`, `docs/ru/rionexgate_pairing.md` |

### Dependencies on other agents

| Dependency | Agent | Blocking? |
|------------|-------|-----------|
| Core connect pipeline | P0 (done) | No |
| Censorship / kill switch / split | A, B, C | No — panel is additive |
| `CredentialService` | existing | No — SOCKS mode toggle must respect golden rules |

### Suggested implementation order (within agent)

1. Phase 1: `PanelManager` skeleton, register, config fetch, `config_hash`, local cache
2. Phase 2: Stats collector + offline queue + `session_id`
3. Phase 3: WebSocket / long-poll commands
4. Phase 4: SOCKS mode toggle (random vs static from panel), integration tests, docs
5. Settings UI for panel URL + pairing

### Security constraints (must not break)

- Device token ≠ transport auth; never send SOCKS passwords in stats
- Panel optional — all code paths no-op when unconfigured
- Cached config on disk: no credentials in cached JSON
- `127.0.0.1` + auth required even for static panel SOCKS
- Never log `device_token` in release builds

### Definition of done

- [ ] Panel unconfigured → zero behavior change
- [ ] Register + sync + cache + hash diff
- [ ] Stats queue with offline replay
- [ ] Remote commands via WS or long-poll
- [ ] Malformed JSON does not crash; keeps previous profile
- [ ] Dart integration tests with mock server
- [ ] RU/EN pairing docs

---

## Parallelization matrix

| Workstream | Can start day 1? | Parallel with | Must wait for |
|------------|------------------|---------------|---------------|
| **A** Kill Switch | Partial (architecture, Strict mobile, desktop) | C, D | **B** for Adaptive mode only |
| **B** Split Tunneling | Yes | A, C, D | — |
| **C** Censorship / Obfuscation | Yes | A, B, D | — |
| **D** RioNexGate | Yes | A, B, C | — |

**Sequential couplings:**
- A *Adaptive* ← B (per-app list API)
- A *integration tests* ← B (split tunnel security baseline)
- Settings UI: A and B both add rows to `settings_screen.dart` — use separate `_SectionCard`s, merge B before A or assign one agent to integrate Settings layout last

**Highly parallel (safe):**
- C + D (zero file overlap)
- B + C (minimal overlap: `profile.dart` — see Risks)
- A native Linux + B Android (different paths)

---

## Merge order recommendation (into `main`)

```
1. cursor/censorship-obfuscation-ddc7   (Agent C)  — config foundation, few native changes
2. cursor/split-tunneling-ddc7          (Agent B)  — per-app API for Adaptive kill switch
3. cursor/kill-switch-ddc7              (Agent A)  — depends on B for Adaptive
4. cursor/rionexgate-panel-ddc7         (Agent D)  — optional; independent; merge last or anytime after P0
```

If **D** is deprioritized, skip entirely — A/B/C deliver external-feedback P1 core.

**Rebase rule:** Each agent rebases onto latest `main` before opening PR; second PR rebases after prior merge.

---

## Risks & conflict avoidance

### High-risk shared files

| File | Agents | Mitigation |
|------|--------|------------|
| `lib/services/vpn_service.dart` | A, C, D | **Ownership split:** A = status/crash hooks; C = transport fallback in `connect()`; D = stats flush only. Use separate private methods; merge C first, then A, then D. |
| `lib/screens/settings_screen.dart` | A, B, C, D | Each agent adds **one** `_SectionCard` with unique key; no refactors. Integrator resolves order: Appearance → Engine → Split Tunnel (B) → Kill Switch (A) → Advanced/Censorship (C) → Panel (D). |
| `lib/models/profile.dart` | B, C | B: optional `splitTunnelPackageIds`; C: `muxEnabled`, `tlsFingerprint`, `censorshipPreset`. Add fields in **separate commits**; C merges first. |
| `lib/utils/config_parser.dart` | C, D | C owns transport/routing; D only adds `applyPanelConfig()` entry point at end of file. |
| `packages/v2ray_box/android/.../VPNService.kt` | A, B | A = kill switch blocking; B = per-app builders. **Same file** — merge B before A, or split into helper classes (`KillSwitchHelper.kt`, `SplitTunnelBuilder.kt`). |
| `packages/v2ray_box/lib/v2ray_box_method_channel.dart` | A, B | Add methods in non-overlapping regions; run `flutter test` in `packages/v2ray_box/`. |

### Process rules

1. **No drive-by refactors** in shared files
2. **New code in new files** where possible (`kill_switch_service.dart`, `panel/panel_manager.dart`)
3. **Feature flags** optional for incomplete platform kill switch (compile-time `kKillSwitchDesktopSupported`)
4. Run `flutter analyze` + `flutter test` before each PR
5. Agent changing native plugin → note in PR body: "requires full restart, not hot reload"

### Testing ownership

| Test type | Owner |
|-----------|-------|
| `security_test.dart`, `security_probe.sh` | B (split tunnel), A (kill switch leak) — coordinate PR timing |
| `link_config_builder_test.dart`, `config_parser_test.dart` | C |
| `panel_*_test.dart` | D |

---

## Launch checklist for parent agent

| # | Action |
|---|--------|
| 1 | Merge or cherry-pick P0 branch if not yet on `main` |
| 2 | Launch **B**, **C**, **D** in parallel |
| 3 | Launch **A** in parallel for Strict mode + architecture; pause Adaptive until B merges |
| 4 | Enforce merge order C → B → A → D |
| 5 | After all merges, run full Linux connect matrix (4 engine×profile combos) + `security_probe.sh` |

---

*Generated: 2026-09-02 — coordinates P1 workstreams for RioNexTunnel external-feedback focus.*
