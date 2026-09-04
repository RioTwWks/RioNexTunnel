# Localization (EN / RU)

RioNexTunnel uses Flutter `gen-l10n` for user-facing strings.

## Files

- `l10n.yaml` — generator config
- `lib/l10n/app_en.arb` — English template
- `lib/l10n/app_ru.arb` — Russian translations
- `lib/providers/locale_provider.dart` — System / English / Russian preference (SharedPreferences)
- `lib/utils/l10n_helpers.dart` — non-widget helpers (connection phase, uptime, panel sync, split tunnel)

## Regenerate after ARB edits

```bash
cd secure_vpn_client
flutter gen-l10n
```

## Language setting

**Settings → Appearance → Language**: System (follow OS), English, or Russian.

## Adding strings

1. Add key to `app_en.arb` and `app_ru.arb`
2. Run `flutter gen-l10n`
3. Use `AppLocalizations.of(context)!.yourKey` in widgets

Parameterized strings use `{name}` placeholders; see existing `@key` metadata in `app_en.arb`.
