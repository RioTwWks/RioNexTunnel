# RioNexTunnel v0.7.0 — Release Notes

**Date:** 2026-09-04  
English · [Русская версия](../ru/release_notes_v0.7.0.md)

---

## Highlights

- **Censorship resistance (P1)** — XHTTP subscription JSON preservation, protocol auto-fallback across transport stacks, platform-aware server ranking, and fair latency probes.
- **XHTTP transport** — full JSON subscriptions keep `path`, `host`, and other XHTTP fields; `mode: auto` coerced to `stream-one` on connect ([#69](https://github.com/RioTwWks/RioNexTunnel/pull/69)).
- **Protocol auto-fallback** — ordered stack probe (XHTTP+Reality → TLS+mux → TCP+Vision → AmneziaWG), reconnect rotation, and per-stack success stats ([#68](https://github.com/RioTwWks/RioNexTunnel/pull/68)).
- **Platform & engine** — iOS deprioritizes XHTTP in auto-pick; `CoreVersionGate` warns when bundled Xray is older than the `fetch_cores.sh` pin; official Xray-only policy ([#67](https://github.com/RioTwWks/RioNexTunnel/pull/67)).
- **Mux & desktop proxy** — bilingual docs for when mux helps; `PingConfigBuilder` strips mux so latency probes measure base transport RTT ([#66](https://github.com/RioTwWks/RioNexTunnel/pull/66)).

Builds on **v0.6.0** RioNexGate panel work (remote commands, resilient config sync, SOCKS auth modes).

---

## Censorship resistance

### XHTTP transport (PR #69)

Providers increasingly ship **VLESS + REALITY + XHTTP** nodes as full JSON (v2rayNG array or single-object configs) instead of share links. `ConfigParser.injectSecureSocksInbound` now normalizes XHTTP for both engines on connect:

| Engine | Transport location | Mode field |
|--------|-------------------|------------|
| Xray | `outbounds[].streamSettings.network: "xhttp"` + `xhttpSettings` | `xhttpSettings.mode` |
| sing-box | `outbounds[].transport.type: "xhttp"` | `transport.mode` |

- **`path`, `host`, and other XHTTP keys** from the subscription are preserved — not rebuilt from defaults.
- Missing or **`mode: auto`** is coerced to **`stream-one`** (same default as `vless://` links via `LinkConfigBuilder`).
- `configHasXhttpAutoMode()` detects subscriptions that still advertise `auto` before normalization (useful for diagnostics).

### Mux fallback & desktop proxy (PR #66)

**Mux** (multiplexing) remains a profile-level option in the censorship wizard — useful on mobile-operator networks with **VLESS + TLS**, but usually unnecessary on desktop when XHTTP is available.

- New **Desktop proxy mode and mux** section in [censorship_resistance.md](censorship_resistance.md).
- **`PingConfigBuilder`** strips `mux` / `multiplex` from temporary probe configs so subscription server picker and **Automatic (best latency)** compare base transport RTT fairly.
- Profile mux settings still apply on **Connect** via `ConfigEnhancer`.

### Protocol auto-fallback (PR #68)

When a subscription lists multiple transport variants for the same host (e.g. `cdn.example.com` with separate XHTTP and Vision nodes), RioNexTunnel groups them into **logical servers** and tries stacks in order on connect failure.

**`TransportStackClassifier`** tags each entry:

| Stack | Tag | Default probe priority |
|-------|-----|------------------------|
| VLESS + REALITY + XHTTP | `XHTTP` | 0 (first) |
| VLESS + TLS + mux | `TLS+mux` | 1 |
| TCP + REALITY + Vision | `Vision` | 2 |
| AmneziaWG / WireGuard | `AmneziaWG` | 3 |

**`SubscriptionManager`** groups subscription rows by host (`serverKey`) or normalized name, deduplicates stacks, and orders candidates using persisted stats when available.

**`VpnService` connect flow:**

1. Resolve ordered probe list for the selected server.
2. Try each stack; on failure, log and continue with exponential backoff between attempts.
3. On **reconnect** after a drop, advance to the **next stack** in the rotation.
4. Record success/failure and latency in **`TransportStackStore`** (`SharedPreferences`, key `transport_stack_stats_v1`).

**Server picker** shows logical entries with stack tags, e.g. `My Node (XHTTP · Vision)`.

### Platform & engine (PR #67)

**`PlatformTransportSelector`** adjusts **Automatic (best latency)** ranking:

| Platform | Preferred stack when multiple are reachable |
|----------|---------------------------------------------|
| iOS | TCP + REALITY + Vision |
| Android / desktop | XHTTP + REALITY |

On iOS, XHTTP+REALITY entries receive the lowest priority (100) when Vision-capable nodes exist in the same probe set. This is **server ranking only** — not the connect-time fallback chain.

**`CoreVersionGate`** compares the bundled Xray version against `DEFAULT_XRAY_VERSION` in `scripts/fetch_cores.sh` (currently **26.3.27**):

- Non-blocking warning at connect when using XHTTP with an older core.
- **Settings → Core engine** shows a reminder to run `./scripts/fetch_cores.sh`.

**Official Xray-core only** — RioNexTunnel does not vendor custom Xray builds (e.g. REALITY-rkn-fix). Mitigations are transport choice, uTLS fingerprints, and server-side configuration.

---

## Testing & reliability

From `secure_vpn_client/`:

```bash
flutter analyze
flutter test test/config_parser_test.dart
flutter test test/ping_config_builder_test.dart
flutter test test/censorship_transport_test.dart
flutter test test/subscription_manager_test.dart
flutter test test/protocol_fallback_test.dart
flutter test test/platform_transport_selector_test.dart
flutter test test/core_version_gate_test.dart
```

| Test file | Coverage |
|-----------|----------|
| `config_parser_test.dart` | XHTTP field preservation, `mode: auto` → `stream-one`, Xray + sing-box JSON |
| `ping_config_builder_test.dart` | Mux stripping in latency probe configs |
| `censorship_transport_test.dart` | Transport preset detection and link enhancement |
| `subscription_manager_test.dart` | Server grouping, stack dedup, stats-based ordering |
| `protocol_fallback_test.dart` | Mock connect failure → fallback to second stack |
| `platform_transport_selector_test.dart` | iOS vs non-iOS stack priority in `selectBest` |
| `core_version_gate_test.dart` | Semver compare against `fetch_cores.sh` pin |

Existing panel tests from v0.6.0 (`panel_*_test.dart`) and `security_test.dart` remain unchanged.

---

## Security

Core invariants are **unchanged** in v0.7.0:

| Principle | Implementation |
|-----------|----------------|
| Localhost only | SOCKS/HTTP listen on `127.0.0.1` — never `0.0.0.0` |
| Mandatory auth | Password auth on every local proxy listener |
| No open port 7890 | Unauthenticated SOCKS rejected in `ConfigParser.validateSecure()` |
| Credential lifecycle | Session SOCKS creds wiped on disconnect; `active_config.json` removed |
| No credential logging | Passwords, transport secrets, and panel tokens never logged |

**Censorship-specific:**

- Transport stack stats store **success rates and latency only** — no outbound secrets.
- Official **Xray-core** binaries from `scripts/fetch_cores.sh`; no patched cores with hidden listeners.
- RU direct routing still requires geo assets and fails closed when missing.

Verify after connect:

```bash
./scripts/security_probe.sh 1080
```

See [security.md](security.md).

---

## Upgrade notes

**No breaking changes expected.** Builds on v0.6.0 without altering RioNexGate panel behavior.

1. **Existing users** — subscriptions and share links work as before; XHTTP JSON nodes now connect correctly with preserved server fields.
2. **XHTTP users** — run `./scripts/fetch_cores.sh` from the repo root if Settings shows a core version warning, then rebuild.
3. **Multi-stack subscriptions** — enable **Automatic (best latency)** or pick a logical server entry; connect failures automatically try alternate stacks.
4. **Desktop** — mux is optional; prefer XHTTP when your provider offers it. See [censorship_resistance.md](censorship_resistance.md).
5. **iOS** — if XHTTP+REALITY fails, pick a Vision node manually or rely on auto-pick deprioritization when both exist.

---

## Known limitations

- **iOS XHTTP gap** — XHTTP+REALITY is deprioritized in auto-pick and may be unreliable on iOS Network Extensions; prefer TCP+REALITY+Vision when available. If only XHTTP nodes exist, iOS still connects to the best reachable XHTTP entry.
- **Fallback vs auto-pick ordering** — connect-time fallback (`TransportStackClassifier` default: XHTTP first) and iOS auto-pick (`PlatformTransportSelector`: Vision first) use **separate code paths**. A future merge will unify stack ordering so reconnect fallback respects platform preferences.
- **AmneziaWG** — classified and included in fallback order when present, but full AmneziaWG client support remains on the roadmap (tasks §5).
- **Platform & engine docs** — the detailed **Platform & engine policy** section from PR #67 may be consolidated into [censorship_resistance.md](censorship_resistance.md) in a follow-up doc PR.

---

## Related documentation

| Topic | English | Русский |
|-------|---------|---------|
| Censorship resistance | [censorship_resistance.md](censorship_resistance.md) | [censorship_resistance.md](../ru/censorship_resistance.md) |
| Security | [security.md](security.md) | [security.md](../ru/security.md) |
| Linux desktop / proxy mode | [linux_setup.md](linux_setup.md) | [linux_setup.md](../ru/linux_setup.md) |
| Troubleshooting | [troubleshooting.md](troubleshooting.md) | [troubleshooting.md](../ru/troubleshooting.md) |
| Release notes v0.6.0 | [release_notes_v0.6.0.md](release_notes_v0.6.0.md) | [release_notes_v0.6.0.md](../ru/release_notes_v0.6.0.md) |

### Pull requests in this release

- [#69](https://github.com/RioTwWks/RioNexTunnel/pull/69) — XHTTP transport: ConfigParser preserves subscription JSON fields
- [#68](https://github.com/RioTwWks/RioNexTunnel/pull/68) — Protocol auto-fallback with stack probe and persistence
- [#67](https://github.com/RioTwWks/RioNexTunnel/pull/67) — Platform transport selector and Xray version gate
- [#66](https://github.com/RioTwWks/RioNexTunnel/pull/66) — Mux fallback docs and fair latency probes
