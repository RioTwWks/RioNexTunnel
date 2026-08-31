# Настройка iOS

<p align="right">
  <a href="../en/ios_setup.md"><img src="https://img.shields.io/badge/lang-English-blue?style=for-the-badge" alt="English version"></a>
</p>


1. Откройте `secure_vpn_client/ios/Runner.xcworkspace` в Xcode.
2. Добавьте capability **Network Extensions** и включите **Packet Tunnel**.
3. Добавьте entitlement `com.apple.developer.networking.vpn.api` для Runner и tunnel extension.
4. Настройте development team и provisioning profile.
5. Скопируйте бинарники ядер в пути, ожидаемые `v2ray_box` (см. README плагина), или используйте xcframeworks.
6. Запуск на macOS из `secure_vpn_client/`:

```bash
flutter run -d ios
```

Для тестирования VPN на устройстве нужен Apple Developer account.

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
