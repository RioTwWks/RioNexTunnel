# Настройка iOS

[← Оглавление документации](README.md) · [English](../en/ios_setup.md)

1. Откройте `secure_vpn_client/ios/Runner.xcworkspace` в Xcode.
2. Добавьте capability **Network Extensions** и включите **Packet Tunnel**.
3. Добавьте entitlement `com.apple.developer.networking.vpn.api` для Runner и tunnel extension.
4. Настройте development team и provisioning profile.
5. Скопируйте бинарники ядер по путям, ожидаемым `v2ray_box` (см. README плагина), либо используйте bundled xcframeworks.
6. Запустите `flutter run -d ios` из `secure_vpn_client/` на macOS.

Для тестирования VPN на устройстве нужен платный аккаунт Apple Developer.
