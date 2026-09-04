import 'package:flutter/material.dart';

class SocksAuthModeStrings {
  SocksAuthModeStrings._();

  static bool _isRu(Locale? locale) =>
      locale?.languageCode.toLowerCase() == 'ru';

  static String sectionTitle(Locale? locale) =>
      _isRu(locale) ? 'SOCKS5 аутентификация' : 'SOCKS5 authentication';

  static String sectionSubtitle(Locale? locale) => _isRu(locale)
      ? 'Локальный прокси всегда на 127.0.0.1 с обязательным паролем.'
      : 'Local proxy is always on 127.0.0.1 with mandatory password auth.';

  static String randomPerSession(Locale? locale) =>
      _isRu(locale) ? 'Случайные на сессию' : 'Random per session';

  static String staticFromPanel(Locale? locale) =>
      _isRu(locale) ? 'Статичные из панели' : 'Static from panel';

  static String randomDescription(Locale? locale) => _isRu(locale)
      ? 'Новый логин и пароль при каждом подключении (по умолчанию).'
      : 'New username and password on every connect (default).';

  static String staticDescription(Locale? locale) => _isRu(locale)
      ? 'Использовать SOCKS из JSON панели RioNexGate, если указаны.'
      : 'Use SOCKS credentials from RioNexGate panel JSON when available.';

  static String staticUnavailable(Locale? locale) => _isRu(locale)
      ? 'Панель не настроена или в конфиге нет SOCKS — будет случайный режим.'
      : 'Panel not configured or config lacks SOCKS — falls back to random.';

  static String disableInjectionTitle(Locale? locale) => _isRu(locale)
      ? 'Отключить подмену SOCKS (расширенное)'
      : 'Disable SOCKS injection (advanced)';
}
