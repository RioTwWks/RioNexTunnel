#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path('/workspace/secure_vpn_client')
L10N = ROOT / 'lib/l10n'
L10N.mkdir(parents=True, exist_ok=True)

# All EN/RU strings - compact tuples (key, en, ru)
T = [
("navHome","Home","Главная"),("navProfiles","Profiles","Профили"),("navSettings","Settings","Настройки"),
("connect","Connect","Подключить"),("disconnect","Disconnect","Отключить"),("pleaseWait","Please wait…","Подождите…"),
("tapToDisconnectSecurely","Tap to disconnect securely","Нажмите для безопасного отключения"),
("tapToConnect","Tap to start protected session","Нажмите для защищённого подключения"),
("establishingSecureTunnel","Establishing secure tunnel…","Установка защищённого туннеля…"),
("connectionDisconnected","Disconnected","Отключено"),("connectionConnecting","Connecting","Подключение"),
("connectionConnected","Connected","Подключено"),("connectionReconnecting","Reconnecting","Переподключение"),
("connectionDisconnecting","Disconnecting","Отключение"),("connectionError","Error","Ошибка"),
("errorSelectProfileFirst","Select or add a profile first","Сначала выберите или добавьте профиль"),
("statusTestingServers","Testing servers…","Проверка серверов…"),
("statusNoProfileSelected","No profile selected","Профиль не выбран"),
("statusAddProfileHint","Add a config link or subscription in Profiles","Добавьте ссылку или подписку в разделе Профили"),
("statusSubscriptionProfile","Subscription profile","Профиль подписки"),
("statusDirectConfigLink","Direct config link","Прямая ссылка конфигурации"),
("statsUpload","Upload","Отдача"),("statsDownload","Download","Загрузка"),("statsUptime","Uptime","Время сессии"),
("appearanceTitle","Appearance","Внешний вид"),("appearanceSubtitle","Theme applies on all platforms","Тема применяется на всех платформах"),
("themeSystem","System","Системная"),("themeLight","Light","Светлая"),("themeDark","Dark","Тёмная"),
("languageTitle","Language","Язык"),("languageSystem","System","Системный"),("languageEnglish","English","English"),("languageRussian","Русский","Русский"),
("workModeTitle","Work mode","Режим работы"),("coreEngineTitle","Core engine","Ядро"),
("coreEngineAutoSubtitle","Auto: pick by availability, subscription format, connect fallback","Авто: по доступности, формату подписки и резерву при подключении"),
("coreEngineDisconnectBeforeSwitch","Disconnect VPN before switching engine","Отключите VPN перед сменой ядра"),
("engineAuto","Auto","Авто"),("engineXray","Xray","Xray"),("engineSingbox","sing-box","sing-box"),
("actionOff","Off","Выкл"),("actionProxy","Proxy","Прокси"),("actionVpn","VPN","VPN"),
("splitTunnelTitle","Split tunneling","Раздельное туннелирование"),
("splitTunnelSubtitleAndroid","Choose which apps use the VPN tunnel (Android)","Выберите приложения для VPN-туннеля (Android)"),
("splitTunnelVpnOnly","VPN only","Только VPN"),("splitTunnelBypass","Bypass","Обход"),
("splitTunnelModeOffDesc","All apps use the VPN tunnel.","Все приложения используют VPN-туннель."),
("splitTunnelModeIncludeDesc","Whitelist: only selected apps are routed through VPN.","Белый список: только выбранные приложения идут через VPN."),
("splitTunnelModeExcludeDesc","Blacklist: selected apps connect directly without VPN.","Чёрный список: выбранные приложения подключаются напрямую."),
("splitTunnelAppsUsingVpn","Apps using VPN","Приложения через VPN"),
("splitTunnelAppsBypassingVpn","Apps bypassing VPN","Приложения в обход VPN"),
("splitTunnelNoAppsSelected","No apps selected","Приложения не выбраны"),
("splitTunnelReconnectAfterChange","Reconnect VPN after changing split tunnel apps.","Переподключите VPN после изменения списка приложений."),
("splitTunnelDesktopBody","Desktop uses proxy mode, not a system TUN VPN. Per-app routing is controlled by each application (browser proxy settings, per-app rules, or OS firewall) — not by this app.","На десктопе используется режим прокси, а не системный TUN VPN. Маршрутизация по приложениям настраивается в каждом приложении — не в этом клиенте."),
("splitTunnelDesktopSecurity","Local SOCKS/HTTP proxies always require per-session authentication on 127.0.0.1 only. Split tunneling does not open unauthenticated ports.","Локальные SOCKS/HTTP прокси всегда требуют аутентификацию на сессию только на 127.0.0.1."),
("killSwitchTitle","Kill switch","Аварийное отключение"),
("killSwitchSubtitle","Block internet when VPN or core stops unexpectedly","Блокировать интернет при неожиданной остановке VPN или ядра"),
("killSwitchStrict","Strict","Строгий"),("killSwitchAdaptive","Adaptive","Адаптивный"),
("killSwitchStrictDesc","Strict blocks all outbound traffic when the tunnel or core drops.","Строгий режим блокирует весь исходящий трафик при падении туннеля или ядра."),
("killSwitchAdaptiveTitle","Adaptive (per-app)","Адаптивный (по приложениям)"),
("killSwitchAdaptiveSubtitle","Requires split tunneling — available after Agent B merges","Требует раздельного туннелирования — будет доступен позже"),
("dnsAdvancedTitle","Advanced DNS","Расширенный DNS"),
("dnsDesktopSubtitle","Desktop proxy mode does not intercept system DNS. See docs/en/dns.md","В режиме прокси на десктопе системный DNS не перехватывается. См. docs/ru/dns.md"),
("dnsVpnSubtitle","DoH/DoT upstreams and leak protection for VPN/TUN mode","DoH/DoT и защита от утечек DNS в режиме VPN/TUN"),
("dnsDefault","Default","По умолчанию"),("dnsCustom","Custom","Свой"),("dnsEncrypted","Encrypted","Шифрованный"),
("dnsLeakProtection","DNS leak protection","Защита от утечек DNS"),
("dnsLeakProtectionSubtitle","Route DNS through the tunnel (TUN mode)","Направлять DNS через туннель (режим TUN)"),
("dnsAddResolver","Add resolver","Добавить резолвер"),("dnsLeakTest","DNS leak test","Тест утечки DNS"),
("dnsInvalidAddress","Invalid address","Неверный адрес"),("dnsAddResolverTitle","Add DNS resolver","Добавить DNS-резолвер"),
("dnsResolverLabel","Label","Метка"),("dnsResolverAddress","Address","Адрес"),
("actionCancel","Cancel","Отмена"),("actionAdd","Add","Добавить"),("actionSave","Save","Сохранить"),
("advancedSecurityTitle","Advanced security","Расширенная безопасность"),
("advancedSecuritySubtitle","Optional hardening for subscription fetch","Дополнительная защита при загрузке подписки"),
("censorshipResistanceTitle","Censorship resistance","Обход цензуры"),
("censorshipResistanceSubtitle","Transport presets, uTLS fingerprint, RU routing","Пресеты транспорта, uTLS, маршрутизация RU"),
("censorshipRuDirectDefault","RU sites direct (default for new profiles)","RU-сайты напрямую (по умолчанию для новых профилей)"),
("censorshipRuDirectDefaultSubtitle","When censorship wizard is enabled, route Russian sites/IP direct","При включённом мастере — российские сайты/IP напрямую"),
("censorshipCustomRouting","Custom routing rules","Свои правила маршрутизации"),
("censorshipCustomRoutingEmpty","Domain, IP, geosite/geoip — import/export JSON","Домен, IP, geosite/geoip — импорт/экспорт JSON"),
("censorshipStackGuide","When to use which stack","Какой стек когда использовать"),
("censorshipStackGuideSubtitle","docs/en/censorship_resistance.md — REALITY vs TLS, XHTTP, mux","docs/ru/censorship_resistance.md — REALITY vs TLS, XHTTP, mux"),
("socksAuthTitle","SOCKS5 authentication","SOCKS5 аутентификация"),
("socksAuthSubtitle","Local proxy is always on 127.0.0.1 with mandatory password auth.","Локальный прокси всегда на 127.0.0.1 с обязательным паролем."),
("socksRandomPerSession","Random per session","Случайные на сессию"),("socksStaticFromPanel","Static from panel","Статичные из панели"),
("socksRandomDesc","New username and password on every connect (default).","Новый логин и пароль при каждом подключении (по умолчанию)."),
("socksStaticDesc","Use SOCKS credentials from RioNexGate panel JSON when available.","Использовать SOCKS из JSON панели RioNexGate, если указаны."),
("socksStaticUnavailable","Panel not configured or config lacks SOCKS — falls back to random.","Панель не настроена или в конфиге нет SOCKS — будет случайный режим."),
("socksDisableInjection","Disable SOCKS injection (advanced)","Отключить подмену SOCKS (расширенное)"),
("localBindTitle","Local bind","Привязка"),("localBindSubtitle","127.0.0.1 only, password required","Только 127.0.0.1, пароль обязателен"),
("diagnosticsTitle","Diagnostics","Диагностика"),("logLevelInfo","Info","Info"),("logLevelDebug","Debug","Debug"),
("viewLogs","View logs","Просмотр логов"),("logFiles","Log files","Файлы логов"),
("logResolving","Resolving…","Определение…"),("logAndroidHint","Android also: Android/data/…/files/logs/","На Android также: Android/data/…/files/logs/"),
("copyPath","Copy path","Копировать путь"),("logPathCopied","Log path copied","Путь к логам скопирован"),
("privacyTitle","Privacy","Конфиденциальность"),("privacyPolicy","Privacy policy","Политика конфиденциальности"),("logsTitle","Logs","Логи"),
("proxyCredsTitle","Proxy credentials","Учётные данные прокси"),
("proxyCredsExtensionHint","Install the browser extension for automatic proxy authentication.","Установите расширение браузера для автоматической аутентификации прокси."),
("proxyUsername","Proxy username","Имя пользователя прокси"),("proxyPassword","Proxy password","Пароль прокси"),
("proxyCopyBoth","Copy both","Копировать оба"),
("browserHelperTitle","Browser helper","Помощник браузера"),
("browserHelperReady","Ready — no login dialog","Готово — диалог не нужен"),
("browserHelperWaiting","Waiting for VPN session credentials","Ожидание учётных данных VPN-сессии"),
("browserHelperHostMissing","Native messaging host not installed","Native messaging host не установлен"),
("browserHelperManifestMissing","Browser manifest missing","Манифест браузера отсутствует"),
("browserHelperExtensionMissing","Extension not detected in browser","Расширение не обнаружено в браузере"),
("browserHelperLabelHost","Native host","Native host"),("browserHelperLabelManifest","Manifest","Манифест"),
("browserHelperLabelExtension","Extension","Расширение"),("browserHelperLabelSession","VPN session","Сессия VPN"),
("panelSectionTitle","RioNexGate (optional)","RioNexGate (опционально)"),
("panelEnable","Enable panel","Включить панель"),("panelUrl","Panel URL","URL панели"),
("panelPairingToken","Pairing token","Токен сопряжения"),("panelRegister","Register device","Зарегистрировать"),
("panelRefresh","Refresh","Обновить"),("panelClear","Clear pairing","Сбросить"),
("panelRegistered","Device registered","Устройство зарегистрировано"),("panelRegisterFailed","Registration failed","Ошибка регистрации"),
("panelDeviceId","Device ID","ID устройства"),("panelLastSync","Last sync","Последняя синхронизация"),
("panelSubscription","Subscription","Подписка"),("panelConfigured","Configured","Настроено"),
("panelNotConfigured","Not configured","Не настроено"),("panelNever","Never","Никогда"),
("panelSyncDisabled","Disabled","Отключено"),("panelSyncSynced","Synced","Синхронизировано"),
("panelSyncStale","Cached (panel offline)","Кэш (панель недоступна)"),("panelSyncOffline","Offline","Нет сети"),("panelSyncError","Error","Ошибка"),
("pinningTitle","Certificate pinning","Закрепление сертификата"),
("pinningNoSavedPins","No saved pins yet.","Нет сохранённых pin."),("pinningAddPin","Add pin","Добавить pin"),
("pinningAddSpkiTitle","Add SPKI pin","Добавить SPKI pin"),("pinningHostRequired","Enter a host","Укажите хост"),
("pinningRemoveHost","Remove host","Удалить хост"),("pinningRemovePin","Remove pin","Удалить pin"),
("configAddProfile","Add profile","Добавить профиль"),
("configAddProfileSubtitle","Paste a share link or subscription URL","Вставьте ссылку или URL подписки"),
("configProfileName","Profile name","Имя профиля"),
("configLinkLabel","Config link (vless://, hy2://, tuic://, …)","Ссылка конфигурации (vless://, hy2://, tuic://, …)"),
("configSubscriptionUrl","Subscription URL","URL подписки"),("configLink","Link","Ссылка"),("configSubscription","Subscription","Подписка"),
("configSavedProfiles","Saved profiles","Сохранённые профили"),("configNoProfiles","No profiles yet","Профилей пока нет"),
("configNoProfilesHint","Add a link or subscription to get started","Добавьте ссылку или подписку для начала"),
("configNameLinkRequired","Name and config link are required","Укажите имя и ссылку конфигурации"),
("configInvalidLink","Invalid VPN config link","Недействительная ссылка VPN"),
("configProfileAdded","Profile added","Профиль добавлен"),
("configCensorshipUpdated","Censorship settings updated","Настройки цензуры обновлены"),
("configDirectLink","Direct link","Прямая ссылка"),("configSubscriptionAutomatic","Subscription · Automatic","Подписка · Авто"),
("configCensorshipModeTooltip","Censorship mode","Режим обхода цензуры"),
("serverPickerTitle","Server","Сервер"),("serverAutomatic","Automatic (best latency)","Авто (лучшая задержка)"),
("serverSelectTitle","Select server","Выбор сервера"),("serverProbeLatency","Test latency (URL test)","Проверить задержку (URL test)"),
("serverRefreshList","Refresh list","Обновить список"),("serverNoServers","No servers found","Серверы не найдены"),
("serverAutoRetest","Automatic: best server is re-tested on each Connect","Авто: лучший сервер перепроверяется при каждом подключении"),
("serverAutoPickLatency","Pick the lowest-latency server on Connect","Выбор сервера с наименьшей задержкой при подключении"),
("serverAutomaticLabel","Automatic","Автоматически"),
("multihopTitle","Multihop (Double VPN)","Multihop (Double VPN)"),
("multihopRouteMultiple","Route traffic through multiple servers","Маршрутизация через несколько серверов"),
("multihopSelectHops","Select additional hop servers","Выберите дополнительные серверы"),
("multihopEditChain","Edit hop chain","Изменить цепочку"),("multihopChainTitle","Multihop chain","Цепочка multihop"),
("multihopRequiresTwoServers","Multihop requires at least 2 servers.","Multihop требует минимум 2 сервера."),
("multihopSaveChain","Save chain","Сохранить цепочку"),
("transportCustom","Custom","Свой"),("transportStandard","Standard","Стандарт"),("transportMux","mux","mux"),("transportRuDirect","RU direct","RU напрямую"),
("advancedTitle","Advanced","Расширенные"),
("censorshipWizardTitle","Censorship mode","Режим обхода цензуры"),("censorshipSkip","Skip","Пропустить"),
("censorshipEnable","Enable censorship mode","Включить режим обхода цензуры"),
("censorshipTransport","Transport preset","Пресет транспорта"),("censorshipTlsFingerprint","TLS fingerprint","TLS fingerprint"),
("censorshipEnableMux","Enable mux","Включить mux"),
("censorshipEnableMuxSubtitle","Mobile fallback — concurrency 8","Резерв для мобильных — concurrency 8"),
("censorshipRuDirect","RU sites direct","RU-сайты напрямую"),
("censorshipRuDirectSubtitle","geosite:ru / geoip:ru → direct (needs geo)","geosite:ru / geoip:ru → direct (нужны geo)"),
("censorshipSaveProfile","Save profile","Сохранить профиль"),
("routingCustomTitle","Custom routing","Своя маршрутизация"),("routingAddDomainRule","Add domain rule","Добавить правило домена"),
("perAppProxyTitleInclude","Apps using VPN","Приложения через VPN"),
("perAppProxyTitleExclude","Apps bypassing VPN","Приложения в обход VPN"),
("perAppProxySearchHint","Search apps","Поиск приложений"),
("perAppProxyLoadError","Could not load installed apps.","Не удалось загрузить список приложений."),
("perAppProxyNoResults","No matching apps","Нет подходящих приложений"),
]

