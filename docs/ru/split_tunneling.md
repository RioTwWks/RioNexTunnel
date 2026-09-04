# Раздельное туннелирование (split tunneling)

<p align="right">
  <a href="../en/split_tunneling.md"><img src="https://img.shields.io/badge/lang-English-blue?style=for-the-badge" alt="English"></a>
</p>

Раздельное туннелирование задаёт, **какие приложения** используют VPN-туннель на мобильных устройствах. В RioNexTunnel на Android это реализовано через API `VpnService`; на десктопе в режиме прокси действуют другие ограничения (см. ниже).

## Режимы (Android VPN)

| Режим | Поведение | Нативный API |
|-------|-----------|--------------|
| **Выкл.** | Все приложения через VPN | Без per-app правил |
| **Только VPN** (whitelist / include) | Только выбранные приложения через VPN | `addAllowedApplication` |
| **Обход** (blacklist / exclude) | Выбранные приложения напрямую | `addDisallowedApplication` |

Настройка: **Настройки → Split tunneling**. После смены режима или списка приложений **переподключите VPN**, чтобы `VpnService.Builder` применил новый список.

Само VPN-приложение всегда исключено из туннеля.

## Безопасность

Раздельное туннелирование **не ослабляет** локальный прокси:

- SOCKS/HTTP только на **`127.0.0.1`** с **обязательной аутентификацией**
- Нет открытого порта `7890` и привязки к `0.0.0.0`
- Учётные данные сессии удаляются при отключении

Исключённые приложения выходят в интернет **напрямую** (мимо VPN). Открытый локальный прокси для них недоступен — RioNexTunnel его не поднимает.

### Проверка утечек

При подключённом VPN и включённом split tunnel:

```bash
./scripts/security_probe.sh 1080
```

Неаутентифицированное SOCKS-соединение должно **отклоняться**. См. [Безопасность](security.md).

## Десктоп (Linux / Windows / macOS)

На десктопе используется **режим прокси**, а не системный TUN VPN. Per-app split tunneling в приложении **не реализован**:

- Маршрутизация — на уровне каждого приложения (прокси браузера, настройки приложений, фаервол ОС)
- В настройках на десктопе показывается предупреждение
- Локальные прокси по-прежнему требуют auth на `127.0.0.1`

## iOS (Network Extension)

У Apple **нет** аналога Android per-app VPN в стороннем клиенте:

- `NEPacketTunnelProvider` маршрутизирует трафик на уровне **интерфейса**
- Списки include/exclude по приложениям **недоступны** как в `VpnService.Builder`
- UI split tunneling сегодня **только на Android**

На iOS используйте **правила маршрутизации в конфиге ядра** (домены/IP) — см. пресет «RU sites direct» (Agent C), а не переключатели по приложениям.

Ограничения: [настройка iOS](ios_setup.md#раздельное-туннелирование).

## Linux TUN (будущее — не реализовано)

**Статус:** отложено. Linux desktop сейчас только в **proxy mode**. Per-app TUN — отдельный будущий workstream.

## Код

| Компонент | Путь |
|-----------|------|
| Модель | `secure_vpn_client/lib/models/split_tunnel_settings.dart` |
| Сервис | `secure_vpn_client/lib/services/split_tunnel_service.dart` |
| Провайдер | `secure_vpn_client/lib/providers/per_app_proxy_provider.dart` |
| Android VPN | `packages/v2ray_box/android/.../bg/VPNService.kt` |

## Тесты

```bash
cd secure_vpn_client
flutter test test/split_tunnel_settings_test.dart
flutter test test/per_app_proxy_provider_test.dart
```
