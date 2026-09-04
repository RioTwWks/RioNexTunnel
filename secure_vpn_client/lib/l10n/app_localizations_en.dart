// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navHome => 'Home';

  @override
  String get navProfiles => 'Profiles';

  @override
  String get navSettings => 'Settings';

  @override
  String get connect => 'Connect';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get pleaseWait => 'Please wait…';

  @override
  String get tapToDisconnectSecurely => 'Tap to disconnect securely';

  @override
  String get tapToConnect => 'Tap to start protected session';

  @override
  String get establishingSecureTunnel => 'Establishing secure tunnel…';

  @override
  String get connectionDisconnected => 'Disconnected';

  @override
  String get connectionConnecting => 'Connecting';

  @override
  String get connectionConnected => 'Connected';

  @override
  String get connectionReconnecting => 'Reconnecting';

  @override
  String get connectionDisconnecting => 'Disconnecting';

  @override
  String get connectionError => 'Error';

  @override
  String get errorSelectProfileFirst => 'Select or add a profile first';

  @override
  String get statusTestingServers => 'Testing servers…';

  @override
  String get statusNoProfileSelected => 'No profile selected';

  @override
  String get statusAddProfileHint =>
      'Add a config link or subscription in Profiles';

  @override
  String get statusSubscriptionProfile => 'Subscription profile';

  @override
  String get statusDirectConfigLink => 'Direct config link';

  @override
  String get statsUpload => 'Upload';

  @override
  String get statsDownload => 'Download';

  @override
  String get statsUptime => 'Uptime';

  @override
  String get appearanceTitle => 'Appearance';

  @override
  String get appearanceSubtitle => 'Theme applies on all platforms';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get languageTitle => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageRussian => 'Русский';

  @override
  String get workModeTitle => 'Work mode';

  @override
  String get coreEngineTitle => 'Core engine';

  @override
  String get coreEngineAutoSubtitle =>
      'Auto: pick by availability, subscription format, connect fallback';

  @override
  String get coreEngineDisconnectBeforeSwitch =>
      'Disconnect VPN before switching engine';

  @override
  String get engineAuto => 'Auto';

  @override
  String get engineXray => 'Xray';

  @override
  String get engineSingbox => 'sing-box';

  @override
  String get actionOff => 'Off';

  @override
  String get actionProxy => 'Proxy';

  @override
  String get actionVpn => 'VPN';

  @override
  String get splitTunnelTitle => 'Split tunneling';

  @override
  String get splitTunnelSubtitleAndroid =>
      'Choose which apps use the VPN tunnel (Android)';

  @override
  String get splitTunnelVpnOnly => 'VPN only';

  @override
  String get splitTunnelBypass => 'Bypass';

  @override
  String get splitTunnelModeOffDesc => 'All apps use the VPN tunnel.';

  @override
  String get splitTunnelModeIncludeDesc =>
      'Whitelist: only selected apps are routed through VPN.';

  @override
  String get splitTunnelModeExcludeDesc =>
      'Blacklist: selected apps connect directly without VPN.';

  @override
  String get splitTunnelAppsUsingVpn => 'Apps using VPN';

  @override
  String get splitTunnelAppsBypassingVpn => 'Apps bypassing VPN';

  @override
  String get splitTunnelNoAppsSelected => 'No apps selected';

  @override
  String get splitTunnelReconnectAfterChange =>
      'Reconnect VPN after changing split tunnel apps.';

  @override
  String get splitTunnelDesktopBody =>
      'Desktop uses proxy mode, not a system TUN VPN. Per-app routing is controlled by each application (browser proxy settings, per-app rules, or OS firewall) — not by this app.';

  @override
  String get splitTunnelDesktopSecurity =>
      'Local SOCKS/HTTP proxies always require per-session authentication on 127.0.0.1 only. Split tunneling does not open unauthenticated ports.';

  @override
  String get killSwitchTitle => 'Kill switch';

  @override
  String get killSwitchSubtitle =>
      'Block internet when VPN or core stops unexpectedly';

  @override
  String get killSwitchStrict => 'Strict';

  @override
  String get killSwitchAdaptive => 'Adaptive';

  @override
  String get killSwitchStrictDesc =>
      'Strict blocks all outbound traffic when the tunnel or core drops.';

  @override
  String get killSwitchAdaptiveTitle => 'Adaptive (per-app)';

  @override
  String get killSwitchAdaptiveSubtitle =>
      'Requires split tunneling — available after Agent B merges';

  @override
  String get dnsAdvancedTitle => 'Advanced DNS';

  @override
  String get dnsDesktopSubtitle =>
      'Desktop proxy mode does not intercept system DNS. See docs/en/dns.md';

  @override
  String get dnsVpnSubtitle =>
      'DoH/DoT upstreams and leak protection for VPN/TUN mode';

  @override
  String get dnsDefault => 'Default';

  @override
  String get dnsCustom => 'Custom';

  @override
  String get dnsEncrypted => 'Encrypted';

  @override
  String get dnsLeakProtection => 'DNS leak protection';

  @override
  String get dnsLeakProtectionSubtitle =>
      'Route DNS through the tunnel (TUN mode)';

  @override
  String get dnsAddResolver => 'Add resolver';

  @override
  String get dnsLeakTest => 'DNS leak test';

  @override
  String get dnsInvalidAddress => 'Invalid address';

  @override
  String get dnsAddResolverTitle => 'Add DNS resolver';

  @override
  String get dnsResolverLabel => 'Label';

  @override
  String get dnsResolverAddress => 'Address';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionAdd => 'Add';

  @override
  String get actionSave => 'Save';

  @override
  String get advancedSecurityTitle => 'Advanced security';

  @override
  String get advancedSecuritySubtitle =>
      'Optional hardening for subscription fetch';

  @override
  String get censorshipResistanceTitle => 'Censorship resistance';

  @override
  String get censorshipResistanceSubtitle =>
      'Transport presets, uTLS fingerprint, RU routing';

  @override
  String get censorshipRuDirectDefault =>
      'RU sites direct (default for new profiles)';

  @override
  String get censorshipRuDirectDefaultSubtitle =>
      'When censorship wizard is enabled, route Russian sites/IP direct';

  @override
  String get censorshipCustomRouting => 'Custom routing rules';

  @override
  String get censorshipCustomRoutingEmpty =>
      'Domain, IP, geosite/geoip — import/export JSON';

  @override
  String get censorshipStackGuide => 'When to use which stack';

  @override
  String get censorshipStackGuideSubtitle =>
      'docs/en/censorship_resistance.md — REALITY vs TLS, XHTTP, mux';

  @override
  String get socksAuthTitle => 'SOCKS5 authentication';

  @override
  String get socksAuthSubtitle =>
      'Local proxy is always on 127.0.0.1 with mandatory password auth.';

  @override
  String get socksRandomPerSession => 'Random per session';

  @override
  String get socksStaticFromPanel => 'Static from panel';

  @override
  String get socksRandomDesc =>
      'New username and password on every connect (default).';

  @override
  String get socksStaticDesc =>
      'Use SOCKS credentials from RioNexGate panel JSON when available.';

  @override
  String get socksStaticUnavailable =>
      'Panel not configured or config lacks SOCKS — falls back to random.';

  @override
  String get socksDisableInjection => 'Disable SOCKS injection (advanced)';

  @override
  String get localBindTitle => 'Local bind';

  @override
  String get localBindSubtitle => '127.0.0.1 only, password required';

  @override
  String get diagnosticsTitle => 'Diagnostics';

  @override
  String get logLevelInfo => 'Info';

  @override
  String get logLevelDebug => 'Debug';

  @override
  String get viewLogs => 'View logs';

  @override
  String get logFiles => 'Log files';

  @override
  String get logResolving => 'Resolving…';

  @override
  String get logAndroidHint => 'Android also: Android/data/…/files/logs/';

  @override
  String get copyPath => 'Copy path';

  @override
  String get logPathCopied => 'Log path copied';

  @override
  String get privacyTitle => 'Privacy';

  @override
  String get privacyPolicy => 'Privacy policy';

  @override
  String get logsTitle => 'Logs';

  @override
  String get proxyCredsTitle => 'Proxy credentials';

  @override
  String get proxyCredsExtensionHint =>
      'Install the browser extension for automatic proxy authentication.';

  @override
  String get proxyUsername => 'Proxy username';

  @override
  String get proxyPassword => 'Proxy password';

  @override
  String get proxyCopyBoth => 'Copy both';

  @override
  String get browserHelperTitle => 'Browser helper';

  @override
  String get browserHelperReady => 'Ready — no login dialog';

  @override
  String get browserHelperWaiting => 'Waiting for VPN session credentials';

  @override
  String get browserHelperHostMissing => 'Native messaging host not installed';

  @override
  String get browserHelperManifestMissing => 'Browser manifest missing';

  @override
  String get browserHelperExtensionMissing =>
      'Extension not detected in browser';

  @override
  String get browserHelperLabelHost => 'Native host';

  @override
  String get browserHelperLabelManifest => 'Manifest';

  @override
  String get browserHelperLabelExtension => 'Extension';

  @override
  String get browserHelperLabelSession => 'VPN session';

  @override
  String get panelSectionTitle => 'RioNexGate (optional)';

  @override
  String get panelEnable => 'Enable panel';

  @override
  String get panelUrl => 'Panel URL';

  @override
  String get panelPairingToken => 'Pairing token';

  @override
  String get panelRegister => 'Register device';

  @override
  String get panelRefresh => 'Refresh';

  @override
  String get panelClear => 'Clear pairing';

  @override
  String get panelRegistered => 'Device registered';

  @override
  String get panelRegisterFailed => 'Registration failed';

  @override
  String get panelDeviceId => 'Device ID';

  @override
  String get panelLastSync => 'Last sync';

  @override
  String get panelSubscription => 'Subscription';

  @override
  String get panelConfigured => 'Configured';

  @override
  String get panelNotConfigured => 'Not configured';

  @override
  String get panelNever => 'Never';

  @override
  String get panelSyncDisabled => 'Disabled';

  @override
  String get panelSyncSynced => 'Synced';

  @override
  String get panelSyncStale => 'Cached (panel offline)';

  @override
  String get panelSyncOffline => 'Offline';

  @override
  String get panelSyncError => 'Error';

  @override
  String get pinningTitle => 'Certificate pinning';

  @override
  String get pinningNoSavedPins => 'No saved pins yet.';

  @override
  String get pinningAddPin => 'Add pin';

  @override
  String get pinningAddSpkiTitle => 'Add SPKI pin';

  @override
  String get pinningHostRequired => 'Enter a host';

  @override
  String get pinningRemoveHost => 'Remove host';

  @override
  String get pinningRemovePin => 'Remove pin';

  @override
  String get configAddProfile => 'Add profile';

  @override
  String get configAddProfileSubtitle =>
      'Paste a share link or subscription URL';

  @override
  String get configProfileName => 'Profile name';

  @override
  String get configLinkLabel => 'Config link (vless://, hy2://, tuic://, …)';

  @override
  String get configSubscriptionUrl => 'Subscription URL';

  @override
  String get configLink => 'Link';

  @override
  String get configSubscription => 'Subscription';

  @override
  String get configSavedProfiles => 'Saved profiles';

  @override
  String get configNoProfiles => 'No profiles yet';

  @override
  String get configNoProfilesHint =>
      'Add a link or subscription to get started';

  @override
  String get configNameLinkRequired => 'Name and config link are required';

  @override
  String get configInvalidLink => 'Invalid VPN config link';

  @override
  String get configProfileAdded => 'Profile added';

  @override
  String get configCensorshipUpdated => 'Censorship settings updated';

  @override
  String get configDirectLink => 'Direct link';

  @override
  String get configSubscriptionAutomatic => 'Subscription · Automatic';

  @override
  String get configCensorshipModeTooltip => 'Censorship mode';

  @override
  String get serverPickerTitle => 'Server';

  @override
  String get serverAutomatic => 'Automatic (best latency)';

  @override
  String get serverSelectTitle => 'Select server';

  @override
  String get serverProbeLatency => 'Test latency (URL test)';

  @override
  String get serverRefreshList => 'Refresh list';

  @override
  String get serverNoServers => 'No servers found';

  @override
  String get serverAutoRetest =>
      'Automatic: best server is re-tested on each Connect';

  @override
  String get serverAutoPickLatency =>
      'Pick the lowest-latency server on Connect';

  @override
  String get serverAutomaticLabel => 'Automatic';

  @override
  String get multihopTitle => 'Multihop (Double VPN)';

  @override
  String get multihopRouteMultiple => 'Route traffic through multiple servers';

  @override
  String get multihopSelectHops => 'Select additional hop servers';

  @override
  String get multihopEditChain => 'Edit hop chain';

  @override
  String get multihopChainTitle => 'Multihop chain';

  @override
  String get multihopRequiresTwoServers =>
      'Multihop requires at least 2 servers.';

  @override
  String get multihopSaveChain => 'Save chain';

  @override
  String get transportCustom => 'Custom';

  @override
  String get transportStandard => 'Standard';

  @override
  String get transportMux => 'mux';

  @override
  String get transportRuDirect => 'RU direct';

  @override
  String get advancedTitle => 'Advanced';

  @override
  String get censorshipWizardTitle => 'Censorship mode';

  @override
  String get censorshipSkip => 'Skip';

  @override
  String get censorshipEnable => 'Enable censorship mode';

  @override
  String get censorshipTransport => 'Transport preset';

  @override
  String get censorshipTlsFingerprint => 'TLS fingerprint';

  @override
  String get censorshipEnableMux => 'Enable mux';

  @override
  String get censorshipEnableMuxSubtitle => 'Mobile fallback — concurrency 8';

  @override
  String get censorshipRuDirect => 'RU sites direct';

  @override
  String get censorshipRuDirectSubtitle =>
      'geosite:ru / geoip:ru → direct (needs geo)';

  @override
  String get censorshipSaveProfile => 'Save profile';

  @override
  String get routingCustomTitle => 'Custom routing';

  @override
  String get routingAddDomainRule => 'Add domain rule';

  @override
  String get perAppProxyTitleInclude => 'Apps using VPN';

  @override
  String get perAppProxyTitleExclude => 'Apps bypassing VPN';

  @override
  String get perAppProxySearchHint => 'Search apps';

  @override
  String get perAppProxyLoadError => 'Could not load installed apps.';

  @override
  String get perAppProxyNoResults => 'No matching apps';

  @override
  String get browserHelperDescription =>
      'Native messaging host + extension auto-fill proxy credentials when Connected.';

  @override
  String get panelSectionSubtitle =>
      'Pair with RioNexGate for subscriptions, stats, and remote commands.';

  @override
  String get pinningSubtitle =>
      'Opt-in SPKI pins for subscription hosts (SHA-256).';

  @override
  String get pinningEnable => 'Enable pinning';

  @override
  String get pinningHost => 'Subscription host';

  @override
  String get pinningSpki => 'SPKI pin';

  @override
  String get pinningSpkiRequired => 'Enter a valid base64 SPKI pin';

  @override
  String get censorshipEnableSubtitle =>
      'Apply transport presets, fingerprint, and routing helpers';

  @override
  String connectionReconnectingAttempt(int current, int max) {
    return 'Reconnecting ($current/$max)';
  }

  @override
  String engineAutoLabel(String engine) {
    return 'auto · $engine';
  }

  @override
  String coreEngineActiveAuto(String version) {
    return 'Auto · active: $version';
  }

  @override
  String coreEngineActive(String version) {
    return 'Active: $version';
  }

  @override
  String coreEngineUsesUntilAuto(String engine) {
    return 'Uses $engine until the next Auto connect';
  }

  @override
  String splitTunnelAppsSelectedCount(int count) {
    return '$count app(s) selected';
  }

  @override
  String censorshipCustomRoutingActiveCount(int count) {
    return '$count active rule(s)';
  }

  @override
  String proxyCredsDescription(int port) {
    return 'HTTP proxy on 127.0.0.1:$port — use with browser extension or manual setup.';
  }

  @override
  String proxyCopied(String label) {
    return 'Copied $label';
  }

  @override
  String configSubscriptionWithServer(String server) {
    return 'Subscription · $server';
  }

  @override
  String configAutomaticWithServer(String server) {
    return 'Automatic · $server';
  }

  @override
  String serverNumber(int number) {
    return 'Server $number';
  }

  @override
  String serverOptionWithLatency(int number, String latency) {
    return 'Server $number · $latency';
  }

  @override
  String serverAutoLastServer(String name) {
    return 'Last: $name · re-tested on Connect';
  }

  @override
  String multihopEntryChain(int entry, String hops) {
    return 'Entry: Server $entry → $hops';
  }

  @override
  String uptimeHoursMinutes(int hours, int minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String uptimeMinutesSeconds(int minutes, int seconds) {
    return '${minutes}m ${seconds}s';
  }

  @override
  String uptimeSeconds(int seconds) {
    return '${seconds}s';
  }
}
