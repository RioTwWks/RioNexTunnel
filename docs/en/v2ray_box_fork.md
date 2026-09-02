# v2ray_box fork — RioNexTunnel patch set

English · [Русская версия](../ru/v2ray_box_fork.md)

The app depends on a **local fork** at [`packages/v2ray_box`](../../packages/v2ray_box), not the pub.dev release. Upstream: [pesaregorg/v2ray_box](https://github.com/pesaregorg/v2ray_box).

## Why we fork

RioNexTunnel requires security and platform behavior that upstream does not provide out of the box:

| Area | Upstream | RioNexTunnel fork |
|------|----------|-------------------|
| SOCKS inbound | Example / link configs may expose unauthenticated listeners | App injects auth via `connectWithJson` only; credentials wiped on stop |
| Desktop (Linux/Windows/macOS) | Partial | Full proxy mode: subprocess cores, `127.0.0.1` SOCKS+HTTP, system proxy, credential channel |
| Config persistence | May leave session JSON on disk | `wipeSensitiveConfigFiles()` on disconnect |
| Android VPN | Upstream BoxService | Session creds in `start_with_json`, sing-box/Xray bridge patches |
| iOS | Example PacketTunnel | Credentials channel, sing-box-only heuristic in app |

See also [`packages/v2ray_box/SECURITY.md`](../../packages/v2ray_box/SECURITY.md) for file-level patch notes.

## Sync with upstream

```bash
./scripts/sync_v2ray_box.sh
```

1. `git fetch upstream` inside `packages/v2ray_box`
2. `git rebase upstream/main` — resolve conflicts in patched files listed in `SECURITY.md`
3. `flutter test` in `packages/v2ray_box` and `secure_vpn_client`
4. Tag: `secure-vpn-<upstream-version>+<patch>`

## Example app (`packages/v2ray_box/example/`)

The example is **kept intentionally** (~1 MB source, binaries gitignored):

- **iOS PacketTunnel** — `scripts/setup_ios_packet_tunnel.py` merges `example/ios/Runner.xcodeproj` into the main app
- **Integration tests** — `example/integration_test/` for core smoke (optional live VPN via `--dart-define`)
- **Android build scripts** — `example/scripts/build_android_libxray.sh` referenced in plugin README

Do not delete the example without replacing those workflows.

## Publishing separately

We do **not** publish this fork to pub.dev under RioNexTunnel. Options:

1. **Stay vendored** (current) — path dependency in `secure_vpn_client/pubspec.yaml`
2. **Git dependency** — point to a tagged fork repo if the monorepo splits
3. **Upstream PRs** — contribute desktop credential channel and wipe behavior upstream when acceptable

## Related docs

- [Architecture](architecture.md) — connect flow through the fork
- [Security](security.md) — SOCKS auth model
- [Contributing](contributing.md) — PR checklist
