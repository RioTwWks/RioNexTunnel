# Настройка iOS

> **Язык / Language:** **Русский** | [English](ios_setup.md)

1. Откройте `secure_vpn_client/ios/Runner.xcworkspace` в Xcode.
2. Добавьте capability **Network Extensions** и включите **Packet Tunnel**.
3. Добавьте entitlement `com.apple.developer.networking.vpn.api` в таргет Runner и в расширение туннеля.
4. Настройте действующую команду разработчика (development team) и provisioning profile.
5. Скопируйте бинарники ядер по путям, ожидаемым `v2ray_box` (см. README плагина), или используйте встроенные xcframeworks.
6. Запустите `flutter run -d ios` из `secure_vpn_client/` на macOS.

Для тестирования VPN на устройстве iOS требуется платный аккаунт Apple Developer.
