# Contributing

[← Documentation index](README.md) · [Русский](../ru/contributing.md)

## Before opening a PR

From `secure_vpn_client/`:

```bash
flutter analyze
flutter test
```

Optional, with VPN connected on Linux:

```bash
# From repository root
./scripts/security_probe.sh
```

## Checklist

1. `flutter analyze` passes (`secure_vpn_client/analysis_options.yaml`).
2. New security-sensitive behavior has unit tests (see `test/security_test.dart`).
3. SOCKS/HTTP local inbounds remain on `127.0.0.1` with password auth.
4. No credentials, subscription URLs, or core binaries committed.
5. Docs updated if you change setup or security behavior (`docs/en/` and `docs/ru/`).

## Do not commit

- `secure_vpn_client/*/runner/resources/{xray,sing-box,geoip.dat,geosite.dat}`
- `secure_vpn_client/assets/binaries/**` (except `.gitkeep`)
- `.cursor/mcp.json` (local MCP config)
- Secrets, API keys, personal subscription URLs

## Suggested change order

1. Dart logic — models → utils → service → provider → UI
2. Tests in `test/`
3. Native code in `packages/v2ray_box/<platform>/` if needed
4. Update troubleshooting / docs if a new failure mode appears
5. Mark or add backlog items in [`.cursor/tasks.md`](../../.cursor/tasks.md)

## Edit targets

| Area | Path |
|------|------|
| App logic | `secure_vpn_client/lib/` |
| Linux native | `packages/v2ray_box/linux/` |
| User docs | `docs/en/`, `docs/ru/` |

Do not edit files under `build/` or `.plugin_symlinks/` — they are ephemeral.

## License

Contributions are accepted under **GNU GPLv3** (same as the project). See [LICENSE](../../LICENSE).
