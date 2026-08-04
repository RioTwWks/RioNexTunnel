# Android setup

> **Language / Язык:** **English** | [Русский](android_setup.ru.md)

1. Open `secure_vpn_client/android/app/src/main/AndroidManifest.xml` and verify:
   - VPN permissions (`FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_SPECIAL_USE`, `POST_NOTIFICATIONS`, …)
   - `<service>` entries for `com.example.v2ray_box.bg.VPNService` and `ProxyService`
2. Ensure `applicationId` is `com.example.secure_vpn_client` (used for per-app proxy allowlist).
3. In `android/app/build.gradle.kts`, keep `multiDexEnabled = true` and
   `packaging.jniLibs.useLegacyPackaging = true` (needed to execute `libsingbox.so`).
4. Prepare cores from repo root:

```bash
./scripts/fetch_cores.sh
```

This downloads desktop cores and also installs Android sing-box as:

`secure_vpn_client/android/app/src/main/jniLibs/<abi>/libsingbox.so`

Xray on Android uses the bundled `android/app/libs/libxray.aar` (already in the tree).

5. Grant **notification** and **VPN** permissions when prompted on first connect
   (Android 13+ requires both; without them the UI used to look idle).
6. Prefer engine **xray** for first device smoke test; use **singbox** only after
   `libsingbox.so` is present under `jniLibs/`.
7. Geo assets (`geoip.dat` / `geosite.dat`) are copied by `fetch_cores.sh` into
   `android/app/src/main/assets/xray/` and extracted at runtime into the app files
   dir (`XRAY_LOCATION_ASSET`). Without them, v2rayNG subscriptions that use
   `geosite:cn` / `geoip:cn` fail to start.
8. Run from `secure_vpn_client/`:

```bash
flutter run -d android
```

Full restart after native/manifest/Gradle changes (hot reload is not enough).

The `v2ray_box` fork registers its own `VpnService`; do not add a custom orphan service entry outside the names above.
