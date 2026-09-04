import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _localePreferenceKey = 'locale_preference';

enum AppLocalePreference {
  system,
  english,
  russian;

  Locale? get locale => switch (this) {
        AppLocalePreference.system => null,
        AppLocalePreference.english => const Locale('en'),
        AppLocalePreference.russian => const Locale('ru'),
      };

  static AppLocalePreference fromStorage(String? raw) {
    return AppLocalePreference.values.firstWhere(
      (value) => value.name == raw,
      orElse: () => AppLocalePreference.system,
    );
  }
}

final localePreferenceProvider =
    StateNotifierProvider<LocalePreferenceNotifier, AppLocalePreference>((ref) {
  return LocalePreferenceNotifier();
});

class LocalePreferenceNotifier extends StateNotifier<AppLocalePreference> {
  LocalePreferenceNotifier() : super(AppLocalePreference.system) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AppLocalePreference.fromStorage(
      prefs.getString(_localePreferenceKey),
    );
  }

  Future<void> setPreference(AppLocalePreference preference) async {
    state = preference;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localePreferenceKey, preference.name);
  }
}