META = {
"connectionReconnectingAttempt": {"placeholders":{"current":{"type":"int"},"max":{"type":"int"}}},
"engineAutoLabel": {"placeholders":{"engine":{"type":"String"}}},
"coreEngineActiveAuto": {"placeholders":{"version":{"type":"String"}}},
"coreEngineActive": {"placeholders":{"version":{"type":"String"}}},
"coreEngineUsesUntilAuto": {"placeholders":{"engine":{"type":"String"}}},
"splitTunnelAppsSelectedCount": {"placeholders":{"count":{"type":"int"}}},
"censorshipCustomRoutingActiveCount": {"placeholders":{"count":{"type":"int"}}},
"proxyCredsDescription": {"placeholders":{"port":{"type":"int"}}},
"proxyCopied": {"placeholders":{"label":{"type":"String"}}},
"configSubscriptionWithServer": {"placeholders":{"server":{"type":"String"}}},
"configAutomaticWithServer": {"placeholders":{"server":{"type":"String"}}},
"serverNumber": {"placeholders":{"number":{"type":"int"}}},
"serverOptionWithLatency": {"placeholders":{"number":{"type":"int"},"latency":{"type":"String"}}},
"serverAutoLastServer": {"placeholders":{"name":{"type":"String"}}},
"multihopEntryChain": {"placeholders":{"entry":{"type":"int"},"hops":{"type":"String"}}},
"uptimeHoursMinutes": {"placeholders":{"hours":{"type":"int"},"minutes":{"type":"int"}}},
"uptimeMinutesSeconds": {"placeholders":{"minutes":{"type":"int"},"seconds":{"type":"int"}}},
"uptimeSeconds": {"placeholders":{"seconds":{"type":"int"}}},
}

