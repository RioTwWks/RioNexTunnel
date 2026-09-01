# Troubleshooting — Linux desktop (and general)

Diagnostic patterns discovered during integration. Check console stderr from xray/sing-box — the Linux plugin forwards it to `PlatformException` details.

## Connect fails — quick checklist

1. Cores present? `ls secure_vpn_client/linux/runner/resources/` → `xray`, `sing-box`
2. Geo assets? same dir → `geoip.dat`, `geosite.dat` (or run `./scripts/fetch_cores.sh`)
3. Full restart? Native plugin changes need `flutter run -d linux`, not hot reload
4. Stale config dir? `ls ~/.local/share/v2ray_box/profiles/` — `active_config.json` must be a **file**, not directory
5. Engine × profile matrix — test all four combinations

## Connect fails — Android

### Connected but no internet (Xray + subscription)

**Cause:** Subscription JSON has SOCKS/HTTP only. `injectSecureSocksInbound` used to strip `tun` and never re-add it. Android still creates a system TUN and passes its fd to Xray — without a `protocol: tun` inbound the fd is ignored and all traffic blackholes. Hiddify works because it always injects TUN.

**Also:** `_configurePerAppProxy` previously set INCLUDE with only the VPN package (Android cannot include itself).

**Fix:** VPN mode (`proxyOnly: false`) injects `tun-in`; per-app mode defaults to OFF (full device, exclude self). Native `writeJsonConfigFile` also ensures TUN as a safety net.

**Logs:** App → `…/app_flutter/logs/app.log` (Settings → Diagnostics). Native → `Android/data/<pkg>/files/logs/` (`vpn-service.log`, `xray-access.log`, `xray-error.log`).

**Cause:** sing-box config used `dns.servers: [{type: local}]`. Under Android VPN the system resolver queries `[::1]:53` → connection refused, so the proxy host never resolves (`lookup rio2skadi.pro`).

**Fix:** Use IP UDP DNS (`8.8.8.8` / `1.1.1.1`) without `detour: direct` (sing-box ≥1.12 fatals on that) and set `route.default_domain_resolver`. The VPN app package is excluded from TUN, so default dial for DNS works.

### Connect stays on Connect (Android) — never shows Disconnect

**Cause:** `EventChannel` status allows only one native sink. UI `watchStatus()` plus `VpnService._waitForStatus()` each called `receiveBroadcastStream()`, so the wait listener replaced (then cancelled) the UI sink. Linux often still looked fine due to timing; Android left the button stuck on Connect after a successful tunnel.

**Fix:** Cache a shared broadcast status stream in `v2ray_box` method channel; `VpnService` owns one native subscription and publishes to UI via `watchStatus()` / `_publishStatus(started)` after connect.

### UI does nothing after Connect (no Connected / no error)

**Cause A:** App `AndroidManifest.xml` missing `VPNService` / `ProxyService` declarations (plugin manifest is empty; services must be in the app).

**Fix:** See `docs/android_setup.md` — copy service blocks from the v2ray_box example manifest.

**Cause B:** Android 13+ notification permission — plugin requested `POST_NOTIFICATIONS` but never resumed start after grant (`onActivityResult` ≠ `onRequestPermissionsResult`).

**Fix:** Plugin now implements `RequestPermissionsResultListener` and continues `startService()` after grant.

**Cause C:** Engine = singbox but `libsingbox.so` not packaged.

**Symptom in logcat:** `sing-box binary not found at: .../lib/arm64/libsingbox.so`

**Fix:** `./scripts/fetch_cores.sh` (installs jniLibs) + `useLegacyPackaging = true` in app `build.gradle.kts`. Or keep engine on **xray** (uses `libxray.aar`).

### Release APK: «App not installed» / «Приложение не установлено»

**Cause A:** Signature mismatch — device already has RioNexTunnel from `flutter run`, an older GitHub release, or a build signed with a different key.

