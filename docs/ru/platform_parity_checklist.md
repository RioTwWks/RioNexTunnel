# Чеклист проверки platform parity

<p align="right">
  <a href="../en/platform_parity_checklist.md"><img src="https://img.shields.io/badge/lang-English-blue?style=for-the-badge" alt="English version"></a>
</p>

Используйте после `scripts/fetch_cores.sh` (десктоп) или настройки нативного плагина (мобильные). На всех платформах **SOCKS только на `127.0.0.1` с паролем на сессию** — никогда не открывайте `0.0.0.0:7890` без auth.

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
| `flutter run -d windows` | Запуск |
| Connect (proxy mode) | **Connected** |
| Системный прокси | HTTP `127.0.0.1:1081` |
| `netstat -ano \| findstr 1080` | `127.0.0.1:1080` LISTENING |
| Disconnect | Прокси выключен; конфиг удалён |
| Browser helper | **Пока нет на Windows** — в UI все `false` (см. P3) |

## macOS

| Шаг | Ожидание |
|-----|----------|
| Cores в bundle | Бинарники в `resources/` |
| `flutter run -d macos` | Запуск |
| Connect (proxy mode) | **Connected** |
| Системный прокси | HTTP `127.0.0.1:1081` |
| SOCKS | `127.0.0.1:1080` с auth сессии |
| Credentials channel | В Settings видны user/pass при Connected |
| Disconnect | Прокси off; credentials сброшены |

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
