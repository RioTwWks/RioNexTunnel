# Настройка Android

[English version](android_setup.md)

1. Откройте `secure_vpn_client/android/app/src/main/AndroidManifest.xml` и проверьте:
   - Разрешения VPN (`FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_SPECIAL_USE`, `POST_NOTIFICATIONS`, …)
   - Элементы `<service>` для `com.example.v2ray_box.bg.VPNService` и `ProxyService`
2. Убедитесь, что `applicationId` равен `com.example.secure_vpn_client` (используется для белого списка per-app прокси).
3. В `android/app/build.gradle.kts` оставьте `multiDexEnabled = true` и
   `packaging.jniLibs.useLegacyPackaging = true` (нужно для выполнения `libsingbox.so`).
4. Подготовьте ядра из корня репозитория:

```bash
./scripts/fetch_cores.sh
```

Скрипт скачивает десктопные ядра и также устанавливает Android sing-box в:

`secure_vpn_client/android/app/src/main/jniLibs/<abi>/libsingbox.so`

Xray на Android использует встроенный `android/app/libs/libxray.aar` (уже в дереве).

5. Выдайте разрешения **уведомлений** и **VPN** при первом подключении
   (Android 13+ требует оба; без них UI может выглядеть неактивным).
6. Для первого дымового теста на устройстве предпочитайте движок **xray**; используйте **singbox** только после того, как `libsingbox.so` появится в `jniLibs/`.
7. Geo-ассеты (`geoip.dat` / `geosite.dat`) копируются `fetch_cores.sh` в
   `android/app/src/main/assets/xray/` и извлекаются во время выполнения в директорию файлов приложения
   (`XRAY_LOCATION_ASSET`). Без них подписки v2rayNG, использующие `geosite:cn` / `geoip:cn`, не запустятся.
8. Запуск из `secure_vpn_client/`:

```bash
flutter run -d android
```

После изменений нативного кода, манифеста или Gradle требуется **полный перезапуск** (hot reload недостаточно).

Форк `v2ray_box` регистрирует собственный `VpnService`; не добавляйте пользовательский orphan-сервис вне указанных имён.
