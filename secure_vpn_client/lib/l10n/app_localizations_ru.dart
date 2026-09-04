// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get navHome => 'Главная';

  @override
  String get navProfiles => 'Профили';

  @override
  String get navSettings => 'Настройки';

  @override
  String get connect => 'Подключить';

  @override
  String get disconnect => 'Отключить';

  @override
  String get pleaseWait => 'Подождите…';

  @override
  String get tapToDisconnectSecurely => 'Нажмите для безопасного отключения';

  @override
  String get tapToConnect => 'Нажмите для защищённого подключения';

  @override
  String get establishingSecureTunnel => 'Установка защищённого туннеля…';

  @override
  String get connectionDisconnected => 'Отключено';

  @override
  String get connectionConnecting => 'Подключение';

  @override
  String get connectionConnected => 'Подключено';

  @override
  String get connectionReconnecting => 'Переподключение';

  @override
  String get connectionDisconnecting => 'Отключение';

  @override
  String get connectionError => 'Ошибка';

  @override
  String get errorSelectProfileFirst => 'Сначала выберите или добавьте профиль';

  @override
  String get statusTestingServers => 'Проверка серверов…';

  @override
  String get statusNoProfileSelected => 'Профиль не выбран';

  @override
  String get statusAddProfileHint =>
      'Добавьте ссылку или подписку в разделе Профили';

  @override
  String get statusSubscriptionProfile => 'Профиль подписки';

  @override
  String get statusDirectConfigLink => 'Прямая ссылка конфигурации';

  @override
  String get statsUpload => 'Отдача';

  @override
  String get statsDownload => 'Загрузка';

  @override
  String get statsUptime => 'Время сессии';

  @override
  String get appearanceTitle => 'Внешний вид';

  @override
  String get appearanceSubtitle => 'Тема применяется на всех платформах';

  @override
  String get themeSystem => 'Системная';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get languageTitle => 'Язык';

  @override
  String get languageSystem => 'Системный';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageRussian => 'Русский';

  @override
  String get workModeTitle => 'Режим работы';

  @override
  String get coreEngineTitle => 'Ядро';

  @override
  String get coreEngineAutoSubtitle =>
      'Авто: по доступности, формату подписки и резерву при подключении';

  @override
  String get coreEngineDisconnectBeforeSwitch =>
      'Отключите VPN перед сменой ядра';

  @override
  String get engineAuto => 'Авто';

  @override
  String get engineXray => 'Xray';

  @override
  String get engineSingbox => 'sing-box';

  @override
  String get actionOff => 'Выкл';

  @override
  String get actionProxy => 'Прокси';

  @override
  String get actionVpn => 'VPN';

  @override
  String get splitTunnelTitle => 'Раздельное туннелирование';

  @override
  String get splitTunnelSubtitleAndroid =>
      'Выберите приложения для VPN-туннеля (Android)';

  @override
  String get splitTunnelVpnOnly => 'Только VPN';

  @override
  String get splitTunnelBypass => 'Обход';

  @override
  String get splitTunnelModeOffDesc => 'Все приложения используют VPN-туннель.';

  @override
  String get splitTunnelModeIncludeDesc =>
      'Белый список: только выбранные приложения идут через VPN.';

  @override
  String get splitTunnelModeExcludeDesc =>
      'Чёрный список: выбранные приложения подключаются напрямую.';

  @override
  String get splitTunnelAppsUsingVpn => 'Приложения через VPN';

  @override
  String get splitTunnelAppsBypassingVpn => 'Приложения в обход VPN';

  @override
  String get splitTunnelNoAppsSelected => 'Приложения не выбраны';

  @override
  String get splitTunnelReconnectAfterChange =>
      'Переподключите VPN после изменения списка приложений.';

  @override
  String get splitTunnelDesktopBody =>
      'На десктопе используется режим прокси, а не системный TUN VPN. Маршрутизация по приложениям настраивается в каждом приложении — не в этом клиенте.';

  @override
  String get splitTunnelDesktopSecurity =>
      'Локальные SOCKS/HTTP прокси всегда требуют аутентификацию на сессию только на 127.0.0.1.';

  @override
  String get killSwitchTitle => 'Аварийное отключение';

  @override
  String get killSwitchSubtitle =>
      'Блокировать интернет при неожиданной остановке VPN или ядра';

  @override
  String get killSwitchStrict => 'Строгий';

  @override
  String get killSwitchAdaptive => 'Адаптивный';

  @override
  String get killSwitchStrictDesc =>
      'Строгий режим блокирует весь исходящий трафик при падении туннеля или ядра.';

  @override
  String get killSwitchAdaptiveTitle => 'Адаптивный (по приложениям)';

  @override
  String get killSwitchAdaptiveSubtitle =>
      'Требует раздельного туннелирования — будет доступен позже';

  @override
  String get dnsAdvancedTitle => 'Расширенный DNS';

  @override
  String get dnsDesktopSubtitle =>
      'В режиме прокси на десктопе системный DNS не перехватывается. См. docs/ru/dns.md';

  @override
  String get dnsVpnSubtitle =>
      'DoH/DoT и защита от утечек DNS в режиме VPN/TUN';

  @override
  String get dnsDefault => 'По умолчанию';

  @override
  String get dnsCustom => 'Свой';

  @override
  String get dnsEncrypted => 'Шифрованный';

  @override
  String get dnsLeakProtection => 'Защита от утечек DNS';

  @override
  String get dnsLeakProtectionSubtitle =>
      'Направлять DNS через туннель (режим TUN)';

  @override
  String get dnsAddResolver => 'Добавить резолвер';

  @override
  String get dnsLeakTest => 'Тест утечки DNS';

  @override
  String get dnsInvalidAddress => 'Неверный адрес';

  @override
  String get dnsAddResolverTitle => 'Добавить DNS-резолвер';

  @override
  String get dnsResolverLabel => 'Метка';

  @override
  String get dnsResolverAddress => 'Адрес';

  @override
  String get actionCancel => 'Отмена';

  @override
  String get actionAdd => 'Добавить';

  @override
  String get actionSave => 'Сохранить';

  @override
  String get advancedSecurityTitle => 'Расширенная безопасность';

  @override
  String get advancedSecuritySubtitle =>
      'Дополнительная защита при загрузке подписки';

  @override
  String get censorshipResistanceTitle => 'Обход цензуры';

  @override
  String get censorshipResistanceSubtitle =>
      'Пресеты транспорта, uTLS, маршрутизация RU';

  @override
  String get censorshipRuDirectDefault =>
      'RU-сайты напрямую (по умолчанию для новых профилей)';

  @override
  String get censorshipRuDirectDefaultSubtitle =>
      'При включённом мастере — российские сайты/IP напрямую';

  @override
  String get censorshipCustomRouting => 'Свои правила маршрутизации';

  @override
  String get censorshipCustomRoutingEmpty =>
      'Домен, IP, geosite/geoip — импорт/экспорт JSON';

  @override
  String get censorshipStackGuide => 'Какой стек когда использовать';

  @override
  String get censorshipStackGuideSubtitle =>
      'docs/ru/censorship_resistance.md — REALITY vs TLS, XHTTP, mux';

  @override
  String get socksAuthTitle => 'SOCKS5 аутентификация';

  @override
  String get socksAuthSubtitle =>
      'Локальный прокси всегда на 127.0.0.1 с обязательным паролем.';

  @override
  String get socksRandomPerSession => 'Случайные на сессию';

  @override
  String get socksStaticFromPanel => 'Статичные из панели';

  @override
  String get socksRandomDesc =>
      'Новый логин и пароль при каждом подключении (по умолчанию).';

  @override
  String get socksStaticDesc =>
      'Использовать SOCKS из JSON панели RioNexGate, если указаны.';

  @override
  String get socksStaticUnavailable =>
      'Панель не настроена или в конфиге нет SOCKS — будет случайный режим.';

  @override
  String get socksDisableInjection => 'Отключить подмену SOCKS (расширенное)';

  @override
  String get localBindTitle => 'Привязка';

  @override
  String get localBindSubtitle => 'Только 127.0.0.1, пароль обязателен';

  @override
  String get diagnosticsTitle => 'Диагностика';

  @override
  String get logLevelInfo => 'Info';

  @override
  String get logLevelDebug => 'Debug';

  @override
  String get viewLogs => 'Просмотр логов';

  @override
  String get logFiles => 'Файлы логов';

  @override
  String get logResolving => 'Определение…';

  @override
  String get logAndroidHint => 'На Android также: Android/data/…/files/logs/';

  @override
  String get copyPath => 'Копировать путь';

  @override
  String get logPathCopied => 'Путь к логам скопирован';

  @override
  String get privacyTitle => 'Конфиденциальность';

  @override
  String get privacyPolicy => 'Политика конфиденциальности';

  @override
  String get logsTitle => 'Логи';

  @override
  String get proxyCredsTitle => 'Учётные данные прокси';

  @override
  String get proxyCredsExtensionHint =>
      'Установите расширение браузера для автоматической аутентификации прокси.';

  @override
  String get proxyUsername => 'Имя пользователя прокси';

  @override
  String get proxyPassword => 'Пароль прокси';

  @override
  String get proxyCopyBoth => 'Копировать оба';

  @override
  String get browserHelperTitle => 'Помощник браузера';

  @override
  String get browserHelperReady => 'Готово — диалог не нужен';

  @override
  String get browserHelperWaiting => 'Ожидание учётных данных VPN-сессии';

  @override
  String get browserHelperHostMissing => 'Native messaging host не установлен';

  @override
  String get browserHelperManifestMissing => 'Манифест браузера отсутствует';

  @override
  String get browserHelperExtensionMissing =>
      'Расширение не обнаружено в браузере';

  @override
  String get browserHelperLabelHost => 'Native host';

  @override
  String get browserHelperLabelManifest => 'Манифест';

  @override
  String get browserHelperLabelExtension => 'Расширение';

  @override
  String get browserHelperLabelSession => 'Сессия VPN';

  @override
  String get panelSectionTitle => 'RioNexGate (опционально)';

  @override
  String get panelEnable => 'Включить панель';

  @override
  String get panelUrl => 'URL панели';

  @override
  String get panelPairingToken => 'Токен сопряжения';

  @override
  String get panelRegister => 'Зарегистрировать';

  @override
  String get panelRefresh => 'Обновить';

  @override
  String get panelClear => 'Сбросить';

  @override
  String get panelRegistered => 'Устройство зарегистрировано';

  @override
  String get panelRegisterFailed => 'Ошибка регистрации';

  @override
  String get panelDeviceId => 'ID устройства';

  @override
  String get panelLastSync => 'Последняя синхронизация';

  @override
  String get panelSubscription => 'Подписка';

  @override
  String get panelConfigured => 'Настроено';

  @override
  String get panelNotConfigured => 'Не настроено';

  @override
  String get panelNever => 'Никогда';

  @override
  String get panelSyncDisabled => 'Отключено';

  @override
  String get panelSyncSynced => 'Синхронизировано';

  @override
  String get panelSyncStale => 'Кэш (панель недоступна)';

  @override
  String get panelSyncOffline => 'Нет сети';

  @override
  String get panelSyncError => 'Ошибка';

  @override
  String get panelSyncInterval => 'Интервал синхронизации';

  @override
  String get pinningTitle => 'Закрепление сертификата';

  @override
  String get pinningNoSavedPins => 'Нет сохранённых pin.';

  @override
  String get pinningAddPin => 'Добавить pin';

  @override
  String get pinningAddSpkiTitle => 'Добавить SPKI pin';

  @override
  String get pinningHostRequired => 'Укажите хост';

  @override
  String get pinningRemoveHost => 'Удалить хост';

  @override
  String get pinningRemovePin => 'Удалить pin';

  @override
  String get configAddProfile => 'Добавить профиль';

  @override
  String get configAddProfileSubtitle => 'Вставьте ссылку или URL подписки';

  @override
  String get configProfileName => 'Имя профиля';

  @override
  String get configLinkLabel =>
      'Ссылка конфигурации (vless://, hy2://, tuic://, …)';

  @override
  String get configSubscriptionUrl => 'URL подписки';

  @override
  String get configLink => 'Ссылка';

  @override
  String get configSubscription => 'Подписка';

  @override
  String get configSavedProfiles => 'Сохранённые профили';

  @override
  String get configNoProfiles => 'Профилей пока нет';

  @override
  String get configNoProfilesHint => 'Добавьте ссылку или подписку для начала';

  @override
  String get configNameLinkRequired => 'Укажите имя и ссылку конфигурации';

  @override
  String get configInvalidLink => 'Недействительная ссылка VPN';

  @override
  String get configProfileAdded => 'Профиль добавлен';

  @override
  String get configCensorshipUpdated => 'Настройки цензуры обновлены';

  @override
  String get configDirectLink => 'Прямая ссылка';

  @override
  String get configSubscriptionAutomatic => 'Подписка · Авто';

  @override
  String get configCensorshipModeTooltip => 'Режим обхода цензуры';

  @override
  String get serverPickerTitle => 'Сервер';

  @override
  String get serverAutomatic => 'Авто (лучшая задержка)';

  @override
  String get serverSelectTitle => 'Выбор сервера';

  @override
  String get serverProbeLatency => 'Проверить задержку (URL test)';

  @override
  String get serverRefreshList => 'Обновить список';

  @override
  String get serverNoServers => 'Серверы не найдены';

  @override
  String get serverAutoRetest =>
      'Авто: лучший сервер перепроверяется при каждом подключении';

  @override
  String get serverAutoPickLatency =>
      'Выбор сервера с наименьшей задержкой при подключении';

  @override
  String get serverAutomaticLabel => 'Автоматически';

  @override
  String get multihopTitle => 'Multihop (Double VPN)';

  @override
  String get multihopRouteMultiple => 'Маршрутизация через несколько серверов';

  @override
  String get multihopSelectHops => 'Выберите дополнительные серверы';

  @override
  String get multihopEditChain => 'Изменить цепочку';

  @override
  String get multihopChainTitle => 'Цепочка multihop';

  @override
  String get multihopRequiresTwoServers =>
      'Multihop требует минимум 2 сервера.';

  @override
  String get multihopSaveChain => 'Сохранить цепочку';

  @override
  String get transportCustom => 'Свой';

  @override
  String get transportStandard => 'Стандарт';

  @override
  String get transportMux => 'mux';

  @override
  String get transportRuDirect => 'RU напрямую';

  @override
  String get advancedTitle => 'Расширенные';

  @override
  String get advancedSettingsSubtitle =>
      'Kill switch, DNS, маршрутизация, split tunnel, обход цензуры';

  @override
  String get censorshipWizardTitle => 'Режим обхода цензуры';

  @override
  String get censorshipSkip => 'Пропустить';

  @override
  String get censorshipEnable => 'Включить режим обхода цензуры';

  @override
  String get censorshipTransport => 'Пресет транспорта';

  @override
  String get censorshipTlsFingerprint => 'TLS fingerprint';

  @override
  String get censorshipEnableMux => 'Включить mux';

  @override
  String get censorshipEnableMuxSubtitle =>
      'Резерв для мобильных — concurrency 8';

  @override
  String get censorshipRuDirect => 'RU-сайты напрямую';

  @override
  String get censorshipRuDirectSubtitle =>
      'geosite:ru / geoip:ru → direct (нужны geo)';

  @override
  String get censorshipSaveProfile => 'Сохранить профиль';

  @override
  String get routingCustomTitle => 'Своя маршрутизация';

  @override
  String get routingAddDomainRule => 'Добавить правило домена';

  @override
  String get perAppProxyTitleInclude => 'Приложения через VPN';

  @override
  String get perAppProxyTitleExclude => 'Приложения в обход VPN';

  @override
  String get perAppProxySearchHint => 'Поиск приложений';

  @override
  String get perAppProxyLoadError => 'Не удалось загрузить список приложений.';

  @override
  String get perAppProxyNoResults => 'Нет подходящих приложений';

  @override
  String get browserHelperDescription =>
      'Native messaging и расширение автоматически подставляют учётные данные прокси при подключении.';

  @override
  String get panelSectionSubtitle =>
      'Сопряжение с RioNexGate для подписок, статистики и удалённых команд.';

  @override
  String get pinningSubtitle =>
      'Опциональные SPKI pin для хостов подписки (SHA-256).';

  @override
  String get pinningEnable => 'Включить pinning';

  @override
  String get pinningHost => 'Хост подписки';

  @override
  String get pinningSpki => 'SPKI pin';

  @override
  String get pinningSpkiRequired => 'Введите корректный base64 SPKI pin';

  @override
  String get censorshipEnableSubtitle =>
      'Пресеты транспорта, отпечаток и помощники маршрутизации';

  @override
  String connectionReconnectingAttempt(int current, int max) {
    return 'Переподключение ($current/$max)';
  }

  @override
  String engineAutoLabel(String engine) {
    return 'авто · $engine';
  }

  @override
  String coreEngineActiveAuto(String version) {
    return 'Авто · активно: $version';
  }

  @override
  String coreEngineActive(String version) {
    return 'Активно: $version';
  }

  @override
  String coreEngineUsesUntilAuto(String engine) {
    return 'Используется $engine до следующего авто-подключения';
  }

  @override
  String splitTunnelAppsSelectedCount(int count) {
    return 'Выбрано приложений: $count';
  }

  @override
  String censorshipCustomRoutingActiveCount(int count) {
    return 'Активных правил: $count';
  }

  @override
  String proxyCredsDescription(int port) {
    return 'HTTP-прокси на 127.0.0.1:$port — для расширения браузера или ручной настройки.';
  }

  @override
  String proxyCopied(String label) {
    return 'Скопировано: $label';
  }

  @override
  String configSubscriptionWithServer(String server) {
    return 'Подписка · $server';
  }

  @override
  String configAutomaticWithServer(String server) {
    return 'Авто · $server';
  }

  @override
  String serverNumber(int number) {
    return 'Сервер $number';
  }

  @override
  String serverOptionWithLatency(int number, String latency) {
    return 'Сервер $number · $latency';
  }

  @override
  String serverAutoLastServer(String name) {
    return 'Последний: $name · перепроверка при подключении';
  }

  @override
  String multihopEntryChain(int entry, String hops) {
    return 'Вход: Сервер $entry → $hops';
  }

  @override
  String uptimeHoursMinutes(int hours, int minutes) {
    return '$hoursч $minutesм';
  }

  @override
  String uptimeMinutesSeconds(int minutes, int seconds) {
    return '$minutesм $secondsс';
  }

  @override
  String uptimeSeconds(int seconds) {
    return '$secondsс';
  }
}