# Parameterized strings with EN templates
PARAM = {
"connectionReconnectingAttempt": ("Reconnecting ({current}/{max})", "Переподключение ({current}/{max})"),
"engineAutoLabel": ("auto · {engine}", "авто · {engine}"),
"coreEngineActiveAuto": ("Auto · active: {version}", "Авто · активно: {version}"),
"coreEngineActive": ("Active: {version}", "Активно: {version}"),
"coreEngineUsesUntilAuto": ("Uses {engine} until the next Auto connect", "Используется {engine} до следующего авто-подключения"),
"splitTunnelAppsSelectedCount": ("{count} app(s) selected", "Выбрано приложений: {count}"),
"censorshipCustomRoutingActiveCount": ("{count} active rule(s)", "Активных правил: {count}"),
"proxyCredsDescription": ("HTTP proxy on 127.0.0.1:{port} — use with browser extension or manual setup.", "HTTP-прокси на 127.0.0.1:{port} — для расширения браузера или ручной настройки."),
"proxyCopied": ("Copied {label}", "Скопировано: {label}"),
"configSubscriptionWithServer": ("Subscription · {server}", "Подписка · {server}"),
"configAutomaticWithServer": ("Automatic · {server}", "Авто · {server}"),
"serverNumber": ("Server {number}", "Сервер {number}"),
"serverOptionWithLatency": ("Server {number} · {latency}", "Сервер {number} · {latency}"),
"serverAutoLastServer": ("Last: {name} · re-tested on Connect", "Последний: {name} · перепроверка при подключении"),
"multihopEntryChain": ("Entry: Server {entry} → {hops}", "Вход: Сервер {entry} → {hops}"),
"uptimeHoursMinutes": ("{hours}h {minutes}m", "{hours}ч {minutes}м"),
"uptimeMinutesSeconds": ("{minutes}m {seconds}s", "{minutes}м {seconds}с"),
"uptimeSeconds": ("{seconds}s", "{seconds}с"),
}

