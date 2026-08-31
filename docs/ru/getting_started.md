# Быстрый старт

<p align="right">
  <a href="../en/getting_started.md"><img src="https://img.shields.io/badge/lang-English-blue?style=for-the-badge" alt="English version"></a>
</p>


## Требования

- Flutter SDK `stable` (Dart `^3.11.0` в `secure_vpn_client/pubspec.yaml`)
- **Android:** Android Studio, SDK 23+, NDK
- **iOS/macOS:** Xcode 15+, CocoaPods
- **Windows:** Visual Studio 2022 с workload «Разработка классических приложений на C++»
- **Linux:** `clang`, `cmake`, `ninja-build`, `gtk3`
- Go `1.21+` (только при пересборке ядер из исходников)

## 1. Клонирование репозитория

```bash
git clone https://github.com/RioTwWks/Secure-Cross-Platform-VPN-Client.git
cd Secure-Cross-Platform-VPN-Client/secure_vpn_client
```

> Для AI-агентов Cursor см. [.cursor/AGENTS.md](../../.cursor/AGENTS.md).

## 2. Установка зависимостей

```bash
flutter pub get
```

## 3. Настройка платформы

| Платформа | Руководство |
|-----------|-------------|
| Linux | [linux_setup.md](linux_setup.md) |
| Android | [android_setup.md](android_setup.md) |
| iOS | [ios_setup.md](ios_setup.md) |
| Windows / macOS | Ядра через `fetch_cores.sh` в `windows/runner/resources/` или `macos/Runner/Resources/` |

## 4. Загрузка бинарников ядер

Из **корня репозитория** (не из `secure_vpn_client/`):

```bash
./scripts/fetch_cores.sh
```

Скрипт скачивает Xray-core, sing-box и `geoip.dat` / `geosite.dat` в:

- `secure_vpn_client/linux/runner/resources/`
- `secure_vpn_client/windows/runner/resources/`
- `secure_vpn_client/macos/Runner/Resources/`
- `secure_vpn_client/assets/binaries/` (мобильные платформы)

Бинарники ядер **не в git** — запускайте `fetch_cores.sh` на каждой машине и перед релизной сборкой.

## 5. Запуск приложения

```bash
cd secure_vpn_client
flutter run -d linux      # или android, windows, macos, ios
```

После изменений нативного плагина (`packages/v2ray_box/linux/`) нужен **полный перезапуск**, не hot reload.

## Проверка безопасности

```bash
# Из корня репозитория, при подключённом VPN
./scripts/security_probe.sh 1080
```

Неавторизованное подключение к SOCKS должно завершиться ошибкой. Подробнее: [security.md](security.md).

## Тесты

```bash
cd secure_vpn_client
flutter analyze
flutter test
```
