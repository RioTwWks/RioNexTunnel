# RioNexGate panel — client testing

English · [Русская версия](../ru/rionexgate_testing.md)

This document describes how RioNexTunnel tests optional RioNexGate panel integration. **CI does not require a live panel** — Dart tests use a mock HTTP panel server.

## Automated tests (CI)

From `secure_vpn_client/`:

```bash
flutter analyze
flutter test test/panel_manager_test.dart
flutter test test/panel_integration_test.dart
```

### Unit tests (`test/panel_manager_test.dart`)

- Panel disabled → no-op
- Register stores `device_token` and `subscription_url`
- `config_hash` unchanged → skip cache rewrite
- `config_hash` changed → cache update
- Stats queue flush uploads batched entries

### Integration tests (`test/panel_integration_test.dart`)

Full client-side lifecycle with `FakePanelServer` (`http.MockClient`):

| Scenario | Coverage |
|----------|----------|
| Register → config sync → connect stats → disconnect stats → flush | End-to-end panel API flow |
| New `config_hash` from panel | Cache and settings refresh without app restart |
| Panel offline | Cached config kept; stats queued and replayed when online |
| Malformed `config` JSON | No throw; previous cache and `config_hash` preserved |
| Riverpod `refreshConfig` | `RioNexGate` profile subscription URL updated |

Fixtures use synthetic URLs (`https://panel.test`) and tokens — never commit real panel credentials.

## Optional: device integration test

`integration_test/vpn_flow_test.dart` covers general UI smoke. A **live RioNexGate** scenario is optional and not run in CI.

To exercise against a local panel:

1. Run RioNexGate (Docker or dev instance) on your machine.
2. Create a pairing token in the panel admin UI.
3. Set environment variables when running the app (do not commit values):

```bash
# Example — adjust host/port to your instance
export RIONEXGATE_PANEL_URL=http://127.0.0.1:8080
export RIONEXGATE_PAIRING_TOKEN=your-one-time-token
flutter run -d linux
```

4. In **Settings → RioNexGate**, enter the panel URL and pairing token, then **Register**.

Verify: status shows **Synced**, a **RioNexGate** profile appears, connect/disconnect updates panel stats (check panel dashboard).

## Observability

- Panel sync lifecycle logs use **device id hash** (first 8 chars of a local UUID) — never `device_token` in release builds.
- User-visible status: `PanelSyncStatus` — Disabled / Synced / Cached (stale) / Offline / Error.

## Related

- [architecture.md](architecture.md) — panel module overview
- [troubleshooting.md](troubleshooting.md) — connect and subscription issues
- RioNexGate server: [github.com/RioTwWks/RioNexGate](https://github.com/RioTwWks/RioNexGate)
