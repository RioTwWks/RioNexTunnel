import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navProfiles.
  ///
  /// In en, this message translates to:
  /// **'Profiles'**
  String get navProfiles;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @pleaseWait.
  ///
  /// In en, this message translates to:
  /// **'Please wait…'**
  String get pleaseWait;

  /// No description provided for @tapToDisconnectSecurely.
  ///
  /// In en, this message translates to:
  /// **'Tap to disconnect securely'**
  String get tapToDisconnectSecurely;

  /// No description provided for @tapToConnect.
  ///
  /// In en, this message translates to:
  /// **'Tap to start protected session'**
  String get tapToConnect;

  /// No description provided for @establishingSecureTunnel.
  ///
  /// In en, this message translates to:
  /// **'Establishing secure tunnel…'**
  String get establishingSecureTunnel;

  /// No description provided for @connectionDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get connectionDisconnected;

  /// No description provided for @connectionConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get connectionConnecting;

  /// No description provided for @connectionConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connectionConnected;

  /// No description provided for @connectionReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting'**
  String get connectionReconnecting;

  /// No description provided for @connectionDisconnecting.
  ///
  /// In en, this message translates to:
  /// **'Disconnecting'**
  String get connectionDisconnecting;

  /// No description provided for @connectionError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get connectionError;

  /// No description provided for @errorSelectProfileFirst.
  ///
  /// In en, this message translates to:
  /// **'Select or add a profile first'**
  String get errorSelectProfileFirst;

  /// No description provided for @statusTestingServers.
  ///
  /// In en, this message translates to:
  /// **'Testing servers…'**
  String get statusTestingServers;

  /// No description provided for @statusNoProfileSelected.
  ///
  /// In en, this message translates to:
  /// **'No profile selected'**
  String get statusNoProfileSelected;

  /// No description provided for @statusAddProfileHint.
  ///
  /// In en, this message translates to:
  /// **'Add a config link or subscription in Profiles'**
  String get statusAddProfileHint;

  /// No description provided for @statusSubscriptionProfile.
  ///
  /// In en, this message translates to:
  /// **'Subscription profile'**
  String get statusSubscriptionProfile;

  /// No description provided for @statusDirectConfigLink.
  ///
  /// In en, this message translates to:
  /// **'Direct config link'**
  String get statusDirectConfigLink;

  /// No description provided for @statsUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get statsUpload;

  /// No description provided for @statsDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get statsDownload;

  /// No description provided for @statsUptime.
  ///
  /// In en, this message translates to:
  /// **'Uptime'**
  String get statsUptime;

  /// No description provided for @appearanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceTitle;

  /// No description provided for @appearanceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Theme applies on all platforms'**
  String get appearanceSubtitle;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @languageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTitle;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageRussian.
  ///
  /// In en, this message translates to:
  /// **'Русский'**
  String get languageRussian;

  /// No description provided for @workModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Work mode'**
  String get workModeTitle;

  /// No description provided for @coreEngineTitle.
  ///
  /// In en, this message translates to:
  /// **'Core engine'**
  String get coreEngineTitle;

  /// No description provided for @coreEngineAutoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Auto: pick by availability, subscription format, connect fallback'**
  String get coreEngineAutoSubtitle;

  /// No description provided for @coreEngineDisconnectBeforeSwitch.
  ///
  /// In en, this message translates to:
  /// **'Disconnect VPN before switching engine'**
  String get coreEngineDisconnectBeforeSwitch;

  /// No description provided for @engineAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get engineAuto;

  /// No description provided for @engineXray.
  ///
  /// In en, this message translates to:
  /// **'Xray'**
  String get engineXray;

  /// No description provided for @engineSingbox.
  ///
  /// In en, this message translates to:
  /// **'sing-box'**
  String get engineSingbox;

  /// No description provided for @actionOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get actionOff;

  /// No description provided for @actionProxy.
  ///
  /// In en, this message translates to:
  /// **'Proxy'**
  String get actionProxy;

  /// No description provided for @actionVpn.
  ///
  /// In en, this message translates to:
  /// **'VPN'**
  String get actionVpn;

  /// No description provided for @splitTunnelTitle.
  ///
  /// In en, this message translates to:
  /// **'Split tunneling'**
  String get splitTunnelTitle;

  /// No description provided for @splitTunnelSubtitleAndroid.
  ///
  /// In en, this message translates to:
  /// **'Choose which apps use the VPN tunnel (Android)'**
  String get splitTunnelSubtitleAndroid;

  /// No description provided for @splitTunnelVpnOnly.
  ///
  /// In en, this message translates to:
  /// **'VPN only'**
  String get splitTunnelVpnOnly;

  /// No description provided for @splitTunnelBypass.
  ///
  /// In en, this message translates to:
  /// **'Bypass'**
  String get splitTunnelBypass;

  /// No description provided for @splitTunnelModeOffDesc.
  ///
  /// In en, this message translates to:
  /// **'All apps use the VPN tunnel.'**
  String get splitTunnelModeOffDesc;

  /// No description provided for @splitTunnelModeIncludeDesc.
  ///
  /// In en, this message translates to:
  /// **'Whitelist: only selected apps are routed through VPN.'**
  String get splitTunnelModeIncludeDesc;

  /// No description provided for @splitTunnelModeExcludeDesc.
  ///
  /// In en, this message translates to:
  /// **'Blacklist: selected apps connect directly without VPN.'**
  String get splitTunnelModeExcludeDesc;

  /// No description provided for @splitTunnelAppsUsingVpn.
  ///
  /// In en, this message translates to:
  /// **'Apps using VPN'**
  String get splitTunnelAppsUsingVpn;

  /// No description provided for @splitTunnelAppsBypassingVpn.
  ///
  /// In en, this message translates to:
  /// **'Apps bypassing VPN'**
  String get splitTunnelAppsBypassingVpn;

  /// No description provided for @splitTunnelNoAppsSelected.
  ///
  /// In en, this message translates to:
  /// **'No apps selected'**
  String get splitTunnelNoAppsSelected;

  /// No description provided for @splitTunnelReconnectAfterChange.
  ///
  /// In en, this message translates to:
  /// **'Reconnect VPN after changing split tunnel apps.'**
  String get splitTunnelReconnectAfterChange;

  /// No description provided for @splitTunnelDesktopBody.
  ///
  /// In en, this message translates to:
  /// **'Desktop uses proxy mode, not a system TUN VPN. Per-app routing is controlled by each application (browser proxy settings, per-app rules, or OS firewall) — not by this app.'**
  String get splitTunnelDesktopBody;

  /// No description provided for @splitTunnelDesktopSecurity.
  ///
  /// In en, this message translates to:
  /// **'Local SOCKS/HTTP proxies always require per-session authentication on 127.0.0.1 only. Split tunneling does not open unauthenticated ports.'**
  String get splitTunnelDesktopSecurity;

  /// No description provided for @killSwitchTitle.
  ///
  /// In en, this message translates to:
  /// **'Kill switch'**
  String get killSwitchTitle;

  /// No description provided for @killSwitchSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Block internet when VPN or core stops unexpectedly'**
  String get killSwitchSubtitle;

  /// No description provided for @killSwitchStrict.
  ///
  /// In en, this message translates to:
  /// **'Strict'**
  String get killSwitchStrict;

  /// No description provided for @killSwitchAdaptive.
  ///
  /// In en, this message translates to:
  /// **'Adaptive'**
  String get killSwitchAdaptive;

  /// No description provided for @killSwitchStrictDesc.
  ///
  /// In en, this message translates to:
  /// **'Strict blocks all outbound traffic when the tunnel or core drops.'**
  String get killSwitchStrictDesc;

  /// No description provided for @killSwitchAdaptiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Adaptive (per-app)'**
  String get killSwitchAdaptiveTitle;

  /// No description provided for @killSwitchAdaptiveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure which apps use the VPN in Split tunneling below.'**
  String get killSwitchAdaptiveSubtitle;

  /// No description provided for @killSwitchAdaptiveDesc.
  ///
  /// In en, this message translates to:
  /// **'When the tunnel or core drops, only VPN-routed apps lose network access. Other apps keep working.'**
  String get killSwitchAdaptiveDesc;

  /// No description provided for @killSwitchAdaptiveDesktopNote.
  ///
  /// In en, this message translates to:
  /// **'Per-app blocking is only available in VPN (TUN) mode on Android. On desktop proxy mode, use Strict for OS-level blocking.'**
  String get killSwitchAdaptiveDesktopNote;

  /// No description provided for @killSwitchAdaptiveIosNote.
  ///
  /// In en, this message translates to:
  /// **'iOS does not support per-app split tunneling; Adaptive behaves like Strict on iOS.'**
  String get killSwitchAdaptiveIosNote;

  /// No description provided for @killSwitchAdaptiveNoApps.
  ///
  /// In en, this message translates to:
  /// **'No apps selected in Split tunneling — Adaptive falls back to full-tunnel blocking.'**
  String get killSwitchAdaptiveNoApps;

  /// No description provided for @killSwitchAdaptiveSplitTunnelLink.
  ///
  /// In en, this message translates to:
  /// **'Uses Split tunneling app list'**
  String get killSwitchAdaptiveSplitTunnelLink;

  /// No description provided for @dnsAdvancedTitle.
  ///
  /// In en, this message translates to:
  /// **'Advanced DNS'**
  String get dnsAdvancedTitle;

  /// No description provided for @dnsDesktopSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Desktop proxy mode does not intercept system DNS. See docs/en/dns.md'**
  String get dnsDesktopSubtitle;

  /// No description provided for @dnsVpnSubtitle.
  ///
  /// In en, this message translates to:
  /// **'DoH/DoT upstreams and leak protection for VPN/TUN mode'**
  String get dnsVpnSubtitle;

  /// No description provided for @dnsDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get dnsDefault;

  /// No description provided for @dnsCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get dnsCustom;

  /// No description provided for @dnsEncrypted.
  ///
  /// In en, this message translates to:
  /// **'Encrypted'**
  String get dnsEncrypted;

  /// No description provided for @dnsLeakProtection.
  ///
  /// In en, this message translates to:
  /// **'DNS leak protection'**
  String get dnsLeakProtection;

  /// No description provided for @dnsLeakProtectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Route DNS through the tunnel (TUN mode)'**
  String get dnsLeakProtectionSubtitle;

  /// No description provided for @dnsAddResolver.
  ///
  /// In en, this message translates to:
  /// **'Add resolver'**
  String get dnsAddResolver;

  /// No description provided for @dnsLeakTest.
  ///
  /// In en, this message translates to:
  /// **'DNS leak test'**
  String get dnsLeakTest;

  /// No description provided for @dnsInvalidAddress.
  ///
  /// In en, this message translates to:
  /// **'Invalid address'**
  String get dnsInvalidAddress;

  /// No description provided for @dnsAddResolverTitle.
  ///
  /// In en, this message translates to:
  /// **'Add DNS resolver'**
  String get dnsAddResolverTitle;

  /// No description provided for @dnsResolverLabel.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get dnsResolverLabel;

  /// No description provided for @dnsResolverAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get dnsResolverAddress;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get actionAdd;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @advancedSecurityTitle.
  ///
  /// In en, this message translates to:
  /// **'Advanced security'**
  String get advancedSecurityTitle;

  /// No description provided for @advancedSecuritySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Optional hardening for subscription fetch'**
  String get advancedSecuritySubtitle;

  /// No description provided for @censorshipResistanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Censorship resistance'**
  String get censorshipResistanceTitle;

  /// No description provided for @censorshipResistanceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Transport presets, uTLS fingerprint, RU routing'**
  String get censorshipResistanceSubtitle;

  /// No description provided for @censorshipRuDirectDefault.
  ///
  /// In en, this message translates to:
  /// **'RU sites direct (default for new profiles)'**
  String get censorshipRuDirectDefault;

  /// No description provided for @censorshipRuDirectDefaultSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When censorship wizard is enabled, route Russian sites/IP direct'**
  String get censorshipRuDirectDefaultSubtitle;

  /// No description provided for @censorshipCustomRouting.
  ///
  /// In en, this message translates to:
  /// **'Custom routing rules'**
  String get censorshipCustomRouting;

  /// No description provided for @censorshipCustomRoutingEmpty.
  ///
  /// In en, this message translates to:
  /// **'Domain, IP, geosite/geoip — import/export JSON'**
  String get censorshipCustomRoutingEmpty;

  /// No description provided for @censorshipStackGuide.
  ///
  /// In en, this message translates to:
  /// **'When to use which stack'**
  String get censorshipStackGuide;

  /// No description provided for @censorshipStackGuideSubtitle.
  ///
  /// In en, this message translates to:
  /// **'docs/en/censorship_resistance.md — REALITY vs TLS, XHTTP, mux'**
  String get censorshipStackGuideSubtitle;

  /// No description provided for @socksAuthTitle.
  ///
  /// In en, this message translates to:
  /// **'SOCKS5 authentication'**
  String get socksAuthTitle;

  /// No description provided for @socksAuthSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Local proxy is always on 127.0.0.1 with mandatory password auth.'**
  String get socksAuthSubtitle;

  /// No description provided for @socksRandomPerSession.
  ///
  /// In en, this message translates to:
  /// **'Random per session'**
  String get socksRandomPerSession;

  /// No description provided for @socksStaticFromPanel.
  ///
  /// In en, this message translates to:
  /// **'Static from panel'**
  String get socksStaticFromPanel;

  /// No description provided for @socksRandomDesc.
  ///
  /// In en, this message translates to:
  /// **'New username and password on every connect (default).'**
  String get socksRandomDesc;

  /// No description provided for @socksStaticDesc.
  ///
  /// In en, this message translates to:
  /// **'Use SOCKS credentials from RioNexGate panel JSON when available.'**
  String get socksStaticDesc;

  /// No description provided for @socksStaticUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Panel not configured or config lacks SOCKS — falls back to random.'**
  String get socksStaticUnavailable;

  /// No description provided for @socksDisableInjection.
  ///
  /// In en, this message translates to:
  /// **'Disable SOCKS injection (advanced)'**
  String get socksDisableInjection;

  /// No description provided for @localBindTitle.
  ///
  /// In en, this message translates to:
  /// **'Local bind'**
  String get localBindTitle;

  /// No description provided for @localBindSubtitle.
  ///
  /// In en, this message translates to:
  /// **'127.0.0.1 only, password required'**
  String get localBindSubtitle;

  /// No description provided for @diagnosticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get diagnosticsTitle;

  /// No description provided for @logLevelInfo.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get logLevelInfo;

  /// No description provided for @logLevelDebug.
  ///
  /// In en, this message translates to:
  /// **'Debug'**
  String get logLevelDebug;

  /// No description provided for @viewLogs.
  ///
  /// In en, this message translates to:
  /// **'View logs'**
  String get viewLogs;

  /// No description provided for @logFiles.
  ///
  /// In en, this message translates to:
  /// **'Log files'**
  String get logFiles;

  /// No description provided for @logResolving.
  ///
  /// In en, this message translates to:
  /// **'Resolving…'**
  String get logResolving;

  /// No description provided for @logAndroidHint.
  ///
  /// In en, this message translates to:
  /// **'Android also: Android/data/…/files/logs/'**
  String get logAndroidHint;

  /// No description provided for @copyPath.
  ///
  /// In en, this message translates to:
  /// **'Copy path'**
  String get copyPath;

  /// No description provided for @logPathCopied.
  ///
  /// In en, this message translates to:
  /// **'Log path copied'**
  String get logPathCopied;

  /// No description provided for @privacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacyTitle;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacyPolicy;

  /// No description provided for @logsTitle.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get logsTitle;

  /// No description provided for @proxyCredsTitle.
  ///
  /// In en, this message translates to:
  /// **'Proxy credentials'**
  String get proxyCredsTitle;

  /// No description provided for @proxyCredsExtensionHint.
  ///
  /// In en, this message translates to:
  /// **'Install the browser extension for automatic proxy authentication.'**
  String get proxyCredsExtensionHint;

  /// No description provided for @proxyUsername.
  ///
  /// In en, this message translates to:
  /// **'Proxy username'**
  String get proxyUsername;

  /// No description provided for @proxyPassword.
  ///
  /// In en, this message translates to:
  /// **'Proxy password'**
  String get proxyPassword;

  /// No description provided for @proxyCopyBoth.
  ///
  /// In en, this message translates to:
  /// **'Copy both'**
  String get proxyCopyBoth;

  /// No description provided for @browserHelperTitle.
  ///
  /// In en, this message translates to:
  /// **'Browser helper'**
  String get browserHelperTitle;

  /// No description provided for @browserHelperReady.
  ///
  /// In en, this message translates to:
  /// **'Ready — no login dialog'**
  String get browserHelperReady;

  /// No description provided for @browserHelperWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for VPN session credentials'**
  String get browserHelperWaiting;

  /// No description provided for @browserHelperHostMissing.
  ///
  /// In en, this message translates to:
  /// **'Native messaging host not installed'**
  String get browserHelperHostMissing;

  /// No description provided for @browserHelperManifestMissing.
  ///
  /// In en, this message translates to:
  /// **'Browser manifest missing'**
  String get browserHelperManifestMissing;

  /// No description provided for @browserHelperExtensionMissing.
  ///
  /// In en, this message translates to:
  /// **'Extension not detected in browser'**
  String get browserHelperExtensionMissing;

  /// No description provided for @browserHelperLabelHost.
  ///
  /// In en, this message translates to:
  /// **'Native host'**
  String get browserHelperLabelHost;

  /// No description provided for @browserHelperLabelManifest.
  ///
  /// In en, this message translates to:
  /// **'Manifest'**
  String get browserHelperLabelManifest;

  /// No description provided for @browserHelperLabelExtension.
  ///
  /// In en, this message translates to:
  /// **'Extension'**
  String get browserHelperLabelExtension;

  /// No description provided for @browserHelperLabelSession.
  ///
  /// In en, this message translates to:
  /// **'VPN session'**
  String get browserHelperLabelSession;

  /// No description provided for @panelSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'RioNexGate (optional)'**
  String get panelSectionTitle;

  /// No description provided for @panelEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable panel'**
  String get panelEnable;

  /// No description provided for @panelUrl.
  ///
  /// In en, this message translates to:
  /// **'Panel URL'**
  String get panelUrl;

  /// No description provided for @panelPairingToken.
  ///
  /// In en, this message translates to:
  /// **'Pairing token'**
  String get panelPairingToken;

  /// No description provided for @panelRegister.
  ///
  /// In en, this message translates to:
  /// **'Register device'**
  String get panelRegister;

  /// No description provided for @panelRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get panelRefresh;

  /// No description provided for @panelClear.
  ///
  /// In en, this message translates to:
  /// **'Clear pairing'**
  String get panelClear;

  /// No description provided for @panelRegistered.
  ///
  /// In en, this message translates to:
  /// **'Device registered'**
  String get panelRegistered;

  /// No description provided for @panelRegisterFailed.
  ///
  /// In en, this message translates to:
  /// **'Registration failed'**
  String get panelRegisterFailed;

  /// No description provided for @panelDeviceId.
  ///
  /// In en, this message translates to:
  /// **'Device ID'**
  String get panelDeviceId;

  /// No description provided for @panelLastSync.
  ///
  /// In en, this message translates to:
  /// **'Last sync'**
  String get panelLastSync;

  /// No description provided for @panelSubscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get panelSubscription;

  /// No description provided for @panelConfigured.
  ///
  /// In en, this message translates to:
  /// **'Configured'**
  String get panelConfigured;

  /// No description provided for @panelNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get panelNotConfigured;

  /// No description provided for @panelNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get panelNever;

  /// No description provided for @panelSyncDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get panelSyncDisabled;

  /// No description provided for @panelSyncSynced.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get panelSyncSynced;

  /// No description provided for @panelSyncStale.
  ///
  /// In en, this message translates to:
  /// **'Cached (panel offline)'**
  String get panelSyncStale;

  /// No description provided for @panelSyncOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get panelSyncOffline;

  /// No description provided for @panelSyncError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get panelSyncError;

  /// No description provided for @panelSyncInterval.
  ///
  /// In en, this message translates to:
  /// **'Config sync interval'**
  String get panelSyncInterval;

  /// No description provided for @pinningTitle.
  ///
  /// In en, this message translates to:
  /// **'Certificate pinning'**
  String get pinningTitle;

  /// No description provided for @pinningNoSavedPins.
  ///
  /// In en, this message translates to:
  /// **'No saved pins yet.'**
  String get pinningNoSavedPins;

  /// No description provided for @pinningAddPin.
  ///
  /// In en, this message translates to:
  /// **'Add pin'**
  String get pinningAddPin;

  /// No description provided for @pinningAddSpkiTitle.
  ///
  /// In en, this message translates to:
  /// **'Add SPKI pin'**
  String get pinningAddSpkiTitle;

  /// No description provided for @pinningHostRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a host'**
  String get pinningHostRequired;

  /// No description provided for @pinningRemoveHost.
  ///
  /// In en, this message translates to:
  /// **'Remove host'**
  String get pinningRemoveHost;

  /// No description provided for @pinningRemovePin.
  ///
  /// In en, this message translates to:
  /// **'Remove pin'**
  String get pinningRemovePin;

  /// No description provided for @configAddProfile.
  ///
  /// In en, this message translates to:
  /// **'Add profile'**
  String get configAddProfile;

  /// No description provided for @configAddProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Paste a share link or subscription URL'**
  String get configAddProfileSubtitle;

  /// No description provided for @configProfileName.
  ///
  /// In en, this message translates to:
  /// **'Profile name'**
  String get configProfileName;

  /// No description provided for @configLinkLabel.
  ///
  /// In en, this message translates to:
  /// **'Config link (vless://, hy2://, tuic://, …)'**
  String get configLinkLabel;

  /// No description provided for @configSubscriptionUrl.
  ///
  /// In en, this message translates to:
  /// **'Subscription URL'**
  String get configSubscriptionUrl;

  /// No description provided for @configLink.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get configLink;

  /// No description provided for @configSubscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get configSubscription;

  /// No description provided for @configSavedProfiles.
  ///
  /// In en, this message translates to:
  /// **'Saved profiles'**
  String get configSavedProfiles;

  /// No description provided for @configNoProfiles.
  ///
  /// In en, this message translates to:
  /// **'No profiles yet'**
  String get configNoProfiles;

  /// No description provided for @configNoProfilesHint.
  ///
  /// In en, this message translates to:
  /// **'Add a link or subscription to get started'**
  String get configNoProfilesHint;

  /// No description provided for @configNameLinkRequired.
  ///
  /// In en, this message translates to:
  /// **'Name and config link are required'**
  String get configNameLinkRequired;

  /// No description provided for @configInvalidLink.
  ///
  /// In en, this message translates to:
  /// **'Invalid VPN config link'**
  String get configInvalidLink;

  /// No description provided for @configProfileAdded.
  ///
  /// In en, this message translates to:
  /// **'Profile added'**
  String get configProfileAdded;

  /// No description provided for @configCensorshipUpdated.
  ///
  /// In en, this message translates to:
  /// **'Censorship settings updated'**
  String get configCensorshipUpdated;

  /// No description provided for @configDirectLink.
  ///
  /// In en, this message translates to:
  /// **'Direct link'**
  String get configDirectLink;

  /// No description provided for @configSubscriptionAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Subscription · Automatic'**
  String get configSubscriptionAutomatic;

  /// No description provided for @configCensorshipModeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Censorship mode'**
  String get configCensorshipModeTooltip;

  /// No description provided for @serverPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get serverPickerTitle;

  /// No description provided for @serverAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic (best latency)'**
  String get serverAutomatic;

  /// No description provided for @serverSelectTitle.
  ///
  /// In en, this message translates to:
  /// **'Select server'**
  String get serverSelectTitle;

  /// No description provided for @serverProbeLatency.
  ///
  /// In en, this message translates to:
  /// **'Test latency (URL test)'**
  String get serverProbeLatency;

  /// No description provided for @serverRefreshList.
  ///
  /// In en, this message translates to:
  /// **'Refresh list'**
  String get serverRefreshList;

  /// No description provided for @serverNoServers.
  ///
  /// In en, this message translates to:
  /// **'No servers found'**
  String get serverNoServers;

  /// No description provided for @serverAutoRetest.
  ///
  /// In en, this message translates to:
  /// **'Automatic: best server is re-tested on each Connect'**
  String get serverAutoRetest;

  /// No description provided for @serverAutoPickLatency.
  ///
  /// In en, this message translates to:
  /// **'Pick the lowest-latency server on Connect'**
  String get serverAutoPickLatency;

  /// No description provided for @serverAutomaticLabel.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get serverAutomaticLabel;

  /// No description provided for @multihopTitle.
  ///
  /// In en, this message translates to:
  /// **'Multihop (Double VPN)'**
  String get multihopTitle;

  /// No description provided for @multihopRouteMultiple.
  ///
  /// In en, this message translates to:
  /// **'Route traffic through multiple servers'**
  String get multihopRouteMultiple;

  /// No description provided for @multihopSelectHops.
  ///
  /// In en, this message translates to:
  /// **'Select additional hop servers'**
  String get multihopSelectHops;

  /// No description provided for @multihopEditChain.
  ///
  /// In en, this message translates to:
  /// **'Edit hop chain'**
  String get multihopEditChain;

  /// No description provided for @multihopChainTitle.
  ///
  /// In en, this message translates to:
  /// **'Multihop chain'**
  String get multihopChainTitle;

  /// No description provided for @multihopRequiresTwoServers.
  ///
  /// In en, this message translates to:
  /// **'Multihop requires at least 2 servers.'**
  String get multihopRequiresTwoServers;

  /// No description provided for @multihopSaveChain.
  ///
  /// In en, this message translates to:
  /// **'Save chain'**
  String get multihopSaveChain;

  /// No description provided for @transportCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get transportCustom;

  /// No description provided for @transportStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get transportStandard;

  /// No description provided for @transportMux.
  ///
  /// In en, this message translates to:
  /// **'mux'**
  String get transportMux;

  /// No description provided for @transportRuDirect.
  ///
  /// In en, this message translates to:
  /// **'RU direct'**
  String get transportRuDirect;

  /// No description provided for @advancedTitle.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advancedTitle;

  /// No description provided for @advancedSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Kill switch, DNS, routing, split tunnel, censorship'**
  String get advancedSettingsSubtitle;

  /// No description provided for @censorshipWizardTitle.
  ///
  /// In en, this message translates to:
  /// **'Censorship mode'**
  String get censorshipWizardTitle;

  /// No description provided for @censorshipSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get censorshipSkip;

  /// No description provided for @censorshipEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable censorship mode'**
  String get censorshipEnable;

  /// No description provided for @censorshipTransport.
  ///
  /// In en, this message translates to:
  /// **'Transport preset'**
  String get censorshipTransport;

  /// No description provided for @censorshipTlsFingerprint.
  ///
  /// In en, this message translates to:
  /// **'TLS fingerprint'**
  String get censorshipTlsFingerprint;

  /// No description provided for @censorshipEnableMux.
  ///
  /// In en, this message translates to:
  /// **'Enable mux'**
  String get censorshipEnableMux;

  /// No description provided for @censorshipEnableMuxSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Mobile fallback — concurrency 8'**
  String get censorshipEnableMuxSubtitle;

  /// No description provided for @censorshipRuDirect.
  ///
  /// In en, this message translates to:
  /// **'RU sites direct'**
  String get censorshipRuDirect;

  /// No description provided for @censorshipRuDirectSubtitle.
  ///
  /// In en, this message translates to:
  /// **'geosite:ru / geoip:ru → direct (needs geo)'**
  String get censorshipRuDirectSubtitle;

  /// No description provided for @censorshipSaveProfile.
  ///
  /// In en, this message translates to:
  /// **'Save profile'**
  String get censorshipSaveProfile;

  /// No description provided for @routingCustomTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom routing'**
  String get routingCustomTitle;

  /// No description provided for @routingAddDomainRule.
  ///
  /// In en, this message translates to:
  /// **'Add domain rule'**
  String get routingAddDomainRule;

  /// No description provided for @perAppProxyTitleInclude.
  ///
  /// In en, this message translates to:
  /// **'Apps using VPN'**
  String get perAppProxyTitleInclude;

  /// No description provided for @perAppProxyTitleExclude.
  ///
  /// In en, this message translates to:
  /// **'Apps bypassing VPN'**
  String get perAppProxyTitleExclude;

  /// No description provided for @perAppProxySearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search apps'**
  String get perAppProxySearchHint;

  /// No description provided for @perAppProxyLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load installed apps.'**
  String get perAppProxyLoadError;

  /// No description provided for @perAppProxyNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matching apps'**
  String get perAppProxyNoResults;

  /// No description provided for @browserHelperDescription.
  ///
  /// In en, this message translates to:
  /// **'Native messaging host + extension auto-fill proxy credentials when Connected.'**
  String get browserHelperDescription;

  /// No description provided for @panelSectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pair with RioNexGate for subscriptions, stats, and remote commands.'**
  String get panelSectionSubtitle;

  /// No description provided for @pinningSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Opt-in SPKI pins for subscription hosts (SHA-256).'**
  String get pinningSubtitle;

  /// No description provided for @pinningEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable pinning'**
  String get pinningEnable;

  /// No description provided for @pinningHost.
  ///
  /// In en, this message translates to:
  /// **'Subscription host'**
  String get pinningHost;

  /// No description provided for @pinningSpki.
  ///
  /// In en, this message translates to:
  /// **'SPKI pin'**
  String get pinningSpki;

  /// No description provided for @pinningSpkiRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid base64 SPKI pin'**
  String get pinningSpkiRequired;

  /// No description provided for @censorshipEnableSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Apply transport presets, fingerprint, and routing helpers'**
  String get censorshipEnableSubtitle;

  /// No description provided for @connectionReconnectingAttempt.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting ({current}/{max})'**
  String connectionReconnectingAttempt(int current, int max);

  /// No description provided for @engineAutoLabel.
  ///
  /// In en, this message translates to:
  /// **'auto · {engine}'**
  String engineAutoLabel(String engine);

  /// No description provided for @coreEngineActiveAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto · active: {version}'**
  String coreEngineActiveAuto(String version);

  /// No description provided for @coreEngineActive.
  ///
  /// In en, this message translates to:
  /// **'Active: {version}'**
  String coreEngineActive(String version);

  /// No description provided for @coreEngineUsesUntilAuto.
  ///
  /// In en, this message translates to:
  /// **'Uses {engine} until the next Auto connect'**
  String coreEngineUsesUntilAuto(String engine);

  /// No description provided for @splitTunnelAppsSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} app(s) selected'**
  String splitTunnelAppsSelectedCount(int count);

  /// No description provided for @censorshipCustomRoutingActiveCount.
  ///
  /// In en, this message translates to:
  /// **'{count} active rule(s)'**
  String censorshipCustomRoutingActiveCount(int count);

  /// No description provided for @proxyCredsDescription.
  ///
  /// In en, this message translates to:
  /// **'HTTP proxy on 127.0.0.1:{port} — use with browser extension or manual setup.'**
  String proxyCredsDescription(int port);

  /// No description provided for @proxyCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied {label}'**
  String proxyCopied(String label);

  /// No description provided for @configSubscriptionWithServer.
  ///
  /// In en, this message translates to:
  /// **'Subscription · {server}'**
  String configSubscriptionWithServer(String server);

  /// No description provided for @configAutomaticWithServer.
  ///
  /// In en, this message translates to:
  /// **'Automatic · {server}'**
  String configAutomaticWithServer(String server);

  /// No description provided for @serverNumber.
  ///
  /// In en, this message translates to:
  /// **'Server {number}'**
  String serverNumber(int number);

  /// No description provided for @serverOptionWithLatency.
  ///
  /// In en, this message translates to:
  /// **'Server {number} · {latency}'**
  String serverOptionWithLatency(int number, String latency);

  /// No description provided for @serverAutoLastServer.
  ///
  /// In en, this message translates to:
  /// **'Last: {name} · re-tested on Connect'**
  String serverAutoLastServer(String name);

  /// No description provided for @multihopEntryChain.
  ///
  /// In en, this message translates to:
  /// **'Entry: Server {entry} → {hops}'**
  String multihopEntryChain(int entry, String hops);

  /// No description provided for @uptimeHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m'**
  String uptimeHoursMinutes(int hours, int minutes);

  /// No description provided for @uptimeMinutesSeconds.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m {seconds}s'**
  String uptimeMinutesSeconds(int minutes, int seconds);

  /// No description provided for @uptimeSeconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String uptimeSeconds(int seconds);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
