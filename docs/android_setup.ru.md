# Настройка Android

> **Язык / Language:** **Русский** | [English](android_setup.md)

1. Откройте `secure_vpn_client/android/app/src/main/AndroidManifest.xml` и проверьте:
   - VPN-разрешения (`FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_SPECIAL_USE`, `POST_NOTIFICATIONS`, …)
   - записи `<service>` для `com.example.v2ray_box.bg.VPNService` и `ProxyService`
2. Убедитесь, что `applicationId` равен `com.example.secure_vpn_client` (используется для per-app белого списка прокси).
3. В `android/app/build.gradle.kts` сохраните `multiDexEnabled = true` и
   `packaging.jniLibs.useLegacyPackaging = true` (необходимо для запуска `libsingbox.so`).
4. Подготовьте ядра из корня репозитория:

```bash
./scripts/fetch_cores.sh
```

Скрипт скачивает десктопные ядра, а также устанавливает Android-версию sing-box в:

`secure_vpn_client/android/app/src/main/jniLibs/<abi>/libsingbox.so`

Xray на Android использует встроенный `android/app/libs/libxray.aar` (уже в дереве исходников).

5. При первом подключении выдайте разрешения на **уведомления** и **VPN**, когда система их запросит
   (на Android 13+ требуются оба; без них UI раньше выглядел неактивным).
6. Для первого smoke-теста на устройстве предпочтительно ядро **xray**; используйте **singbox** только после того,
   как `libsingbox.so` появится в `jniLibs/`.
7. Geo-файлы (`geoip.dat` / `geosite.dat`) копируются скриптом `fetch_cores.sh` в
   `android/app/src/main/assets/xray/` и извлекаются при запуске в файловую директорию приложения
   (`XRAY_LOCATION_ASSET`). Без них подписки v2rayNG с правилами
   `geosite:cn` / `geoip:cn` не запускаются.
8. Запуск из `secure_vpn_client/`:

```bash
flutter run -d android
```

После изменений в нативном коде / манифесте / Gradle нужен полный перезапуск (hot reload недостаточно).

Форк `v2ray_box` регистрирует собственный `VpnService`; не добавляйте собственную «осиротевшую» запись сервиса вне указанных выше имён.
