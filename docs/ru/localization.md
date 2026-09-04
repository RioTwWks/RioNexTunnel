# Локализация (EN / RU)

RioNexTunnel использует Flutter `gen-l10n` для пользовательских строк.

## Файлы

- `l10n.yaml` — конфигурация генератора
- `lib/l10n/app_en.arb` — шаблон (английский)
- `lib/l10n/app_ru.arb` — русские переводы
- `lib/providers/locale_provider.dart` — предпочтение: системный / English / Русский (SharedPreferences)
- `lib/utils/l10n_helpers.dart` — вспомогательные функции вне виджетов

## Перегенерация после правок ARB

```bash
cd secure_vpn_client
flutter gen-l10n
```

## Выбор языка

**Настройки → Внешний вид → Язык**: системный, English или Русский.

## Добавление строк

1. Добавьте ключ в `app_en.arb` и `app_ru.arb`
2. Выполните `flutter gen-l10n`
3. В виджетах используйте `AppLocalizations.of(context)!.yourKey`

Для параметризованных строк используйте плейсхолдеры `{name}`; см. метаданные `@key` в `app_en.arb`.
