# Настройка Android

[English version](../en/android_setup.md)

1. Откройте `secure_vpn_client/android/app/src/main/AndroidManifest.xml` и проверьте:
   - разрешения VPN (`FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_SPECIAL_USE`, `POST_NOTIFICATIONS`, …)
   - `<service>` для `com.example.v2ray_box.bg.VPNService` и `ProxyService`
2. `applicationId` должен быть `com.example.secure_vpn_client` (для allowlist приложений).
3. В `android/app/build.gradle.kts` оставьте `multiDexEnabled = true` и
   `packaging.jniLibs.useLegacyPackaging = true` (нужно для `libsingbox.so`).
4. Подготовьте ядра из корня репозитория:

```bash
./scripts/fetch_cores.sh
```

Скрипт скачивает desktop-ядра и устанавливает Android sing-box как:

`secure_vpn_client/android/app/src/main/jniLibs/<abi>/libsingbox.so`

Xray на Android использует `android/app/libs/libxray.aar` (уже в репозитории).

5. При первом подключении разрешите **уведомления** и **VPN**
   (Android 13+ требует оба; без них UI мог выглядеть «мёртвым»).
6. Для первого smoke test выберите ядро **xray**; **singbox** — только после появления `libsingbox.so` в `jniLibs/`.
7. Geo-файлы (`geoip.dat` / `geosite.dat`) копируются `fetch_cores.sh` в
   `android/app/src/main/assets/xray/` и извлекаются в runtime (`XRAY_LOCATION_ASSET`).
   Без них подписки v2rayNG с `geosite:cn` / `geoip:cn` не запускаются.
8. Запуск из `secure_vpn_client/`:

```bash
flutter run -d android
```

После изменений native/manifest/Gradle — полный перезапуск (hot reload недостаточен).

Форк `v2ray_box` регистрирует свой `VpnService`; не добавляйте посторонние service-записи.
