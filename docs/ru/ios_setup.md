# Настройка iOS

<p align="right">
  <a href="../en/ios_setup.md"><img src="https://img.shields.io/badge/lang-English-blue?style=for-the-badge" alt="English version"></a>
</p>


1. Откройте `secure_vpn_client/ios/Runner.xcworkspace` в Xcode.
2. Выполните `python3 scripts/setup_ios_packet_tunnel.py` из корня репозитория, если target **PacketTunnel** отсутствует.
3. Скопируйте `Libbox.xcframework` в `secure_vpn_client/ios/Frameworks/` (не в git).
4. Добавьте capability **Network Extensions** и **Packet Tunnel** для Runner и PacketTunnel.
5. Согласуйте App Group `group.com.example.secureVpnClient` с bundle ID для production.
6. Настройте development team и provisioning profile.
7. Запуск на macOS из `secure_vpn_client/`:

```bash
flutter run -d ios
```

Чеклист smoke-тестов: [platform_parity_checklist.md](platform_parity_checklist.md).

Для тестирования VPN на устройстве нужен Apple Developer account.

## Раздельное туннелирование

Per-app split tunneling (whitelist/blacklist по установленным приложениям) **на iOS недоступен** как на Android:

- Network Extension маршрутизирует на уровне **интерфейса туннеля**; нет публичного API, аналогичного `VpnService.Builder.addAllowedApplication` / `addDisallowedApplication`.
- UI split tunneling в RioNexTunnel **только на Android**. На iOS используйте **правила маршрутизации в конфиге ядра** (домены/IP в xray/sing-box).

Подробнее: [split_tunneling.md](split_tunneling.md).

## Подпись release (опционально)

Подписанные сборки App Store / ad-hoc используют `./scripts/setup-ios-signing.sh` с secrets GitHub (или те же переменные локально):

| Secret / переменная | Описание |
|---------------------|----------|
| `IOS_DISTRIBUTION_CERTIFICATE_BASE64` | Apple Distribution `.p12` (base64) |
| `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD` | Пароль сертификата |
| `IOS_PROVISIONING_PROFILE_BASE64` | `.mobileprovision` (base64) |
| `IOS_DEVELOPMENT_TEAM` | Apple Team ID |
| `KEYCHAIN_PASSWORD` | Пароль временного keychain (CI) |
| `IOS_EXPORT_METHOD` | Variable репозитория: `app-store` (по умолчанию), `ad-hoc` и т.д. |

Без secrets CI собирает `flutter build ios --release --no-codesign` и упаковывает unsigned `.app` zip. С secrets — подписанный `.ipa`.
