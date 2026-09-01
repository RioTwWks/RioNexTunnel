# Android setup

<p align="right">
  <a href="../ru/android_setup.md"><img src="https://img.shields.io/badge/lang-Русский-red?style=for-the-badge" alt="Русская версия"></a>
</p>


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

## Release signing (optional)

For signed release APK/AAB locally:

1. Generate a keystore (once):

```bash
keytool -genkey -v -keystore rionextunnel-release.jks -keyalg RSA \
  -keysize 2048 -validity 10000 -alias rionextunnel
```

2. Copy `android/key.properties.example` → `android/key.properties` and fill in paths/passwords.
3. Build: `flutter build apk --release` / `flutter build appbundle --release`.

Without `key.properties`, release builds use **debug signing** (same as CI when GitHub secrets are not configured).

CI reads signing material from repository secrets via `./scripts/setup-android-signing.sh`:

| Secret | Description |
|--------|-------------|
| `ANDROID_KEYSTORE_BASE64` | `.jks` file encoded as base64 |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_ALIAS` | Key alias |
| `ANDROID_KEY_PASSWORD` | Key password (optional; defaults to store password) |

The `v2ray_box` fork registers its own `VpnService`; do not add a custom orphan service entry outside the names above.

## Installing release APK from GitHub

Download the correct file from [Releases](https://github.com/RioTwWks/RioNexTunnel/releases):

| File | When to use |
|------|-------------|
| `RioNexTunnel-*-android-arm64.apk` | Most phones/tablets from ~2017 onward |
| `RioNexTunnel-*-android-armv7.apk` | Older 32-bit ARM devices only |
| `RioNexTunnel-*-android-universal.apk` | If unsure about CPU architecture |
| `RioNexTunnel-*-android.aab` | **Google Play / bundletool only** — cannot be installed directly |

### "App not installed" (Приложение не установлено)

1. **Uninstall the old app first** — Settings → Apps → RioNexTunnel → Uninstall.  
   This is required if you previously installed via `flutter run`, an older release, or a build signed with a different key (local debug vs CI debug vs release keystore).
2. **Pick the right APK** — do not open the `.aab` file on the device.
3. **Enable "Install unknown apps"** for your browser/files app (Android 8+).
4. **Configure release signing in CI** — without `ANDROID_KEYSTORE_*` GitHub secrets, CI APKs are debug-signed. They install cleanly on a device with no prior RioNexTunnel, but not over an app signed with another key.

To sideload with `adb`:

```bash
adb uninstall com.example.secure_vpn_client || true
adb install -r RioNexTunnel-0.2.4-android-arm64.apk
```

If install still fails, capture the exact reason:

```bash
adb install -r RioNexTunnel-0.2.4-android-arm64.apk
# or: adb logcat -d | tail -50
```