**Fix:** Uninstall first (`adb uninstall com.example.secure_vpn_client`), then install `*-android-arm64.apk` (or `*-android-universal.apk`). Do **not** try to install `.aab` directly.

**Cause B:** Wrong architecture — e.g. `armv7` APK on an arm64-only device (rare on modern phones).

**Fix:** Use `*-android-arm64.apk` or `*-android-universal.apk`.

**Cause C:** CI builds without `ANDROID_KEYSTORE_*` secrets use the runner debug keystore — incompatible with a locally debug-signed install.

**Fix:** Uninstall old app; for production releases configure GitHub signing secrets (see `docs/en/android_setup.md`).

**Cause D:** Missing `geosite.dat` / `geoip.dat` — Xray looks under `/system/bin/` by default.

**Symptom:** `failed to open geosite.dat > stat /system/bin/geosite.dat`

**Fix:** `fetch_cores.sh` installs `android/app/src/main/assets/xray/*.dat`; `XrayBridge.initCoreEnv` copies them to the app files dir and sets `XRAY_LOCATION_ASSET`.

**Cause E:** sing-box readiness probed port `10808` while Dart secure SOCKS listens on `1080`.

**Symptom:** `sing-box started successfully` then immediate stop; UI never reaches Connected.

**Fix:** Probe / TUN-bridge use `SecureVpnCredentials.getSocksPort()` (and SOCKS auth for the bridge).

### `Lost connection to device` right after connect

Often an undeclared VPN service / crash while starting foreground VPN. Fix manifest first, full restart (`flutter run`), grant VPN + notifications.

## Error → cause → fix

### `Failed to write config file`

**Cause:** `~/.local/share/v2ray_box/profiles/active_config.json` existed as a **directory** (old plugin bug).

**Fix:** `rm -rf ~/.local/share/v2ray_box/profiles/active_config.json` + rebuild app. Plugin now calls `RemovePathIfExists` before write.

### `Failed to start core binary` (generic)

**Cause A:** Binary not found — plugin searched wrong path (`bundle/resources/` instead of `bundle/lib/resources/`).

**Fix:** `FindBinary` includes `lib/resources/` — verify with `ls build/linux/x64/debug/bundle/lib/resources/`.

**Cause B:** Process exited immediately — real error was in stderr (misleading generic message before fix).

**Fix:** Read Flutter console for xray/sing-box output; UI now shows stderr text.

### `Listen on specific ip without port` / `tun-in`

**Cause:** Subscription returned Hiddify sing-box JSON (Dart default User-Agent) or full VPN config with TUN inbounds.

**Fix:** `parseFromUrl` uses engine-specific UA; `proxyOnly` strips non-SOCKS inbounds on desktop.

### `legacy DNS servers is deprecated` (sing-box)

**Cause:** sing-box ≥1.12 rejects `"address": "8.8.8.8"` DNS format.

**Fix:** `_migrateSingboxLegacyDns()` in `ConfigParser`; prefer link-based subscription for sing-box.

### `geosite.dat: no such file or directory`

**Cause:** v2rayNG subscription routing uses `geosite:cn` / `geoip:cn` rules.

**Fix:** Run `./scripts/fetch_cores.sh`; `EnsureXrayGeoAssets()` copies from bundle to `~/.local/share/v2ray_box/assets/`.

### `Core process exited during startup` (no stderr)

**Cause:** Often first v2rayNG array entry is a **decoy** server (no real outbound).

**Fix:** `_selectV2rayNgConfig()` skips entries without vless/vmess/trojan/ss outbound.

### `outboundTag: proxy` not found

**Cause:** v2rayNG templates use placeholder tag `proxy`.

**Fix:** `_normalizeXraySubscriptionConfig()` rewrites to primary outbound tag.

### Browser asks for proxy login (`127.0.0.1:1081`)

