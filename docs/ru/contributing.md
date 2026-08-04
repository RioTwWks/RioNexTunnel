# Участие в разработке

[← Оглавление документации](README.md) · [English](../en/contributing.md)

## Перед Pull Request

Из `secure_vpn_client/`:

```bash
flutter analyze
flutter test
```

Опционально, при активном VPN на Linux:

```bash
# Из корня репозитория
./scripts/security_probe.sh
```

## Чеклист

1. `flutter analyze` проходит без ошибок (`secure_vpn_client/analysis_options.yaml`).
2. Новое поведение, связанное с безопасностью, покрыто unit-тестами (см. `test/security_test.dart`).
3. Локальные SOCKS/HTTP inbound остаются на `127.0.0.1` с password auth.
4. В коммит не попадают credentials, URL подписок и бинарники ядер.
5. При изменении setup или модели безопасности обновлены обе языковые версии (`docs/en/` и `docs/ru/`).

## Не коммитить

- `secure_vpn_client/*/runner/resources/{xray,sing-box,geoip.dat,geosite.dat}`
- `secure_vpn_client/assets/binaries/**` (кроме `.gitkeep`)
- `.cursor/mcp.json` (локальный MCP-конфиг)
- Секреты, API-ключи, личные URL подписок

## Рекомендуемый порядок изменений

1. Dart-логика — models → utils → service → provider → UI
2. Тесты в `test/`
3. При необходимости — native в `packages/v2ray_box/<platform>/`
4. Обновить troubleshooting / docs при новом классе ошибок
5. Отметить или добавить пункты в [`.cursor/tasks.md`](../../.cursor/tasks.md)

## Куда править

| Область | Путь |
|---------|------|
| Логика приложения | `secure_vpn_client/lib/` |
| Native Linux | `packages/v2ray_box/linux/` |
| Пользовательская документация | `docs/en/`, `docs/ru/` |

Не редактируйте файлы в `build/` и `.plugin_symlinks/` — они эфемерны.

## Лицензия

Вклад принимается на условиях **GNU GPLv3** (как и весь проект). См. [LICENSE](../../LICENSE).
