# Troubleshooting

<p align="right">
  <a href="../ru/troubleshooting.md"><img src="https://img.shields.io/badge/lang-Русский-red?style=for-the-badge" alt="Русская версия"></a>
</p>


Diagnostic patterns for Linux desktop and general issues. Check console stderr from xray/sing-box — the Linux plugin forwards it to `PlatformException` details.

## Connect fails — quick checklist

1. Cores present? `ls secure_vpn_client/linux/runner/resources/` → `xray`, `sing-box`
2. Geo assets? same dir → `geoip.dat`, `geosite.dat` (or run `./scripts/fetch_cores.sh`)
3. Full restart? Native plugin changes need `flutter run -d linux`, not hot reload
4. Stale config dir? `ls ~/.local/share/v2ray_box/profiles/` — `active_config.json` must be a **file**, not directory
5. Engine × profile matrix — test all four combinations

## Connect fails — Android

### UI does nothing after Connect (no Connected / no error)

**Cause A:** App `AndroidManifest.xml` missing `VPNService` / `ProxyService` declarations.

**Fix:** See [android_setup.md](android_setup.md).

**Cause B:** Android 13+ notification permission — plugin requested `POST_NOTIFICATIONS` but never resumed start after grant.

**Fix:** Plugin implements `RequestPermissionsResultListener` and continues `startService()` after grant.

**Cause C:** Engine = singbox but `libsingbox.so` not packaged.

**Symptom:** `sing-box binary not found at: .../lib/arm64/libsingbox.so`

**Fix:** `./scripts/fetch_cores.sh` + `useLegacyPackaging = true` in app `build.gradle.kts`. Or use engine **xray**.

**Cause D:** Missing `geosite.dat` / `geoip.dat`.

**Symptom:** `failed to open geosite.dat > stat /system/bin/geosite.dat`

**Fix:** `fetch_cores.sh` installs assets; `XrayBridge.initCoreEnv` copies them and sets `XRAY_LOCATION_ASSET`.

**Cause E:** sing-box readiness probed port `10808` while Dart secure SOCKS listens on `1080`.

**Fix:** Probe uses `SecureVpnCredentials.getSocksPort()`.

### `Lost connection to device` right after connect

Often undeclared VPN service / crash while starting foreground VPN. Fix manifest first, full restart, grant VPN + notifications.

## Error → cause → fix

### `Failed to write config file`

**Cause:** `active_config.json` existed as a **directory** (old plugin bug).

**Fix:** `rm -rf ~/.local/share/v2ray_box/profiles/active_config.json` + rebuild. Plugin now removes path before write.

### `Failed to start core binary` (generic)

**Cause A:** Binary not found — wrong search path.

**Fix:** Verify `ls build/linux/x64/debug/bundle/lib/resources/`.

**Cause B:** Process exited immediately — read stderr in Flutter console.

### `Listen on specific ip without port` / `tun-in`

**Cause:** Hiddify sing-box JSON (Dart default User-Agent) or full VPN config with TUN inbounds.

**Fix:** Engine-specific UA in `parseFromUrl`; `proxyOnly` strips non-SOCKS inbounds on desktop.

### `legacy DNS servers is deprecated` (sing-box)

**Cause:** sing-box ≥1.12 rejects legacy DNS format.

**Fix:** `_migrateSingboxLegacyDns()` in `ConfigParser`.

### `geosite.dat: no such file or directory`

**Cause:** v2rayNG subscription routing uses `geosite:cn` / `geoip:cn`.

**Fix:** Run `./scripts/fetch_cores.sh`; `EnsureXrayGeoAssets()` copies from bundle.

### `Core process exited during startup` (no stderr)

**Cause:** First v2rayNG array entry is a **decoy** server.

**Fix:** `_selectV2rayNgConfig()` skips entries without real outbound.

### `outboundTag: proxy` not found

**Cause:** v2rayNG templates use placeholder tag `proxy`.

**Fix:** `_normalizeXraySubscriptionConfig()` rewrites to primary outbound tag.

### Browser asks for proxy login (`127.0.0.1:1081`)

**Symptom:** VPN shows **Connected**, but browser shows proxy auth dialog.

**Cause:** Mandatory local proxy auth; Chromium ignores GSettings passwords.

**Fix (recommended):** Install [browser extension](browser_extension.md).

**Fix (fallback):** Copy credentials from Home or Settings. New credentials each reconnect.

**Verify system proxy:**

```bash
gsettings get org.gnome.system.proxy mode
gsettings get org.gnome.system.proxy.http host
gsettings get org.gnome.system.proxy.http port
gsettings get org.gnome.system.proxy.http use-authentication
```

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

# Security probe (app must be connected)
./scripts/security_probe.sh 1080
```

## Files to inspect when debugging

| Symptom | Files |
|---------|-------|
| Config content | `lib/utils/config_parser.dart`, `lib/utils/link_config_builder.dart` |
| Connect flow | `lib/services/vpn_service.dart` |
| Linux spawn | `packages/v2ray_box/linux/desktop_core.cc` |
| GNOME system proxy | `packages/v2ray_box/linux/system_proxy.cc` |
| Browser proxy auth | `browser_helper_card.dart`, `native_messaging.cc`, `extensions/secure-vpn-proxy-auth/` |
