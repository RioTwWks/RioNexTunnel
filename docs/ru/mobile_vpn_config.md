# Мобильный VPN — sing-box `mixed` и DNS

[English version](../en/mobile_vpn_config.md) · Русский

Аудит путей конфигурации sing-box на **мобильных** (Android/iOS, VPN / TUN) для RioNexTunnel.

## Inbound `mixed` на мобильных

В **режиме VPN** плагин может добавлять sing-box inbound `mixed` (`127.0.0.1`, локальный SOCKS+HTTP) вместе с TUN. Это **нормально**:

- Мост трафика приложение ↔ ядро (как в example v2ray_box)
- Слушает только **`127.0.0.1`**, не `0.0.0.0`
- На **desktop proxy** `ConfigParser.injectSecureSocksInbound(..., proxyOnly: true)` **удаляет** `mixed` и `tun`, оставляя только аутентифицированный SOCKS (+ HTTP)

Код:

- `packages/v2ray_box/ios/Classes/ConfigBuilder.swift`
- `packages/v2ray_box/android/.../SingboxConfigParser.kt`
- `secure_vpn_client/lib/utils/config_parser.dart` — `_isValidSingboxInboundForProxy` отбрасывает `mixed` в proxy mode

**Вывод:** `mixed` на мобильных допустим при bind на localhost; на desktop подписки не отдают `mixed` пользователю.

## Устаревший DNS sing-box

Подписки могут содержать legacy DNS. Перед connect:

- `ConfigParser._migrateSingboxLegacyDns`
- `ConfigParser._ensureSingboxRemoteDns`

См. [Troubleshooting](troubleshooting.md) при сообщении `legacy DNS servers is deprecated`.

## Расширенный DNS (P2)

См. [dns.md](dns.md).

## Правила Xray `geosite:` / `geoip:`

Если в конфиге есть `geosite:` / `geoip:` и **нет geo-файлов**, подключение **блокируется** с понятной ошибкой (`fetch_cores.sh` или sing-box). Auto engine понижает приоритет xray без geo.

## Тесты

- `secure_vpn_client/test/config_parser_test.dart`
- `secure_vpn_client/test/engine_auto_selector_test.dart`
