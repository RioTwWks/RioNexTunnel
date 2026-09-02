# Форк v2ray_box — набор патчей RioNexTunnel

[English version](../en/v2ray_box_fork.md) · Русский

Приложение использует **локальный форк** в [`packages/v2ray_box`](../../packages/v2ray_box), а не релиз с pub.dev. Upstream: [pesaregorg/v2ray_box](https://github.com/pesaregorg/v2ray_box).

## Зачем форк

RioNexTunnel требует безопасности и поведения на платформах, которых нет в upstream:

| Область | Upstream | Форк RioNexTunnel |
|---------|----------|-------------------|
| SOCKS inbound | В примерах возможны неаутентифицированные слушатели | Только `connectWithJson` с auth; учётные данные стираются при отключении |
| Desktop (Linux/Windows/macOS) | Частично | Полный proxy mode: subprocess, SOCKS+HTTP на `127.0.0.1`, системный прокси, канал credentials |
| Конфиг на диске | Может оставлять JSON сессии | `wipeSensitiveConfigFiles()` при disconnect |
| Android VPN | BoxService upstream | Session creds в `start_with_json`, патчи sing-box/Xray |
| iOS | PacketTunnel из example | Канал credentials, эвристика sing-box-only в приложении |

Подробности по файлам: [`packages/v2ray_box/SECURITY.md`](../../packages/v2ray_box/SECURITY.md).

## Синхронизация с upstream

```bash
./scripts/sync_v2ray_box.sh
```

1. `git fetch upstream` в `packages/v2ray_box`
2. `git rebase upstream/main` — разрешить конфликты в файлах из `SECURITY.md`
3. `flutter test` в `packages/v2ray_box` и `secure_vpn_client`
4. Тег: `secure-vpn-<upstream-version>+<patch>`

## Example (`packages/v2ray_box/example/`)

Example **намеренно сохранён** (~1 МБ исходников, бинарники в gitignore):

- **iOS PacketTunnel** — `scripts/setup_ios_packet_tunnel.py` мержит `example/ios/Runner.xcodeproj` в основное приложение
- **Интеграционные тесты** — `example/integration_test/` (опциональный live VPN через `--dart-define`)
- **Скрипты сборки Android** — `example/scripts/build_android_libxray.sh` в README плагина

Не удаляйте example без замены этих workflow.

## Отдельная публикация

Форк **не публикуется** на pub.dev от имени RioNexTunnel. Варианты:

1. **Vendored** (сейчас) — path dependency в `secure_vpn_client/pubspec.yaml`
2. **Git dependency** — на тег форка при выносе из монорепо
3. **PR в upstream** — desktop credential channel и wipe при готовности

## См. также

- [Архитектура](architecture.md)
- [Безопасность](security.md)
- [Участие в разработке](contributing.md)
