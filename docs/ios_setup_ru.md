# Настройка iOS

[English version](ios_setup.md)

1. Откройте `secure_vpn_client/ios/Runner.xcworkspace` в Xcode.
2. Добавьте возможность **Network Extensions** и включите **Packet Tunnel**.
3. Добавьте entitlement `com.apple.developer.networking.vpn.api` в цель Runner и tunnel extension.
4. Настройте действующую команду разработки и provisioning profile.
5. Скопируйте бинарники ядер в пути, ожидаемые `v2ray_box` (см. README плагина), или используйте bundled xcframeworks.
6. Запустите `flutter run -d ios` из `secure_vpn_client/` на macOS.

Для тестирования VPN на устройстве iOS требуется платная учётная запись Apple Developer.
