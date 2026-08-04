# Настройка Android

[← Оглавление документации](README.md) · [English](../en/android_setup.md)

1. Откройте `secure_vpn_client/android/app/src/main/AndroidManifest.xml` и убедитесь, что есть:
   - разрешения VPN (`FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_SPECIAL_USE`, `POST_NOTIFICATIONS`, …)
   - записи `<service>` для `com.example.v2ray_box.bg.VPNService` и `ProxyService`
2. `applicationId` должен быть `com.example.secure_vpn_client` (используется для per-app allowlist прокси).
3. В `android/app/build.gradle.kts` оставьте `multiDexEnabled = true` и
   `packaging.jniLibs.useLegacyPackaging = true` (нужно для запуска `libsingbox.so`).
4. Подготовьте ядра из корня репозитория:

```bash
./scripts/fetch_cores.sh
```

Скрипт скачивает desktop-ядра и также ставит Android sing-box как:

`secure_vpn_client/android/app/src/main/jniLibs/<abi>/libsingbox.so`

Xray на Android использует уже включённый в дерево `android/app/libs/libxray.aar`.

5. При первом подключении выдайте разрешения **уведомлений** и **VPN**
   (на Android 13+ нужны оба; без них UI раньше выглядел «зависшим»).
6. Для первого smoke-теста на устройстве предпочтите ядро **xray**; **singbox** —
   только после появления `libsingbox.so` в `jniLibs/`.
7. Geo-файлы (`geoip.dat` / `geosite.dat`) копируются `fetch_cores.sh` в
   `android/app/src/main/assets/xray/` и извлекаются во время работы в каталог
   приложения (`XRAY_LOCATION_ASSET`). Без них подписки v2rayNG с
   `geosite:cn` / `geoip:cn` не стартуют.
8. Запуск из `secure_vpn_client/`:

```bash
flutter run -d android
```

После изменений native/manifest/Gradle нужен полный перезапуск (hot reload недостаточен).

Форк `v2ray_box` регистрирует свой `VpnService`; не добавляйте сторонний orphan-сервис с другими именами.