browser_desc_en = "Native messaging host + extension auto-fill proxy credentials when Connected."
browser_desc_ru = "Native messaging и расширение автоматически подставляют учётные данные прокси при подключении."
panel_sub_en = "Pair with RioNexGate for subscriptions, stats, and remote commands."
panel_sub_ru = "Сопряжение с RioNexGate для подписок, статистики и удалённых команд."
pinning_sub_en = "Opt-in SPKI pins for subscription hosts (SHA-256)."
pinning_sub_ru = "Опциональные SPKI pin для хостов подписки (SHA-256)."
pinning_enable_en = "Enable pinning"
pinning_enable_ru = "Включить pinning"
pinning_host_en = "Subscription host"
pinning_host_ru = "Хост подписки"
pinning_spki_en = "SPKI pin"
pinning_spki_ru = "SPKI pin"
pinning_spki_req_en = "Enter a valid base64 SPKI pin"
pinning_spki_req_ru = "Введите корректный base64 SPKI pin"
censorship_enable_sub_en = "Apply transport presets, fingerprint, and routing helpers"
censorship_enable_sub_ru = "Пресеты транспорта, отпечаток и помощники маршрутизации"

EXTRA = [
("browserHelperDescription", browser_desc_en, browser_desc_ru),
("panelSectionSubtitle", panel_sub_en, panel_sub_ru),
("pinningSubtitle", pinning_sub_en, pinning_sub_ru),
("pinningEnable", pinning_enable_en, pinning_enable_ru),
("pinningHost", pinning_host_en, pinning_host_ru),
("pinningSpki", pinning_spki_en, pinning_spki_ru),
("pinningSpkiRequired", pinning_spki_req_en, pinning_spki_req_ru),
("censorshipEnableSubtitle", censorship_enable_sub_en, censorship_enable_sub_ru),
]

def build(lang):
    arb = {"@@locale": lang}
    for k, en, ru in T + EXTRA:
        arb[k] = en if lang == "en" else ru
    for k, (en, ru) in PARAM.items():
        arb[k] = en if lang == "en" else ru
        if lang == "en":
            arb[f"@{k}"] = META[k]
    return arb

(L10N / "app_en.arb").write_text(json.dumps(build("en"), ensure_ascii=False, indent=2) + "\n")
(L10N / "app_ru.arb").write_text(json.dumps(build("ru"), ensure_ascii=False, indent=2) + "\n")
print(f"Wrote {len(T)+len(EXTRA)+len(PARAM)} keys")
