# Быстрый старт

[← Оглавление документации](README.md) · [English](../en/getting-started.md)

## Требования

- Flutter SDK `stable` (версия Dart — в `secure_vpn_client/pubspec.yaml`, сейчас `^3.11.0`)
- **Android:** Android Studio, SDK 23+, NDK
- **iOS / macOS:** Xcode 15+, CocoaPods
- **Windows:** Visual Studio 2022 с workload «Разработка классических приложений на C++»
- **Linux:** `clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`
- Go `1.21+` — только если пересобираете ядра самостоятельно

## 1. Клонирование

```bash
git clone https://github.com/RioTwWks/Secure-Cross-Platform-VPN-Client.git
cd Secure-Cross-Platform-VPN-Client
```

## 2. Загрузка бинарников ядер

Ядра (`xray`, `sing-box`) и geo-файлы (`geoip.dat`, `geosite.dat`) **не хранятся в git**. Из корня репозитория:

```bash
./scripts/fetch_cores.sh
```

Файлы копируются в `runner/resources/` платформ (и в Android `jniLibs` / assets). Запускайте скрипт один раз на машине или перед релизной сборкой.

## 3. Зависимости Flutter

```bash
cd secure_vpn_client
flutter pub get
```

## 4. Настройка платформы

| Платформа | Руководство |
|-----------|-------------|
| Linux | [linux_setup.md](linux_setup.md) |
| Android | [android_setup.md](android_setup.md) |
| iOS | [ios_setup.md](ios_setup.md) |
| Windows / macOS | Ядра через `fetch_cores.sh`, затем `flutter run -d windows` / `-d macos` |

## 5. Запуск

```bash
# Из secure_vpn_client/
flutter run -d linux      # или android / windows / macos / ios
```

После правок в `packages/v2ray_box/` нужен **полный перезапуск** — hot reload для нативного кода недостаточен.

## 6. Проверка безопасности

При активном VPN:

```bash
# Из корня репозитория
./scripts/security_probe.sh 1080
```

Неавторизованный доступ к локальному SOCKS-прокси должен завершаться ошибкой. Подробнее: [security.md](security.md).

## Дальше

- Стек и потоки данных: [architecture.md](architecture.md)
- Трафик браузера на Linux: [browser-extension.md](browser-extension.md)
- Участие в разработке: [contributing.md](contributing.md)
