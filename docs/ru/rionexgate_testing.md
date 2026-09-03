# RioNexGate — тестирование клиента

[English version](../en/rionexgate_testing.md) · Русский

Как RioNexTunnel тестирует опциональную интеграцию с панелью RioNexGate. **CI не требует живой панели** — Dart-тесты используют mock HTTP-сервер.

## Автотесты (CI)

Из каталога `secure_vpn_client/`:

```bash
flutter analyze
flutter test test/panel_manager_test.dart
flutter test test/panel_integration_test.dart
```

### Юнит-тесты (`test/panel_manager_test.dart`)

- Панель выключена → no-op
- Регистрация сохраняет `device_token` и `subscription_url`
- Неизменный `config_hash` → без перезаписи кэша
- Новый `config_hash` → обновление кэша
- Очередь статистики → пакетная отправка

### Интеграционные тесты (`test/panel_integration_test.dart`)

Полный клиентский сценарий с `FakePanelServer` (`http.MockClient`):

| Сценарий | Покрытие |
|----------|----------|
| Регистрация → sync → stats connect → disconnect → flush | Сквозной API-поток |
| Новый `config_hash` с панели | Обновление кэша без перезапуска приложения |
| Панель offline | Кэш сохраняется; stats в очереди и replay при восстановлении сети |
| Битый JSON в `config` | Без throw; прежний кэш и `config_hash` |
| Riverpod `refreshConfig` | Обновление URL профиля **RioNexGate** |

Фикстуры — синтетические URL (`https://panel.test`) и токены; не коммитьте реальные учётные данные.

## Опционально: интеграция с живой панелью

`integration_test/vpn_flow_test.dart` — общий UI smoke. Сценарий с **живым RioNexGate** опционален и в CI не запускается.

Локальная проверка:

1. Запустите RioNexGate (Docker или dev).
2. Создайте pairing token в админке.
3. Переменные окружения при запуске (не коммитить):

```bash
export RIONEXGATE_PANEL_URL=http://127.0.0.1:8080
export RIONEXGATE_PAIRING_TOKEN=ваш-одноразовый-токен
flutter run -d linux
```

4. **Настройки → RioNexGate** — URL панели и токен, **Зарегистрировать**.

Проверьте: статус **Синхронизировано**, профиль **RioNexGate**, stats на панели после connect/disconnect.

## Наблюдаемость

- Логи sync — только **хэш device id** (8 символов локального UUID), без `device_token` в release.
- Статус в UI: `PanelSyncStatus` — Отключено / Синхронизировано / Кэш / Нет сети / Ошибка.

## См. также

- [architecture.md](architecture.md)
- [troubleshooting.md](troubleshooting.md)
- Сервер: [github.com/RioTwWks/RioNexGate](https://github.com/RioTwWks/RioNexGate)
