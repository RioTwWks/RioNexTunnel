# Устранение неполадок

<p align="right">
  <a href="../en/troubleshooting.md"><img src="https://img.shields.io/badge/lang-English-blue?style=for-the-badge" alt="English version"></a>
</p>


Паттерны диагностики для Linux desktop и общих проблем. Проверьте stderr xray/sing-box — Linux plugin передаёт его в `PlatformException` details.

## Connect не работает — чеклист

1. Ядра есть? `ls secure_vpn_client/linux/runner/resources/` → `xray`, `sing-box`
2. Geo-файлы? в той же папке → `geoip.dat`, `geosite.dat` (или `./scripts/fetch_cores.sh`)
3. Полный перезапуск? Изменения plugin — `flutter run -d linux`, не hot reload
4. Старый config? `ls ~/.local/share/v2ray_box/profiles/` — `active_config.json` должен быть **файлом**, не директорией
5. Матрица engine × profile — проверьте все четыре комбинации

## Connect не работает — Android

### UI ничего не делает после Connect

**Причина A:** В `AndroidManifest.xml` нет `VPNService` / `ProxyService`.

**Fix:** См. [android_setup.md](android_setup.md).

**Причина B:** Android 13+ — разрешение уведомлений; start не продолжался после grant.

**Fix:** Plugin реализует `RequestPermissionsResultListener`.

**Причина C:** Engine = singbox, но `libsingbox.so` не в пакете.

**Симптом:** `sing-box binary not found at: .../lib/arm64/libsingbox.so`

**Fix:** `./scripts/fetch_cores.sh` + `useLegacyPackaging = true`. Или ядро **xray**.

**Причина D:** Нет `geosite.dat` / `geoip.dat`.

**Симптом:** `failed to open geosite.dat > stat /system/bin/geosite.dat`

**Fix:** `fetch_cores.sh` + `XRAY_LOCATION_ASSET`.

**Причина E:** sing-box проверял порт `10808`, а SOCKS на `1080`.

**Fix:** Probe использует `SecureVpnCredentials.getSocksPort()`.

### `Lost connection to device` после connect

Часто — незарегистрированный VPN service / crash. Исправьте manifest, полный перезапуск, разрешите VPN + уведомления.

## Ошибка → причина → решение

### `Failed to write config file`

**Причина:** `active_config.json` был **директорией** (старый баг plugin).

**Fix:** `rm -rf ~/.local/share/v2ray_box/profiles/active_config.json` + rebuild.

### `Failed to start core binary`

**Причина A:** Бинарник не найден — неверный путь.

**Fix:** `ls build/linux/x64/debug/bundle/lib/resources/`.

**Причина B:** Процесс завершился — читайте stderr в консоли Flutter.

### `Listen on specific ip without port` / `tun-in`

**Причина:** Hiddify sing-box JSON (UA Dart) или TUN inbound.

**Fix:** Engine-specific UA; `proxyOnly` убирает non-SOCKS inbound на desktop.

### `legacy DNS servers is deprecated` (sing-box)

**Причина:** sing-box ≥1.12 не принимает legacy DNS.

**Fix:** `_migrateSingboxLegacyDns()` в `ConfigParser`.

### `geosite.dat: no such file or directory`

**Причина:** Routing v2rayNG с `geosite:cn` / `geoip:cn`.

**Fix:** `./scripts/fetch_cores.sh`; `EnsureXrayGeoAssets()`.

### `Core process exited during startup`

**Причина:** Первый entry v2rayNG — **decoy**.

**Fix:** `_selectV2rayNgConfig()` пропускает decoy.

### `outboundTag: proxy` not found

**Причина:** Placeholder tag `proxy` в шаблонах v2rayNG.

**Fix:** `_normalizeXraySubscriptionConfig()`.

### Браузер запрашивает логин прокси (`127.0.0.1:1081`)

**Симптом:** VPN **Connected**, но браузер показывает диалог прокси.

**Причина:** Обязательный local proxy auth; Chromium игнорирует GSettings.

**Fix (рекомендуется):** Установите [расширение браузера](browser_extension.md).

**Fix (fallback):** Скопируйте creds с Home или Settings. Новые creds при каждом reconnect.

**Проверка системного прокси:**

```bash
gsettings get org.gnome.system.proxy mode
gsettings get org.gnome.system.proxy.http host
gsettings get org.gnome.system.proxy.http port
gsettings get org.gnome.system.proxy.http use-authentication
```

## Матрица User-Agent подписок

| User-Agent | Типичный ответ |
|------------|----------------|
| `Dart/x.x (dart:io)` | Hiddify sing-box JSON (tun, legacy DNS) — **плохо** |
| `HiddifyNext/2.0` | Полный sing-box JSON |
| `v2rayNG/1.8.29` | JSON-массив xray — **для engine xray** |
| `sing-box` | Base64 список ссылок — **для sing-box** |
| (empty / curl) | Base64 список ссылок |

## Полезные команды

```bash
# Формат подписки
curl -fsSL -A "v2rayNG/1.8.29" -H "Accept-Encoding: identity" "<SUB_URL>" | head -c 200

# Security probe (VPN подключён)
./scripts/security_probe.sh 1080
```

## Файлы для отладки

| Симптом | Файлы |
|---------|-------|
| Конфиг | `lib/utils/config_parser.dart`, `link_config_builder.dart` |
| Connect | `lib/services/vpn_service.dart` |
| Linux spawn | `packages/v2ray_box/linux/desktop_core.cc` |
| GNOME proxy | `packages/v2ray_box/linux/system_proxy.cc` |
| Диалог прокси | `browser_helper_card.dart`, `native_messaging.cc`, `extensions/secure-vpn-proxy-auth/` |
