# Настройка iOS

[English version](../en/ios_setup.md)

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
