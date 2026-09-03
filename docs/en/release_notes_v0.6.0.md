# RioNexTunnel v0.6.0 — Release Notes

**Date:** 2026-09-03  
English · [Русская версия](../ru/release_notes_v0.6.0.md)

---

## Highlights

- **RioNexGate panel integration (Phase 2–4)** — remote commands, resilient config sync, SOCKS auth modes, and automated test coverage on top of the v0.5.0 MVP.
- **Remote commands** — WebSocket listener with long-poll fallback for `refresh_config`, `disconnect`, and `switch_server` ([#61](https://github.com/RioTwWks/RioNexTunnel/pull/61)).
- **Resilient config sync** — malformed panel JSON no longer crashes the client; offline stale cache and stats queue replay ([#62](https://github.com/RioTwWks/RioNexTunnel/pull/62)).
- **SOCKS5 auth modes** — random per session (default), static from panel JSON, or disable injection for advanced manual configs ([#63](https://github.com/RioTwWks/RioNexTunnel/pull/63)).
- **Panel testing docs** — bilingual guide for CI unit/integration tests and optional live-panel smoke ([rionexgate_testing.md](rionexgate_testing.md)).

---

## RioNexGate panel integration

RioNexTunnel remains a universal VPN client. Panel pairing is **opt-in** — if you never configure RioNexGate, behavior is unchanged from v0.5.x.

This release completes the client-side track outlined in tasks §2.1–2.5 (building on the v0.5.0 MVP from PR [#51](https://github.com/RioTwWks/RioNexTunnel/pull/51)).

### Registration and config sync

- **Settings → RioNexGate (optional)** — panel URL, pairing token, **Register device**, manual **Refresh**, and **Clear pairing**.
- **`PanelManager`** REST client — `POST /api/client/register`, `GET /api/client/config`, `POST /api/client/stats` with `X-API-Version: v1`, timeouts, and exponential backoff (up to 4 retries).
- **`config_hash` diff** — skip cache rewrite when unchanged; apply subscription URL to a **RioNexGate** profile via the standard `ConfigParser` pipeline.
- **Offline cache** — last good config kept on disk; status card shows **Synced**, **Cached (stale)**, **Offline**, or **Error** (`PanelSyncStatus`).
- **Malformed JSON** — invalid `config` from the panel is logged, previous cache and hash are preserved, and a non-blocking warning is shown (no crash).

### Stats upload

- Bytes in/out collected from core counters on **disconnect** and uploaded with a per-session `session_id`.
- **Local queue** when the panel is unreachable; **batch replay** via `flushStats()` when connectivity returns.
- Stats payload never includes SOCKS passwords or transport secrets.

### Remote commands (push)

- **`PanelCommandService`** — prefers WebSocket at `wss://<panel>/api/client/commands` with `Authorization: Bearer <device_token>`.
- **Handled commands:** `refresh_config`, `disconnect`, `switch_server` (with optional `server_index` / `server_name`).
- **Fallback** — long poll `GET /api/client/commands?last_seq=...` every ~5 minutes when WebSocket is unavailable; reconnect delay ~30 s.
- Commands delegate to existing `VpnService` / profile refresh paths — no duplicate connect logic.
- Sequence numbers persisted locally to avoid replaying handled commands.

### SOCKS5 auth modes

New setting: **Settings → SOCKS5 authentication**

| Mode | Behavior |
|------|----------|
| **Random per session** (default) | New username/password on every connect via `CredentialService` + `injectSecureSocksInbound`. |
| **Static from panel** | Use SOCKS user/pass from RioNexGate panel JSON when present; falls back to random if panel is not configured or JSON lacks SOCKS. |
| **Disable SOCKS injection (advanced)** | Skip secure inbound injection for broken third-party configs (Config screen option for manual imports). |

When the panel supplies SOCKS parameters, port alignment is applied before connect. The golden rule is unchanged: **`127.0.0.1` only, password auth always required**.

---

## Testing and reliability

### Automated tests (CI)

From `secure_vpn_client/`:

```bash
flutter analyze
flutter test test/panel_manager_test.dart
flutter test test/panel_integration_test.dart
flutter test test/panel_command_service_test.dart
```

| Test file | Coverage |
|-----------|----------|
| `panel_manager_test.dart` | Register, `config_hash` skip/update, stats queue flush |
| `panel_integration_test.dart` | Full lifecycle with `FakePanelServer`; offline cache; malformed JSON; Riverpod `refreshConfig` |
| `panel_command_service_test.dart` | Command parsing, seq ordering, WebSocket/long-poll dispatch |

See [rionexgate_testing.md](rionexgate_testing.md) for fixtures and optional live-panel steps.

### Reliability improvements (PR #62)

- Panel offline → cached config retained; stats queued and replayed when online.
- Bad panel JSON → no throw; previous profile stays active.
- New `config_hash` from panel → cache and **RioNexGate** profile URL refresh without app restart.

---

## Security

Core invariants are **unchanged** in v0.6.0:

| Principle | Implementation |
|-----------|----------------|
| Localhost only | SOCKS/HTTP listen on `127.0.0.1` — never `0.0.0.0` |
| Mandatory auth | Password auth on every local proxy listener |
| No open port 7890 | Unauthenticated SOCKS rejected in `ConfigParser.validateSecure()` |
| Credential lifecycle | Session SOCKS creds wiped on disconnect; `active_config.json` removed |
| No credential logging | Passwords and `device_token` never logged in release builds |

**Panel-specific separation:**

- **Device token** — used only for RioNexGate REST/WebSocket API (`Authorization: Bearer …`). Stored locally with panel URL and subscription URL; not mixed with VPN transport auth.
- **Transport auth** — VLESS/VMess/Trojan/etc. credentials from subscription or share links, unchanged.
- **SOCKS auth** — still required on localhost; static-from-panel mode uses panel-supplied password but keeps `127.0.0.1` binding.

Verify after connect:

```bash
./scripts/security_probe.sh 1080
```

See [security.md](security.md).

---

## Upgrade notes

**No breaking changes expected.** RioNexGate is optional.

1. **Existing users** — no action required; manual links and third-party subscriptions work as before.
2. **Panel users** — update to v0.6.0 to gain remote commands and SOCKS mode settings. Re-register only if your panel admin rotates pairing tokens.
3. **SOCKS mode** — default remains **Random per session** (recommended). Choose **Static from panel** only when RioNexGate JSON includes matching SOCKS inbound credentials.
4. **Desktop** — run `./scripts/fetch_cores.sh` before connect if geo rules or censorship presets are used (unchanged from v0.5.x).

---

## Known limitations

- **Background stats flush (~60 s)** — not implemented; stats upload runs on **disconnect** and when the queue is flushed after reconnect (tasks §2.3).
- **Periodic config sync** — manual **Refresh** only; scheduled background sync is not yet wired.
- **Full JSON config apply** — panel `config` JSON is validated and cached; primary apply path is still **subscription URL → Profile** (full raw JSON injection pending).
- **Server JSON schema** — client assumes RioNexGate v1 API shapes; unexpected fields are ignored, but malformed structures may skip an update (cache preserved).
- **Panel docs** — removing panel pairing does not delete manually imported profiles (documentation backlog in tasks §2.7).

---

## Related documentation

| Topic | English | Русский |
|-------|---------|---------|
| Panel testing | [rionexgate_testing.md](rionexgate_testing.md) | [rionexgate_testing.md](../ru/rionexgate_testing.md) |
| Security | [security.md](security.md) | [security.md](../ru/security.md) |
| Architecture | [architecture.md](architecture.md) | [architecture.md](../ru/architecture.md) |
| Troubleshooting | [troubleshooting.md](troubleshooting.md) | [troubleshooting.md](../ru/troubleshooting.md) |
| RioNexGate server | [github.com/RioTwWks/RioNexGate](https://github.com/RioTwWks/RioNexGate) | same |

### Pull requests in this release

- [#61](https://github.com/RioTwWks/RioNexTunnel/pull/61) — Remote commands (WebSocket + long-poll)
- [#62](https://github.com/RioTwWks/RioNexTunnel/pull/62) — Integration tests and resilient config sync
- [#63](https://github.com/RioTwWks/RioNexTunnel/pull/63) — SOCKS5 auth modes (random / static / disable injection)
