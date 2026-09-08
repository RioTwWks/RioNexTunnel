# Чеклист проверки platform parity

<p align="right">
  <a href="../en/platform_parity_checklist.md"><img src="https://img.shields.io/badge/lang-English-blue?style=for-the-badge" alt="English version"></a>
</p>

Используйте после `scripts/fetch_cores.sh` (десктоп) или настройки нативного плагина (мобильные). На всех платформах **SOCKS только на `127.0.0.1` с паролем на сессию** — никогда не открывайте `0.0.0.0:7890` без auth.

## Шаблон E2E sign-off

Заполняйте при проверке на физическом устройстве или VM. Обновляйте таблицу в [README](README.md#e2e-проверка-на-устройствах), когда платформа подписана.

| Поле | Значение |
|------|----------|
| **Дата** | ГГГГ-ММ-ДД |
| **Тестер** | имя / ник |
| **Версия приложения** | git tag или commit |
| **Платформа** | напр. Windows 11 x64, macOS 14 arm64 |
| **Engine × profile** | xray/sing-box × config link / subscription |
| **Connect** | pass / fail + заметки |
| **Security probe** | pass / fail / N/A |
| **Browser helper** | pass / fail / N/A (только desktop) |
| **Блокеры** | открытые issues или PR |

## Linux (эталон — проверено)

| Шаг | Ожидание |
|-----|----------|
| `flutter run -d linux` | Приложение запускается |
| Подключение (xray/sing-box × config/subscription) | Статус **Connected** |
| `ss -lntp \| grep 1080` | Слушатель только `127.0.0.1:1080` |
| `curl` без учётных данных прокси | Отказ или ошибка auth |
| Отключение | Порты 1080/1081 закрыты; credentials сброшены |
| Browser helper | Карточка показывает пути host/manifest |

## Windows

| Шаг | Ожидание |
|-----|----------|
| Cores в bundle `resources/` | `xray.exe`, `sing-box.exe`, geo |
| `flutter build windows` или `flutter run -d windows` | Запуск |
| Connect (proxy mode) | **Connected** |
| Системный прокси | HTTP `127.0.0.1:1081` |
| `netstat -ano \| findstr 1080` | `127.0.0.1:1080` LISTENING |
| Disconnect | Прокси выключен; конфиг удалён |
| Browser helper | Native host + реестр Chrome/Edge + manifest Firefox; карточка в Settings |

**CI:** сборка Windows в workflow `windows-build` на `windows-latest` (PR + main).

## macOS

| Шаг | Ожидание |
|-----|----------|
| Cores в bundle | Бинарники в `resources/` |
| `flutter run -d macos` | Запуск |
| Connect (proxy mode) | **Connected** |
| Системный прокси | HTTP `127.0.0.1:1081` |
| SOCKS | `127.0.0.1:1080` с auth сессии |
| Credentials channel | В Settings видны user/pass при Connected |
| Browser helper | При первом `setup()` host копируется в `~/Library/Application Support/V2rayBox/working/native_host/secure_vpn_native_host`; manifests в Chrome/Chromium/Edge/Firefox `NativeMessagingHosts/` |
| Расширение | Unpacked из `extensions/secure-vpn-proxy-auth/` (dev) или store; карточка Browser helper — **Ready** при Connected |
| Disconnect | Прокси off; credentials сброшены; `session.json` удалён |

### Пути browser helper на macOS

| Компонент | Путь |
|-----------|------|
| Native host (установленный) | `~/Library/Application Support/V2rayBox/working/native_host/secure_vpn_native_host` |
| Chrome manifest | `~/Library/Application Support/Google/Chrome/NativeMessagingHosts/com.secure.vpn.proxy_auth.json` |
| Edge manifest | `~/Library/Application Support/Microsoft Edge/NativeMessagingHosts/com.secure.vpn.proxy_auth.json` |
| Firefox manifest | `~/Library/Application Support/Mozilla/NativeMessagingHosts/com.secure.vpn.proxy_auth.json` |

## Android

| Шаг | Ожидание |
|-----|----------|
| Физическое устройство | VPN на эмуляторе — ограниченно |
| Разрешение VPN | Диалог системы принят |
| `get_core_info` | `xray_available` по наличию AAR |
| Connect (TUN) | Foreground service + **Connected** |
| `start_with_json` | Передаются `socksUsername` / `socksPassword` / `socksPort` |
| Disconnect | VPN остановлен; credentials сброшены |

## iOS

| Шаг | Ожидание |
|-----|----------|
| `python3 scripts/setup_ios_packet_tunnel.py` | Target PacketTunnel в Xcode |
| `Libbox.xcframework` | `secure_vpn_client/ios/Frameworks/` |
| Capability Network Extension | Entitlements Runner + PacketTunnel |
| App Group | `group.com.example.secureVpnClient` |
| Сборка на устройстве | `flutter run -d <device>` на macOS |
| Connect | VPN-профиль и tunnel extension |
| `get_core_info` | `singbox_available: true`, `xray_available: false` |
| Disconnect | Конфиги удалены из app group |

## Регрессия безопасности

```bash
./scripts/security_probe.sh
```

Нет слушателей на `0.0.0.0`, SOCKS с auth, credentials меняются каждую сессию.