**Symptom:** VPN shows **Connected**, but the browser pops up a proxy authentication dialog (username/password for `127.0.0.1:1081`). Real IP may still appear until credentials are entered.

**Cause:** Local proxy auth is **mandatory by design** (protection against unauthenticated localhost proxies). On Linux desktop:

- GNOME system proxy does not support SOCKS with authentication → the app uses an **HTTP inbound** on port `1081` (`socksPort + 1`).
- The app writes session credentials into GSettings via `SystemProxy::Enable`, but **Chromium and some browsers ignore GSettings auth** and show their own dialog.
- Credentials are **per-session** — each Connect generates new random username/password; saved browser credentials from a previous session will not work.

**Important:** These are **local proxy credentials**, not your VPN server account.

**Fix (recommended): Browser helper extension**

1. Run the VPN app once (installs native messaging host on `setup()`).
2. Load unpacked extension from `extensions/secure-vpn-proxy-auth/` (Chromium: `chrome://extensions`, Firefox: `about:debugging`).
3. Connect VPN; open **Settings → Browser helper** — host, manifest, extension, and session should be green.
4. Browse — no proxy dialog; extension receives session creds via native messaging.

**Fix (fallback — manual):**

1. In the app: **Home** or **Settings → System proxy (this session)** — copy username/password (or **Copy both**).
2. Paste into the browser dialog when prompted.
3. After **reconnecting** VPN, use the **new** credentials (or keep extension installed — it updates automatically).

**Verify system proxy is set:**

```bash
gsettings get org.gnome.system.proxy mode                    # manual
gsettings get org.gnome.system.proxy.http host               # 127.0.0.1
gsettings get org.gnome.system.proxy.http port               # 1081
gsettings get org.gnome.system.proxy.http use-authentication # true
```

**Related files:** `packages/v2ray_box/linux/system_proxy.cc`, `packages/v2ray_box/linux/native_messaging.cc`, `extensions/secure-vpn-proxy-auth/`, `secure_vpn_client/lib/widgets/browser_helper_card.dart`, `secure_vpn_client/lib/widgets/proxy_credentials_card.dart`, `secure_vpn_client/lib/utils/config_parser.dart` (HTTP inbound when `proxyOnly: true`).

## Subscription User-Agent matrix

| User-Agent | Typical response |
|------------|------------------|
| `Dart/x.x (dart:io)` | Hiddify sing-box JSON (tun, legacy DNS) — **bad for us** |
| `HiddifyNext/2.0` | Full sing-box JSON |
| `v2rayNG/1.8.29` | JSON array of xray configs — **used for xray engine** |
| `sing-box` | Base64 link list — **used for sing-box engine** |
| (empty / curl) | Base64 link list |

## Useful commands

```bash
# Inspect subscription format
curl -fsSL -A "v2rayNG/1.8.29" -H "Accept-Encoding: identity" "<SUB_URL>" | head -c 200

# Test xray manually
~/.local/share/v2ray_box/profiles/active_config.json
/path/to/xray run -c ~/.local/share/v2ray_box/profiles/active_config.json

# Security probe (app must be connected)
./scripts/security_probe.sh 1080
```

## Files to inspect when debugging

| Symptom | Files |
|---------|-------|
| Config content | `lib/utils/config_parser.dart`, `lib/utils/link_config_builder.dart` |
| Connect flow | `lib/services/vpn_service.dart` |
| Linux spawn | `packages/v2ray_box/linux/desktop_core.cc` |
| Channel API | `packages/v2ray_box/linux/v2ray_box_plugin.cc` |
| GNOME system proxy | `packages/v2ray_box/linux/system_proxy.cc` |
| Browser proxy auth dialog | `browser_helper_card.dart`, `native_messaging.cc`, `extensions/secure-vpn-proxy-auth/` |
| Written config | `~/.local/share/v2ray_box/profiles/active_config.json` (after failed connect may be wiped) |
